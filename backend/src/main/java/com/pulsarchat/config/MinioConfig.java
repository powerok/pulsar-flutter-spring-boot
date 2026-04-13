package com.pulsarchat.config;

import io.minio.MinioClient;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Slf4j
@Configuration
public class MinioConfig {

    @Value("${minio.endpoint:http://localhost:9000}")
    private String endpoint;

    @Value("${minio.access-key:minioadmin}")
    private String accessKey;

    @Value("${minio.secret-key:minioadmin123}")
    private String secretKey;

    @Bean
    public MinioClient minioClient() {
        log.info("MinIO 클라이언트 초기화: {}", endpoint);
        return MinioClient.builder()
                .endpoint(endpoint)
                .credentials(accessKey, secretKey)
                .build();
    }
}
