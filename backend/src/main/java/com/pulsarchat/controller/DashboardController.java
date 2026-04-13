package com.pulsarchat.controller;

import com.pulsarchat.dto.ApiResponse;
import com.pulsarchat.service.PulsarAdminService;
import com.pulsarchat.service.TrafficGeneratorService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/api/dashboard")
@RequiredArgsConstructor
public class DashboardController {

    private final PulsarAdminService adminService;
    private final TrafficGeneratorService trafficService;

    /**
     * 토픽 통계 조회
     */
    @GetMapping("/stats")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getStats(
            @RequestParam(defaultValue = "persistent://public/chat/room-load-test") String topic) {
        return ResponseEntity.ok(ApiResponse.success(adminService.getTopicStats(topic)));
    }

    /**
     * 클러스터 헬스 체크
     */
    @GetMapping("/health")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getHealth() {
        boolean isHealthy = adminService.checkHealth();
        return ResponseEntity.ok(ApiResponse.success(Map.of(
            "pulsar", isHealthy ? "UP" : "DOWN",
            "trafficActive", trafficService.isRunning(),
            "totalInjected", trafficService.getTotalInjected()
        )));
    }

    /**
     * 트래픽 주입 시작
     */
    @PostMapping("/traffic/start")
    public ResponseEntity<ApiResponse<String>> startTraffic(
            @RequestParam(defaultValue = "load-test") String roomId,
            @RequestParam(defaultValue = "10") int tps) {
        
        trafficService.startInjection(roomId, tps);
        return ResponseEntity.ok(ApiResponse.success("트래픽 주입이 시작되었습니다. (TPS: " + tps + ")"));
    }

    /**
     * 트래픽 주입 중지
     */
    @PostMapping("/traffic/stop")
    public ResponseEntity<ApiResponse<String>> stopTraffic() {
        trafficService.stopInjection();
        return ResponseEntity.ok(ApiResponse.success("트래픽 주입이 중지되었습니다."));
    }
}
