
#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if [ ! -f .env ]; then
  echo "ERROR: .env file not found."
  exit 1
fi

set -a
source .env
set +a

if [ -z "${LITELLM_MASTER_KEY:-}" ]; then
  echo "ERROR: LITELLM_MASTER_KEY is missing."
  exit 1
fi

BASE_URL="http://127.0.0.1:4000"

echo "Checking LiteLLM model list..."

curl --fail-with-body -sS \
  "$BASE_URL/v1/models" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY"

echo
echo "Sending a test message to Qwen..."

curl --fail-with-body -sS \
  "$BASE_URL/v1/chat/completions" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen-coder",
    "messages": [
      {
        "role": "system",
        "content": "You are a helpful AI assistant."
      },
      {
        "role": "user",
        "content": "Hello! Explain your capabilities briefly."
      }
    ],
    "max_tokens": 512
  }'

echo
