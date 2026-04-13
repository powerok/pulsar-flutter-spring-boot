package com.pulsarchat.service;

import com.pulsarchat.dto.ChatMessage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.UUID;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

@Slf4j
@Service
@RequiredArgsConstructor
public class TrafficGeneratorService {

    private final PulsarProducerService producerService;
    private final AtomicBoolean isRunning = new AtomicBoolean(false);
    private ScheduledExecutorService scheduler;
    private final AtomicInteger totalInjected = new AtomicInteger(0);

    /**
     * 트래픽 주입 시작
     * @param roomId 대상 채팅방
     * @param tps 초당 트래픽 (Transactions Per Second)
     */
    public synchronized void startInjection(String roomId, int tps) {
        if (isRunning.get()) {
            stopInjection();
        }

        isRunning.set(true);
        totalInjected.set(0);
        scheduler = Executors.newSingleThreadScheduledExecutor();

        long intervalMs = 1000 / Math.max(1, tps);
        
        scheduler.scheduleAtFixedRate(() -> {
            if (!isRunning.get()) return;

            ChatMessage dummy = ChatMessage.builder()
                    .messageId(UUID.randomUUID().toString())
                    .roomId(roomId)
                    .senderId("traffic-bot")
                    .senderName("AI Injector")
                    .content("Simulated load test message #" + totalInjected.incrementAndGet())
                    .type(ChatMessage.MessageType.CHAT)
                    .status("INJECTED")
                    .build();

            producerService.publishChatMessage(roomId, dummy);
            
            if (totalInjected.get() % 100 == 0) {
                log.info("트래픽 인젝션 수행 중: roomId={}, total={}", roomId, totalInjected.get());
            }
        }, 0, intervalMs, TimeUnit.MILLISECONDS);

        log.info("트래픽 인젝션 시작: roomId={}, target_tps={}", roomId, tps);
    }

    /**
     * 트래픽 주입 중단
     */
    public synchronized void stopInjection() {
        if (isRunning.get()) {
            isRunning.set(false);
            if (scheduler != null) {
                scheduler.shutdown();
            }
            log.info("트래픽 인젝션 중단 완료. 총 인입량: {}", totalInjected.get());
        }
    }

    public boolean isRunning() {
        return isRunning.get();
    }

    public int getTotalInjected() {
        return totalInjected.get();
    }
}
