#!/bin/sh
echo "=== Find H2 DB file ==="
find / -name "*.mv.db" 2>/dev/null | head -5
find /pulsar-manager -type f 2>/dev/null | head -20

echo "=== Check application.properties ==="
find / -name "application.properties" 2>/dev/null | head -3 | xargs cat 2>/dev/null

echo "=== Try login with CSRF ==="
# Step 1: Get CSRF cookie from login page
curl -v -c /tmp/c.txt -s http://localhost:7750/pulsar-manager/login 2>&1 | grep -E "XSRF|csrf|Set-Cookie" | head -10

# Step 2: Extract token
XSRF=$(cat /tmp/c.txt | grep XSRF | awk '{print $7}')
echo "XSRF from cookie: $XSRF"

# Step 3: Login
curl -s -b /tmp/c.txt -c /tmp/c.txt \
  -X POST \
  -H "Content-Type: application/json" \
  -H "X-XSRF-TOKEN: $XSRF" \
  http://localhost:7750/pulsar-manager/login \
  -d '{"username":"admin","password":"apachepulsar"}'
echo ""
