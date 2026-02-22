# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Overload::FileCheck is a Perl XS module that hooks into Perl's OP dispatch mechanism to mock file check operators (-e, -f, -d, -s, etc.) and stat/lstat at the interpreter level. Designed for unit testing scenarios where you need to simulate filesystem conditions without real files.

## Build & Test Commands

```bash
# Build (compiles XS/C code)
perl Makefile.PL && make

# Run full test suite
make test

# Run a single test
prove -lv t/02_basic-mock.t

# Author testing via Dist::Zilla
dzil test

# Build a release
dzil build
```

Makefile.PL is auto-generated from dist.ini — edit dist.ini for build configuration, not Makefile.PL directly.

## Architecture

### Two-layer design

**Perl layer** (`lib/Overload/FileCheck.pm`): Public API — `mock_file_check`, `mock_stat`, `mock_lstat`, `mock_all_file_checks`, `mock_all_from_stat`, and their `unmock_*` counterparts. Manages the mapping from operator names (e.g., '-e') to Perl OP types (e.g., `OP_FTIS`). Provides export groups `:check` (return value constants), `:stat` (stat index constants and helpers like `stat_as_file()`), and `:all`.

**XS layer** (`FileCheck.xs` + `FileCheck.h`): Replaces Perl's default `pp_*` OP handlers with custom ones that call back into Perl. Three handler types: `pp_overload_ft_yes_no` (boolean ops like -e, -f), `pp_overload_ft_int`/`pp_overload_ft_nv` (numeric ops like -s, -M), and `pp_overload_stat` (stat/lstat). `FileCheck.h` contains compatibility macros for Perl 5.14 vs 5.15+ internal API differences.

### Return value protocol

Mock callbacks return: `CHECK_IS_TRUE` (1), `CHECK_IS_FALSE` (0), or `FALLBACK_TO_REAL_OP` (-1) for boolean ops. Numeric ops (-s, -M, -C, -A) return the actual value. Stat mocks return an arrayref of 13 elements (or empty arrayref for "file not found").

### Test structure

Tests in `t/` use Test2 framework. Many test files for individual operators (test-e.t, test-f.t, etc.) are symlinks to template files (`test-true-false.t` for boolean ops, `test-integer.t` for numeric ops) — the test determines which operator to exercise based on its own filename.

## Key Conventions

- Minimum Perl version: **5.010** (enforced in dist.ini and CI)
- CI tests across Perl 5.10 through latest dev release
- Operators accepted with or without dash: `'-e'` and `'e'` are equivalent
- Code style: PerlTidy with 2-space indent (see `tidyall.ini`), PerlCritic severity 3
- Distribution managed with **Dist::Zilla** (`dist.ini`); `[@Git]` plugin handles version tagging and push
