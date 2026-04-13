package com.pulsarchat.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.pulsarchat.dto.ChatMessage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.pulsar.client.api.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;

@Slf4j
@Service
@RequiredArgsConstructor
public class PulsarProducerService {

    private final PulsarClient pulsarClient;
    private final ObjectMapper objectMapper;

    @Value("${pulsar.topics.test:persistent://public/default/test-topic}")
    private String testTopic;

    @Value("${pulsar.topics.chat-room-prefix:persistent://public/chat/room-}")
    private String chatRoomPrefix;

    @Value("${pulsar.topics.file-uploads:persistent://public/files/uploads}")
    private String fileUploadsTopic;

    // 토픽별 Producer 캐싱 (재사용)
    private final Map<String, Producer<byte[]>> producerCache = new ConcurrentHashMap<>();

    /**
     * 특정 토픽으로 메시지 발행
     */
    public String publishMessage(String topic, ChatMessage message) {
        try {
            if (message.getMessageId() == null) {
                message.setMessageId(UUID.randomUUID().toString());
            }

            Producer<byte[]> producer = getOrCreateProducer(topic);
            byte[] payload = objectMapper.writeValueAsBytes(message);

            MessageId messageId = producer.newMessage()
                    .key(message.getRoomId())
                    .value(payload)
                    .property("messageType", message.getType().name())
                    .property("senderId", message.getSenderId())
                    .sendAsync()
                    .get(5, TimeUnit.SECONDS);

            log.info("메시지 발행 성공 - topic: {}, messageId: {}, sender: {}",
                    topic, messageId, message.getSenderName());
            return messageId.toString();

        } catch (Exception e) {
            log.error("메시지 발행 실패 - topic: {}, error: {}", topic, e.getMessage(), e);
            throw new RuntimeException("메시지 발행 중 오류가 발생했습니다: " + e.getMessage(), e);
        }
    }

    /**
     * 채팅방 토픽으로 메시지 발행
     */
    public String publishChatMessage(String roomId, ChatMessage message) {
        String topic = chatRoomPrefix + roomId;
        return publishMessage(topic, message);
    }

    /**
     * 기본 테스트 토픽으로 메시지 발행
     */
    public String publishToTestTopic(ChatMessage message) {
        return publishMessage(testTopic, message);
    }

    /**
     * 파일 업로드 이벤트 발행
     */
    public String publishFileUploadEvent(ChatMessage fileMessage) {
        return publishMessage(fileUploadsTopic, fileMessage);
    }

    /**
     * Producer 가져오기 (없으면 생성, Retry Policy 포함)
     */
    private Producer<byte[]> getOrCreateProducer(String topic) {
        return producerCache.computeIfAbsent(topic, t -> {
            try {
                return pulsarClient.newProducer()
                        .topic(t)
                        .producerName("chat-producer-" + UUID.randomUUID().toString().substring(0, 8))
                        .sendTimeout(10, TimeUnit.SECONDS)
                        .blockIfQueueFull(true)
                        .compressionType(CompressionType.LZ4)
                        .batchingMaxMessages(100)
                        .batchingMaxPublishDelay(10, TimeUnit.MILLISECONDS)
                        .create();
            } catch (PulsarClientException e) {
                log.error("Producer 생성 실패 - topic: {}", t, e);
                throw new RuntimeException("Producer 생성 실패: " + e.getMessage(), e);
            }
        });
    }

    @PreDestroy
    public void cleanup() {
        log.info("Pulsar Producer 정리 중...");
        producerCache.forEach((topic, producer) -> {
            try {
                producer.close();
                log.info("Producer 닫기 완료: {}", topic);
            } catch (PulsarClientException e) {
                log.warn("Producer 닫기 실패: {}", topic, e);
            }
        });
    }
}
