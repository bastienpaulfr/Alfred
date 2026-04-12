#!/usr/bin/env bash
set -euo pipefail

# git-clean-branches — Remove local branches with no corresponding remote branch.
# Usage: git-clean-branches.sh [-c config] [-n] [-f] [-h] <repo-path>
#   <repo-path> Path to the git repository to clean (required)
#   -c config   Path to whitelist config file (default: .git-clean-branches.conf
#               in repo root, then ~/.git-clean-branches.conf, then the bundled
#               git-clean-branches.conf next to this script)
#   -n          Dry run — show what would be deleted without deleting
#   -f          Force delete (git branch -D) instead of safe delete (git branch -d)
#   -h          Show this help

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false
FORCE=false
CONFIG_FILE=""

usage() {
    sed -n '3,11s/^# \?//p' "${BASH_SOURCE[0]}"
    exit 0
}

while getopts "c:nfh" opt; do
    case "$opt" in
        c) CONFIG_FILE="$OPTARG" ;;
        n) DRY_RUN=true ;;
        f) FORCE=true ;;
        h) usage ;;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))

# Repo path is a required positional argument
REPO_PATH="${1:-}"
if [[ -z "$REPO_PATH" ]]; then
    echo "Error: missing required <repo-path> argument." >&2
    usage
fi

# Resolve to absolute path
REPO_PATH="$(cd "$REPO_PATH" 2>/dev/null && pwd)" || {
    echo "Error: '$1' is not a valid directory." >&2
    exit 1
}

# Helper: run git commands against the target repo
git() { command git -C "$REPO_PATH" "$@"; }

# Ensure it's a git repo
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "Error: '$REPO_PATH' is not a git repository." >&2
    exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
echo "Target repo: $REPO_ROOT"

# Resolve config file: explicit flag > repo-local > home > bundled
if [[ -z "$CONFIG_FILE" ]]; then
    if [[ -f "$REPO_ROOT/.git-clean-branches.conf" ]]; then
        CONFIG_FILE="$REPO_ROOT/.git-clean-branches.conf"
    elif [[ -f "$HOME/.git-clean-branches.conf" ]]; then
        CONFIG_FILE="$HOME/.git-clean-branches.conf"
    elif [[ -f "$SCRIPT_DIR/git-clean-branches.conf" ]]; then
        CONFIG_FILE="$SCRIPT_DIR/git-clean-branches.conf"
    fi
fi

# Load whitelist patterns from config
WHITELIST_PATTERNS=()
if [[ -n "$CONFIG_FILE" && -f "$CONFIG_FILE" ]]; then
    while IFS= read -r line; do
        # Skip comments and empty lines
        line="${line%%#*}"
        line="$(echo "$line" | xargs)" # trim whitespace
        [[ -z "$line" ]] && continue
        WHITELIST_PATTERNS+=("$line")
    done < "$CONFIG_FILE"
fi

# Always protect the current branch and the default branch
CURRENT_BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null || true)"

is_whitelisted() {
    local branch="$1"

    # Current branch is always protected
    if [[ "$branch" == "$CURRENT_BRANCH" ]]; then
        return 0
    fi

    # Check against whitelist patterns (glob matching)
    for pattern in "${WHITELIST_PATTERNS[@]+"${WHITELIST_PATTERNS[@]}"}"; do
        # shellcheck disable=SC2254
        case "$branch" in
            $pattern) return 0 ;;
        esac
    done

    return 1
}

# Fetch latest remote state (prune stale tracking refs)
echo "Fetching remotes and pruning stale references..."
git fetch --all --prune --quiet

# Build newline-separated list of remote branch names (without the remote/ prefix)
REMOTE_BRANCHES=""
while IFS= read -r ref; do
    [[ -z "$ref" ]] && continue
    # Strip "origin/", "upstream/", etc. — keep everything after first /
    branch="${ref#*/}"
    REMOTE_BRANCHES="${REMOTE_BRANCHES}${branch}"$'\n'
done < <(git branch -r --format='%(refname:short)')

has_remote() {
    local needle="$1"
    local entry
    while IFS= read -r entry; do
        [[ "$entry" == "$needle" ]] && return 0
    done <<< "$REMOTE_BRANCHES"
    return 1
}

# Collect local branches to delete
TO_DELETE=()
SKIPPED_WHITELIST=()

while IFS= read -r branch; do
    [[ -z "$branch" ]] && continue

    # Skip if it exists on any remote
    if has_remote "$branch"; then
        continue
    fi

    # Skip if whitelisted
    if is_whitelisted "$branch"; then
        SKIPPED_WHITELIST+=("$branch")
        continue
    fi

    TO_DELETE+=("$branch")
done < <(git branch --format='%(refname:short)')

# Report whitelisted skips
if [[ ${#SKIPPED_WHITELIST[@]} -gt 0 ]]; then
    echo ""
    echo "Whitelisted (skipped):"
    for b in "${SKIPPED_WHITELIST[@]}"; do
        echo "  ~ $b"
    done
fi

# Delete or report
if [[ ${#TO_DELETE[@]} -eq 0 ]]; then
    echo ""
    echo "Nothing to clean — all local branches have a remote or are whitelisted."
    exit 0
fi

echo ""
echo "Branches to delete (${#TO_DELETE[@]}):"
for b in "${TO_DELETE[@]}"; do
    echo "  - $b"
done

DELETE_FLAG="-d"
$FORCE && DELETE_FLAG="-D"

if $DRY_RUN; then
    echo ""
    echo "Dry run — no branches were deleted."
    exit 0
fi

echo ""
read -rp "Proceed with deletion? [y/N] " answer
if [[ ! "$answer" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Deleting branches..."
DELETED=0
FAILED=()
for branch in "${TO_DELETE[@]}"; do
    if git branch "$DELETE_FLAG" "$branch" 2>/dev/null; then
        echo "  - $branch"
        ((DELETED++))
    else
        FAILED+=("$branch")
    fi
done

# Report failures (unmerged branches when not using -f)
if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo ""
    echo "Failed to delete (not fully merged — use -f to force):"
    for b in "${FAILED[@]}"; do
        echo "  ! $b"
    done
fi

if ! $DRY_RUN; then
    echo ""
    echo "Done. Deleted $DELETED branch(es)."
fi
