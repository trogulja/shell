#!/usr/bin/env sh

TESTING_FILE="$SHELLSPEC_PROJECT_ROOT/bin/pomo"

Describe 'bin/pomo'
  Include "$TESTING_FILE"

  #region: parse_args - mode validation
  Describe 'parse_args() mode validation'
    It 'fails when mode is missing'
      When run parse_args
      The status should be failure
      The stderr should include "First argument must be either 'work' or 'rest'"
    End

    It 'fails when mode is invalid'
      When run parse_args nope
      The status should be failure
      The stderr should include "First argument must be either 'work' or 'rest'"
    End

    It 'accepts work'
      When call parse_args work
      The status should be success
      The variable POMO_MODE should eq 'work'
    End

    It 'accepts rest'
      When call parse_args rest
      The status should be success
      The variable POMO_MODE should eq 'rest'
    End
  End
  #endregion

  #region: parse_args - defaults
  Describe 'parse_args() defaults'
    It 'work with no args defaults to 25 minutes and "Work timer"'
      When call parse_args work
      The variable POMO_DURATION should eq '25'
      The variable POMO_MESSAGE should eq 'Work timer'
    End

    It 'rest with no args defaults to 5 minutes and "Rest timer"'
      When call parse_args rest
      The variable POMO_DURATION should eq '5'
      The variable POMO_MESSAGE should eq 'Rest timer'
    End

    It 'falls back to default duration when no number is given'
      When call parse_args work some message
      The variable POMO_DURATION should eq '25'
      The variable POMO_MESSAGE should eq 'some message'
    End
  End
  #endregion

  #region: parse_args - duration parsing
  Describe 'parse_args() duration parsing'
    It 'reads single trailing integer as duration'
      When call parse_args work 45
      The variable POMO_DURATION should eq '45'
      The variable POMO_MESSAGE should eq 'Work timer'
    End

    It 'reads trailing integer as duration with message before'
      When call parse_args rest some message 15
      The variable POMO_DURATION should eq '15'
      The variable POMO_MESSAGE should eq 'some message'
    End

    It 'reads leading integer as duration with message after'
      When call parse_args rest 15 some message
      The variable POMO_DURATION should eq '15'
      The variable POMO_MESSAGE should eq 'some message'
    End

    It 'prefers trailing integer when both leading and trailing are integers'
      When call parse_args work 30 60
      The variable POMO_DURATION should eq '60'
      The variable POMO_MESSAGE should eq '30'
    End
  End
  #endregion

  #region: parse_args - message edge cases
  Describe 'parse_args() message edge cases'
    It 'replaces empty/whitespace-only message with default'
      When call parse_args work 25 ""
      The variable POMO_MESSAGE should eq 'Work timer'
    End

    It 'joins multi-word message with single spaces'
      When call parse_args work focus on PR review 50
      The variable POMO_DURATION should eq '50'
      The variable POMO_MESSAGE should eq 'focus on PR review'
    End

    It 'treats negative number as message, not duration'
      When call parse_args work -5
      The variable POMO_DURATION should eq '25'
      The variable POMO_MESSAGE should eq '-5'
    End
  End
  #endregion

  #region: main - help flag
  Describe 'main() help'
    It 'prints help with --help'
      When run main --help
      The status should be success
      The stdout should include 'pomo - Pomodoro timer'
      The stdout should include 'Usage:'
    End

    It 'prints help with -h'
      When run main -h
      The status should be success
      The stdout should include 'pomo - Pomodoro timer'
    End

    It 'documents the --no-slack flag'
      When run main --help
      The status should be success
      The stdout should include '--no-slack'
    End
  End
  #endregion

  #region: json_escape
  Describe 'json_escape()'
    It 'passes plain text unchanged'
      When call json_escape 'hello world'
      The stdout should eq 'hello world'
    End

    It 'escapes double quotes'
      When call json_escape 'say "hi"'
      The stdout should eq 'say \"hi\"'
    End

    It 'escapes backslashes'
      When call json_escape 'a\b'
      The stdout should eq 'a\\b'
    End

    It 'escapes backslash before quotes correctly'
      When call json_escape 'a\"b'
      The stdout should eq 'a\\\"b'
    End
  End
  #endregion

  #region: filter_flags
  Describe 'filter_flags()'
    It 'leaves args untouched when --no-slack absent'
      When call filter_flags work 25 hello
      The variable POMO_NO_SLACK should eq '0'
      The value "${POMO_FILTERED_ARGS[*]}" should eq 'work 25 hello'
    End

    It 'sets POMO_NO_SLACK and removes flag when present'
      When call filter_flags --no-slack work 25
      The variable POMO_NO_SLACK should eq '1'
      The value "${POMO_FILTERED_ARGS[*]}" should eq 'work 25'
    End

    It 'finds --no-slack regardless of position'
      When call filter_flags work 25 --no-slack hello
      The variable POMO_NO_SLACK should eq '1'
      The value "${POMO_FILTERED_ARGS[*]}" should eq 'work 25 hello'
    End
  End
  #endregion

  #region: Slack helpers - mocks
  Describe 'Slack helpers'
    setup_slack_mocks() {
      MOCK_BIN_DIR="$SHELLSPEC_TMPBASE/mock_bin"
      mkdir -p "$MOCK_BIN_DIR"
      MOCK_CURL_LOG="$SHELLSPEC_TMPBASE/curl_calls"
      : > "$MOCK_CURL_LOG"
      export MOCK_CURL_LOG

      cat > "$MOCK_BIN_DIR/security" << 'MOCK_SEC'
#!/bin/sh
if [ -n "$MOCK_SLACK_TOKEN" ]; then
  printf '%s' "$MOCK_SLACK_TOKEN"
  exit 0
fi
exit 44
MOCK_SEC
      chmod +x "$MOCK_BIN_DIR/security"

      cat > "$MOCK_BIN_DIR/curl" << 'MOCK_CURL'
#!/bin/sh
{
  echo "---"
  for a in "$@"; do echo "ARG:$a"; done
} >> "$MOCK_CURL_LOG"
exit 0
MOCK_CURL
      chmod +x "$MOCK_BIN_DIR/curl"
      export PATH="$MOCK_BIN_DIR:$PATH"
    }

    cleanup_slack_mocks() {
      rm -rf "$MOCK_BIN_DIR"
      unset MOCK_SLACK_TOKEN
    }

    BeforeEach 'setup_slack_mocks'
    AfterEach 'cleanup_slack_mocks'

    Describe 'slack_token()'
      It 'returns the keychain token when set'
        export MOCK_SLACK_TOKEN='xoxp-test-1'
        When call slack_token
        The status should be success
        The stdout should eq 'xoxp-test-1'
      End

      It 'returns empty when keychain entry missing'
        When call slack_token
        The status should be failure
        The stdout should eq ''
      End
    End

    Describe 'slack_set_status()'
      It 'no-ops silently when no token'
        When call slack_set_status ':dart:' 'focus' 0
        The status should be success
        The contents of file "$MOCK_CURL_LOG" should eq ''
      End

      It 'POSTs to users.profile.set when token present'
        export MOCK_SLACK_TOKEN='xoxp-test-1'
        When call slack_set_status ':dart:' 'focus' 1777551675
        The status should be success
        The contents of file "$MOCK_CURL_LOG" should include 'https://slack.com/api/users.profile.set'
        The contents of file "$MOCK_CURL_LOG" should include 'Authorization: Bearer xoxp-test-1'
        The contents of file "$MOCK_CURL_LOG" should include ':dart:'
        The contents of file "$MOCK_CURL_LOG" should include '"status_text":"focus"'
        The contents of file "$MOCK_CURL_LOG" should include '"status_expiration":1777551675'
      End

      It 'JSON-escapes the message text'
        export MOCK_SLACK_TOKEN='xoxp-test-1'
        When call slack_set_status ':dart:' 'say "hi"' 0
        The contents of file "$MOCK_CURL_LOG" should include '"status_text":"say \"hi\""'
      End
    End

    Describe 'slack_dnd_snooze()'
      It 'no-ops when no token'
        When call slack_dnd_snooze 25
        The status should be success
        The contents of file "$MOCK_CURL_LOG" should eq ''
      End

      It 'POSTs to dnd.setSnooze with num_minutes'
        export MOCK_SLACK_TOKEN='xoxp-test-1'
        When call slack_dnd_snooze 25
        The status should be success
        The contents of file "$MOCK_CURL_LOG" should include 'https://slack.com/api/dnd.setSnooze'
        The contents of file "$MOCK_CURL_LOG" should include 'num_minutes=25'
      End
    End

    Describe 'slack_dnd_end()'
      It 'no-ops when no token'
        When call slack_dnd_end
        The status should be success
        The contents of file "$MOCK_CURL_LOG" should eq ''
      End

      It 'POSTs to dnd.endSnooze when token present'
        export MOCK_SLACK_TOKEN='xoxp-test-1'
        When call slack_dnd_end
        The status should be success
        The contents of file "$MOCK_CURL_LOG" should include 'https://slack.com/api/dnd.endSnooze'
      End
    End

    Describe 'slack_enabled()'
      It 'is disabled when --no-slack flag set'
        export MOCK_SLACK_TOKEN='xoxp-test-1'
        POMO_NO_SLACK=1
        When call slack_enabled
        The status should be failure
      End

      It 'is disabled when token missing'
        POMO_NO_SLACK=0
        When call slack_enabled
        The status should be failure
      End

      It 'is enabled when token present and flag unset'
        export MOCK_SLACK_TOKEN='xoxp-test-1'
        POMO_NO_SLACK=0
        When call slack_enabled
        The status should be success
      End
    End
  End
  #endregion
End
