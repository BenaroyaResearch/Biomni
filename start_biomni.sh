#!/bin/bash
# Biomni Startup Script
# Usage: ./start_biomni.sh

# Set locale to prevent R warnings (use C.utf8 which is available in the container)
export LANG=C.utf8
export LC_ALL=C.utf8

set -a  # automatically export all variables
[ -f .env ] && source .env
set +a

echo "🧬 Starting Biomni Agent..."
conda run --no-capture-output -n biomni_e1 python start_biomni.py
