#!/bin/sh
echo "=== Try login with CSRF ==="
# Step 1: Get CSRF cookie from login page
curl -v -c /tmp/cookies.txt -s http://localhost:9527/pulsar-manager/login 2>&1 | grep -E "XSRF|csrf|Set-Cookie" | head -10

# Step 2: Extract token
XSRF=$(cat /tmp/cookies.txt | grep XSRF | awk '{print $7}')
echo "XSRF from cookie: $XSRF"

# Step 3: Login as pulsar/pulsar
curl -s -i -b /tmp/cookies.txt -c /tmp/cookies.txt \
  -X POST \
  -H "Content-Type: application/json" \
  -H "X-XSRF-TOKEN: $XSRF" \
  http://localhost:9527/pulsar-manager/login \
  -d '{"username":"pulsar","password":"pulsar"}'
echo ""
