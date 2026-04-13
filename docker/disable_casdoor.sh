#!/bin/sh
echo "=== Setting default environment to bypass Casdoor ==="

# Find the application.properties file
CONFIG_FILE=$(find / -name "application.properties" 2>/dev/null | grep pulsar-manager | head -1)
echo "Config file: $CONFIG_FILE"

# Disable casdoor by clearing its endpoint
sed -i 's|casdoor.endpoint = http://localhost:8000|casdoor.endpoint =|g' "$CONFIG_FILE"
sed -i 's|casdoor.clientId = 6ba06c1e1a30929fdda7|casdoor.clientId =|g' "$CONFIG_FILE"

echo "=== Config after edit ==="
grep casdoor "$CONFIG_FILE"

echo "=== Restarting pulsar-manager service ==="
supervisorctl restart pulsar-manager 2>/dev/null || true
sleep 5

echo "Done"
