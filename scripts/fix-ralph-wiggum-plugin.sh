#!/bin/bash
# Fix for ralph-wiggum plugin permission error
# Applies the fix from https://github.com/anthropics/claude-plugins-official/pull/98
#
# Problem: The plugin uses restrictive allowed-tools path which triggers permission errors
# Solution: Change to ["Bash"] to allow proper script execution

set -euo pipefail

PLUGIN_CACHE_DIR="$HOME/.claude/plugins/cache/claude-plugins-official/ralph-wiggum"

# Find the active plugin directory (latest hash)
if [[ ! -d "$PLUGIN_CACHE_DIR" ]]; then
    echo "Error: ralph-wiggum plugin not found at $PLUGIN_CACHE_DIR"
    exit 1
fi

# Get all version directories, excluding 'unknown'
PLUGIN_DIR=$(find "$PLUGIN_CACHE_DIR" -maxdepth 1 -type d -name '[a-f0-9]*' | head -1)

if [[ -z "$PLUGIN_DIR" ]]; then
    echo "Error: No plugin version directory found"
    exit 1
fi

echo "Found plugin at: $PLUGIN_DIR"

RALPH_LOOP_MD="$PLUGIN_DIR/commands/ralph-loop.md"

if [[ ! -f "$RALPH_LOOP_MD" ]]; then
    echo "Error: ralph-loop.md not found at $RALPH_LOOP_MD"
    exit 1
fi

# Check if fix is already applied
if grep -q 'allowed-tools: \["Bash"\]' "$RALPH_LOOP_MD"; then
    echo "Fix already applied - allowed-tools is set to [\"Bash\"]"
    exit 0
fi

# Apply the fix - change restrictive path to just "Bash"
echo "Applying fix to $RALPH_LOOP_MD..."

# Use sed to replace the restrictive allowed-tools line
sed -i 's/allowed-tools: \["Bash([^"]*setup-ralph-loop\.sh[^"]*)"]/allowed-tools: ["Bash"]/' "$RALPH_LOOP_MD"

# Verify the fix
if grep -q 'allowed-tools: \["Bash"\]' "$RALPH_LOOP_MD"; then
    echo "Fix applied successfully!"
    echo ""
    echo "You can now run:"
    echo '  /ralph-wiggum:ralph-loop "/orchestrate_plan" --max-iterations 30 --completion-promise "ORCHESTRATION_STOPPED"'
else
    echo "Error: Fix may not have been applied correctly"
    echo "Current allowed-tools line:"
    grep 'allowed-tools' "$RALPH_LOOP_MD"
    exit 1
fi
