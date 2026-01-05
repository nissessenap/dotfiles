#!/bin/bash
# Fix for ralph-wiggum plugin permission error
# Applies the fix from https://github.com/anthropics/claude-plugins-official/pull/98
#
# Problem: The plugin uses inline ```! bash execution which Claude Code blocks for security
# Solution: Remove inline bash, instruct Claude to use Bash tool directly

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

COMMANDS_DIR="$PLUGIN_DIR/commands"
SCRIPTS_DIR="$PLUGIN_DIR/scripts"

# ============================================================================
# 1. Fix ralph-loop.md - Remove inline bash, use Bash tool instruction
# ============================================================================
RALPH_LOOP_MD="$COMMANDS_DIR/ralph-loop.md"

echo "Fixing $RALPH_LOOP_MD..."

cat > "$RALPH_LOOP_MD" << 'EOF'
---
description: "Start Ralph Wiggum loop in current session"
argument-hint: "PROMPT [--max-iterations N] [--completion-promise TEXT]"
allowed-tools: ["Bash"]
hide-from-slash-command-tool: "true"
---

# Ralph Loop Command

Use the Bash tool to execute the setup script:

```
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh" $ARGUMENTS
```

Replace `${CLAUDE_PLUGIN_ROOT}` with the actual plugin path and `$ARGUMENTS` with the user's arguments.

After the script runs, work on the task. When you try to exit, the Ralph loop will feed the SAME PROMPT back to you for the next iteration. You'll see your previous work in files and git history, allowing you to iterate and improve.

CRITICAL RULE: If a completion promise is set, you may ONLY output it when the statement is completely and unequivocally TRUE. Do not output false promises to escape the loop, even if you think you're stuck or should exit for other reasons. The loop is designed to continue until genuine completion.
EOF

echo "  ✓ ralph-loop.md fixed"

# ============================================================================
# 2. Fix cancel-ralph.md - Remove inline bash, use Bash tool instruction
# ============================================================================
CANCEL_RALPH_MD="$COMMANDS_DIR/cancel-ralph.md"

echo "Fixing $CANCEL_RALPH_MD..."

cat > "$CANCEL_RALPH_MD" << 'EOF'
---
description: "Cancel active Ralph Wiggum loop"
allowed-tools: ["Bash"]
hide-from-slash-command-tool: "true"
---

# Cancel Ralph

Use the Bash tool to execute the cancel script:

```
"${CLAUDE_PLUGIN_ROOT}/scripts/cancel-ralph-loop.sh"
```

Replace `${CLAUDE_PLUGIN_ROOT}` with the actual plugin path.

Check the output:

1. **If FOUND_LOOP=false**:
   - Say "No active Ralph loop found."

2. **If FOUND_LOOP=true**:
   - Use Bash: `rm .claude/ralph-loop.local.md`
   - Report: "Cancelled Ralph loop (was at iteration N)" where N is the ITERATION value from above.
EOF

echo "  ✓ cancel-ralph.md fixed"

# ============================================================================
# 3. Create cancel-ralph-loop.sh script (if missing)
# ============================================================================
CANCEL_SCRIPT="$SCRIPTS_DIR/cancel-ralph-loop.sh"

echo "Creating $CANCEL_SCRIPT..."

cat > "$CANCEL_SCRIPT" << 'EOF'
#!/bin/bash
set -euo pipefail

if [[ -f .claude/ralph-loop.local.md ]]; then
  ITERATION=$(grep '^iteration:' .claude/ralph-loop.local.md | sed 's/iteration: *//')
  echo "FOUND_LOOP=true"
  echo "ITERATION=$ITERATION"
else
  echo "FOUND_LOOP=false"
fi
EOF

chmod +x "$CANCEL_SCRIPT"
echo "  ✓ cancel-ralph-loop.sh created"

# ============================================================================
# Done
# ============================================================================
echo ""
echo "✅ All fixes applied successfully!"
echo ""
echo "Changes made:"
echo "  1. ralph-loop.md - Removed inline bash, uses Bash tool instruction"
echo "  2. cancel-ralph.md - Removed inline bash, uses Bash tool instruction"
echo "  3. cancel-ralph-loop.sh - Created script for cancel logic"
echo ""
echo "You can now run:"
echo '  /ralph-wiggum:ralph-loop "/orchestrate_plan" --max-iterations 30 --completion-promise "ORCHESTRATION_STOPPED"'