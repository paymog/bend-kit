#!/usr/bin/env bash
# Print the top N open, unblocked leaf issues, highest priority first.
# Priority: pri-high > pri-med > pri-low > none; then lowest issue number.
set -euo pipefail
limit="${1:-10}"
repo="$(gh repo view --json nameWithOwner -q .nameWithOwner)"

# ponytail: first 100 open issues, 4 ancestor levels; paginate or deepen when the repo outgrows that.
gh api graphql -F owner="${repo%/*}" -F name="${repo#*/}" -f query='
fragment B on Issue { number blockedBy(first: 50) { nodes { state } } }
query($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    issues(states: OPEN, first: 100) { nodes {
      ...B title url
      labels(first: 20) { nodes { name } }
      assignees(first: 5) { nodes { login } }
      subIssues(first: 50) { nodes { state } }
      parent { ...B parent { ...B parent { ...B parent { ...B } } } }
    } }
  }
}' | jq -r --argjson limit "$limit" '
  def blocked: any(.blockedBy.nodes[]; .state == "OPEN");
  def chain: ., (.parent // empty | chain);
  def rank: ([.labels.nodes[].name | {"pri-high": 0, "pri-med": 1, "pri-low": 2}[.] // empty] | min) // 3;
  [.data.repository.issues.nodes[]
    | select(all(.subIssues.nodes[]; .state != "OPEN") and all(.labels.nodes[]; .name != "in-progress"))
    | select(any(chain; blocked) | not)]
  | sort_by(rank, .number) | .[:$limit][]
  | "#\(.number)\t\(["high", "med", "low", "-"][rank])\t\([.assignees.nodes[].login] | join(",") | if . == "" then "-" else . end)\t\(.title)\t\(.url)"'
