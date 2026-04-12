# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is Alfred

Alfred is a personal collection of standalone shell scripts and utilities for macOS developer workflows. There is no build system, test suite, or package manager — each script is self-contained.

## Repository structure

- `scripts/` — General-purpose dev utilities (git branch cleanup, cache cleaning)
- `photobackup/` — Android device media management via ADB

## Conventions

- Scripts use `#!/usr/bin/env bash` with `set -euo pipefail`
- Each script includes a usage header comment block and a `usage()` function
- Scripts support `--dry-run` / `-n` flags where destructive operations are involved
- Interactive confirmation is required before deleting anything
