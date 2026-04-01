#!/bin/bash
# Simple HTTP POST wrapper using curl
# Usage: http-post.sh <url> <json> <timeout> <api-key>

URL="$1"
JSON="$2"
TIMEOUT="${3:-120}"
API_KEY="$4"

curl -s -X POST \
  -H "Content-Type: application/json" \
  --max-time "$TIMEOUT" \
  "$URL" \
  --data "$JSON" \
  ${API_KEY:+-H "Authorization: Bearer $API_KEY"}