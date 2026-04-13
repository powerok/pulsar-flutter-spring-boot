package com.pulsarchat.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class MessageRequest {

    private String messageId;

    @NotBlank(message = "roomId는 필수입니다.")
    private String roomId;

    @NotBlank(message = "senderId는 필수입니다.")
    private String senderId;

    @NotBlank(message = "senderName은 필수입니다.")
    private String senderName;

    @NotBlank(message = "content는 필수입니다.")
    @Size(max = 1000, message = "메시지는 1000자 이내여야 합니다.")
    private String content;

    private ChatMessage.MessageType type = ChatMessage.MessageType.CHAT;
}
