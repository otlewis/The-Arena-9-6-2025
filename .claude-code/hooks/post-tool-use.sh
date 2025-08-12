#!/bin/bash

# PostToolUse hook - Play sound after certain tools complete
# This hook runs after a tool completes successfully

# Get the tool name from the environment
TOOL_NAME="$CLAUDE_CODE_TOOL_NAME"

# Tools that should trigger a completion sound
COMPLETION_TOOLS=("Write" "Edit" "MultiEdit" "TodoWrite")

# Check if the tool is in our completion list
for tool in "${COMPLETION_TOOLS[@]}"; do
    if [[ "$TOOL_NAME" == "$tool" ]]; then
        # Play Glass sound for task completion
        afplay /System/Library/Sounds/Glass.aiff &
        break
    fi
done

# Always exit 0 to allow the action to proceed
exit 0