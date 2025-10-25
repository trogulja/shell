#!/usr/bin/env sh

TESTING_FILE="$SHELLSPEC_PROJECT_ROOT/bin/ppr"

Describe 'bin/ppr'
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

  setup_git_upstream() {
    git branch --set-upstream-to=origin/feature/test feature/test >/dev/null 2>&1
  }

  setup_gh_mock() {
    MOCK_BIN_DIR="$SHELLSPEC_TMPBASE/mock_bin"
    mkdir -p "$MOCK_BIN_DIR"

    # Mock gh command
    cat > "$MOCK_BIN_DIR/gh" << 'MOCK_GH'
#!/bin/sh
# Mock GitHub CLI

# Extract branch name from arguments
branch=""
for arg in "$@"; do
  case "$arg" in
    --head)
      next_arg=true
      continue
      ;;
  esac
  if [ "$next_arg" = "true" ]; then
    branch="$arg"
    next_arg=false
  fi
done

# Check for test scenarios via environment variables
if [ "$GH_MOCK_FAIL" = "true" ]; then
  exit 1
fi

if [ "$GH_MOCK_NO_PR" = "true" ]; then
  echo "[]"
  exit 0
fi

# Return mock PR data
echo '[{"number":123,"title":"Test PR Title","url":"https://github.com/test/repo/pull/123"}]'
exit 0
MOCK_GH

    chmod +x "$MOCK_BIN_DIR/gh"
    export PATH="$MOCK_BIN_DIR:$PATH"
  }

  cleanup_gh_mock() {
    rm -rf "$MOCK_BIN_DIR"
    unset GH_MOCK_FAIL
    unset GH_MOCK_NO_PR
  }

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
    unset MOCK_OPEN_FAIL
  }

  #region: is_protected_branch
  Describe 'is_protected_branch()'
    It 'returns true for master branch'
      When call is_protected_branch "master"
      The status should be success
    End

    It 'returns true for main branch'
      When call is_protected_branch "main"
      The status should be success
    End

    It 'returns true for develop branch'
      When call is_protected_branch "develop"
      The status should be success
    End

    It 'returns false for feature branch'
      When call is_protected_branch "feature/test"
      The status should be failure
    End

    It 'returns false for bugfix branch'
      When call is_protected_branch "bugfix/issue-123"
      The status should be failure
    End
  End
  #endregion

  #region: get_current_branch
  Describe 'get_current_branch()'
    BeforeEach 'setup_mock_git_repo'
    AfterEach 'cleanup_mock_git_repo'

    It 'returns current branch name'
      When call get_current_branch
      The status should be success
      # Git defaults to 'main' or 'master'
      The stdout should match pattern 'main|master'
    End

    It 'returns correct branch name when on feature branch'
      git checkout -b feature/test-pr >/dev/null 2>&1
      When call get_current_branch
      The status should be success
      The stdout should eq "feature/test-pr"
    End

    It 'fails when not in a git repository'
      outside_repo() {
        cd /tmp
        get_current_branch
      }
      When run outside_repo
      The status should be failure
      The status should eq 1
      The stderr should include "Could not determine current branch"
    End
  End
  #endregion

  #region: has_upstream
  Describe 'has_upstream()'
    BeforeEach 'setup_mock_git_repo'
    AfterEach 'cleanup_mock_git_repo'

    It 'returns failure when upstream is not set (default state)'
      When call has_upstream
      The status should be failure
    End

    It 'returns failure for new branch without upstream'
      git checkout -b feature/brand-new >/dev/null 2>&1
      When call has_upstream
      The status should be failure
    End
  End
  #endregion

  #region: get_pr_for_branch
  Describe 'get_pr_for_branch()'
    BeforeEach 'setup_gh_mock'
    AfterEach 'cleanup_gh_mock'

    It 'returns PR data in tab-separated format'
      When call get_pr_for_branch "feature/test"
      The status should be success
      The stdout should include "123"
      The stdout should include "Test PR Title"
      The stdout should include "https://github.com/test/repo/pull/123"
    End

    It 'fails when gh command fails'
      export GH_MOCK_FAIL="true"
      When run get_pr_for_branch "feature/test"
      The status should be failure
      The status should eq 1
      The stderr should include "Failed to fetch pull request data"
    End

    It 'fails when no PR found for branch'
      export GH_MOCK_NO_PR="true"
      When run get_pr_for_branch "feature/test"
      The status should be failure
      The status should eq 1
      The stderr should include "No pull request found"
    End
  End
  #endregion

  #region: parse_pr_data
  Describe 'parse_pr_data()'
    It 'parses PR data correctly'
      When call parse_pr_data "123	Test PR Title	https://github.com/test/repo/pull/123"
      The status should be success
      The variable pr_number should eq "123"
      The variable pr_title should eq "Test PR Title"
      The variable pr_url should eq "https://github.com/test/repo/pull/123"
    End

    It 'fails when URL field is empty'
      When run parse_pr_data "123	Test PR Title	"
      The status should be failure
      The status should eq 1
      The stderr should include "Failed to parse pull request data"
    End

    It 'fails when title field is empty'
      When run parse_pr_data "123		https://github.com/test/repo/pull/123"
      The status should be failure
      The status should eq 1
      The stderr should include "Failed to parse pull request data"
    End
  End
  #endregion

  #region: open_pr_url
  Describe 'open_pr_url()'
    setup_full_open_mock() {
      setup_open_mock
      setup_gh_mock
    }

    cleanup_full_open_mock() {
      cleanup_open_mock
      cleanup_gh_mock
    }

    BeforeEach 'setup_full_open_mock'
    AfterEach 'cleanup_full_open_mock'

    It 'opens URL successfully'
      export MOCK_OPEN_FAIL="false"
      When call open_pr_url "https://github.com/test/repo/pull/123"
      The status should be success
    End

    It 'fails when open command fails'
      export MOCK_OPEN_FAIL="true"
      When run open_pr_url "https://github.com/test/repo/pull/123"
      The status should be failure
      The status should eq 1
      The stderr should include "Failed to open URL in browser"
    End
  End
  #endregion

  #region: main
  Describe 'main()'
    BeforeEach 'setup_mock_git_repo && setup_gh_mock && setup_open_mock'
    AfterEach 'cleanup_mock_git_repo && cleanup_gh_mock && cleanup_open_mock'

    It 'shows help when --help flag is provided'
      When run main --help
      The status should be success
      The stdout should include "USAGE:"
    End

    It 'shows help when -h flag is provided'
      When run main -h
      The status should be success
      The stdout should include "Find and open pull request"
    End

    It 'fails when on protected branch'
      on_protected() {
        cd "$MOCK_GIT_REPO"
        main >/dev/null 2>&1
      }
      When run on_protected
      The status should be failure
    End

    It 'fails when upstream is not set'
      no_upstream() {
        cd "$MOCK_GIT_REPO"
        git checkout -b feature/test >/dev/null 2>&1
        main >/dev/null 2>&1
      }
      When run no_upstream
      The status should be failure
    End
  End
  #endregion
End
