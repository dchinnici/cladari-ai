#!/bin/bash
# Cladari AI Server Launcher

echo "🌿 Starting Cladari AI Server..."

# Use axo_env Python which has Flask installed
PORT=${PORT:-8091}
/Users/davidchinnici/axo_env/bin/python3 /Users/davidchinnici/cladari/ai/server.py

# Note: Use PORT=8091 since 8090 is often in use
# Access at: http://localhost:8091