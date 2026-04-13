# 시스템 아키텍처 설계서

**프로젝트명:** Pulsar Chat System  
**버전:** 1.0.0  
**작성일:** 2025-04-12

---

## 1. 전체 시스템 구성도

```mermaid
graph TB
    subgraph CLIENT["클라이언트 레이어"]
        VUE["🌐 Vue.js CDN\n브라우저\nSSE + STOMP"]
        FLUTTER["📱 Flutter App\nAndroid / iOS\nWebSocket + REST"]
    end

    subgraph BACKEND["Spring Boot Backend :8081"]
        direction TB
        subgraph API["API 레이어"]
            MCTRL["MessageController\n/api/messages\n/api/sse"]
            FCTRL["FileController\n/api/files"]
        end
        subgraph SVC["서비스 레이어"]
            PROD["PulsarProducerService\n토픽 발행"]
            CONS["PulsarConsumerService\nSSE / WS 브로드캐스트"]
            FSVC["FileStorageService\nMinIO 연동"]
        end
        subgraph CFG["설정 레이어"]
            PCFG["PulsarConfig"]
            WSCFG["WebSocketConfig\nSTOMP"]
            MCFG["MinioConfig"]
        end
        API --> SVC
        SVC --> CFG
    end

    subgraph INFRA["Docker Compose 인프라"]
        PULSAR["⚡ Apache Pulsar 3.2\nStandalone\n:6650 / :8080"]
        MINIO["🗄 MinIO\nObject Storage\n:9000 / :9001"]
    end

    VUE     -->|REST POST| MCTRL
    VUE     -->|SSE GET| MCTRL
    VUE     -->|STOMP WS| WSCFG
    FLUTTER -->|REST| MCTRL
    FLUTTER -->|REST| FCTRL
    FLUTTER -->|WS| WSCFG

    PROD -->|pulsar://| PULSAR
    PULSAR -->|consume| CONS
    FSVC -->|S3 API| MINIO

    style CLIENT  fill:#0f1117,stroke:#6c63ff,color:#e8eaf6
    style BACKEND fill:#0f1117,stroke:#43d98c,color:#e8eaf6
    style INFRA   fill:#0f1117,stroke:#ffd166,color:#e8eaf6
```

---

## 2. 메시지 흐름 아키텍처

```mermaid
flowchart LR
    subgraph PUB["발행 경로"]
        C1["클라이언트\n(REST / STOMP)"]
        P["Producer\nLZ4 압축\nBatch 100msg"]
        T["Pulsar Topic\npersistent://\npublic/chat/room-{id}"]
    end

    subgraph SUB["수신 경로"]
        C2["Consumer\nShared 구독\nACK / NACK"]
        B["브로드캐스트\n라우터"]
        WS["WebSocket\n/topic/chat/{id}"]
        SSE["SSE Emitter\n클라이언트별"]
    end

    subgraph DLQ["장애 처리"]
        RETRY["재시도 큐\n3회"]
        DL["Dead Letter Topic\n-DLQ"]
    end

    C1 --> P --> T --> C2 --> B
    B --> WS
    B --> SSE
    C2 -->|NACK| RETRY --> DL

    style PUB fill:#1a1d27,stroke:#6c63ff,color:#e8eaf6
    style SUB fill:#1a1d27,stroke:#43d98c,color:#e8eaf6
    style DLQ fill:#1a1d27,stroke:#ff6584,color:#e8eaf6
```

---

## 3. 컴포넌트 다이어그램

```mermaid
graph LR
    subgraph FE["프론트엔드"]
        VUE_APP["Vue.js App\n- 채팅 UI\n- 파일 업로드\n- 모니터링 패널"]
        FLUTTER_APP["Flutter App\n- 채팅 화면\n- 파일 공유\n- 로컬 캐시(Hive)"]
    end

    subgraph BE["백엔드"]
        MSG_CTRL["MessageController"]
        FILE_CTRL["FileController"]
        PULSAR_PROD["PulsarProducerService\n- 토픽별 Producer 캐싱\n- 비동기 발행\n- 재시도 정책"]
        PULSAR_CONS["PulsarConsumerService\n- Shared 구독\n- SSE Emitter 관리\n- WS 브로드캐스트"]
        FILE_SVC["FileStorageService\n- 멀티파트 업로드\n- Pre-signed URL\n- 버킷 초기화"]
    end

    subgraph STORE["저장소"]
        PULSAR_BROKER["Pulsar Broker\n- Persistent 토픽\n- 7일 보관\n- DLQ"]
        MINIO_STORE["MinIO\n- chat-files 버킷\n- 경로: rooms/{id}/*\n- 50MB 제한"]
    end

    VUE_APP --> MSG_CTRL
    VUE_APP --> FILE_CTRL
    FLUTTER_APP --> MSG_CTRL
    FLUTTER_APP --> FILE_CTRL

    MSG_CTRL --> PULSAR_PROD
    MSG_CTRL --> PULSAR_CONS
    FILE_CTRL --> FILE_SVC

    PULSAR_PROD --> PULSAR_BROKER
    PULSAR_CONS --> PULSAR_BROKER
    FILE_SVC --> MINIO_STORE

    style FE    fill:#1a1d27,stroke:#6c63ff,color:#e8eaf6
    style BE    fill:#1a1d27,stroke:#43d98c,color:#e8eaf6
    style STORE fill:#1a1d27,stroke:#ffd166,color:#e8eaf6
```

---

## 4. Pulsar 토픽 구조

```mermaid
graph TD
    NS_DEFAULT["Namespace\npublic/default"]
    NS_CHAT["Namespace\npublic/chat"]
    NS_FILES["Namespace\npublic/files"]

    T1["persistent://public/default/test-topic"]
    T2["persistent://public/default/test-topic-DLQ"]
    T3["persistent://public/chat/general"]
    T4["persistent://public/chat/room-random"]
    T5["persistent://public/chat/room-tech"]
    T6["persistent://public/chat/room-{custom}"]
    T7["persistent://public/files/uploads"]

    NS_DEFAULT --> T1
    NS_DEFAULT --> T2
    NS_CHAT --> T3
    NS_CHAT --> T4
    NS_CHAT --> T5
    NS_CHAT --> T6
    NS_FILES --> T7

    style NS_DEFAULT fill:#22263a,stroke:#6c63ff,color:#e8eaf6
    style NS_CHAT    fill:#22263a,stroke:#43d98c,color:#e8eaf6
    style NS_FILES   fill:#22263a,stroke:#ffd166,color:#e8eaf6
```

---

## 5. 배포 구성도 (Docker Compose)

```mermaid
graph TB
    subgraph HOST["WSL2 Host (Ubuntu 22.04)"]
        subgraph DC["Docker Compose Network: pulsar-chat-network"]
            PULSAR_C["pulsar-standalone\napachepulsar/pulsar:3.2.0\n6650 / 8080"]
            MINIO_C["minio\nminio/minio:latest\n9000 / 9001"]
            MINIO_INIT["minio-init\nbucket 생성"]
            BACKEND_C["pulsar-chat-backend\nSpring Boot JAR\n8081"]
        end

        subgraph VOL["Docker Volumes"]
            V1["pulsar-data"]
            V2["pulsar-conf"]
            V3["minio-data"]
        end
    end

    PULSAR_C --> V1
    PULSAR_C --> V2
    MINIO_C  --> V3
    MINIO_INIT -->|depends_on| MINIO_C
    BACKEND_C  -->|depends_on| PULSAR_C
    BACKEND_C  -->|depends_on| MINIO_C

    style HOST fill:#0f1117,stroke:#2e3350,color:#e8eaf6
    style DC   fill:#1a1d27,stroke:#6c63ff,color:#e8eaf6
    style VOL  fill:#1a1d27,stroke:#43d98c,color:#e8eaf6
```

---

## 6. 기술 선택 근거

| 기술 | 선택 이유 | 대안 |
|------|-----------|------|
| Apache Pulsar | 토픽별 독립 파티션, Geo-replication, DLQ 지원 | Kafka, RabbitMQ |
| Spring Boot 3.x | Pulsar Spring 공식 지원, 풍부한 생태계 | Quarkus, Micronaut |
| SSE + STOMP 이중화 | SSE: 단방향 낮은 오버헤드 / STOMP: 양방향 채팅 | 순수 WebSocket |
| MinIO | S3 호환 로컬 환경, Docker 간편 구성 | AWS S3, GCS |
| Flutter | 단일 코드베이스 Android/iOS 지원 | React Native |
| Riverpod | 컴파일 타임 안전성, Provider 보다 테스트 용이 | BLoC, GetX |
| Hive | 순수 Dart, Flutter에 최적화된 경량 NoSQL | SQLite, Isar |
