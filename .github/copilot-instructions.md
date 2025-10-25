# P-Scripts Governance

- All code MUST comply with [constitution.md](../.specify/memory/constitution.md)
- Shared code goes in `bin/p-common.zsh`
- Personal scripts in `bin/`, automation scripts in `automation/`
- All scripts MUST have ShellSpec tests in `spec/`
- See full rules: [constitution.md](../.specify/memory/constitution.md)

## Shell Command Safety Rules

**CRITICAL**: Keep all shell commands extremely minimal (under 20 lines total) to prevent PTY crashes:
- ❌ Do NOT pass multi-line commit messages with code samples in the shell command
- ❌ Do NOT put large documentation or code content directly in shell string parameters
- ❌ Do NOT use heredocs (<<EOF) - they break the PTY
- ❌ Do NOT send any command longer than 20 lines to run_in_terminal
- ✅ DO use file creation/editing tools for any large content instead
- ✅ DO keep shell commands under 200 characters when possible
- ✅ DO use single-line commands exclusively
- ✅ DO break complex operations into multiple small commands

**When you need to:**
- Pass large strings → Create a temporary file first, then reference it
- Test complex commands → Break into smaller, single-line testable steps
- Work with multi-line content → Use file creation tools (create_file, edit_notebook_file, etc.) instead of shell

## Git Commit Control

**CRITICAL**: Never use `git commit` automatically
- ❌ Do NOT execute git commit commands automatically
- ❌ Do NOT use mcp_gitkraken_git_add_or_commit tool for commits
- ❌ Do NOT use run_in_terminal for git commit
- ✅ DO inform the user when commits are needed
- ✅ DO show what files need to be committed
- ✅ DO let the user control all commits manually

The user wants full control over when and how commits happen. Always ask or wait for explicit user instruction before staging/committing changes.

## ShellSpec Testing Patterns

**CRITICAL**: Understanding `When call` vs `When run` is essential for testing:

### `When call` - Direct function call (no subshell)
- Executes the function in the **current shell process**
- ❌ **Cannot test functions that call `exit`** - exit will terminate the test
- ✅ Use for normal functions that return normally
- Example: `When call check_command "sh"`

### `When run` - Subshell execution
- Executes the function in a **separate subshell**
- ✅ **Can test functions that call `exit`** - exit only terminates the subshell
- ✅ Use for functions that call `die()`, `exit`, or other terminating functions
- Exit status is captured and can be verified
- Example: `When run die 'error message'`

**Key Rule**: Functions that call `exit` (like `die()`) MUST use `When run`, not `When call`.

**Testing functions in different conditions:**
- ❌ Do NOT use `When run sh -c "... get_git_root"` - the function won't exist in the new shell (error 127)
- ✅ DO wrap the function call in an embedded function and use `When run`:
  ```
  test_outside_repo() {
    cd /tmp
    get_git_root
  }
  When run test_outside_repo
  ```
- This way the embedded function has access to sourced functions, but runs in a subshell for proper isolation

```
