#!/usr/bin/env bash
#
# Start Traffic Monitor Web UI
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 is not installed"
    exit 1
fi

# Check if virtual environment exists
if [ -d "venv" ]; then
    echo "Activating virtual environment..."
    source venv/bin/activate
else
    echo "Creating virtual environment..."
    python3 -m venv venv
    source venv/bin/activate
    pip install Flask Werkzeug
fi

# Create necessary directories
mkdir -p ~/.traffic-monitor/logs
mkdir -p ~/.traffic-monitor/state

# Make scripts executable
chmod +x traffic-monitor.sh traffic-monitor-v2.sh web_app.py

# Run initial traffic monitoring to create baseline
echo "Running initial traffic monitoring..."
./traffic-monitor-v2.sh

# Start continuous monitoring in background (every 60 seconds)
echo "Starting continuous monitoring in background..."
(
  while true; do
    ./traffic-monitor-v2.sh
    sleep 60
  done
) &

echo ""
echo "============================================="
echo "Starting Traffic Monitor Web UI..."
echo "============================================="
echo "Web Interface: http://localhost:8080"
echo "Username: admin"
echo "Password: admin123"
echo ""
echo "Press Ctrl+C to stop the server"
echo "============================================="

# Start the web application
python3 web_app.py