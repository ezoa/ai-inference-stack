
#!/usr/bin/env bash
set -euo pipefail

echo "Checking Tailscale installation..."

if ! command -v tailscale >/dev/null 2>&1; then
  echo "Tailscale is not installed."
  echo "Install it using:"
  echo "curl -fsSL https://tailscale.com/install.sh | sh"
  exit 1
fi

echo "Checking Tailscale authentication..."

if ! tailscale status >/dev/null 2>&1; then
  echo "Please authenticate Tailscale:"
  echo "sudo tailscale up"
  exit 1
fi

echo "Checking LiteLLM availability..."

if ! curl -fsS \
  http://127.0.0.1:4000/health/liveliness \
  >/dev/null; then
  echo "LiteLLM is not responding locally."
  echo "Start the containers first."
  exit 1
fi

echo "Enabling private HTTPS access..."

sudo tailscale serve --bg 4000

echo
echo "Remote access configuration:"
tailscale serve status

echo
echo "Only authorized devices in your"
echo "Tailscale network can connect."
echo
echo "To disable remote access:"
echo "sudo tailscale serve off"
