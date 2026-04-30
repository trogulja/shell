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
  End
  #endregion
End
