#!/bin/bash

# Test webhook with proper GitHub signature
# Usage: ./test-webhook.sh <webhook-secret> <server-url>

WEBHOOK_SECRET="$1"
SERVER_URL="$2"

if [ -z "$WEBHOOK_SECRET" ] || [ -z "$SERVER_URL" ]; then
    echo "Usage: $0 <webhook-secret> <server-url>"
    echo "Example: $0 your-secret-here http://your-server.com/webhook/github"
    exit 1
fi

# Test payload (GitHub ping event)
PAYLOAD='{
  "zen": "Responsive is better than fast.",
  "hook_id": 12345678,
  "hook": {
    "type": "Repository",
    "id": 12345678,
    "name": "web",
    "active": true,
    "events": ["push", "pull_request"],
    "config": {
      "content_type": "json",
      "insecure_ssl": "0",
      "url": "'"$SERVER_URL"'"
    }
  },
  "repository": {
    "id": 35129377,
    "name": "public-repo",
    "full_name": "baxterthehacker/public-repo",
    "owner": {
      "login": "baxterthehacker",
      "id": 6752317
    }
  }
}'

echo "Testing webhook with payload:"
echo "$PAYLOAD"
echo ""

# Generate HMAC signature
SIGNATURE=$(echo -n "$PAYLOAD" | openssl dgst -sha256 -hmac "$WEBHOOK_SECRET" | sed 's/^.* //')

echo "Generated signature: sha256=$SIGNATURE"
echo ""

# Send request
curl -v -X POST "$SERVER_URL" \
  -H "Content-Type: application/json" \
  -H "X-GitHub-Event: ping" \
  -H "X-GitHub-Delivery: 12345678-1234-1234-1234-123456789012" \
  -H "X-Hub-Signature-256: sha256=$SIGNATURE" \
  -d "$PAYLOAD"