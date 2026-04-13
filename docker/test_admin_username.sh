#!/bin/sh
echo "=== Pulsar Manager Admin Creation (username payload) ==="
RESPONSE=$(curl -s -c /tmp/cookies.txt http://localhost:7750/pulsar-manager/csrf-token)
TOKEN=$(echo $RESPONSE | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('token',''))" 2>/dev/null)
if [ -z "$TOKEN" ]; then
  curl -s -c /tmp/cookies.txt http://localhost:7750 > /dev/null
  TOKEN=$(cat /tmp/cookies.txt | grep XSRF | awk '{print $7}')
fi

echo "Token: $TOKEN"

curl -s -i -b /tmp/cookies.txt -c /tmp/cookies.txt \
  -X PUT \
  -H "Content-Type: application/json" \
  -H "X-XSRF-TOKEN: $TOKEN" \
  http://localhost:7750/pulsar-manager/users/superuser \
  -d '{"username":"admin","password":"apachepulsar","description":"admin","email":"admin@abc.com"}'

echo "\n=== Testing Login ==="
curl -s -i -b /tmp/cookies.txt -c /tmp/cookies.txt \
  -X POST \
  -H "Content-Type: application/json" \
  -H "X-XSRF-TOKEN: $TOKEN" \
  http://localhost:7750/pulsar-manager/login \
  -d '{"username":"admin","password":"apachepulsar"}'
echo ""
