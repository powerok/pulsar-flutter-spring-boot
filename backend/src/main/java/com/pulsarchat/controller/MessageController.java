package com.pulsarchat.controller;

import com.pulsarchat.dto.ApiResponse;
import com.pulsarchat.dto.ChatMessage;
import com.pulsarchat.dto.MessageRequest;
import com.pulsarchat.repository.MessageRepository;
import com.pulsarchat.service.PulsarConsumerService;
import com.pulsarchat.service.PulsarProducerService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.messaging.handler.annotation.DestinationVariable;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.SendTo;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.util.*;

@Slf4j
@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
public class MessageController {

    private final PulsarProducerService producerService;
    private final PulsarConsumerService consumerService;
    private final MessageRepository messageRepository;

    // ─────────────────────────────────────────
    // REST API - 메시지 발행
    // ─────────────────────────────────────────

    /**
     * 채팅방 메시지 발행
     * POST /api/messages/send
     */
    @PostMapping("/messages/send")
    public ResponseEntity<ApiResponse<Map<String, String>>> sendMessage(
            @Valid @RequestBody MessageRequest request) {

        String mid = (request.getMessageId() != null && !request.getMessageId().isEmpty())
                ? request.getMessageId() : UUID.randomUUID().toString();

        ChatMessage message = ChatMessage.builder()
                .messageId(mid)
                .roomId(request.getRoomId())
                .senderId(request.getSenderId())
                .senderName(request.getSenderName())
                .content(request.getContent())
                .type(request.getType())
                .build();

        // Consumer 구독 (없으면 시작)
        consumerService.subscribeToRoom(request.getRoomId());

        String messageId = producerService.publishChatMessage(request.getRoomId(), message);

        return ResponseEntity.ok(ApiResponse.success(
                "메시지가 발행되었습니다.",
                Map.of("messageId", messageId, "roomId", request.getRoomId())
        ));
    }

    /**
     * 테스트 토픽으로 메시지 발행
     * POST /api/messages/test
     */
    @PostMapping("/messages/test")
    public ResponseEntity<ApiResponse<Map<String, String>>> sendTestMessage(
            @RequestBody Map<String, String> body) {

        ChatMessage message = ChatMessage.builder()
                .messageId(UUID.randomUUID().toString())
                .roomId("test")
                .senderId(body.getOrDefault("senderId", "anonymous"))
                .senderName(body.getOrDefault("senderName", "테스터"))
                .content(body.getOrDefault("content", "테스트 메시지"))
                .type(ChatMessage.MessageType.CHAT)
                .build();

        String messageId = producerService.publishToTestTopic(message);
        log.info("테스트 메시지 발행: {}", messageId);

        return ResponseEntity.ok(ApiResponse.success(
                Map.of("messageId", messageId, "status", "published")
        ));
    }

    // ─────────────────────────────────────────
    // SSE - 실시간 이벤트 구독
    // ─────────────────────────────────────────

    /**
     * SSE 연결 (Vue.js 프론트엔드용)
     * GET /api/sse/subscribe
     */
    @GetMapping(value = "/sse/subscribe", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter subscribeSse(
            @RequestParam(value = "clientId", required = false) String clientId) {
        if (clientId == null) {
            clientId = UUID.randomUUID().toString();
        }
        log.info("SSE 구독 요청: clientId={}", clientId);
        return consumerService.addSseEmitter(clientId);
    }

    /**
     * 채팅방 SSE 구독 + 자동 Pulsar 구독
     * GET /api/sse/room/{roomId}
     */
    @GetMapping(value = "/sse/room/{roomId}", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter subscribeRoom(
            @PathVariable String roomId,
            @RequestParam(value = "clientId", required = false) String clientId) {

        if (clientId == null) {
            clientId = UUID.randomUUID().toString();
        }

        // Pulsar 채팅방 구독 (서버 측)
        consumerService.subscribeToRoom(roomId);
        
        // 클라이언트 구독 정보 매핑 (메시지 필터링용)
        consumerService.addSubscription(clientId, roomId);

        log.info("채팅방 SSE 구독: roomId={}, clientId={}", roomId, clientId);
        return consumerService.addSseEmitter(clientId);
    }

    /**
     * 채팅방 최근 메시지 내역 조회
     * GET /api/rooms/{roomId}/history
     */
    public ResponseEntity<ApiResponse<List<ChatMessage>>> getChatHistory(
            @PathVariable String roomId) {
        
        List<ChatMessage> history = messageRepository.getHistory(roomId);
        return ResponseEntity.ok(ApiResponse.success(
                String.format("[%s] 채널의 최근 메시지 내역입니다.", roomId),
                history
        ));
    }

    // ─────────────────────────────────────────
    // WebSocket STOMP - 채팅
    // ─────────────────────────────────────────

    /**
     * STOMP 채팅 메시지 처리
     * /app/chat/{roomId} → /topic/chat/{roomId}
     */
    @MessageMapping("/chat/{roomId}")
    @SendTo("/topic/chat/{roomId}")
    public ChatMessage handleChatMessage(
            @DestinationVariable String roomId,
            ChatMessage message) {

        if (message.getMessageId() == null || message.getMessageId().isEmpty()) {
            message.setMessageId(UUID.randomUUID().toString());
        }
        message.setRoomId(roomId);

        // Pulsar에 발행 (비동기 처리)
        consumerService.subscribeToRoom(roomId);
        producerService.publishChatMessage(roomId, message);

        log.info("STOMP 메시지 처리: room={}, sender={}", roomId, message.getSenderName());
        return message;
    }

    // ─────────────────────────────────────────
    // 헬스 체크
    // ─────────────────────────────────────────

    @GetMapping("/health")
    public ResponseEntity<ApiResponse<Map<String, String>>> health() {
        return ResponseEntity.ok(ApiResponse.success(
                Map.of("status", "UP", "service", "pulsar-chat-backend")
        ));
    }
}
