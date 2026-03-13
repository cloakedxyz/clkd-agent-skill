#!/usr/bin/env bash
# Check that every operationId in the OpenAPI spec appears in the
# sync:operations block in SKILL.md. Catches new endpoints that
# haven't been documented in the skill yet.
set -euo pipefail

OPENAPI_URL="${OPENAPI_URL:-https://clkd.xyz/openapi.json}"
SKILL_FILE="SKILL.md"

echo "Fetching OpenAPI spec from $OPENAPI_URL..."
spec=$(curl -sfL "$OPENAPI_URL") || { echo "ERROR: Failed to fetch OpenAPI spec"; exit 1; }

# Extract all operationIds from the spec
api_ops=$(echo "$spec" | jq -r '[.paths[][].operationId] | sort | unique | .[]')
api_count=$(echo "$api_ops" | wc -l | tr -d ' ')
echo "Found $api_count operations in OpenAPI spec"

# Extract the sync:operations block from SKILL.md
skill_ops=$(sed -n '/<!-- sync:operations/,/-->/p' "$SKILL_FILE" | grep -v '^<!--' | grep -v '^-->' | sed '/^$/d' | sort)
skill_count=$(echo "$skill_ops" | wc -l | tr -d ' ')
echo "Found $skill_count operations in $SKILL_FILE"
echo ""

# Check for operations in the API but missing from the skill
missing_from_skill=()
for op in $api_ops; do
  if ! echo "$skill_ops" | grep -qx "$op"; then
    missing_from_skill+=("$op")
  fi
done

# Check for operations in the skill but removed from the API
stale_in_skill=()
for op in $skill_ops; do
  if ! echo "$api_ops" | grep -qx "$op"; then
    stale_in_skill+=("$op")
  fi
done

exit_code=0

if [ ${#missing_from_skill[@]} -gt 0 ]; then
  echo "ERROR: ${#missing_from_skill[@]} new operation(s) in the API but missing from $SKILL_FILE:"
  for op in "${missing_from_skill[@]}"; do
    echo "  + $op"
  done
  echo ""
  echo "Add these to the sync:operations block, the quick reference table, and the appropriate reference file."
  echo ""
  exit_code=1
fi

if [ ${#stale_in_skill[@]} -gt 0 ]; then
  echo "WARNING: ${#stale_in_skill[@]} operation(s) in $SKILL_FILE but no longer in the API:"
  for op in "${stale_in_skill[@]}"; do
    echo "  - $op"
  done
  echo ""
  echo "Remove these from the sync:operations block and reference files."
  echo ""
  exit_code=1
fi

if [ $exit_code -eq 0 ]; then
  echo "All operations in sync."
fi

exit $exit_code
