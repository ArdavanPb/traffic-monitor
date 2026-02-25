#!/usr/bin/env python3
"""
Traffic Monitor Web UI
Provides web interface to monitor network traffic with authentication
"""

import os
import json
import time
import subprocess
from datetime import datetime
from flask import Flask, render_template, request, redirect, url_for, session, jsonify
from functools import wraps

app = Flask(__name__)
app.secret_key = os.urandom(24)
app.config['PERMANENT_SESSION_LIFETIME'] = 3600  # 1 hour

# Configuration
CONFIG = {
    'web_user': 'admin',
    'web_pass': 'admin123',  # Change this in production!
    'log_dir': os.path.expanduser('~/.traffic-monitor/logs'),
    'state_dir': os.path.expanduser('~/.traffic-monitor/state'),
    'script_path': os.path.join(os.path.dirname(os.path.abspath(__file__)), 'traffic-monitor-v2.sh')
}

# Create directories if they don't exist
os.makedirs(CONFIG['log_dir'], exist_ok=True)
os.makedirs(CONFIG['state_dir'], exist_ok=True)

def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'logged_in' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

def get_network_interfaces():
    """Get list of available network interfaces"""
    interfaces = []
    try:
        result = subprocess.run(['ip', 'link', 'show'], capture_output=True, text=True)
        for line in result.stdout.split('\n'):
            if ':' in line and not 'lo:' in line:
                parts = line.strip().split(':')
                if len(parts) > 1:
                    iface = parts[1].strip()
                    if iface and not iface.startswith('docker') and not iface.startswith('br-'):
                        interfaces.append(iface)
    except:
        pass
    return interfaces if interfaces else ['eth0', 'wlan0']

def get_traffic_stats(interface=None):
    """Get traffic statistics from the monitoring script"""
    try:
        cmd = [CONFIG['script_path']]
        if interface:
            cmd.extend(['--interface', interface])
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        return result.stdout
    except Exception as e:
        return f"Error getting traffic stats: {str(e)}"

def parse_traffic_output(output):
    """Parse the traffic monitor output into structured data"""
    data = {
        'primary_interface': '',
        'monitoring_since': '',
        'time_elapsed': '',
        'download_used': '',
        'upload_used': '',
        'total_used': '',
        'current_rx': '',
        'current_tx': '',
        'current_total': '',
        'avg_download_rate': '',
        'avg_upload_rate': '',
        'all_interfaces': [],
        'log_file': '',
        'state_file': ''
    }
    
    lines = output.split('\n')
    in_all_interfaces_section = False
    
    for i, line in enumerate(lines):
        if 'ALL INTERFACES' in line:
            in_all_interfaces_section = True
            # Parse all interfaces section
            for j in range(i + 1, len(lines)):
                if ':' in lines[j] and ('RX:' in lines[j] or 'TX:' in lines[j]):
                    iface_data = lines[j].strip()
                    data['all_interfaces'].append(iface_data)
            continue
        
        if in_all_interfaces_section and ':' in line and ('RX:' in line or 'TX:' in line):
            # Skip interface lines in the ALL INTERFACES section
            continue
            
        if 'Primary Interface:' in line:
            data['primary_interface'] = line.split(':')[1].strip()
        elif 'Monitoring since:' in line:
            data['monitoring_since'] = line.split(':', 1)[1].strip()
        elif 'Time elapsed:' in line:
            data['time_elapsed'] = line.split(':', 1)[1].strip()
        elif 'Downloaded' in line and 'bytes' in line:
            parts = line.split(':')
            if len(parts) > 1:
                data['download_used'] = parts[1].strip().split('(')[0].strip()
        elif 'Uploaded' in line and 'bytes' in line:
            parts = line.split(':')
            if len(parts) > 1:
                data['upload_used'] = parts[1].strip().split('(')[0].strip()
        elif 'Total traffic' in line and 'bytes' in line:
            parts = line.split(':')
            if len(parts) > 1:
                data['total_used'] = parts[1].strip().split('(')[0].strip()
        elif 'RX:' in line and 'TX:' not in line:
            data['current_rx'] = line.split(':')[1].strip()
        elif 'TX:' in line:
            data['current_tx'] = line.split(':')[1].strip()
        elif '∑ :' in line:
            data['current_total'] = line.split(':')[1].strip()
        elif 'Avg. download rate:' in line:
            data['avg_download_rate'] = line.split(':')[1].strip()
        elif 'Avg. upload rate' in line:
            data['avg_upload_rate'] = line.split(':')[1].strip()
        elif 'Log file:' in line:
            data['log_file'] = line.split(':')[1].strip()
        elif 'State file:' in line:
            data['state_file'] = line.split(':')[1].strip()
    
    return data

def get_recent_logs(limit=50):
    """Get recent log entries"""
    log_files = []
    try:
        # Get today's log file
        today = datetime.now().strftime('%Y-%m-%d')
        today_log = os.path.join(CONFIG['log_dir'], f'traffic-{today}.log')
        
        if os.path.exists(today_log):
            with open(today_log, 'r') as f:
                lines = f.readlines()[-limit:]
                return lines
        
        # Get all log files sorted by date
        for fname in os.listdir(CONFIG['log_dir']):
            if fname.startswith('traffic-') and fname.endswith('.log'):
                log_files.append(fname)
        
        log_files.sort(reverse=True)
        
        if log_files:
            latest_log = os.path.join(CONFIG['log_dir'], log_files[0])
            with open(latest_log, 'r') as f:
                lines = f.readlines()[-limit:]
                return lines
    except:
        pass
    
    return ["No log entries found."]

@app.route('/')
@login_required
def index():
    """Main dashboard"""
    interfaces = get_network_interfaces()
    stats_output = get_traffic_stats()
    stats = parse_traffic_output(stats_output)
    logs = get_recent_logs(20)
    
    return render_template('index.html', 
                         stats=stats, 
                         interfaces=interfaces,
                         logs=logs,
                         current_time=datetime.now().strftime('%Y-%m-%d %H:%M:%S'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    """Login page"""
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        
        if username == CONFIG['web_user'] and password == CONFIG['web_pass']:
            session['logged_in'] = True
            session.permanent = True
            return redirect(url_for('index'))
        else:
            return render_template('login.html', error='Invalid credentials')
    
    return render_template('login.html')

@app.route('/logout')
def logout():
    """Logout user"""
    session.pop('logged_in', None)
    return redirect(url_for('login'))

@app.route('/api/stats')
@login_required
def api_stats():
    """API endpoint for getting stats (for AJAX updates)"""
    stats_output = get_traffic_stats()
    stats = parse_traffic_output(stats_output)
    return jsonify(stats)

@app.route('/api/logs')
@login_required
def api_logs():
    """API endpoint for getting recent logs"""
    logs = get_recent_logs(50)
    return jsonify({'logs': logs})

@app.route('/api/interface/<interface>')
@login_required
def api_interface_stats(interface):
    """API endpoint for specific interface stats"""
    stats_output = get_traffic_stats(interface)
    stats = parse_traffic_output(stats_output)
    return jsonify(stats)

@app.route('/reset', methods=['POST'])
@login_required
def reset_stats():
    """Reset monitoring statistics"""
    try:
        # Find and remove state files
        for fname in os.listdir(CONFIG['state_dir']):
            if fname.startswith('traffic-') and fname.endswith('.state'):
                os.remove(os.path.join(CONFIG['state_dir'], fname))
        
        return jsonify({'success': True, 'message': 'Statistics reset successfully'})
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)})

if __name__ == '__main__':
    port = 8080
    print(f"Traffic Monitor Web UI starting on http://localhost:{port}")
    print(f"Login with username: {CONFIG['web_user']}, password: {CONFIG['web_pass']}")
    app.run(host='0.0.0.0', port=port, debug=True)