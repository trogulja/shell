# P-Scripts

A collection of zsh scripts for streamlined development workflows with Productive repositories. These scripts handle common tasks like AWS authentication, opening PRs, checking CI status, and navigating test runners.

<p align="center">
  <img src="./docs/combo.svg">
</p>

## Overview

P-Scripts provides two types of tools:

- **Development Scripts** (`bin/`) - Interactive CLI tools designed for manual use during development
- **Automation Scripts** (`automation/`) - Non-interactive scripts designed for CI/CD pipelines and remote execution

All scripts follow consistent interfaces with proper error handling, help documentation, and colored output for easy parsing.

---

### Main Scripts

<details>
  <summary><code>p</code> - smart repository dispatcher</summary>

  Automatically detects which Productive repository you're in and runs the appropriate startup script. Works from any subdirectory within a repository. Supports `productiveio/frontend`, `productiveio/api`, and `productiveio/ai-agent`.

  <p align="center">
    <img src="./docs/p.svg">
  </p>
</details>

<details>
  <summary><code>paws</code> - aws smart login</summary>

  Intelligently manages AWS SSO authentication with automatic session refresh and expiration detection.

  <p align="center">
    <img src="./docs/paws.svg">
  </p>
</details>

<details>
  <summary><code>pci</code> - open semaphore test start webpage</summary>

  Opens the CI workflow runner (Semaphore) for the current git branch in your browser. Asks are you sure before opening for protected branches.

  <p align="center">
    <img src="./docs/pci.svg">
  </p>
</details>

<details>
  <summary><code>ppr</code> - open github pull request web page</summary>

  Finds the pull request for your current branch and opens it in the browser. Includes safeguards for protected branches.

  <p align="center">
    <img src="./docs/ppr.svg">
  </p>
</details>

<details>
  <summary><code>ptest</code> - interactive test selector</summary>

  Search and open frontend tests directly in the browser. Filters tests by filename, suite, or test name interactively.

  <p align="center">
    <img src="./docs/ptest.svg">
  </p>
</details>

---

### Utility Scripts

- `pdetect` - Repository detection utility that outputs JSON with repository information (root path, org/name format).

- `prun-*` - Project-specific startup scripts for individual repositories (frontend, API, AI agent). Sourced by `p` dispatcher based on current repository.

---

### Automation Scripts

- `report-to-slack.sh`: runs on CI (Semaphore) to report test failures to Slack. Parses test results, maps failed tests to developers, and sends formatted notifications.

---

### Shared Utilities

- `p-common.zsh` - Shared library of utility functions used by all scripts:
  - Color/output helpers (`print_status`, `die`)
  - Command validation (`check_command`)
  - JSON utilities (`extract_json_value`)
  - Time utilities (`format_time_remaining`, `get_remaining_seconds`)

---

## Installation

Copy scripts to a directory in your `PATH`:

```bash
# Copy all development scripts
cp bin/p* ~/bin/

# Make them executable
chmod +x ~/bin/p*

# Verify installation
which p
p --help
```

### Adding a Directory to PATH

To add a directory to your `PATH`, you can modify your shell configuration file (e.g., `~/.zshrc` for zsh) and add the following line:

```bash
export PATH="$HOME/bin:$PATH"
```

After editing the file, apply the changes with:

```bash
source ~/.zshrc
```

**Requirements:**
- zsh shell
- `git` for repository detection
- `jq` for JSON parsing (optional for some scripts)
- AWS CLI for `paws` script
- `fzf` for interactive selection in `ptest`
- `ripgrep` for fast searching in `ptest`
