#!/bin/sh
echo "=== Pulsar Manager Admin Creation ==="

# 1. Get CSRF token
echo "[1] Getting CSRF token..."
RESPONSE=$(curl -s -c /tmp/cookies.txt http://localhost:7750/pulsar-manager/csrf-token)
echo "  Response: $RESPONSE"

TOKEN=$(echo $RESPONSE | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('token',''))" 2>/dev/null)
if [ -z "$TOKEN" ]; then
  # Try cookie-based CSRF
  curl -s -c /tmp/cookies.txt http://localhost:7750 > /dev/null
  TOKEN=$(cat /tmp/cookies.txt | grep XSRF | awk '{print $7}')
fi
echo "  CSRF Token: $TOKEN"

# 2. Create superuser with PUT
echo "[2] Creating superuser admin..."
RESULT=$(curl -s -b /tmp/cookies.txt -c /tmp/cookies.txt \
  -X PUT \
  -H "Content-Type: application/json" \
  -H "X-XSRF-TOKEN: $TOKEN" \
  http://localhost:7750/pulsar-manager/users/superuser \
  -d '{"name":"admin","password":"apachepulsar","description":"admin","email":"admin@abc.com"}')
echo "  Result: $RESULT"

# 3. Try POST as fallback
if echo "$RESULT" | grep -q "403\|error\|Forbidden"; then
  echo "[3] Trying POST method..."
  RESULT2=$(curl -s -b /tmp/cookies.txt -c /tmp/cookies.txt \
    -X POST \
    -H "Content-Type: application/json" \
    -H "X-XSRF-TOKEN: $TOKEN" \
    http://localhost:7750/pulsar-manager/users/superuser \
    -d '{"name":"admin","password":"apachepulsar","description":"admin","email":"admin@abc.com"}')
  echo "  Result2: $RESULT2"
fi

echo "=== Done ==="
