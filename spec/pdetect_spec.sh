#!/usr/bin/env sh

TESTING_FILE="$SHELLSPEC_PROJECT_ROOT/bin/pdetect"

Describe 'bin/pdetect'
  # Source the script
  Include "$TESTING_FILE"

  setup_mock_git_repo() {
    MOCK_GIT_REPO="$SHELLSPEC_TMPBASE/mock_git_repo"
    mkdir -p "$MOCK_GIT_REPO"
    cd "$MOCK_GIT_REPO"
    git init >/dev/null 2>&1
    git remote add origin "https://github.com/test/repo.git"
  }

  cleanup_mock_git_repo() {
    cd /
    rm -rf "$MOCK_GIT_REPO"
  }

  #region: get_git_root
  Describe 'get_git_root()'
    BeforeEach 'setup_mock_git_repo'
    AfterEach 'cleanup_mock_git_repo'

    It 'returns git root when in a git repository'
      When call get_git_root
      The status should be success
      The stdout should include '/'
    End

    It 'fails when not in a git repository'
      cd_outside_repo() {
        cd /tmp
        get_git_root
      }
      When run cd_outside_repo
      The status should be failure
      The status should eq 1
      The stderr should include "Not in a git repository"
    End
  End
  #endregion

  #region: get_remote_url
  Describe 'get_remote_url()'
    BeforeEach 'setup_mock_git_repo'
    AfterEach 'cleanup_mock_git_repo'

    It 'returns remote URL when in a git repository'
      When call get_remote_url
      The status should be success
      The stdout should eq "https://github.com/test/repo.git"
    End

    It 'fails when not in a git repository'
      outside_repo() {
        cd /tmp
        get_remote_url
      }
      When run outside_repo
      The status should be failure
      The status should eq 1
      The stderr should include "✗ Error: No git remote URL configured"
    End
  End
  #endregion

  #region: extract_repo_name
  Describe 'extract_repo_name()'
    It 'extracts org/repo from HTTPS URL with .git'
      When call extract_repo_name "https://github.com/productiveio/frontend.git"
      The stdout should eq "productiveio/frontend"
      The status should be success
    End

    It 'extracts org/repo from HTTPS URL without .git'
      When call extract_repo_name "https://github.com/productiveio/backend"
      The stdout should eq "productiveio/backend"
      The status should be success
    End

    It 'extracts org/repo from SSH URL with .git'
      When call extract_repo_name "git@github.com:productiveio/api.git"
      The stdout should eq "productiveio/api"
      The status should be success
    End

    It 'extracts org/repo from SSH URL without .git'
      When call extract_repo_name "git@github.com:productiveio/cli"
      The stdout should eq "productiveio/cli"
      The status should be success
    End

    It 'fails on invalid URL format'
      When run extract_repo_name "not-a-valid-url"
      The status should be failure
      The status should eq 1
      The stderr should include "Could not parse repository name"
    End

    It 'fails on URL with single component'
      When run extract_repo_name "https://github.com/singlename"
      The status should be failure
      The status should eq 1
      The stderr should include "Could not parse repository name"
    End
  End
  #endregion

  #region: main
  Describe 'main()'
    BeforeEach 'setup_mock_git_repo'
    AfterEach 'cleanup_mock_git_repo'

    It 'outputs valid JSON when in a git repository'
      When run main
      The status should be success
      The stdout should include '"root":"'
      The stdout should include '/mock_git_repo","repo":"test/repo"'
    End

    It 'fails when not in a git repository'
      outside_git() {
        cd /tmp
        main
      }
      When run outside_git
      The status should be failure
      The stderr should include "Not in a git repository"
    End
  End
  #endregion
End
