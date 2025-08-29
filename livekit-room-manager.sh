#!/bin/bash

# LiveKit Room Manager for Arena Open Discussion Rooms
# This script helps manage LiveKit rooms via CLI

# LiveKit server configuration
LIVEKIT_URL="ws://172.236.109.9:7880"
API_KEY="LKAPI1234567890"
API_SECRET="7e9fb42854e466daf92dabbc9b88e98f7811486704338e062d30815a592de45d"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper function to run lk commands using configured project
run_lk() {
    lk "$@" --project arena
}

# List all rooms
list_rooms() {
    echo -e "${BLUE}📋 Listing all LiveKit rooms:${NC}"
    run_lk room list
}

# Create a new room
create_room() {
    if [ -z "$1" ]; then
        echo -e "${RED}❌ Error: Room name required${NC}"
        echo -e "${YELLOW}Usage: $0 create <room-name>${NC}"
        return 1
    fi
    
    local room_name="$1"
    echo -e "${BLUE}🏗️  Creating room: $room_name${NC}"
    run_lk room create "$room_name"
}

# Delete a room
delete_room() {
    if [ -z "$1" ]; then
        echo -e "${RED}❌ Error: Room ID required${NC}"
        echo -e "${YELLOW}Usage: $0 delete <room-id>${NC}"
        return 1
    fi
    
    local room_id="$1"
    echo -e "${BLUE}🗑️  Deleting room: $room_id${NC}"
    run_lk room delete "$room_id"
}

# Get room details
room_info() {
    if [ -z "$1" ]; then
        echo -e "${RED}❌ Error: Room ID required${NC}"
        echo -e "${YELLOW}Usage: $0 info <room-id>${NC}"
        return 1
    fi
    
    local room_id="$1"
    echo -e "${BLUE}ℹ️  Room info for: $room_id${NC}"
    run_lk room info "$room_id"
}

# List participants in a room
list_participants() {
    if [ -z "$1" ]; then
        echo -e "${RED}❌ Error: Room ID required${NC}"
        echo -e "${YELLOW}Usage: $0 participants <room-id>${NC}"
        return 1
    fi
    
    local room_id="$1"
    echo -e "${BLUE}👥 Participants in room: $room_id${NC}"
    run_lk room list-participants "$room_id"
}

# Generate a token for room access
generate_token() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo -e "${RED}❌ Error: Room name and identity required${NC}"
        echo -e "${YELLOW}Usage: $0 token <room-name> <user-identity> [moderator|participant]${NC}"
        return 1
    fi
    
    local room_name="$1"
    local identity="$2"
    local role="${3:-participant}"
    
    echo -e "${BLUE}🎫 Generating token for: $identity in room: $room_name (role: $role)${NC}"
    
    if [ "$role" = "moderator" ]; then
        # Generate token with admin permissions for moderators
        run_lk token create --room "$room_name" --identity "$identity" --join --admin --allow-update-metadata
    else
        # Generate token with basic join permissions for participants
        run_lk token create --room "$room_name" --identity "$identity" --join --allow-update-metadata
    fi
}

# Test server connectivity
test_connection() {
    echo -e "${BLUE}🔄 Testing LiveKit server connectivity...${NC}"
    echo -e "${BLUE}Server: $LIVEKIT_URL${NC}"
    
    if run_lk room list >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Connection successful!${NC}"
    else
        echo -e "${RED}❌ Connection failed!${NC}"
    fi
}

# Clean up empty rooms
cleanup_empty() {
    echo -e "${BLUE}🧹 Cleaning up empty rooms...${NC}"
    
    # Get room list in JSON format
    local rooms_json
    rooms_json=$(run_lk room list --output json 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$rooms_json" ]; then
        # Parse JSON and delete empty rooms (this is a simplified approach)
        echo -e "${YELLOW}⚠️  Manual cleanup required - check room list and delete empty rooms${NC}"
        list_rooms
    else
        echo -e "${RED}❌ Failed to get room list${NC}"
    fi
}

# Main script logic
case "$1" in
    "list" | "ls")
        list_rooms
        ;;
    "create")
        create_room "$2"
        ;;
    "delete" | "rm")
        delete_room "$2"
        ;;
    "info")
        room_info "$2"
        ;;
    "participants" | "users")
        list_participants "$2"
        ;;
    "token")
        generate_token "$2" "$3" "$4"
        ;;
    "test")
        test_connection
        ;;
    "cleanup")
        cleanup_empty
        ;;
    "help" | "-h" | "--help" | "")
        echo -e "${BLUE}🎮 Arena LiveKit Room Manager${NC}"
        echo
        echo -e "${YELLOW}Usage:${NC}"
        echo "  $0 list                           - List all rooms"
        echo "  $0 create <room-name>            - Create a new room"
        echo "  $0 delete <room-id>              - Delete a room"
        echo "  $0 info <room-id>                - Get room details"
        echo "  $0 participants <room-id>        - List participants in room"
        echo "  $0 token <room> <identity> [role] - Generate access token"
        echo "  $0 test                          - Test server connection"
        echo "  $0 cleanup                       - Clean up empty rooms"
        echo "  $0 help                          - Show this help"
        echo
        echo -e "${YELLOW}Examples:${NC}"
        echo "  $0 create open-discussion-test"
        echo "  $0 participants RM_abc123"
        echo "  $0 token my-room user123 moderator"
        ;;
    *)
        echo -e "${RED}❌ Unknown command: $1${NC}"
        echo -e "${YELLOW}Use '$0 help' for usage information${NC}"
        exit 1
        ;;
esac