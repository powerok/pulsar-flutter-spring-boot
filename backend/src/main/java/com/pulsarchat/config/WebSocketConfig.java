package com.pulsarchat.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

    @Override
    public void configureMessageBroker(MessageBrokerRegistry config) {
        // 클라이언트로 메시지 전송 시 prefix
        config.enableSimpleBroker("/topic", "/queue");
        // 클라이언트에서 서버로 메시지 전송 시 prefix
        config.setApplicationDestinationPrefixes("/app");
    }

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        // STOMP WebSocket 엔드포인트
        registry.addEndpoint("/ws")
                .setAllowedOriginPatterns("*")
                .withSockJS();

        // 순수 WebSocket (Flutter 앱용)
        registry.addEndpoint("/ws-native")
                .setAllowedOriginPatterns("*");
    }
}
