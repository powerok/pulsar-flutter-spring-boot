#!/bin/bash
# Pulsar 토픽 초기화 스크립트
echo "=== Pulsar Topic 초기화 시작 ==="

PULSAR_ADMIN="bin/pulsar-admin"

# 네임스페이스 생성
$PULSAR_ADMIN namespaces create public/chat 2>/dev/null || true
$PULSAR_ADMIN namespaces create public/files 2>/dev/null || true

# 채팅 토픽 생성
$PULSAR_ADMIN topics create persistent://public/default/test-topic 2>/dev/null || true
$PULSAR_ADMIN topics create persistent://public/chat/general 2>/dev/null || true
$PULSAR_ADMIN topics create persistent://public/chat/room-1 2>/dev/null || true
$PULSAR_ADMIN topics create persistent://public/chat/room-load-test 2>/dev/null || true
$PULSAR_ADMIN topics create persistent://public/files/uploads 2>/dev/null || true

# Dead Letter Topic 생성
$PULSAR_ADMIN topics create persistent://public/default/test-topic-DLQ 2>/dev/null || true

# 메시지 보관 정책 설정 (7일)
$PULSAR_ADMIN namespaces set-retention public/chat \
  --size -1 \
  --time 7d 2>/dev/null || true

echo "=== Pulsar Topic 초기화 완료 ==="
$PULSAR_ADMIN topics list public/default
$PULSAR_ADMIN topics list public/chat
