#!/bin/sh
echo "=== Config check ==="
cat /pulsar-manager/pulsar-manager/application.properties | awk '/user.management|account|casdoor/{print}'

echo "=== API login test with pulsar/pulsar ==="
curl -s -c /tmp/c2.txt http://localhost:7750/pulsar-manager/login 2>/dev/null | head -5
XSRF=$(cat /tmp/c2.txt | awk '/XSRF/{print $7}')
echo "XSRF: $XSRF"
curl -s -b /tmp/c2.txt -c /tmp/c2.txt \
  -X POST \
  -H "Content-Type: application/json" \
  -H "X-XSRF-TOKEN: $XSRF" \
  http://localhost:7750/pulsar-manager/login \
  -d '{"username":"pulsar","password":"pulsar"}'
echo ""
