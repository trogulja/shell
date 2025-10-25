<!--
Sync Impact Report - Constitution v1.0.0
================================================================================
Version Change: [TEMPLATE] → 1.0.0 (Initial constitution ratification)

Modified Principles:
- (None - initial creation from template)

Added Sections:
- Core Principles (all 5 principles defined)
- Script Organization (folder conventions and structure)
- Testing Standards (ShellSpec testing requirements)
- Governance (amendment process and compliance rules)

Removed Sections:
- (None - initial creation)

Templates Status:
✅ spec-template.md - Aligned with test-first principle, supports independent testable user stories
✅ tasks-template.md - Aligned with library-first and independent testing principles, organized by user stories
✅ plan-template.md - Aligned with shell script project structure (bin/, automation/, spec/)

Suggested Commit Message:
docs: ratify constitution v1.0.0 (establish P-Scripts governance and principles)
================================================================================
-->

# P-Scripts Constitution

## Core Principles

### I. Library-First Architecture

Shared functionality MUST be extracted into libraries before duplication occurs.

**Rules:**
- Common code patterns appearing in 2+ scripts MUST be moved to `bin/p-common.zsh`
- Library functions MUST be self-contained and independently testable
- Each library function MUST have a clear, singular purpose (no organizational-only functions)
- Scripts MUST source the library with: `source "${0:A:h}/p-common.zsh"`
- Library changes MUST maintain backward compatibility or document breaking changes
- New shared utilities MUST be added to `p-common.zsh` with corresponding tests

**Rationale:** Eliminates code duplication, ensures single source of truth, enables testing of actual implementations rather than copies, and improves maintainability across all scripts.

### II. Script Interface Standards

Scripts MUST follow consistent I/O patterns based on their intended usage context.

**Rules:**
- **Personal tools** (`bin/`): Interactive CLI flags, colored human-readable output to stdout, designed for manual use with Productive repos and tools
- **Automation scripts** (`automation/`): Non-interactive operation, machine-parseable output, suitable for CI/CD pipelines and remote execution
- **All scripts**: Errors to stderr with appropriate exit codes, `--help`/`-h` flag required
- **Exit codes**: 0 for success, 1 for general errors, 2+ for specific error conditions (must be documented in help text)
- **Structured output**: When providing machine-readable data, use JSON or clearly delimited text to stdout
- **Color usage**: Personal tools may use colors (via `p-common.zsh` utilities), automation scripts must not depend on ANSI codes for parsing

**Rationale:** Clear separation between interactive and automation contexts ensures scripts are fit for purpose. Predictable interfaces enable composition, debugging, and reliable automation.

### III. Test-First Development (NON-NEGOTIABLE)

Tests MUST be written and approved before implementation begins.

**Rules:**
- **Workflow**: Write tests → Run tests (RED) → Implement → Run tests (GREEN) → Refactor
- **Test location**: All tests in `spec/` directory, named `[script-name]_spec.sh` or `[library-name]_spec.sh`
- **Test execution**: Run via `make test` (all tests), `make test-[name]` (specific file), or `make test find` (interactive selection)
- **Coverage requirements**: Library functions MUST have unit tests; Scripts MUST have integration tests
- **Test quality**: Tests MUST verify actual behavior using real implementations (use ShellSpec `Include` directive), not mock copies
- **No exceptions**: Features, bug fixes, and refactors without tests cannot be merged

**Rationale:** TDD ensures correctness, prevents regressions, documents expected behavior, enables confident refactoring, and serves as living documentation for script behavior.

### IV. Mock Real-World Dependencies

Tests MUST NOT touch real system state, external services, or persistent data.

**Rules:**
- **Temporary resources**: Use `$SHELLSPEC_TMPBASE` for all temporary test files and directories
- **Command mocking**: Mock external commands by creating temporary wrapper scripts in test-specific `$PATH`
- **Environment isolation**: Use `BeforeEach`/`After` hooks to set up and tear down isolated test environments
- **External services**: Mock AWS, git, APIs, and other external services with fake implementations (see `spec/paws_spec.sh` for pattern)
- **Cleanup**: All mocks and temporary resources MUST be cleaned up in `After` hooks
- **Determinism**: Tests must produce identical results on every run, regardless of external state

**Rationale:** Tests must be fast, reliable, safe, and repeatable without side effects, external dependencies, or environmental assumptions.

### V. Simplicity and Shell Conventions

Code MUST prioritize clarity, maintainability, and idiomatic zsh patterns.

**Rules:**
- **Dependencies**: Use zsh built-ins and standard POSIX utilities; avoid unnecessary external dependencies
- **Utilities**: Prefer simple text processing (`grep`, `sed`, `awk`) over heavy dependencies (e.g., `jq` is optional, not required)
- **Styling**: Use `p-common.zsh` functions for colors and formatting; no raw ANSI codes in scripts
- **Error handling**: Use library functions (e.g., `die()`) for consistent error messages
- **Function size**: Keep functions small (<50 lines), single-purpose, with descriptive names
- **Comments**: Document "why" not "what"; code should be self-explanatory
- **YAGNI**: Don't add features or abstractions until they're needed; start simple and evolve based on actual usage

**Rationale:** Simple, idiomatic code is maintainable code. Shell scripts should leverage shell strengths and avoid unnecessary complexity.

## Script Organization

Scripts MUST follow the project's organizational structure by usage context.

**Directory Structure:**
- **`bin/`** — Personal CLI tools for interactive use with Productive repos and workflows
  - Executable shell scripts (chmod +x, shebang `#!/usr/bin/env zsh`)
  - `bin/p-common.zsh` — Shared library functions (sourced, not executed)
- **`automation/`** — Non-interactive scripts for CI/CD pipelines, remote execution, and automation
  - Designed for unattended operation
  - Machine-parseable output
- **`spec/`** — ShellSpec test files (pattern: `*_spec.sh`)
  - `spec/spec_helper.sh` — Test utilities and common test setup
- **`.shellspec`** — ShellSpec configuration (test runner settings)
- **`Makefile`** — Test execution interface

**Sourcing Convention:**
Scripts in `bin/` that need shared utilities MUST source the library using:
```zsh
source "${0:A:h}/p-common.zsh"
```

This uses zsh parameter expansion to construct an absolute path relative to the script's location.

## Testing Standards

All code changes MUST include corresponding test updates.

**Test Organization:**
- **Unit tests**: Test library functions (`p-common.zsh`) in isolation using ShellSpec `Include` directive
- **Integration tests**: Test complete script behavior with mocked external dependencies
- **Test structure**: Use `Describe` for logical grouping, `It` for specific test cases
- **Setup/teardown**: Use `BeforeEach`/`After` for test setup and cleanup
- **Test naming**: Use descriptive `It` blocks that read as specifications (e.g., "exits with status 1 when authentication fails")

**Test Execution:**
- **All tests**: `make test` — runs entire test suite (must pass before commit)
- **Specific test**: `make test-[script-name]` — runs single test file
- **Interactive**: `make test find` — uses fzf for test file selection
- **CI/CD**: All tests run automatically on push (when CI is configured)

**Test Quality Standards:**
- Tests MUST verify actual implementation code, not test-local copies
- Tests MUST be deterministic (no time-based, random, or environment-dependent failures)
- Tests MUST clean up all temporary resources (files, directories, environment variables)
- Test failures MUST provide clear, actionable error messages
- Tests MUST run quickly (<10 seconds for full suite under normal conditions)

**ShellSpec Resources:**
- Documentation: https://github.com/shellspec/shellspec
- Use `Include` directive to source actual library code in tests
- Use `$SHELLSPEC_TMPBASE` for all temporary test resources
- Mock external commands by prepending to `$PATH` in test setup

## Governance

This constitution defines the non-negotiable standards for the P-Scripts project.

**Amendment Process:**
- Constitution changes require explicit documentation of rationale in Sync Impact Report
- Version bumps follow semantic versioning:
  - **MAJOR**: Backward-incompatible governance changes, principle removals, or fundamental redefinitions
  - **MINOR**: New principles added, new sections added, or material expansion of guidance
  - **PATCH**: Clarifications, wording improvements, typo fixes, non-semantic refinements
- All amendments MUST include updated Sync Impact Report at top of constitution file
- After amendments, all templates in `.specify/templates/` MUST be reviewed for consistency

**Compliance Requirements:**
- All code changes MUST comply with core principles
- Principle violations MUST be explicitly justified in writing and documented
- Test failures block all merges (no exceptions)
- Complexity increases MUST be justified against Simplicity principle
- README MUST be maintained and kept current with project structure and conventions

**Runtime Development:**
- Refer to `.specify/templates/` for feature development workflows
- Use `/speckit` commands for guided development processes
- Constitution supersedes all other documentation in case of conflicts
- When in doubt, prioritize simplicity and testability

**Version**: 1.0.0 | **Ratified**: 2025-10-19 | **Last Amended**: 2025-10-19
