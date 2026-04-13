#!/bin/sh
echo "=== Testing Login ==="
curl -s -X POST http://localhost:7750/pulsar-manager/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"apachepulsar"}'
echo ""

echo "=== Checking DB users ==="
# Try to list users via API
curl -s http://localhost:7750/pulsar-manager/users/superuser 2>/dev/null || true
echo ""
