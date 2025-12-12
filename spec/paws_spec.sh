#!/usr/bin/env sh

TESTING_FILE="$SHELLSPEC_PROJECT_ROOT/bin/paws"

Describe 'bin/paws'
  # Source the script
  Include "$TESTING_FILE"

  #region: Mock Setup Functions
  # Common setup that all mock scenarios use
  setup_mock_base() {
    export HOME="$SHELLSPEC_TMPBASE/mock_home"
    mkdir -p "$HOME/.aws/sso/cache"

    MOCK_AWS_CALLS_FILE="$SHELLSPEC_TMPBASE/aws_calls"
    : > "$MOCK_AWS_CALLS_FILE"
    export MOCK_AWS_CALLS_FILE

    MOCK_BIN_DIR="$SHELLSPEC_TMPBASE/mock_bin"
    mkdir -p "$MOCK_BIN_DIR"

    # Create mock aws command
    cat > "$MOCK_BIN_DIR/aws" << 'MOCK_AWS'
#!/bin/sh
if [ "$1" = "sts" ] && [ "$2" = "get-caller-identity" ]; then
  if [ "$MOCK_AWS_AUTHENTICATED" = "true" ]; then
    user_id="${MOCK_AWS_USERID:-AIDAI123456}"
    echo "{\"UserId\":\"$user_id\",\"Account\":\"123456789012\",\"Arn\":\"arn:aws:iam::123456789012:user/testuser\"}"
    exit 0
  else
    exit 1
  fi
elif [ "$1" = "sso" ] && [ "$2" = "logout" ]; then
  if [ -n "${MOCK_AWS_CALLS_FILE:-}" ]; then
    echo "sso logout" >> "$MOCK_AWS_CALLS_FILE"
  fi

  if [ "${MOCK_AWS_LOGOUT_SUCCESS:-true}" = "true" ]; then
    exit 0
  else
    exit 1
  fi
elif [ "$1" = "sso" ] && [ "$2" = "login" ]; then
  if [ -n "${MOCK_AWS_CALLS_FILE:-}" ]; then
    echo "sso login" >> "$MOCK_AWS_CALLS_FILE"
  fi

  if [ "$MOCK_AWS_LOGIN_SUCCESS" = "true" ]; then
    exit 0
  else
    exit 1
  fi
fi
MOCK_AWS
    chmod +x "$MOCK_BIN_DIR/aws"
    export PATH="$MOCK_BIN_DIR:$PATH"
  }

  cleanup_mock_base() {
    rm -rf "$SHELLSPEC_TMPBASE/mock_home"
    rm -rf "$MOCK_BIN_DIR"
  }

  # Scenario: Empty SSO cache (no files)
  setup_empty_cache() {
    setup_mock_base
    # Cache directory exists but is empty
  }

  # Scenario: Valid cache expiring in 20 minutes
  setup_cache_expires_20min() {
    setup_mock_base
    future_time=$(date -u -v+20M +"%Y-%m-%dT%H:%M:%SZ")
    echo '{"otherField":"old"}' > "$HOME/.aws/sso/cache/old.json"
    sleep 0.1
    echo "{\"accessToken\":\"token123\",\"expiresAt\":\"$future_time\",\"region\":\"us-east-1\"}" > "$HOME/.aws/sso/cache/session.json"
  }

  # Scenario: Valid cache expiring in 8 hours
  setup_cache_expires_8hrs() {
    setup_mock_base
    future_time=$(date -u -v+8H +"%Y-%m-%dT%H:%M:%SZ")
    echo '{"otherField":"old"}' > "$HOME/.aws/sso/cache/old.json"
    sleep 0.1
    echo "{\"accessToken\":\"token456\",\"expiresAt\":\"$future_time\",\"region\":\"us-east-1\"}" > "$HOME/.aws/sso/cache/session.json"
  }

  # Scenario: Valid cache but missing expiresAt field
  setup_cache_no_expiration() {
    setup_mock_base
    echo '{"otherField":"old"}' > "$HOME/.aws/sso/cache/old.json"
    sleep 0.1
    echo '{"accessToken":"token789","region":"us-east-1","startUrl":"https://example.awsapps.com/start"}' > "$HOME/.aws/sso/cache/session.json"
  }
  #endregion

  #region: Unit Tests - get_sso_session_expiration
  Describe 'get_sso_session_expiration()'
    BeforeEach 'setup_mock_base'
    AfterEach 'cleanup_mock_base'

    It 'returns newest cache file expiresAt when multiple files have accessToken'
      echo '{"accessToken":"token1","expiresAt":"2025-10-20T10:00:00Z"}' > "$HOME/.aws/sso/cache/old.json"
      sleep 0.1
      echo '{"accessToken":"token2","expiresAt":"2025-10-20T12:00:00Z"}' > "$HOME/.aws/sso/cache/new.json"

      When call get_sso_session_expiration
      The status should be success
      The stdout should eq "2025-10-20T12:00:00Z"
    End

    It 'skips files without accessToken and returns file with accessToken'
      echo '{"otherField":"value","expiresAt":"2025-10-20T10:00:00Z"}' > "$HOME/.aws/sso/cache/no-token.json"
      echo '{"accessToken":"token","expiresAt":"2025-10-20T12:00:00Z"}' > "$HOME/.aws/sso/cache/has-token.json"

      When call get_sso_session_expiration
      The status should be success
      The stdout should eq "2025-10-20T12:00:00Z"
    End

    It 'extracts expiresAt from valid cache expiring in 8 hours'
      setup_cache_expires_8hrs

      When call get_sso_session_expiration
      The status should be success
      The stdout should match pattern "20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z"
    End

    It 'extracts expiresAt from valid cache expiring in 20 minutes'
      setup_cache_expires_20min

      When call get_sso_session_expiration
      The status should be success
      The stdout should match pattern "20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z"
    End

    It 'handles cache file with spaces around expiresAt'
      echo '{"accessToken":"token", "expiresAt" : "2025-10-20T12:00:00Z" }' > "$HOME/.aws/sso/cache/session.json"

      When call get_sso_session_expiration
      The status should be success
      The stdout should eq "2025-10-20T12:00:00Z"
    End

    It 'returns failure when cache directory does not exist'
      rm -rf "$HOME/.aws/sso/cache"

      When call get_sso_session_expiration
      The status should be failure
      The stdout should eq ""
    End

    It 'returns failure when cache is empty'
      setup_empty_cache

      When call get_sso_session_expiration
      The status should be failure
      The stdout should eq ""
    End

    It 'returns failure when no files have accessToken'
      echo '{"otherField":"value1","expiresAt":"2025-10-20T10:00:00Z"}' > "$HOME/.aws/sso/cache/file1.json"
      echo '{"otherField":"value2","expiresAt":"2025-10-20T11:00:00Z"}' > "$HOME/.aws/sso/cache/file2.json"

      When call get_sso_session_expiration
      The status should be failure
      The stdout should eq ""
    End

    It 'returns failure when accessToken exists but expiresAt field is missing'
      setup_cache_no_expiration

      When call get_sso_session_expiration
      The status should be failure
      The stdout should eq ""
    End

    It 'returns failure when cache file has accessToken but empty expiresAt'
      echo '{"accessToken":"token","expiresAt":""}' > "$HOME/.aws/sso/cache/session.json"

      When call get_sso_session_expiration
      The status should be failure
      The stdout should eq ""
    End
  End
  #endregion

  #region: Unit Tests - should_refresh_login
  Describe 'should_refresh_login()'
    AfterEach 'cleanup_mock_base'

    It 'returns success when authenticated without grace period'
      setup_cache_expires_8hrs
      export MOCK_AWS_AUTHENTICATED="true"

      When call should_refresh_login
      The status should be success
    End

    It 'returns failure when not authenticated without grace period'
      setup_empty_cache
      export MOCK_AWS_AUTHENTICATED="false"

      When call should_refresh_login
      The status should be failure
    End

    It 'returns success when authenticated with time beyond grace period (8hrs > 30min)'
      setup_cache_expires_8hrs
      export MOCK_AWS_AUTHENTICATED="true"

      When call should_refresh_login 30
      The status should be success
    End

    It 'returns failure when session expires within grace period (20min < 30min)'
      setup_cache_expires_20min
      export MOCK_AWS_AUTHENTICATED="true"

      When call should_refresh_login 30
      The status should be failure
    End

    It 'returns success when session expires beyond custom grace period (20min > 15min)'
      setup_cache_expires_20min
      export MOCK_AWS_AUTHENTICATED="true"

      When call should_refresh_login 15
      The status should be success
    End

    It 'returns failure when session already expired'
      setup_mock_base
      echo '{"accessToken":"token","expiresAt":"2020-01-01T00:00:00Z"}' > "$HOME/.aws/sso/cache/session.json"
      export MOCK_AWS_AUTHENTICATED="true"

      When call should_refresh_login 30
      The status should be failure
    End

    It 'returns success when authenticated with no expiration info and grace period'
      setup_cache_no_expiration
      export MOCK_AWS_AUTHENTICATED="true"

      When call should_refresh_login 30
      The status should be success
    End

    It 'works with empty cache'
      setup_empty_cache
      export MOCK_AWS_AUTHENTICATED="true"

      When call should_refresh_login 30
      The status should be success
    End
  End
  #endregion

  #region: Integration Tests - show_status
  Describe 'show_status()'
    AfterEach 'cleanup_mock_base'

    It 'shows authenticated status with session expiring in 8 hours'
      setup_cache_expires_8hrs
      export MOCK_AWS_AUTHENTICATED="true"

      When call show_status
      The status should be success
      The stdout should include "✓ Authenticated"
      The stdout should include "Account: 123456789012"
      The stdout should include "User ID: AIDAI123456"
      The stdout should include "Session Details:"
      The stdout should include "Time remaining:"
    End

    It 'shows authenticated status without session info'
      setup_cache_no_expiration
      export MOCK_AWS_AUTHENTICATED="true"

      When call show_status
      The status should be success
      The stdout should include "✓ Authenticated"
      The stdout should include "Account: 123456789012"
    End

    It 'shows not authenticated error'
      setup_empty_cache
      export MOCK_AWS_AUTHENTICATED="false"

      When call show_status
      The status should be failure
      The status should eq 1
      The stdout should include "✗ Not authenticated or session expired"
      The stdout should include "Run with --login flag"
    End

    It 'shows error when session is expired'
      setup_mock_base
      echo '{"accessToken":"token","expiresAt":"2020-01-01T00:00:00Z"}' > "$HOME/.aws/sso/cache/session.json"
      export MOCK_AWS_AUTHENTICATED="true"

      When call show_status
      The status should be failure
      The stdout should include "✓ Authenticated"
      The stdout should include "Session expired!"
    End
  End
  #endregion

  #region: Integration Tests - perform_login
  Describe 'perform_login()'
    AfterEach 'cleanup_mock_base'

    show_mock_aws_calls() {
      if [[ -n "${MOCK_AWS_CALLS_FILE:-}" ]] && [[ -f "$MOCK_AWS_CALLS_FILE" ]]; then
        echo "MOCK_AWS_CALLS:$(tr '\n' '|' < "$MOCK_AWS_CALLS_FILE")"
      fi
    }

    It 'skips login when session expires in 8 hours (beyond default 30min grace)'
      setup_cache_expires_8hrs
      export MOCK_AWS_AUTHENTICATED="true"

      When call perform_login
      The status should be success
      The stdout should include "✓ Already authenticated"
      The stdout should include "remaining)"
    End

    It 'skips login when already authenticated without session info'
      setup_cache_no_expiration
      export MOCK_AWS_AUTHENTICATED="true"

      When call perform_login
      The status should be success
      The stdout should include "✓ Already authenticated"
    End

    It 'performs successful login when not authenticated (empty cache)'
      setup_empty_cache
      export MOCK_AWS_AUTHENTICATED="false"
      export MOCK_AWS_LOGIN_SUCCESS="true"

      When call perform_login
      The status should be success
      The stdout should include "✗ Credentials expired or invalid"
      The stdout should include "Running aws sso login"
      The stdout should include "✓ AWS login successful"
    End

    It 'exits with error when login fails'
      setup_empty_cache
      export MOCK_AWS_AUTHENTICATED="false"
      export MOCK_AWS_LOGIN_SUCCESS="false"

      When run perform_login
      The status should be failure
      The status should eq 1
      The stdout should include "✗ Credentials expired or invalid"
      The stdout should include "Running aws sso login"
      The stderr should include "AWS SSO login failed"
    End

    It 'performs login when session expires in 20min (within default 30min grace)'
      setup_cache_expires_20min
      export MOCK_AWS_AUTHENTICATED="true"
      export MOCK_AWS_LOGIN_SUCCESS="true"

      When call perform_login
      The status should be success
      The stdout should include "⚠ Session expiring soon"
      The stdout should include "Running aws sso login"
      The stdout should include "✓ AWS login successful"
    End

    It 'performs login when session expires within custom grace period (20min < 60min)'
      setup_cache_expires_20min
      export MOCK_AWS_AUTHENTICATED="true"
      export MOCK_AWS_LOGIN_SUCCESS="true"

      When call perform_login 60
      The status should be success
      The stdout should include "⚠ Session expiring soon"
      The stdout should include "Running aws sso login"
      The stdout should include "✓ AWS login successful"
    End

    It 'skips login when session has time beyond custom grace period (8hrs > 60min)'
      setup_cache_expires_8hrs
      export MOCK_AWS_AUTHENTICATED="true"

      When call perform_login 60
      The status should be success
      The stdout should include "✓ Already authenticated"
      The stdout should include "remaining)"
      The stdout should not include "Running aws sso login"
    End

    It 'forces login even when session is valid with 8 hours remaining'
      setup_cache_expires_8hrs
      export MOCK_AWS_AUTHENTICATED="true"
      export MOCK_AWS_LOGIN_SUCCESS="true"

      force_login_and_show_calls() {
        perform_login 30 "true"
        show_mock_aws_calls
      }

      When call force_login_and_show_calls
      The status should be success
      The stdout should include "Force login requested"
      The stdout should include "running aws sso login"
      The stdout should include "✓ AWS login successful"
      The stdout should not include "Already authenticated"
      The stdout should include "MOCK_AWS_CALLS:sso logout|sso login|"
    End

    It 'fails when force login is requested but login fails'
      setup_cache_expires_8hrs
      export MOCK_AWS_AUTHENTICATED="true"
      export MOCK_AWS_LOGIN_SUCCESS="false"

      force_login_fail_and_show_calls() {
        perform_login 30 "true"
        show_mock_aws_calls
      }

      When run force_login_fail_and_show_calls
      The status should be failure
      The status should eq 1
      The stdout should include "Force login requested"
      The stdout should include "Invalidating cached SSO session"
      The stdout should include "running aws sso login"
      The stderr should include "AWS SSO login failed"
    End
  End
  #endregion

  #region: Integration Tests - show_whoami
  Describe 'show_whoami()'
    AfterEach 'cleanup_mock_base'

    It 'prints email when authenticated'
      setup_cache_expires_8hrs
      export MOCK_AWS_AUTHENTICATED="true"
      export MOCK_AWS_USERID="SOMERANDOMSTRING12345:tibor.rogulja@productive.io"

      When call show_whoami
      The status should be success
      The stdout should eq "tibor.rogulja@productive.io"
    End

    It 'returns 1 when not authenticated'
      setup_empty_cache
      export MOCK_AWS_AUTHENTICATED="false"

      When call show_whoami
      The status should be failure
      The status should eq 1
      The stdout should eq ""
    End
  End
  #endregion
End
