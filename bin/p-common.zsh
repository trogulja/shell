#!/usr/bin/env zsh
# p-common.zsh - Common utilities for productive shell scripts
#
# Usage:
#   source "${0:A:h}/p-common.zsh"

# =============================================================================
# COLORS
# =============================================================================
# ANSI color codes for terminal output

typeset -gr P_RED=$'\033[0;31m'
typeset -gr P_GREEN=$'\033[0;32m'
typeset -gr P_YELLOW=$'\033[1;33m'
typeset -gr P_BLUE=$'\033[0;34m'
typeset -gr P_NC=$'\033[0m'  # No Color

# =============================================================================
# OUTPUT UTILITIES
# =============================================================================

# Print colored status message
# Usage: print_status <color> <message>
# Example: print_status "$P_GREEN" "✓ Success"
print_status() {
  local color=$1
  local message=$2
  echo "${color}${message}${P_NC}"
}

# Print error message and exit with status 1
# Usage: die <error_message>
# Example: die "Configuration file not found"
die() {
  print_status "$P_RED" "✗ Error: $1" >&2
  exit 1
}

# =============================================================================
# COMMAND VALIDATION
# =============================================================================

# Check if a required command exists in PATH
# Usage: check_command <command_name>
# Example: check_command jq
# Exits with error if command is not found
check_command() {
  local cmd=$1
  if ! command -v "$cmd" &>/dev/null; then
    die "$cmd is required but not installed"
  fi
}

# =============================================================================
# JSON UTILITIES
# =============================================================================

# Extract a value from JSON without requiring jq
# Uses grep and basic text processing for simple key-value extraction
# Usage: extract_json_value <json_string> <key>
# Example: extract_json_value '{"name":"test"}' "name"
# Returns: test
extract_json_value() {
  local json=$1
  local key=$2
  echo "$json" | grep -o "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | grep -o '"[^"]*"$' | tr -d '"'
}

# =============================================================================
# TIME FORMATTING
# =============================================================================

# Format seconds into human-readable time (hours and minutes)
# Usage: format_time_remaining <seconds>
# Example: format_time_remaining 3900
# Returns: 1h 5m
format_time_remaining() {
  local seconds=$1
  local hours=$((seconds / 3600))
  local minutes=$(((seconds % 3600) / 60))
  echo "${hours}h ${minutes}m"
}

# Calculate remaining seconds from an ISO 8601 timestamp
# Usage: get_remaining_seconds <iso8601_timestamp>
# Example: get_remaining_seconds "2025-10-20T15:30:00Z"
# Returns: number of seconds remaining (empty if expired or invalid)
get_remaining_seconds() {
  local expires_at=$1
  [[ -z "$expires_at" ]] && return 1

  local expires_seconds=$(date -ju -f "%Y-%m-%dT%H:%M:%SZ" "$expires_at" +%s 2>/dev/null)
  [[ -z "$expires_seconds" ]] && return 1

  local current_seconds=$(date +%s)
  local remaining=$((expires_seconds - current_seconds))

  [[ $remaining -gt 0 ]] && echo "$remaining"
}

# =============================================================================
# REPOSITORY VALIDATION
# =============================================================================

# Validate that we're in the correct git repository
# Requires pdetect script in PATH and jq for JSON parsing
# Usage: validate_repository <expected_repo>
# Example: validate_repository "productiveio/frontend"
# Returns: repository root path on success
# Exits: with error if not in expected repository
validate_repository() {
  local expected_repo=$1

  check_command pdetect
  check_command jq

  local result
  result=$(pdetect) || exit 1

  local repo
  repo=$(echo "$result" | jq -r .repo) || die "Failed to parse repository information"

  if [[ "$repo" != "$expected_repo" ]]; then
    die "Must be run from $expected_repo repository (current: $repo)"
  fi

  local root
  root=$(echo "$result" | jq -r .root) || die "Failed to parse repository root"

  echo "$root"
}
