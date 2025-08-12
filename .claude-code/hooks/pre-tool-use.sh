#!/bin/bash

# PreToolUse hook - Validate Flutter code before certain operations
# This hook runs before a tool is executed

# Get the tool name and parameters from the environment
TOOL_NAME="$CLAUDE_CODE_TOOL_NAME"
TOOL_PARAMS="$CLAUDE_CODE_TOOL_PARAMETERS"

# Only check for Git commit operations
if [[ "$TOOL_NAME" == "Bash" ]] && [[ "$TOOL_PARAMS" == *"git commit"* ]]; then
    echo "Checking Flutter code quality before commit..."
    
    # Run flutter analyze
    cd /Users/otislewis/arena2
    ANALYZE_OUTPUT=$(flutter analyze 2>&1)
    ANALYZE_EXIT_CODE=$?
    
    if [[ $ANALYZE_EXIT_CODE -ne 0 ]] || [[ "$ANALYZE_OUTPUT" != *"No issues found!"* ]]; then
        echo "❌ Flutter analyze found issues. Please fix before committing:"
        echo "$ANALYZE_OUTPUT"
        # Exit with non-zero to block the action
        exit 1
    fi
    
    echo "✅ Flutter analyze passed - proceeding with commit"
fi

# Allow all other operations to proceed
exit 0