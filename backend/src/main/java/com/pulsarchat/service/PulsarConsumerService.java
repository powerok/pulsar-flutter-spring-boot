package com.pulsarchat.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.pulsarchat.dto.ChatMessage;
import com.pulsarchat.repository.MessageRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.pulsar.client.api.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;

@Slf4j
@Service
@RequiredArgsConstructor
public class PulsarConsumerService {

    private final PulsarClient pulsarClient;
    private final ObjectMapper objectMapper;
    private final SimpMessagingTemplate messagingTemplate;
    private final MessageRepository messageRepository;

    @Value("${pulsar.topics.test:persistent://public/default/test-topic}")
    private String testTopic;

    @Value("${pulsar.topics.chat-room-prefix:persistent://public/chat/room-}")
    private String chatRoomPrefix;

    @Value("${pulsar.topics.file-uploads:persistent://public/files/uploads}")
    private String fileUploadsTopic;

    @Value("${pulsar.subscription.name:chat-subscription}")
    private String subscriptionName;

    @Value("${pulsar.subscription.max-retries:3}")
    private int maxRetries;

    // SSE Emitter 관리 (clientId -> Emitter)
    private final Map<String, SseEmitter> sseEmitters = new ConcurrentHashMap<>();
    
    // 클라이언트별 구독 중인 채널 관리 (clientId -> Set<roomId>)
    private final Map<String, Set<String>> clientSubscriptions = new ConcurrentHashMap<>();

    // 채팅방별 Consumer 관리
    private final Map<String, Consumer<byte[]>> roomConsumers = new ConcurrentHashMap<>();

    private final ExecutorService executorService = Executors.newCachedThreadPool();

    @PostConstruct
    public void initConsumers() {
        // 기본 테스트 토픽 구독 시작
        startConsumingTopic(testTopic, "test-subscription");
        // 파일 업로드 이벤트 구독
        startConsumingTopic(fileUploadsTopic, "file-subscription");
        log.info("기본 Consumer 초기화 완료");
    }

    /**
     * 특정 채팅방 구독 시작
     */
    public void subscribeToRoom(String roomId) {
        String topic = chatRoomPrefix + roomId;
        String subName = subscriptionName + "-" + roomId;

        if (!roomConsumers.containsKey(roomId)) {
            startConsumingTopic(topic, subName, roomId);
            log.info("채팅방 구독 시작: room={}, topic={}", roomId, topic);
        }
    }

    /**
     * 토픽 소비 시작 (내부)
     */
    private void startConsumingTopic(String topic, String subName) {
        startConsumingTopic(topic, subName, null);
    }

    private void startConsumingTopic(String topic, String subName, String roomId) {
        executorService.submit(() -> {
            try {
                Consumer<byte[]> consumer = pulsarClient.newConsumer()
                        .topic(topic)
                        .subscriptionName(subName)
                        .subscriptionType(SubscriptionType.Shared)  // 다중 소비자 지원
                        .subscriptionInitialPosition(SubscriptionInitialPosition.Latest)
                        .negativeAckRedeliveryDelay(maxRetries, TimeUnit.SECONDS)
                        .deadLetterPolicy(DeadLetterPolicy.builder()
                                .maxRedeliverCount(maxRetries)
                                .deadLetterTopic(topic + "-DLQ")
                                .build())
                        .subscribe();

                if (roomId != null) {
                    roomConsumers.put(roomId, consumer);
                }

                log.info("Consumer 시작 - topic: {}, subscription: {}", topic, subName);

                while (!Thread.currentThread().isInterrupted()) {
                    try {
                        Message<byte[]> msg = consumer.receive(1, TimeUnit.SECONDS);
                        if (msg != null) {
                            processMessage(msg, consumer, roomId, topic);
                        }
                    } catch (PulsarClientException e) {
                        if (Thread.currentThread().isInterrupted()) break;
                        log.warn("메시지 수신 중 오류, 재시도: {}", e.getMessage());
                        Thread.sleep(1000);
                    }
                }

            } catch (Exception e) {
                log.error("Consumer 초기화 실패 - topic: {}", topic, e);
            }
        });
    }

    /**
     * 수신된 메시지 처리
     */
    private void processMessage(Message<byte[]> msg, Consumer<byte[]> consumer,
                                String roomId, String topic) {
        try {
            ChatMessage chatMessage = objectMapper.readValue(msg.getValue(), ChatMessage.class);
            log.debug("메시지 수신 - topic: {}, sender: {}, type: {}",
                    topic, chatMessage.getSenderName(), chatMessage.getType());

            // 0. 히스토리 저장
            if (roomId != null) {
                messageRepository.save(roomId, chatMessage);
            }

            // 1. WebSocket(STOMP)으로 브로드캐스트
            broadcastViaWebSocket(chatMessage, roomId);

            // 2. SSE로 브로드캐스트
            broadcastViaSse(chatMessage, roomId);

            // 3. 메시지 ACK
            consumer.acknowledge(msg);

        } catch (Exception e) {
            log.error("메시지 처리 실패", e);
            try {
                consumer.negativeAcknowledge(msg);
            } catch (Exception ignored) {}
        }
    }

    /**
     * WebSocket STOMP 브로드캐스트
     */
    private void broadcastViaWebSocket(ChatMessage message, String roomId) {
        try {
            String destination = roomId != null
                    ? "/topic/chat/" + roomId
                    : "/topic/messages";
            messagingTemplate.convertAndSend(destination, message);
            log.debug("WebSocket 브로드캐스트 완료: {}", destination);
        } catch (Exception e) {
            log.warn("WebSocket 브로드캐스트 실패: {}", e.getMessage());
        }
    }

    /**
     * SSE 브로드캐스트 (Vue.js 프론트엔드용)
     */
    private void broadcastViaSse(ChatMessage message, String roomId) {
        List<String> toRemove = new java.util.ArrayList<>();

        sseEmitters.forEach((clientId, emitter) -> {
            // 해당 클라이언트가 이 방을 구독 중이거나, 전체 채널 메시지인 경우 전송
            Set<String> subRooms = clientSubscriptions.getOrDefault(clientId, Collections.emptySet());
            if (roomId == null || subRooms.contains(roomId)) {
                try {
                    emitter.send(SseEmitter.event()
                            .id(message.getMessageId())
                            .name("message")
                            .data(message));
                } catch (IOException e) {
                    log.debug("SSE 클라이언트 연결 끊김: {}", clientId);
                    toRemove.add(clientId);
                }
            }
        });

        toRemove.forEach(id -> {
            sseEmitters.remove(id);
            clientSubscriptions.remove(id);
        });
    }

    /**
     * SSE 구독 등록
     */
    public SseEmitter addSseEmitter(String clientId) {
        SseEmitter emitter = new SseEmitter(Long.MAX_VALUE);

        emitter.onCompletion(() -> {
            sseEmitters.remove(clientId);
            clientSubscriptions.remove(clientId);
            log.debug("SSE 연결 종료: {}", clientId);
        });
        emitter.onTimeout(() -> {
            sseEmitters.remove(clientId);
            clientSubscriptions.remove(clientId);
            log.debug("SSE 타임아웃: {}", clientId);
        });
        emitter.onError(e -> {
            sseEmitters.remove(clientId);
            clientSubscriptions.remove(clientId);
            log.debug("SSE 에러: {}", clientId);
        });

        sseEmitters.put(clientId, emitter);
        log.info("SSE 클라이언트 등록: {} (총 {}명)", clientId, sseEmitters.size());

        // 연결 확인용 초기 이벤트
        try {
            emitter.send(SseEmitter.event()
                    .name("connected")
                    .data(Map.of("clientId", clientId, "message", "SSE 연결 성공")));
        } catch (IOException e) {
            log.warn("SSE 초기 이벤트 전송 실패: {}", clientId);
        }

        return emitter;
    }

    /**
     * 클라이언트가 특정 방을 구독하도록 설정
     */
    public void addSubscription(String clientId, String roomId) {
        clientSubscriptions.computeIfAbsent(clientId, k -> ConcurrentHashMap.newKeySet()).add(roomId);
        log.info("구독 정보 추가: clientId={}, roomId={}", clientId, roomId);
    }

    @PreDestroy
    public void cleanup() {
        log.info("Consumer 서비스 정리 중...");
        executorService.shutdownNow();
        roomConsumers.forEach((roomId, consumer) -> {
            try { consumer.close(); } catch (Exception ignored) {}
        });
        sseEmitters.forEach((id, emitter) -> emitter.complete());
    }
}
