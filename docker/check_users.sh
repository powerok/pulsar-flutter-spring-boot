#!/bin/sh
echo "=== Getting Users ==="
# Get CSRF
RESPONSE=$(curl -s -c /tmp/cookies.txt http://localhost:7750/pulsar-manager/csrf-token)
TOKEN=$(echo $RESPONSE | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('token',''))" 2>/dev/null)
if [ -z "$TOKEN" ]; then
  curl -s -c /tmp/cookies.txt http://localhost:7750 > /dev/null
  TOKEN=$(cat /tmp/cookies.txt | grep XSRF | awk '{print $7}')
fi

# List Users
curl -s -b /tmp/cookies.txt -X GET http://localhost:7750/pulsar-manager/users \
  -H "X-XSRF-TOKEN: $TOKEN"

echo ""
