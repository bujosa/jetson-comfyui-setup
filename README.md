# jetson-comfyui-setup

Automated setup for running [ComfyUI](https://github.com/comfyanonymous/ComfyUI) on a **NVIDIA Jetson Orin Nano Super** with GPU acceleration via Docker.

## Hardware

| Component | Spec |
|-----------|------|
| Board | NVIDIA Jetson Orin Nano Super |
| CPU | 6-core ARM Cortex-A78AE |
| RAM | 8 GB LPDDR5 (shared CPU/GPU) |
| GPU | 1024-core NVIDIA Ampere (67 TOPS INT8) |
| CUDA | 12.6 |
| Storage | NVMe SSD |
| JetPack | 6.x (R36.4.x) |

## What the script does

1. **SSH key setup** — Copies your public key for passwordless access
2. **Disable sleep/suspend** — Keeps the Jetson running 24/7
3. **Static IP + DNS** — Assigns a fixed IP, sets custom DNS, disables IPv6
4. **SSH alias** — Adds `ssh nano` shortcut to `~/.ssh/config`
5. **Install dependencies** — pip, venv, git
6. **Stop Ollama** — Frees RAM for ComfyUI
7. **Pull & run ComfyUI** — Docker container with NVIDIA runtime, auto-restart on boot
8. **Download models** — Stable Diffusion 1.5 + Realistic Vision v5.1

## Prerequisites

- Jetson Orin Nano Super with JetPack 6 (R36.x)
- Docker pre-installed (included with JetPack)
- `sshpass` on your local machine (`brew install hudochenkov/sshpass/sshpass` on Mac)
- WiFi or Ethernet connection to the Jetson

## Usage

1. Clone this repo:
```bash
git clone https://github.com/YOUR_USER/jetson-comfyui-setup.git
cd jetson-comfyui-setup
```

2. Edit the configuration variables at the top of `setup.sh`:
```bash
JETSON_CURRENT_IP="192.168.1.100"  # Current IP of your Jetson
JETSON_NEW_IP="192.168.1.50"      # Static IP to assign
JETSON_USER="your_user"           # Your username
JETSON_PASS="your_password"       # Your password
WIFI_CONNECTION_NAME="your_wifi"  # WiFi connection name (run: nmcli con show)
```

3. Run the script:
```bash
chmod +x setup.sh
bash setup.sh
```

4. Open ComfyUI in your browser:
```
http://<JETSON_IP>:8188
```

## Models included

| Model | Size | Use case |
|-------|------|----------|
| Stable Diffusion 1.5 | 4 GB | General purpose, art, various styles |
| Realistic Vision v5.1 | 2 GB | Photorealistic portraits and photos |

## Useful commands

```bash
# Connect to Jetson
ssh nano

# View ComfyUI logs
ssh nano 'sudo docker logs --tail 20 comfyui'

# Restart ComfyUI
ssh nano 'sudo docker restart comfyui'

# Check resource usage
ssh nano 'free -h && sudo docker stats --no-stream'

# Clear system cache (frees RAM)
ssh nano 'sudo sh -c "sync && echo 3 > /proc/sys/vm/drop_caches"'

# List generated images
ssh nano 'sudo docker exec comfyui ls -lh /opt/ComfyUI/output/'

# Re-enable Ollama
ssh nano 'sudo systemctl enable --now ollama'
```

## Tips for 8GB RAM

- Use **fp16** models when possible (half the memory)
- Start with **384x512** or **512x512** resolution (SD 1.5 native)
- Use **15-20 steps** (more steps = more memory)
- Clear system cache before generating: `sudo sh -c "sync && echo 3 > /proc/sys/vm/drop_caches"`
- Disable unused services (Ollama, desktop environment)

## Power consumption

| Mode | Watts | Monthly cost (~$0.15/kWh) |
|------|-------|---------------------------|
| Idle | ~7W | ~$0.77 |
| Moderate (inference) | ~15W | ~$1.64 |
| Full GPU load | ~25W | ~$2.74 |

## License

MIT
