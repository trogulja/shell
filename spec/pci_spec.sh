#!/usr/bin/env sh

TESTING_FILE="$SHELLSPEC_PROJECT_ROOT/bin/pci"

Describe 'bin/pci'
  # Source the script
  Include "$TESTING_FILE"

  setup_mock_git_repo() {
    MOCK_GIT_REPO="$SHELLSPEC_TMPBASE/mock_git_repo"
    mkdir -p "$MOCK_GIT_REPO"
    cd "$MOCK_GIT_REPO"
    git init >/dev/null 2>&1
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Create initial commit so we have a proper branch
    echo "test" > test.txt
    git add test.txt
    git commit -m "Initial commit" >/dev/null 2>&1
  }

  cleanup_mock_git_repo() {
    cd /
    rm -rf "$MOCK_GIT_REPO"
  }

  setup_workflow_file() {
    mkdir -p "$MOCK_GIT_REPO/.github/workflows"
    cat > "$MOCK_GIT_REPO/.github/workflows/ci.yml" << 'EOF'
name: CI
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo "https://productive.semaphoreci.com/projects/frontend/schedulers/abc123?branch=develop"
EOF
  }

  #region: get_current_branch
  Describe 'get_current_branch()'
    BeforeEach 'setup_mock_git_repo'
    AfterEach 'cleanup_mock_git_repo'

    It 'returns current branch name'
      When call get_current_branch
      The status should be success
      # Git now defaults to 'main' instead of 'master'
      The stdout should match pattern 'main|master'
    End

    It 'returns correct branch when on feature branch'
      git checkout -b feature/test-branch >/dev/null 2>&1
      When call get_current_branch
      The status should be success
      The stdout should eq "feature/test-branch"
    End

    It 'fails when not in a git repository'
      not_in_repo() {
        cd /tmp
        get_current_branch
      }
      When run not_in_repo
      The status should be failure
      The status should eq 1
      The stderr should include "Not in a git repository"
    End
  End
  #endregion

  #region: find_workflow_file
  Describe 'find_workflow_file()'
    BeforeEach 'setup_mock_git_repo'
    AfterEach 'cleanup_mock_git_repo'

    It 'finds workflow file with Semaphore URL'
      setup_workflow_file
      When call find_workflow_file
      The status should be success
      The stdout should include ".github/workflows/ci.yml"
    End

    It 'fails when workflow directory does not exist'
      When run find_workflow_file
      The status should be failure
      The status should eq 1
      The stderr should include "Could not find workflow file"
    End

    It 'fails when workflow file exists but has no Semaphore URL'
      mkdir -p "$MOCK_GIT_REPO/.github/workflows"
      echo "name: CI" > "$MOCK_GIT_REPO/.github/workflows/ci.yml"
      When run find_workflow_file
      The status should be failure
      The stderr should include "Could not find workflow file"
    End

    It 'returns first matching file when multiple exist'
      setup_workflow_file
      mkdir -p "$MOCK_GIT_REPO/.github/workflows"
      cat > "$MOCK_GIT_REPO/.github/workflows/another.yml" << 'EOF'
name: Another
jobs:
  test:
    steps:
      - run: echo "https://productive.semaphoreci.com/projects/frontend/schedulers/xyz789"
EOF
      When call find_workflow_file
      The status should be success
      The stdout should include ".github/workflows/"
      The stdout should include ".yml"
    End
  End
  #endregion

  #region: extract_semaphore_url
  Describe 'extract_semaphore_url()'
    BeforeEach 'setup_mock_git_repo'
    AfterEach 'cleanup_mock_git_repo'

    It 'extracts base URL without branch parameter'
      setup_workflow_file
      local workflow_file=".github/workflows/ci.yml"
      When call extract_semaphore_url "$workflow_file"
      The status should be success
      The stdout should eq "https://productive.semaphoreci.com/projects/frontend/schedulers/abc123"
    End

    It 'extracts URL when no branch parameter exists'
      mkdir -p "$MOCK_GIT_REPO/.github/workflows"
      cat > "$MOCK_GIT_REPO/.github/workflows/ci.yml" << 'EOF'
name: CI
steps:
  - run: echo "https://productive.semaphoreci.com/projects/frontend/schedulers/def456"
EOF
      local workflow_file=".github/workflows/ci.yml"
      When call extract_semaphore_url "$workflow_file"
      The status should be success
      The stdout should start with "https://productive.semaphoreci.com/projects/frontend/schedulers/def456"
    End

    It 'fails when URL pattern not found in file'
      mkdir -p "$MOCK_GIT_REPO/.github/workflows"
      echo "name: CI" > "$MOCK_GIT_REPO/.github/workflows/ci.yml"
      local workflow_file=".github/workflows/ci.yml"
      When run extract_semaphore_url "$workflow_file"
      The status should be failure
      The status should eq 1
      The stderr should include "Could not extract Semaphore scheduler URL"
    End
  End
  #endregion

  #region: construct_ci_url
  Describe 'construct_ci_url()'
    It 'constructs URL with branch parameter'
      When call construct_ci_url "https://example.com/scheduler/abc" "feature/test"
      The stdout should eq "https://example.com/scheduler/abc?branch=feature/test"
    End

    It 'handles branch names with special characters'
      When call construct_ci_url "https://example.com/scheduler/abc" "feature/PROJ-123-fix"
      The stdout should eq "https://example.com/scheduler/abc?branch=feature/PROJ-123-fix"
    End
  End
  #endregion

  #region: open_ci_url
  Describe 'open_ci_url()'
    setup_open_mock() {
      MOCK_BIN_DIR="$SHELLSPEC_TMPBASE/mock_bin"
      mkdir -p "$MOCK_BIN_DIR"

      cat > "$MOCK_BIN_DIR/open" << 'MOCK_OPEN'
#!/bin/sh
if [ "$MOCK_OPEN_FAIL" = "true" ]; then
  exit 1
fi
exit 0
MOCK_OPEN
      chmod +x "$MOCK_BIN_DIR/open"
      export PATH="$MOCK_BIN_DIR:$PATH"
    }

    cleanup_open_mock() {
      rm -rf "$MOCK_BIN_DIR"
    }

    BeforeEach 'setup_open_mock'
    AfterEach 'cleanup_open_mock'

    It 'opens URL in browser successfully'
      export MOCK_OPEN_FAIL="false"
      When call open_ci_url "https://example.com" "test-branch"
      The status should be success
      The stdout should include "Opening CI Workflow for branch:"
      The stdout should include "test-branch"
      The stdout should include "https://example.com"
    End

    It 'fails when open command fails'
      export MOCK_OPEN_FAIL="true"
      When run open_ci_url "https://example.com" "test-branch"
      The status should be failure
      The status should eq 1
      The stdout should include "Opening CI Workflow for branch:"
      The stderr should include "Failed to open URL in browser"
    End
  End
  #endregion

  #region: main
  Describe 'main()'
    setup_full_integration() {
      setup_mock_git_repo
      setup_workflow_file

      MOCK_BIN_DIR="$SHELLSPEC_TMPBASE/mock_bin"
      mkdir -p "$MOCK_BIN_DIR"

      cat > "$MOCK_BIN_DIR/open" << 'MOCK_OPEN'
#!/bin/sh
# Mock open - just succeed without actually opening
exit 0
MOCK_OPEN
      chmod +x "$MOCK_BIN_DIR/open"
      export PATH="$MOCK_BIN_DIR:$PATH"
    }

    cleanup_full_integration() {
      cleanup_mock_git_repo
      rm -rf "$MOCK_BIN_DIR"
    }

    BeforeEach 'setup_full_integration'
    AfterEach 'cleanup_full_integration'

    It 'shows help when --help flag is provided'
      When run main --help
      The status should be success
      The stdout should include "USAGE:"
      The stdout should include "pci [OPTIONS]"
    End

    It 'shows help when -h flag is provided'
      When run main -h
      The status should be success
      The stdout should include "USAGE:"
    End

    It 'opens CI for feature branch without confirmation'
      git checkout -b feature/test >/dev/null 2>&1
      When call main
      The status should be success
      The stdout should include "Opening CI Workflow for branch:"
      The stdout should include "feature/test"
      The stdout should include "https://productive.semaphoreci.com/projects/frontend/schedulers/abc123?branch=feature/test"
    End

    It 'fails when not in git repository'
      outside_repo() {
        cd /tmp
        main
      }
      When run outside_repo
      The status should be failure
      The stderr should include "Not in a git repository"
    End

    It 'fails when workflow file not found'
      rm -rf "$MOCK_GIT_REPO/.github"
      When run main
      The status should be failure
      The stderr should include "Could not find workflow file"
    End
  End
  #endregion
End
