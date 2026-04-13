package com.pulsarchat;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableAsync;

@SpringBootApplication
@EnableAsync
public class PulsarChatApplication {
    public static void main(String[] args) {
        SpringApplication.run(PulsarChatApplication.class, args);
    }
}
