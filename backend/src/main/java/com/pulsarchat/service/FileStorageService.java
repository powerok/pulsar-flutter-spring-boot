package com.pulsarchat.service;

import io.minio.*;
import io.minio.http.Method;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import jakarta.annotation.PostConstruct;
import java.io.InputStream;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

@Slf4j
@Service
@RequiredArgsConstructor
public class FileStorageService {

    private final MinioClient minioClient;

    @Value("${minio.bucket:chat-files}")
    private String bucketName;

    @PostConstruct
    public void initBucket() {
        try {
            boolean exists = minioClient.bucketExists(
                    BucketExistsArgs.builder().bucket(bucketName).build()
            );
            if (!exists) {
                minioClient.makeBucket(
                        MakeBucketArgs.builder().bucket(bucketName).build()
                );
                log.info("MinIO 버킷 생성 완료: {}", bucketName);
            } else {
                log.info("MinIO 버킷 확인: {}", bucketName);
            }
        } catch (Exception e) {
            log.error("MinIO 버킷 초기화 실패: {}", e.getMessage(), e);
        }
    }

    /**
     * 파일 업로드
     * @return fileId (MinIO object name)
     */
    public String uploadFile(MultipartFile file, String roomId, String uploaderId) {
        String originalFilename = file.getOriginalFilename();
        String extension = originalFilename != null && originalFilename.contains(".")
                ? originalFilename.substring(originalFilename.lastIndexOf("."))
                : "";
        String fileId = "rooms/" + roomId + "/" + UUID.randomUUID() + extension;

        try (InputStream inputStream = file.getInputStream()) {
            minioClient.putObject(
                    PutObjectArgs.builder()
                            .bucket(bucketName)
                            .object(fileId)
                            .stream(inputStream, file.getSize(), -1)
                            .contentType(file.getContentType())
                            .userMetadata(Map.of(
                                    "uploader-id", uploaderId,
                                    "original-name", originalFilename != null ? originalFilename : "unknown",
                                    "room-id", roomId
                            ))
                            .build()
            );

            log.info("파일 업로드 완료: fileId={}, size={}, uploader={}", fileId, file.getSize(), uploaderId);
            return fileId;

        } catch (Exception e) {
            log.error("파일 업로드 실패: {}", e.getMessage(), e);
            throw new RuntimeException("파일 업로드 실패: " + e.getMessage(), e);
        }
    }

    /**
     * Pre-signed URL 생성 (보안 다운로드 링크, 1시간 유효)
     */
    public String generatePresignedUrl(String fileId) {
        try {
            return minioClient.getPresignedObjectUrl(
                    GetPresignedObjectUrlArgs.builder()
                            .method(Method.GET)
                            .bucket(bucketName)
                            .object(fileId)
                            .expiry(1, TimeUnit.HOURS)
                            .build()
            );
        } catch (Exception e) {
            log.error("Pre-signed URL 생성 실패: {}", e.getMessage(), e);
            throw new RuntimeException("다운로드 링크 생성 실패: " + e.getMessage(), e);
        }
    }

    /**
     * 파일 존재 여부 확인
     */
    public boolean fileExists(String fileId) {
        try {
            minioClient.statObject(
                    StatObjectArgs.builder()
                            .bucket(bucketName)
                            .object(fileId)
                            .build()
            );
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * 파일 삭제
     */
    public void deleteFile(String fileId) {
        try {
            minioClient.removeObject(
                    RemoveObjectArgs.builder()
                            .bucket(bucketName)
                            .object(fileId)
                            .build()
            );
            log.info("파일 삭제 완료: {}", fileId);
        } catch (Exception e) {
            log.error("파일 삭제 실패: {}", e.getMessage(), e);
        }
    }
}
