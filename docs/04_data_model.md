# 데이터 모델 정의서

**프로젝트명:** Pulsar Chat System  
**버전:** 1.0.0  
**작성일:** 2025-04-12

---

## 1. 전체 데이터 구조 개요

```mermaid
erDiagram
    CHAT_MESSAGE {
        string messageId PK
        string roomId FK
        string senderId
        string senderName
        string content
        string type
        datetime timestamp
        string fileUrl
        string fileName
        string fileSize
        string fileType
        string status
    }

    CHAT_ROOM {
        string id PK
        string name
        string icon
        string topic
        int memberCount
        int unreadCount
        string lastMessage
        datetime lastMessageTime
    }

    USER_PROFILE {
        string id PK
        string name
        int colorIndex
    }

    FILE_OBJECT {
        string fileId PK
        string roomId FK
        string uploaderId
        string originalName
        string contentType
        long size
        string storagePath
        datetime uploadedAt
    }

    CHAT_ROOM ||--o{ CHAT_MESSAGE : "contains"
    USER_PROFILE ||--o{ CHAT_MESSAGE : "sends"
    CHAT_MESSAGE ||--o| FILE_OBJECT : "references"
```

---

## 2. Pulsar 메시지 모델

### 2.1 ChatMessage (Pulsar Payload)

```mermaid
classDiagram
    class ChatMessage {
        +String messageId "UUID v4"
        +String roomId "채팅방 식별자"
        +String senderId "사용자 UUID"
        +String senderName "닉네임 최대 20자"
        +String content "최대 1000자"
        +MessageType type
        +LocalDateTime timestamp
        +String fileUrl "null 가능"
        +String fileName "null 가능"
        +String fileSize "포맷 문자열"
        +String fileType "MIME 타입"
        +String status "SENT/SENDING/FAILED"
        +fromJson(json) ChatMessage$
        +toJson() Map
    }

    class MessageType {
        <<enumeration>>
        CHAT "일반 텍스트"
        FILE "파일 공유"
        JOIN "입장"
        LEAVE "퇴장"
        SYSTEM "시스템 알림"
    }

    ChatMessage --> MessageType : type
```

### 2.2 Pulsar 토픽 메타데이터

Pulsar 메시지 Property (헤더)에 포함되는 메타데이터:

| Property 키 | 값 예시 | 설명 |
|-------------|---------|------|
| messageType | CHAT | 메시지 유형 |
| senderId | user-abc123 | 발신자 ID |

---

## 3. MinIO 파일 저장 구조

```mermaid
graph TD
    BUCKET["Bucket: chat-files"]
    ROOM1["rooms/general/"]
    ROOM2["rooms/tech/"]
    ROOM3["rooms/{custom}/"]
    F1["uuid1.pdf\n메타: uploader-id, original-name"]
    F2["uuid2.png\n메타: room-id"]
    F3["uuid3.zip"]

    BUCKET --> ROOM1
    BUCKET --> ROOM2
    BUCKET --> ROOM3
    ROOM1 --> F1
    ROOM1 --> F2
    ROOM2 --> F3

    style BUCKET fill:#22263a,stroke:#ffd166,color:#e8eaf6
    style ROOM1  fill:#22263a,stroke:#6c63ff,color:#e8eaf6
    style ROOM2  fill:#22263a,stroke:#6c63ff,color:#e8eaf6
    style ROOM3  fill:#22263a,stroke:#6c63ff,color:#e8eaf6
```

**오브젝트 키 규칙:**

```
rooms/{roomId}/{UUID}{.확장자}
```

**오브젝트 사용자 메타데이터:**

| 키 | 값 |
|----|-----|
| uploader-id | 업로드한 사용자 ID |
| original-name | 원본 파일명 |
| room-id | 채팅방 ID |

---

## 4. Flutter 로컬 저장소 (Hive)

### 4.1 Box 구성

| Box 이름 | 타입 | 설명 |
|----------|------|------|
| `messages` | `Box<ChatMessage>` | 메시지 오프라인 캐시 |
| `settings` | `Box<dynamic>` | 사용자 프로필 설정 |

### 4.2 ChatMessage Hive Adapter

```mermaid
classDiagram
    class ChatMessage {
        <<HiveType typeId=1>>
        +HiveField(0) String messageId
        +HiveField(1) String roomId
        +HiveField(2) String senderId
        +HiveField(3) String senderName
        +HiveField(4) String content
        +HiveField(5) MessageType type
        +HiveField(6) DateTime timestamp
        +HiveField(7) String? fileUrl
        +HiveField(8) String? fileName
        +HiveField(9) String? fileSize
        +HiveField(10) String? fileType
        +HiveField(11) String status
    }

    class MessageType {
        <<HiveType typeId=0>>
        <<enumeration>>
        +HiveField(0) chat
        +HiveField(1) file
        +HiveField(2) image
        +HiveField(3) join
        +HiveField(4) leave
        +HiveField(5) system
    }
```

### 4.3 settings Box 키 목록

| 키 | 타입 | 설명 |
|----|------|------|
| `userId` | String | UUID v4 사용자 ID |
| `userName` | String | 닉네임 |
| `colorIndex` | int | 아바타 색상 인덱스 (0~11) |

---

## 5. Vue.js 상태 구조 (In-Memory)

```mermaid
classDiagram
    class AppState {
        +UserProfile profile
        +List~ChatRoom~ rooms
        +Map~String_List~ChatMessage~~ messages
        +Map~String_int~ unread
        +String currentRoom
        +String sseStatus
        +bool wsConnected
        +Stats stats
        +List~LogEntry~ logs
    }

    class UserProfile {
        +String id
        +String name
        +String color
    }

    class ChatRoom {
        +String id
        +String name
        +String icon
        +int memberCount
    }

    class Stats {
        +int sent
        +int received
        +int files
    }

    AppState --> UserProfile
    AppState --> ChatRoom
    AppState --> Stats
```

---

## 6. Riverpod 상태 모델 (Flutter)

```mermaid
graph TD
    subgraph Providers["Riverpod Providers"]
        UP["userProfileProvider\nStateNotifier&lt;UserProfile?&gt;"]
        RL["roomListProvider\nStateNotifier&lt;List&lt;ChatRoom&gt;&gt;"]
        CR["currentRoomProvider\nStateProvider&lt;String?&gt;"]
        MP["messagesProvider\nStateNotifier&lt;Map&lt;String,List&lt;ChatMessage&gt;&gt;&gt;"]
        WC["wsConnectedProvider\nStateProvider&lt;bool&gt;"]
        BH["backendHealthProvider\nStateProvider&lt;bool&gt;"]
        UPG["uploadProgressProvider\nStateProvider&lt;double&gt;"]
        CC["chatControllerProvider\nProvider&lt;ChatController&gt;"]
        API["apiServiceProvider\nProvider&lt;ApiService&gt;"]
        WS["wsServiceProvider\nProvider&lt;ChatWebSocketService&gt;"]
    end

    CC --> UP
    CC --> RL
    CC --> CR
    CC --> MP
    CC --> API
    CC --> WS

    style Providers fill:#1a1d27,stroke:#6c63ff,color:#e8eaf6
```

---

## 7. 데이터 흐름 요약

```mermaid
flowchart TD
    USER["사용자 입력"]

    subgraph WEB["웹 (Vue.js)"]
        V_STATE["Vue reactive state\n(In-Memory)"]
    end

    subgraph APP["앱 (Flutter)"]
        RIVERPOD["Riverpod State"]
        HIVE["Hive Box\n(오프라인 캐시)"]
    end

    subgraph SERVER["서버"]
        SPRING["Spring Boot\nApplication"]
    end

    subgraph MQ["메시지 큐"]
        PULSAR_T["Pulsar Topic"]
    end

    subgraph STORAGE["파일 저장소"]
        MINIO_B["MinIO Bucket"]
    end

    USER --> V_STATE
    USER --> RIVERPOD
    RIVERPOD <--> HIVE

    V_STATE -->|REST / STOMP| SPRING
    RIVERPOD -->|REST / WS| SPRING

    SPRING -->|publish| PULSAR_T
    PULSAR_T -->|consume + broadcast| SPRING
    SPRING -->|SSE / WS| V_STATE
    SPRING -->|SSE / WS| RIVERPOD

    SPRING -->|upload| MINIO_B
    MINIO_B -->|pre-signed URL| SPRING
```
