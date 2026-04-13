package com.pulsarchat.config;

import org.apache.pulsar.client.admin.PulsarAdmin;
import org.apache.pulsar.client.api.PulsarClient;
import org.apache.pulsar.client.api.PulsarClientException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import lombok.extern.slf4j.Slf4j;

@Slf4j
@Configuration
public class PulsarConfig {

    @Value("${spring.pulsar.client.service-url:pulsar://localhost:6650}")
    private String serviceUrl;

    @Value("${spring.pulsar.admin.service-url:http://localhost:8080}")
    private String adminUrl;

    @Bean
    public PulsarClient pulsarClient() throws PulsarClientException {
        log.info("Pulsar 클라이언트 연결: {}", serviceUrl);
        return PulsarClient.builder()
                .serviceUrl(serviceUrl)
                .connectionTimeout(10, java.util.concurrent.TimeUnit.SECONDS)
                .operationTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
                .ioThreads(4)
                .listenerThreads(4)
                .build();
    }

    @Bean
    public PulsarAdmin pulsarAdmin() throws PulsarClientException {
        log.info("Pulsar Admin 클라이언트 연결: {}", adminUrl);
        return PulsarAdmin.builder()
                .serviceHttpUrl(adminUrl)
                .build();
    }
}
