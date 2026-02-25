FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    iproute2 \
    procps \
    bc \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY . .

# Make scripts executable
RUN chmod +x *.sh web_app.py

# Create directories for logs and state
RUN mkdir -p /root/.traffic-monitor/logs /root/.traffic-monitor/state

# Expose web port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/login')" || exit 1

# Start the application
CMD ["./start-web.sh"]