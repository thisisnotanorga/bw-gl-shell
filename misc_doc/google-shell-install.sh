#!/bin/bash

# BotWave - Google Cloud Shell Quick Install
# Sets up BotWave server with ngrok tunnels (better WebSocket support)

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

# ============================================================================
# INSTALLATION STEPS
# ============================================================================

install_ngrok() {
    log INFO "Installing ngrok..."
    
    if command -v ngrok &> /dev/null; then
        log INFO "ngrok already installed, skipping"
        return 0
    fi

    local arch=$(uname -m)
    local download_url=""

    case "$arch" in
        x86_64)
            download_url="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz"
            ;;
        aarch64|arm64)
            download_url="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm64.tgz"
            ;;
        *)
            log ERROR "Unsupported architecture: $arch"
            exit 1
            ;;
    esac

    curl -sSL "$download_url" | sudo tar -xz -C /usr/local/bin
    sudo chmod +x /usr/local/bin/ngrok
    log INFO "ngrok installed successfully"
}

install_botwave() {
    log INFO "Installing BotWave server..."
    
    curl -sSL https://botwave.dpip.lol/install | sudo bash -s server
    
    log INFO "BotWave server installed"
}

create_tunnel_script() {
    log INFO "Creating ngrok tunnel script..."
    
    local script_dir="/opt/BotWave/googleshell"
    local script_file="$script_dir/tunnel.sh"
    
    sudo mkdir -p "$script_dir"
    
    sudo tee "$script_file" > /dev/null <<'EOF'
#!/bin/bash

# BotWave ngrok Tunnel Starter
# Uses ngrok for better WebSocket support

echo "=========================================="
echo "BotWave Server Started!"
echo "=========================================="
echo ""
echo "Starting ngrok tunnels..."
echo "This will expose your BotWave server to the internet."
echo ""

# Install ngrok if not present
if ! command -v ngrok &> /dev/null; then
    echo "Installing ngrok..."
    curl -sSL https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz | tar -xz -C /tmp
    sudo mv /tmp/ngrok /usr/local/bin/
    sudo chmod +x /usr/local/bin/ngrok
fi

# Kill any existing ngrok processes
pkill ngrok 2>/dev/null || true
sleep 2

# Start tunnels
ngrok http 9938 --log /tmp/ngrok_9938.log > /dev/null 2>&1 &
echo $! > /tmp/ngrok_9938.pid

ngrok http 9921 --log /tmp/ngrok_9921.log > /dev/null 2>&1 &
echo $! > /tmp/ngrok_9921.pid

# Wait for tunnels
sleep 5

# Get URLs
echo ""
echo "=========================================="
WS_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"https://[^"]*"' | head -1 | cut -d'"' -f4 | sed 's|https://||')
HTTP_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"https://[^"]*"' | tail -1 | cut -d'"' -f4 | sed 's|https://||')

if [ -n "$WS_URL" ] && [ -n "$HTTP_URL" ]; then
    echo "WebSocket: https://$WS_URL"
    echo "HTTP:      https://$HTTP_URL"
    echo "=========================================="
    echo ""
    echo "Connect with: bw-client $WS_URL --port 443 --fhost $HTTP_URL --fport 443"
    echo ""
    echo "Tunnel status: http://localhost:4040"
else
    echo "Error getting tunnel URLs. Check http://localhost:4040"
fi
echo "=========================================="
EOF

    sudo chmod +x "$script_file"
    log INFO "Tunnel script created at $script_file"
}

create_tunnel_handler() {
    log INFO "Creating tunnel handler..."
    
    local handler_file="/opt/BotWave/handlers/s_onready.shdl"
    
    sudo mkdir -p "$(dirname "$handler_file")"
    
    sudo tee "$handler_file" > /dev/null <<'EOF'
# BotWave Server Ready Handler
# Automatically starts ngrok tunnels when server is ready

< bash /opt/BotWave/googleshell/tunnel.sh
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
    echo "Using ngrok for tunnels"
    echo "=================================="
    echo ""
    
    log INFO "Starting installation..."
    
    install_ngrok
    
    install_botwave
    
    create_tunnel_script
    
    create_tunnel_handler
    
    echo ""
    log INFO "Installation complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Start BotWave server: bw-server"
    echo "  2. The tunnels will start automatically"
    echo "  3. View tunnel dashboard at http://localhost:4040"
    echo ""
}

main "$@"