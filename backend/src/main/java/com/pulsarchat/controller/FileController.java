package com.pulsarchat.controller;

import com.pulsarchat.dto.ApiResponse;
import com.pulsarchat.dto.ChatMessage;
import com.pulsarchat.service.FileStorageService;
import com.pulsarchat.service.PulsarProducerService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.Map;
import java.util.UUID;

@Slf4j
@RestController
@RequestMapping("/api/files")
@RequiredArgsConstructor
public class FileController {

    private final FileStorageService fileStorageService;
    private final PulsarProducerService producerService;

    /**
     * 파일 업로드
     * POST /api/files/upload
     */
    @PostMapping("/upload")
    public ResponseEntity<ApiResponse<Map<String, String>>> uploadFile(
            @RequestParam("file") MultipartFile file,
            @RequestParam("roomId") String roomId,
            @RequestParam("senderId") String senderId,
            @RequestParam("senderName") String senderName) {

        if (file.isEmpty()) {
            return ResponseEntity.badRequest()
                    .body(ApiResponse.error("파일이 비어있습니다."));
        }

        // 파일 크기 제한 (50MB)
        if (file.getSize() > 50 * 1024 * 1024) {
            return ResponseEntity.badRequest()
                    .body(ApiResponse.error("파일 크기는 50MB를 초과할 수 없습니다."));
        }

        // MinIO에 파일 저장
        String fileId = fileStorageService.uploadFile(file, roomId, senderId);

        // Pre-signed URL 생성
        String fileUrl = fileStorageService.generatePresignedUrl(fileId);

        // Pulsar에 파일 공유 메시지 발행
        ChatMessage fileMessage = ChatMessage.builder()
                .messageId(UUID.randomUUID().toString())
                .roomId(roomId)
                .senderId(senderId)
                .senderName(senderName)
                .content(senderName + "님이 파일을 공유했습니다: " + file.getOriginalFilename())
                .type(ChatMessage.MessageType.FILE)
                .fileUrl(fileUrl)
                .fileName(file.getOriginalFilename())
                .fileSize(formatFileSize(file.getSize()))
                .fileType(file.getContentType())
                .build();

        producerService.publishChatMessage(roomId, fileMessage);
        producerService.publishFileUploadEvent(fileMessage);

        log.info("파일 업로드 및 메시지 발행 완료: fileId={}, room={}", fileId, roomId);

        return ResponseEntity.ok(ApiResponse.success(
                "파일이 업로드되었습니다.",
                Map.of(
                        "fileId", fileId,
                        "fileUrl", fileUrl,
                        "fileName", file.getOriginalFilename(),
                        "fileSize", formatFileSize(file.getSize()),
                        "fileType", file.getContentType() != null ? file.getContentType() : "unknown"
                )
        ));
    }

    /**
     * 파일 다운로드 링크 제공 (보안 Pre-signed URL)
     * GET /api/files/download/{fileId}
     */
    @GetMapping("/download/{fileId}")
    public ResponseEntity<ApiResponse<Map<String, String>>> getDownloadUrl(
            @PathVariable String fileId) {

        String decodedFileId = java.net.URLDecoder.decode(fileId, java.nio.charset.StandardCharsets.UTF_8);

        if (!fileStorageService.fileExists(decodedFileId)) {
            return ResponseEntity.notFound().build();
        }

        String downloadUrl = fileStorageService.generatePresignedUrl(decodedFileId);

        return ResponseEntity.ok(ApiResponse.success(
                Map.of("downloadUrl", downloadUrl, "fileId", decodedFileId)
        ));
    }

    private String formatFileSize(long bytes) {
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1024 * 1024) return String.format("%.1f KB", bytes / 1024.0);
        if (bytes < 1024 * 1024 * 1024) return String.format("%.1f MB", bytes / (1024.0 * 1024));
        return String.format("%.1f GB", bytes / (1024.0 * 1024 * 1024));
    }
}
