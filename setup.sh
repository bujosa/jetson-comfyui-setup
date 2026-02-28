#!/bin/bash
# =============================================================================
# Jetson Orin Nano Super - ComfyUI Setup Script
# =============================================================================
# This script configures a Jetson Orin Nano Super for running ComfyUI
# with Stable Diffusion models using Docker + NVIDIA GPU acceleration.
#
# Prerequisites:
#   - Jetson Orin Nano Super with JetPack 6 (R36.x)
#   - SSH access to the Jetson
#   - Docker pre-installed (comes with JetPack)
#
# Usage:
#   1. Edit the variables below to match your setup
#   2. Run from your local machine (Mac/Linux): bash setup.sh
# =============================================================================

set -e

# ---- Configuration (edit these) ----
JETSON_CURRENT_IP="192.168.1.100"    # Current IP of the Jetson
JETSON_NEW_IP="192.168.1.50"         # Static IP to assign
JETSON_GATEWAY="192.168.1.1"         # Network gateway
JETSON_DNS="8.8.8.8"                 # DNS resolver
JETSON_USER="your_user"              # SSH username
JETSON_PASS="your_password"          # SSH password
WIFI_CONNECTION_NAME="your_wifi"     # NetworkManager WiFi connection name
SSH_ALIAS="nano"                     # SSH alias for ~/.ssh/config
SSH_KEY="$HOME/.ssh/id_ed25519"      # Path to your SSH key

# ---- Colors ----
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[ok]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

# =============================================================================
# Step 1: Copy SSH key for passwordless access
# =============================================================================
echo ""
echo "========================================="
echo " Step 1: SSH Key Setup"
echo "========================================="

if [ ! -f "$SSH_KEY.pub" ]; then
    warn "SSH key not found. Generating one..."
    ssh-keygen -t ed25519 -N "" -f "$SSH_KEY"
fi

cat "$SSH_KEY.pub" | sshpass -p "$JETSON_PASS" ssh -o StrictHostKeyChecking=no \
    "$JETSON_USER@$JETSON_CURRENT_IP" \
    "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
log "SSH key copied to Jetson"

# =============================================================================
# Step 2: Disable sleep/suspend/hibernate
# =============================================================================
echo ""
echo "========================================="
echo " Step 2: Disable Sleep/Suspend"
echo "========================================="

ssh "$JETSON_USER@$JETSON_CURRENT_IP" "
    echo '$JETSON_PASS' | sudo -S systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target 2>/dev/null
    echo '$JETSON_PASS' | sudo -S systemctl set-default multi-user.target 2>/dev/null
"
log "Sleep/suspend/hibernate disabled"

# =============================================================================
# Step 3: Set static IP and DNS
# =============================================================================
echo ""
echo "========================================="
echo " Step 3: Network Configuration"
echo "========================================="

ssh "$JETSON_USER@$JETSON_CURRENT_IP" "
    echo '$JETSON_PASS' | sudo -S nmcli con mod '$WIFI_CONNECTION_NAME' \
        ipv4.method manual \
        ipv4.addresses $JETSON_NEW_IP/24 \
        ipv4.gateway $JETSON_GATEWAY \
        ipv4.dns '$JETSON_DNS' 2>/dev/null
    echo '$JETSON_PASS' | sudo -S nmcli con mod '$WIFI_CONNECTION_NAME' \
        ipv6.method disabled 2>/dev/null
    echo '$JETSON_PASS' | sudo -S nmcli con down '$WIFI_CONNECTION_NAME' 2>/dev/null
    echo '$JETSON_PASS' | sudo -S nmcli con up '$WIFI_CONNECTION_NAME' 2>/dev/null
"

sleep 5

ssh-keygen -R "$JETSON_NEW_IP" 2>/dev/null || true

ssh -o StrictHostKeyChecking=no "$JETSON_USER@$JETSON_NEW_IP" "hostname" && \
    log "Static IP $JETSON_NEW_IP assigned, IPv6 disabled, DNS set to $JETSON_DNS" || \
    { warn "Could not reach Jetson at $JETSON_NEW_IP"; exit 1; }

# =============================================================================
# Step 4: Add SSH config alias
# =============================================================================
echo ""
echo "========================================="
echo " Step 4: SSH Config"
echo "========================================="

if grep -q "Host $SSH_ALIAS" ~/.ssh/config 2>/dev/null; then
    warn "SSH alias '$SSH_ALIAS' already exists in ~/.ssh/config"
else
    cat >> ~/.ssh/config <<EOF

Host $SSH_ALIAS
    HostName $JETSON_NEW_IP
    User $JETSON_USER
    IdentityFile $SSH_KEY
EOF
    chmod 600 ~/.ssh/config
    log "SSH alias added: 'ssh $SSH_ALIAS'"
fi

# =============================================================================
# Step 5: Install dependencies on Jetson
# =============================================================================
echo ""
echo "========================================="
echo " Step 5: Install Dependencies"
echo "========================================="

ssh "$SSH_ALIAS" "
    echo '$JETSON_PASS' | sudo -S apt-get update -qq
    echo '$JETSON_PASS' | sudo -S apt-get install -y -qq python3-pip python3-venv git
"
log "Dependencies installed"

# =============================================================================
# Step 6: Stop unnecessary services
# =============================================================================
echo ""
echo "========================================="
echo " Step 6: Optimize Services"
echo "========================================="

ssh "$SSH_ALIAS" "
    echo '$JETSON_PASS' | sudo -S systemctl stop ollama 2>/dev/null || true
    echo '$JETSON_PASS' | sudo -S systemctl disable ollama 2>/dev/null || true
"
log "Ollama stopped and disabled"

# =============================================================================
# Step 7: Pull and run ComfyUI Docker container
# =============================================================================
echo ""
echo "========================================="
echo " Step 7: ComfyUI Docker Setup"
echo "========================================="

ssh "$SSH_ALIAS" "
    echo '$JETSON_PASS' | sudo -S docker pull dustynv/comfyui:r36.4.3
"
log "ComfyUI Docker image pulled"

ssh "$SSH_ALIAS" "
    echo '$JETSON_PASS' | sudo -S docker run -d \
        --name comfyui \
        --runtime nvidia \
        --restart always \
        --network=host \
        -v /home/$JETSON_USER/comfyui-data:/data \
        dustynv/comfyui:r36.4.3
"
log "ComfyUI container started (auto-restarts on reboot)"

# =============================================================================
# Step 8: Download Stable Diffusion models
# =============================================================================
echo ""
echo "========================================="
echo " Step 8: Download Models"
echo "========================================="

echo "Downloading Stable Diffusion 1.5 (4GB)..."
ssh "$SSH_ALIAS" "
    echo '$JETSON_PASS' | sudo -S docker exec comfyui wget -q --show-progress \
        -O /opt/ComfyUI/models/checkpoints/sd-v1-5.safetensors \
        'https://huggingface.co/stable-diffusion-v1-5/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.safetensors'
"
log "SD 1.5 downloaded"

echo "Downloading Realistic Vision v5.1 (2GB)..."
ssh "$SSH_ALIAS" "
    echo '$JETSON_PASS' | sudo -S docker exec comfyui wget -q --show-progress \
        -O /opt/ComfyUI/models/checkpoints/realistic-vision-v51.safetensors \
        'https://huggingface.co/SG161222/Realistic_Vision_V5.1_noVAE/resolve/main/Realistic_Vision_V5.1_fp16-no-ema.safetensors'
"
log "Realistic Vision v5.1 downloaded"

ssh "$SSH_ALIAS" "echo '$JETSON_PASS' | sudo -S docker restart comfyui"
log "ComfyUI restarted with models"

echo ""
echo "========================================="
echo " Setup Complete!"
echo "========================================="
echo ""
echo " Jetson IP:    $JETSON_NEW_IP"
echo " SSH:          ssh $SSH_ALIAS"
echo " ComfyUI:      http://$JETSON_NEW_IP:8188"
echo ""
