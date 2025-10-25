#!/usr/bin/env sh

TESTING_FILE="$SHELLSPEC_PROJECT_ROOT/bin/p-common.zsh"

Describe 'bin/p-common.zsh'
  # Source the library
  Include "$TESTING_FILE"

  #region: Color constants
  Describe 'Color constants'
    It 'defines P_RED'
      The variable P_RED should be defined
      The value "$P_RED" should not be blank
    End

    It 'defines P_GREEN'
      The variable P_GREEN should be defined
      The value "$P_GREEN" should not be blank
    End

    It 'defines P_YELLOW'
      The variable P_YELLOW should be defined
      The value "$P_YELLOW" should not be blank
    End

    It 'defines P_BLUE'
      The variable P_BLUE should be defined
      The value "$P_BLUE" should not be blank
    End

    It 'defines P_NC (no color)'
      The variable P_NC should be defined
      The value "$P_NC" should not be blank
    End
  End
  #endregion

  #region: print_status function
  Describe 'print_status()'
    It 'prints colored message to stdout'
      When call print_status "$P_GREEN" "test message"
      The stdout should include "test message"
      The status should be success
    End

    It 'includes color codes in output'
      When call print_status "$P_RED" "error"
      The stdout should start with "$P_RED"
      The stdout should end with "${P_NC}"
    End
  End
  #endregion

  #region: die function
  Describe 'die()'
    It 'exits with status 1'
      When run die 'test error'
      The status should be failure
      The status should eq 1
      The stderr should include "✗ Error: test error"
    End
  End
  #endregion

  #region: check_command function
  Describe 'check_command()'
    It 'succeeds for existing command'
      When call check_command "sh"
      The status should be success
    End

    It 'fails when command does not exist'
      When run check_command "nonexistent_command_xyz"
      The status should be failure
      The status should eq 1
      The stderr should include "nonexistent_command_xyz is required but not installed"
    End
  End
  #endregion

  #region: extract_json_value function
  Describe 'extract_json_value()'
    It 'extracts simple string value'
      When call extract_json_value '{"name":"test"}' "name"
      The stdout should eq "test"
    End

    It 'extracts value with spaces in JSON'
      When call extract_json_value '{"key" : "value"}' "key"
      The stdout should eq "value"
    End

    It 'extracts Account from AWS identity JSON'
      When call extract_json_value '{"Account":"123456789012"}' "Account"
      The stdout should eq "123456789012"
    End

    It 'extracts UserId from AWS identity JSON'
      When call extract_json_value '{"UserId":"AIDAI123456"}' "UserId"
      The stdout should eq "AIDAI123456"
    End

    It 'returns empty for non-existent key'
      When call extract_json_value '{"name":"test"}' "missing"
      The stdout should eq ""
    End

    It 'handles complex JSON with multiple keys'
      When call extract_json_value '{"first":"a","second":"b","third":"c"}' "second"
      The stdout should eq "b"
    End
  End
  #endregion

  #region: format_time_remaining function
  Describe 'format_time_remaining()'
    It 'formats 3600 seconds as 1h 0m'
      When call format_time_remaining 3600
      The stdout should eq "1h 0m"
    End

    It 'formats 7200 seconds as 2h 0m'
      When call format_time_remaining 7200
      The stdout should eq "2h 0m"
    End

    It 'formats 3900 seconds as 1h 5m'
      When call format_time_remaining 3900
      The stdout should eq "1h 5m"
    End

    It 'formats 28800 seconds as 8h 0m (typical AWS session)'
      When call format_time_remaining 28800
      The stdout should eq "8h 0m"
    End

    It 'formats 1800 seconds as 0h 30m'
      When call format_time_remaining 1800
      The stdout should eq "0h 30m"
    End

    It 'formats 90 seconds as 0h 1m'
      When call format_time_remaining 90
      The stdout should eq "0h 1m"
    End

    It 'handles zero seconds'
      When call format_time_remaining 0
      The stdout should eq "0h 0m"
    End

    It 'handles large values'
      When call format_time_remaining 86400
      The stdout should eq "24h 0m"
    End
  End
  #endregion

  #region: get_remaining_seconds function
  Describe 'get_remaining_seconds()'
    # Mock the date command to return predictable values
    setup_date_mock() {
      MOCK_BIN_DIR="$SHELLSPEC_TMPBASE/mock_bin"
      mkdir -p "$MOCK_BIN_DIR"

      # Create a mock date script
      cat > "$MOCK_BIN_DIR/date" << 'MOCK_DATE_SCRIPT'
#!/bin/sh
# Mock date command for testing
# When called with -j -f or -ju -f format, return fixed timestamp
# When called with +%s, return current time

if [ "$1" = "-j" ] || [ "$1" = "-ju" ]; then
  if [ "$2" = "-f" ] || [ "$1" = "-ju" ] && [ "$2" = "-f" ]; then
    # Parse ISO timestamp and return as epoch
    # Handle both -j -f and -ju -f
    timestamp="${4:-$4}"
    case "$timestamp" in
      "2025-10-20T15:30:00Z")
        echo "1729436400"  # Fixed epoch for this timestamp
        ;;
      "2025-10-20T12:00:00Z")
        echo "1729423200"  # 3.5 hours earlier
        ;;
      "invalid-timestamp")
        exit 1
        ;;
      *)
        echo "1729440000"  # Default future time
        ;;
    esac
  fi
elif [ "$1" = "+%s" ]; then
  # Return current time - fixed for deterministic tests
  echo "1729432800"  # Base time for "now"
else
  # Fallback to real date for other calls
  /bin/date "$@"
fi
MOCK_DATE_SCRIPT
      chmod +x "$MOCK_BIN_DIR/date"

      # Prepend mock bin to PATH
      export PATH="$MOCK_BIN_DIR:$PATH"
    }

    cleanup_date_mock() {
      rm -rf "$MOCK_BIN_DIR"
      # PATH will be restored by ShellSpec after test
    }

    BeforeEach 'setup_date_mock'
    AfterEach 'cleanup_date_mock'

    It 'returns remaining seconds for future timestamp'
      # With mocked date: expires at 1729436400, now is 1729432800
      # Remaining: 3600 seconds (1 hour)
      When call get_remaining_seconds "2025-10-20T15:30:00Z"
      The stdout should eq "3600"
      The status should be success
    End

    It 'returns empty for past timestamp'
      # With mocked date: expires at 1729423200, now is 1729432800
      # Already expired (past by 9600 seconds)
      When call get_remaining_seconds "2025-10-20T12:00:00Z"
      The stdout should eq ""
      The status should be failure
    End

    It 'fails on empty input'
      When run get_remaining_seconds ""
      The stdout should eq ""
      The status should be failure
      The status should eq 1
    End

    It 'fails on invalid timestamp format'
      When run get_remaining_seconds "invalid-timestamp"
      The stdout should eq ""
      The status should be failure
    End

    It 'handles timestamp with no arguments'
      When run get_remaining_seconds
      The stdout should eq ""
      The status should be failure
      The status should eq 1
    End
  End
  #endregion
End
