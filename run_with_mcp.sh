#!/bin/bash

# Run Flutter app with MCP debugging flags
echo "Starting Flutter app with MCP debugging enabled..."
echo "Make sure the mcp_flutter server is running in your AI tool"
echo ""

flutter run \
  --debug \
  --host-vmservice-port=8182 \
  --dds-port=8181 \
  --enable-vm-service \
  --disable-service-auth-codes