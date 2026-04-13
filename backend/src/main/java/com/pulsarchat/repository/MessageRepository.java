package com.pulsarchat.repository;

import com.pulsarchat.dto.ChatMessage;
import org.springframework.stereotype.Repository;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;

@Repository
public class MessageRepository {

    // roomId -> List<ChatMessage>
    private final Map<String, List<ChatMessage>> messageStore = new ConcurrentHashMap<>();
    private static final int MAX_HISTORY = 100;

    /**
     * 메시지 저장
     */
    public void save(String roomId, ChatMessage message) {
        messageStore.computeIfAbsent(roomId, k -> Collections.synchronizedList(new ArrayList<>()));
        List<ChatMessage> history = messageStore.get(roomId);
        
        synchronized (history) {
            history.add(message);
            if (history.size() > MAX_HISTORY) {
                history.remove(0);
            }
        }
    }

    /**
     * 최근 메시지 조회
     */
    public List<ChatMessage> getHistory(String roomId) {
        List<ChatMessage> history = messageStore.get(roomId);
        if (history == null) return Collections.emptyList();
        
        synchronized (history) {
            return new ArrayList<>(history);
        }
    }

    /**
     * 특정 채널의 메시지 삭제 (방 초기화용)
     */
    public void clear(String roomId) {
        messageStore.remove(roomId);
    }
}
