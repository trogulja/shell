# P-Scripts

A collection of zsh scripts for streamlined development workflows with Productive repositories. These scripts handle common tasks like AWS authentication, opening PRs, checking CI status, and navigating test runners.

## Table of Contents

- [Overview](#overview)
- [Development Scripts](#development-scripts)
  - [Main Scripts](#main-scripts)
    - [p - Smart Repository Dispatcher](#p---smart-repository-dispatcher)
    - [paws - AWS Smart Login](#paws---aws-smart-login)
    - [pci - Open CI Workflow](#pci---open-ci-workflow)
    - [ppr - Find and Open Pull Request](#ppr---find-and-open-pull-request)
    - [ptest - Interactive Test Selector](#ptest---interactive-test-selector)
  - [Utility Scripts](#utility-scripts)
- [Automation Scripts](#automation-scripts)
- [Shared Utilities](#shared-utilities)
- [Installation](#installation)
- [Requirements](#requirements)

## Overview

P-Scripts provides two types of tools:

- **Development Scripts** (`bin/`) - Interactive CLI tools designed for manual use during development
- **Automation Scripts** (`automation/`) - Non-interactive scripts designed for CI/CD pipelines and remote execution

All scripts follow consistent interfaces with proper error handling, help documentation, and colored output for easy parsing.

## Development Scripts

### Main Scripts

#### `p` - Smart Repository Dispatcher

Automatically detects which Productive repository you're in and runs the appropriate startup script. Works from any subdirectory within a repository. Supports `productiveio/frontend`, `productiveio/api`, and `productiveio/ai-agent`.

<p align="center">
  <img src="./docs/p.svg">
</p>

**Example:**
```bash
# Run from directory linked to productiveio/frontend remote url
❯ p -p
🚀 Validating repository...
✓ Repository validated: productiveio/frontend
  Root: /Users/tibor/code/productive/app1

ℹ Repository is clean, auto-enabling pull

ℹ Using production API (DEV_API_ENV=production)

🚀 Pulling latest changes...
... (output truncated) ...
```

---

#### `paws` - AWS Smart Login

Intelligently manages AWS SSO authentication with automatic session refresh and expiration detection.

<p align="center">
  <img src="./docs/paws.svg">
</p>

**Usage:**
```bash
paws                    # Check and auto-login if needed
paws --status           # Show current AWS session status
paws --login            # Force AWS login
paws --help             # Show help
```

**Example:**
```bash
❯ paws -s
Checking AWS SSO status...

✓ Authenticated
  Account: xxxxxxxx
  User ID: xxxxxxxx
  ARN: xxxxxxxx

Session Details:
  Expires: 2025-10-24T15:50:02Z
  Session expired!
```

---

#### `pci` - Open CI Workflow

Opens the CI workflow runner (Semaphore) for the current git branch in your browser. Asks are you sure before opening for protected branches.

<p align="center">
  <img src="./docs/pci.svg">
</p>

**Examples:**
```bash
❯ pci
Are you sure you want to run tests for 'develop'? (y/N)
y
Opening CI Workflow for branch: develop
... (opens browser) ...
```

---

#### `ppr` - Find and Open Pull Request

Finds the pull request for your current branch and opens it in the browser. Includes safeguards for protected branches.

<p align="center">
  <img src="./docs/ppr.svg">
</p>

**Example:**
```bash
❯ ppr
🔍 Checking prerequisites...

📍 Detecting current branch...
  Branch: fix/add-thumbs-to-agent-chat

🔗 Checking upstream...
✓ Upstream is configured

🔎 Fetching pull request...

✓ Pull Request Found
  #20492: feature: agent chat user satisfaction feedback
  URL: https://github.com/productiveio/frontend/pull/20492

🌐 Opening in browser...
✓ Done
```

---

#### `ptest` - Interactive Test Selector

Search and open frontend tests directly in the browser. Filters tests by filename, suite, or test name interactively.

<p align="center">
  <img src="./docs/ptest.svg">
</p>

**Example:**
```bash
❯ ptest agent-chat/message/feedback
Searching for test modules...
Opening test: integration/components/ai/agent-chat/message/feedback
... (opens browser) ...
```

---

### Utility Scripts

**`pdetect`** - Repository detection utility that outputs JSON with repository information (root path, org/name format).

**`prun-*`** - Project-specific startup scripts for individual repositories (frontend, API, AI agent). Sourced by `p` dispatcher based on current repository.

---

## Automation Scripts

### `report-to-slack.sh`

Runs on CI (Semaphore) to report test failures to Slack. Parses test results, maps failed tests to developers, and sends formatted notifications.

**Runs automatically** on the master branch after test completion. CI-only usage.

---

## Shared Utilities

**`p-common.zsh`** - Shared library of utility functions used by all scripts:
- Color/output helpers (`print_status`, `die`)
- Command validation (`check_command`)
- JSON utilities (`extract_json_value`)
- Time utilities (`format_time_remaining`, `get_remaining_seconds`)

All functions are documented inline. Source this file in your scripts using:
```bash
source "${0:A:h}/p-common.zsh"
```

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
