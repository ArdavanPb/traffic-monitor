# Traffic Monitor System

A comprehensive network traffic monitoring system with automatic interface detection and web UI.

## Features

- **Automatic Network Interface Detection**: Automatically detects primary network interfaces
- **Real-time Traffic Monitoring**: Tracks upload/download statistics across all interfaces
- **Web Dashboard**: Modern web interface with authentication
- **Historical Logging**: Maintains daily logs of network usage
- **Multi-interface Support**: Monitor traffic on all available interfaces
- **Auto-refresh**: Real-time updates in the web UI

## Installation

1. **Clone or download the project**
   ```bash
   cd /home/ap/projects/traffic-monitor
   ```

2. **Make scripts executable**
   ```bash
   chmod +x *.sh
   chmod +x web_app.py
   ```

3. **Install Python dependencies**
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   pip install Flask Werkzeug
   ```

## Usage

### Quick Start
```bash
./start-web.sh
```

This will:
- Create necessary directories
- Set up initial traffic monitoring baseline
- Start the web server on http://localhost:8080

### Manual Monitoring
```bash
# Run the enhanced monitor
./traffic-monitor-v2.sh

# Or the basic version
./traffic-monitor.sh
```

### Web Interface
- URL: http://localhost:8080
- Username: `admin`
- Password: `admin123`

## Files

- `traffic-monitor.sh` - Basic traffic monitoring script
- `traffic-monitor-v2.sh` - Enhanced version with auto-detection
- `web_app.py` - Flask web application
- `start-web.sh` - Startup script
- `requirements.txt` - Python dependencies
- `templates/` - HTML templates for web UI

## Configuration

### Web UI Credentials
Edit `web_app.py` to change default credentials:
```python
CONFIG = {
    'web_user': 'admin',        # Change this
    'web_pass': 'admin123',     # Change this in production!
    # ...
}
```

### Monitoring Directories
Data is stored in:
- `~/.traffic-monitor/logs/` - Daily log files
- `~/.traffic-monitor/state/` - Monitoring state files

## How It Works

1. **Interface Detection**: Script automatically detects active network interfaces
2. **Traffic Counting**: Reads `/sys/class/net/*/statistics/*_bytes` or `/proc/net/dev`
3. **State Management**: Stores baseline readings to calculate usage over time
4. **Web Interface**: Provides real-time dashboard with authentication
5. **Logging**: Maintains daily logs of network activity

## Security Notes

1. **Change default password** in `web_app.py` before production use
2. The web server binds to `0.0.0.0:8080` - adjust as needed
3. Monitoring requires read access to `/sys/class/net/` and `/proc/net/dev`

## Troubleshooting

### Permission Issues
If you see permission errors:
```bash
# Run with sudo for system-wide monitoring
sudo ./traffic-monitor-v2.sh
```

### Interface Not Found
The script will list available interfaces. Update `INTERFACE` in `traffic-monitor.sh` if needed.

### Web UI Not Starting
Check Python installation:
```bash
python3 --version
pip list | grep Flask
```

## License

MIT License