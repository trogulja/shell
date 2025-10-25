#!/bin/bash

# Run only on master branch
if [ "$SEMAPHORE_GIT_BRANCH" != "master" ]; then
  echo "Branch is not master. Exiting."
  exit 0
fi

# get the file (should be single file in single directory)
dir=$(ls -d /tmp/test-result* | head -n 1)
file=$(ls "$dir"/*.json | head -n 1)

# check if the file is compressed and uncompress if needed
file_type=$(file --mime-type -b "$file")
if [ "$file_type" == "application/gzip" ]; then
  mv "$file" "$file".gz
  gunzip "$file".gz
fi

organizations_file="data/organizations.yml"
avatars_file="data/avatars.yml"

# Check if the file exists
if [ ! -f "$file" ]; then
  echo "File not found: $file"
  exit 1
fi

# Extract total, passed, skipped, and failed tests
summary=$(jq '.testResults[0].suites[0].summary | {total: .total, passed: .passed, skipped: .skipped, failed: .failed}' "$file")
total=$(jq -r '.total' <<< "$summary")
passed=$(jq -r '.passed' <<< "$summary")
skipped=$(jq -r '.skipped' <<< "$summary")
failed=$(jq -r '.failed' <<< "$summary")

# Check if we can parse the numbers
if ! [[ "$total" =~ ^[0-9]+$ ]] || ! [[ "$failed" =~ ^[0-9]+$ ]]; then
  echo "Error: Unable to parse total or failed test numbers."
  exit 1
fi

# Exit if there are no failed tests
if [ "$failed" -eq 0 ]; then
  echo "No failed tests found."
  exit 0
fi

# Load organizations and avatars data and join into a user->organization map
avatars=$(yq eval -o=json '. | to_entries | map({"blame": .key, "url": .value})' "$avatars_file")
organizations=$(yq eval -o=json '. | to_entries | map({"blame": .value.blame, "organization": .key})' "$organizations_file")
user_organization=$(jq -n --argjson organizations "$organizations" --argjson avatars "$avatars" '
  $organizations as $o |
  $avatars as $a |
  [
    $o[] |
    . as $org |
    ( $a[] | select(.blame == $org.blame) | {blame: .blame, slackId: .url | capture("https://ca.slack-edge.com/[^-]+-(?<id>[^-]+)-.*").id, organization: $org.organization} ) //
    {blame: $org.blame, slackId: null, organization: $org.organization}
  ]
')

# Build feature -> organization mapping from feature files (feature_organization)
# This finds each Feature: line and the first Given current organization is "..." line in the same file.
features_meta_tmp=$(mktemp)
find features -name '*.feature' -print0 | \
  while IFS= read -r -d '' f; do
    feature=$(grep -m1 '^Feature:' "$f" | sed 's/^Feature:[[:space:]]*//')
    org=$(grep -m1 'Given current organization is "' "$f" | sed -E 's/.*Given current organization is "([^"]+)".*/\1/' || true)
    jq -n --arg feature "$feature" --arg organization "$org" --arg file "$f" '{feature:$feature, organization:$organization, file:$file}'
  done > "$features_meta_tmp"
feature_organization=$(jq -s '.' "$features_meta_tmp")
rm -f "$features_meta_tmp"

# Extract failed tests details and enhance with blame and slackId from meta
failed_tests=$(jq -n --argjson meta "$user_organization" --argjson features "$feature_organization" --slurpfile file "$file" '
  [$file[0].testResults[0].suites[0].tests[] |
    select(.state == "failed") as $t |
    { feature: $t.classname, scenario: $t.name } as $ft |
    ( ($features[] | select(.feature == $ft.feature) | .organization) // null ) as $orgName |
    ( ($meta[] | select(.organization | startswith($orgName // "")) | {organization, blame, slackId}) // null ) as $meta_info |
    $ft + { organization: ($orgName // "N/A") } + ($meta_info // {})
  ]
')

# Define the common variables
url="https://productive.semaphoreci.com/workflows/$SEMAPHORE_WORKFLOW_ID?pipeline_id=$SEMAPHORE_PIPELINE_ID"
date=$(LC_TIME=en_US.UTF-8 TZ=Europe/Zagreb date +'%a %d %b %H:%M')

if [ "$SEMAPHORE_WORKFLOW_TRIGGERED_BY_SCHEDULE" != "true" ]; then
  context="*$failed failed*  |  $date  |  run by $SEMAPHORE_WORKFLOW_TRIGGERED_BY"
else
  context="*$failed failed*  |  $date  |  scheduled run"
fi

# Defaults for few (up to 8) and many (up to 40) failed tests
if [ "$failed" -lt 9 ]; then
  template="./data/slack-few-failed.json"
  details=$(jq -n -r --argjson ft "$failed_tests" '
    $ft | map("*\(.feature)*\n_\(.scenario)_\n\((.slackId | select(. != null) | "<@" + . + ">") // .blame)") | join("\n\n")
  ')
elif [ "$failed" -lt 41 ]; then
  template="./data/slack-many-failed.json"
  details=$(jq -n -r --argjson ft "$failed_tests" '
    $ft | group_by(.feature) | map(
      "*\(.[0].feature)*\n" +
      (map("  _\(.scenario)_") | join("\n"))
    ) | join("\n\n")
  ')
else
  template=""
  details=""
fi

# text block in slack must be less than 3001 characters
if [ ${#details} -gt 2500 ] || [ -z "$details" ]; then
  template="./data/slack-all-failed.json"
  output=$(jq --arg context "$context" \
    --arg url "$url" '
    .blocks[1].elements[0].text = $context |
    .blocks[3].elements[0].url = $url
    ' "$template"
  )
else
  output=$(jq --arg context "$context" \
    --arg details "$details" \
    --arg url "$url" \
    '
    .blocks[1].elements[0].text = $context |
    .blocks[3].text.text = $details |
    .blocks[5].elements[0].url = $url
    ' "$template"
  )
fi

echo "Sending the following JSON to Slack webhook:"
echo "$output" | jq .
echo ""

response=$(curl -X POST -H 'Content-type: application/json' --data "$output" "$SLACK_WEBHOOK_E2E_URL")
echo "Slack API response:"
echo "$response"
