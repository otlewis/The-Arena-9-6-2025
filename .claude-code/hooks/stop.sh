#!/bin/bash

# Stop hook - Play a completion sound when Claude Code finishes all tasks
# This hook runs when the main Claude Code agent finishes responding

# Play Hero sound to indicate all tasks are complete
afplay /System/Library/Sounds/Hero.aiff &

# Always exit 0 to allow the action to proceed
exit 0