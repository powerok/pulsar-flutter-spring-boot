package com.pulsarchat.dto;

import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ChatMessage {

    public enum MessageType {
        CHAT,       // 일반 채팅
        FILE,       // 파일 공유
        JOIN,       // 입장
        LEAVE,      // 퇴장
        SYSTEM      // 시스템 메시지
    }

    private String messageId;
    private String roomId;
    private String senderId;
    private String senderName;
    private String content;
    private MessageType type;

    // 파일 공유 시 사용
    private String fileUrl;
    private String fileName;
    private String fileSize;
    private String fileType;

    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    @Builder.Default
    private LocalDateTime timestamp = LocalDateTime.now();

    @Builder.Default
    private String status = "SENT";
}
