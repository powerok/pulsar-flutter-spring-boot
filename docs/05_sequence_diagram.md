# 시퀀스 다이어그램

**프로젝트명:** Pulsar Chat System  
**버전:** 1.0.0  
**작성일:** 2025-04-12

---

## 1. 시스템 초기화 및 연결 수립

```mermaid
sequenceDiagram
    autonumber
    participant User as 사용자
    participant Browser as 브라우저/앱
    participant Spring as Spring Boot
    participant Pulsar as Apache Pulsar
    participant MinIO as MinIO

    Note over Spring,Pulsar: 서버 기동 시

    Spring->>Pulsar: PulsarClient 생성 (pulsar://localhost:6650)
    Pulsar-->>Spring: 연결 완료
    Spring->>Pulsar: 기본 토픽 Consumer 시작\n(test-topic, files/uploads)
    Spring->>MinIO: MinioClient 초기화
    MinIO-->>Spring: chat-files 버킷 확인/생성

    Note over User,Browser: 사용자 접속

    User->>Browser: 닉네임 / 색상 입력
    Browser->>Spring: GET /api/health
    Spring-->>Browser: {"status": "UP"}

    Browser->>Spring: GET /api/sse/subscribe?clientId=xxx
    Spring-->>Browser: SSE 연결 수립 (text/event-stream)
    Spring-->>Browser: event: connected

    Browser->>Spring: WS Connect /ws (SockJS)
    Spring-->>Browser: CONNECTED frame

    Browser->>Spring: STOMP SUBSCRIBE /topic/chat/general
    Spring-->>Browser: 구독 확인
```

---

## 2. 텍스트 메시지 전송 흐름

```mermaid
sequenceDiagram
    autonumber
    participant UserA as 사용자 A (발신)
    participant Spring as Spring Boot
    participant Pulsar as Pulsar Topic
    participant UserB as 사용자 B (수신)
    participant UserC as 사용자 C (수신)

    UserA->>Spring: POST /api/messages/send\n{roomId, senderId, content}

    Note over Spring: 낙관적 UI 업데이트 (클라이언트)

    Spring->>Spring: ChatMessage 객체 생성\nmessageId = UUID.randomUUID()
    Spring->>Pulsar: Producer.send(payload)\ntopic: persistent://public/chat/room-general\nproperty: messageType=CHAT

    Pulsar-->>Spring: MessageId 반환 (예: 24:0:0:0)
    Spring-->>UserA: {"success": true, "data": {"messageId": "24:0:0:0"}}

    Note over Pulsar,Spring: Consumer가 메시지 수신

    Pulsar->>Spring: Consumer.receive() → ChatMessage
    Spring->>Spring: consumer.acknowledge(msg)

    par 브로드캐스트
        Spring->>UserB: SSE event: message\nChatMessage JSON
        Spring->>UserC: SSE event: message\nChatMessage JSON
        Spring->>UserB: STOMP /topic/chat/general\nChatMessage JSON
        Spring->>UserC: STOMP /topic/chat/general\nChatMessage JSON
    end
```

---

## 3. 파일 업로드 및 공유 흐름

```mermaid
sequenceDiagram
    autonumber
    participant User as 사용자
    participant Spring as Spring Boot
    participant MinIO as MinIO
    participant Pulsar as Apache Pulsar
    participant Others as 다른 사용자들

    User->>Spring: POST /api/files/upload\n(multipart: file + roomId + senderId)

    Spring->>Spring: 파일 크기 검증 (≤50MB)
    Spring->>Spring: fileId 생성\nrooms/{roomId}/{UUID}.{ext}

    Spring->>MinIO: putObject(bucket, fileId, inputStream)\nuser-metadata: uploader-id, original-name
    MinIO-->>Spring: 저장 완료

    Spring->>MinIO: getPresignedObjectUrl(fileId, 1hour)
    MinIO-->>Spring: Pre-signed URL 반환

    Spring->>Spring: ChatMessage 생성\ntype=FILE, fileUrl, fileName, fileSize

    par Pulsar 발행
        Spring->>Pulsar: publish → room-{id} topic
        Spring->>Pulsar: publish → files/uploads topic
    end

    Pulsar->>Spring: Consumer 수신 (files/uploads)
    Spring->>Others: SSE / WebSocket 브로드캐스트\ntype=FILE 메시지

    Spring-->>User: {"fileId": "...", "fileUrl": "...", "fileName": "..."}

    Note over Others: 파일 링크 클릭 시
    Others->>Spring: GET /api/files/download/{fileId}
    Spring->>MinIO: getPresignedObjectUrl() 재발급
    MinIO-->>Spring: 새 Pre-signed URL (1시간)
    Spring-->>Others: {"downloadUrl": "..."}
    Others->>MinIO: 파일 다운로드 (직접)
```

---

## 4. SSE 재연결 흐름

```mermaid
sequenceDiagram
    autonumber
    participant Browser as 브라우저
    participant Spring as Spring Boot

    Browser->>Spring: GET /api/sse/subscribe?clientId=xxx
    Spring-->>Browser: SSE 연결 (emitter 등록)
    Spring-->>Browser: event: connected

    loop 정상 수신
        Spring-->>Browser: event: message (ChatMessage)
    end

    Note over Browser,Spring: 네트워크 단절 / 서버 재시작

    Spring->>Spring: emitter.onError → sseEmitters.remove(clientId)
    Browser->>Browser: EventSource.onerror 발생
    Browser->>Browser: 5초 대기 (setTimeout)

    Browser->>Spring: GET /api/sse/subscribe?clientId=xxx (재연결)
    Spring->>Spring: 새 SseEmitter 등록
    Spring-->>Browser: event: connected (재연결 완료)
```

---

## 5. Flutter 앱 — WebSocket 연결 및 메시지 흐름

```mermaid
sequenceDiagram
    autonumber
    participant App as Flutter App
    participant WS as ChatWebSocketService
    participant Spring as Spring Boot
    participant Pulsar as Apache Pulsar
    participant Hive as Hive (로컬 캐시)

    App->>WS: connect()
    WS->>Spring: WS Upgrade /ws-native
    Spring-->>WS: CONNECTED
    WS->>App: onConnectionChanged(true)

    App->>WS: subscribeToRoom("general")
    WS->>Spring: STOMP SUBSCRIBE /topic/chat/general

    Note over App: 메시지 전송

    App->>App: ChatController.sendMessage(text)
    App->>Hive: 낙관적 저장 (status=SENDING)
    App->>Spring: POST /api/messages/send
    Spring->>Pulsar: publish message
    Pulsar->>Spring: consume + broadcast
    Spring-->>WS: STOMP frame /topic/chat/general
    WS->>App: onMessageReceived(ChatMessage)
    App->>Hive: 저장 (status=SENT)

    Note over App: 앱 백그라운드 전환

    App->>App: FCM 토큰 서버 등록 (v2 예정)
    Spring-->>App: FCM Push Notification\n(새 메시지 알림)

    Note over App: 오프라인 → 온라인

    App->>Hive: 캐시된 메시지 로드
    App->>Spring: WS 재연결 (reconnectDelay: 5s)
```

---

## 6. Dead Letter Queue (DLQ) 처리 흐름

```mermaid
sequenceDiagram
    autonumber
    participant Pulsar as Apache Pulsar
    participant Consumer as PulsarConsumerService
    participant DLQ as Dead Letter Topic

    Pulsar->>Consumer: Message 전달

    alt 정상 처리
        Consumer->>Consumer: JSON 파싱 + 브로드캐스트
        Consumer->>Pulsar: acknowledge(msg) ✅
    else 처리 실패 (1회)
        Consumer->>Pulsar: negativeAcknowledge(msg)
        Note over Pulsar: 3초 후 재전달
        Pulsar->>Consumer: Message 재전달 (1/3)
    else 처리 실패 (2회)
        Consumer->>Pulsar: negativeAcknowledge(msg)
        Pulsar->>Consumer: Message 재전달 (2/3)
    else 처리 실패 (3회 초과)
        Pulsar->>DLQ: persistent://public/default/test-topic-DLQ
        Note over DLQ: 수동 검토 / 알림 발송 예정
    end
```
