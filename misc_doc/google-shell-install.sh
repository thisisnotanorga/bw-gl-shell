#!/bin/bash

# BotWave - Google Cloud Shell Quick Install
# Sets up BotWave server with Cloudflare tunnels

set -e

# ============================================================================
# CONSTANTS
# ============================================================================

readonly RED='\033[0;31m'
readonly GRN='\033[0;32m'
readonly YEL='\033[1;33m'
readonly BLU='\033[0;34m'
readonly NC='\033[0m'

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

log() {
    local level="$1"
    shift
    local color=""

    case "$level" in
        INFO)  color="$GRN" ;;
        WARN)  color="$YEL" ;;
        ERROR) color="$RED" ;;
        *)     color="$NC" ;;
    esac

    printf "[%s] ${color}%-5s${NC} %s\n" "$(date +%T)" "$level" "$*" >&2
}

silent() {
    "$@" >/dev/null 2>&1
}

# ============================================================================
# INSTALLATION STEPS
# ============================================================================

install_cloudflared() {
    log INFO "Installing cloudflared..."
    
    if command -v cloudflared &> /dev/null; then
        log INFO "cloudflared already installed, skipping"
        return 0
    fi

    local arch=$(uname -m)
    local download_url=""

    case "$arch" in
        x86_64)
            download_url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
            ;;
        aarch64|arm64)
            download_url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64"
            ;;
        armv7l)
            download_url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm"
            ;;
        *)
            log ERROR "Unsupported architecture: $arch"
            exit 1
            ;;
    esac

    sudo wget -q -O /usr/local/bin/cloudflared "$download_url"
    sudo chmod +x /usr/local/bin/cloudflared
    log INFO "cloudflared installed successfully"
}

install_botwave() {
    log INFO "Installing BotWave server..."
    log WARN "This will prompt for sudo password if needed..."
    
    curl -sSL https://botwave.dpip.lol/install | sudo bash -s server
    
    log INFO "BotWave server installed"
}

create_tunnel_handler() {
    log INFO "Creating cloudflared tunnel handler..."
    
    local handler_file="/opt/BotWave/handlers/s_onready.shdl"
    
    sudo mkdir -p "$(dirname "$handler_file")"
    
    sudo tee "$handler_file" > /dev/null <<'EOF'
# BotWave Server Ready Handler
# Automatically starts Cloudflare tunnels when server is ready

< echo "=========================================="
< echo "BotWave Server Started!"
< echo "=========================================="
< echo ""
< echo "Starting Cloudflare tunnels..."
< echo "This will expose your BotWave server to the internet."
< echo ""

# Start tunnel for main server port (9938)
< echo "Starting tunnel for main server (port 9938)..."
< cloudflared tunnel --url http://localhost:9938 > /tmp/cloudflared_9938.log 2>&1 &
< echo $! > /tmp/cloudflared_9938.pid

# Start tunnel for WebSocket port (9921)
< echo "Starting tunnel for WebSocket (port 9921)..."
< cloudflared tunnel --url http://localhost:9921 > /tmp/cloudflared_9921.log 2>&1 &
< echo $! > /tmp/cloudflared_9921.pid

# Wait for tunnels to initialize
< sleep 3

# Display tunnel information
< echo ""
< echo "=========================================="
< echo "Your BotWave server is now accessible at:"
< echo "=========================================="
< grep -oP 'https://[a-z0-9-]+\.trycloudflare\.com' /tmp/cloudflared_9938.log | head -1 | xargs -I {} echo "Main Server: {}"
< grep -oP 'https://[a-z0-9-]+\.trycloudflare\.com' /tmp/cloudflared_9921.log | head -1 | xargs -I {} echo "WebSocket:   {}"
< echo "=========================================="
< echo ""
< echo "Tunnel PIDs stored in /tmp/cloudflared_*.pid"
< cat /tmp/cloudflared_9938.pid /tmp/cloudflared_9921.pid | xargs echo "To stop tunnels: kill"
< echo ""
< grep -oP 'https://[a-z0-9-]+\.trycloudflare\.com' /tmp/cloudflared_9938.log | head -1 | sed 's|https://||' | xargs -I {} echo "Start clients with: sudo bw-client {} --port 80 --fhost $(grep -oP '[a-z0-9-]+\.trycloudflare\.com' /tmp/cloudflared_9921.log | head -1) --fport 80"
< echo "=========================================="
EOF

    log INFO "Tunnel handler created at $handler_file"
}
# ============================================================================
# MAIN
# ============================================================================

main() {
    echo ""
    echo "=================================="
    echo "BotWave Google Cloud Shell Install"
    echo "=================================="
    echo ""
    
    log INFO "Starting installation..."
    
    install_cloudflared
    
    install_botwave
    
    create_tunnel_handler
    
    echo ""
    log INFO "Installation complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Start BotWave server: bw-server"
    echo "  2. The tunnels will start automatically when server is ready"
    echo "  3. Use the provided URLs to access your server"
    echo ""
}

main "$@"