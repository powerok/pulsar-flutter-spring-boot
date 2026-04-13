package com.pulsarchat.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.pulsar.client.admin.PulsarAdmin;
import org.apache.pulsar.client.admin.PulsarAdminException;
import org.apache.pulsar.common.policies.data.TopicStats;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class PulsarAdminService {

    private final PulsarAdmin pulsarAdmin;

    /**
     * 클러스터 내 모든 테넌트 조회
     */
    public List<String> getTenants() throws PulsarAdminException {
        return pulsarAdmin.tenants().getTenants();
    }

    /**
     * 특정 토픽의 상세 통계 조회
     */
    public Map<String, Object> getTopicStats(String topic) {
        Map<String, Object> stats = new HashMap<>();
        try {
            TopicStats topicStats = pulsarAdmin.topics().getStats(topic);
            stats.put("msgInCounter", topicStats.getMsgInCounter());
            stats.put("msgOutCounter", topicStats.getMsgOutCounter());
            stats.put("averageMsgSize", topicStats.getAverageMsgSize());
            stats.put("msgRateIn", topicStats.getMsgRateIn());
            stats.put("msgRateOut", topicStats.getMsgRateOut());
            stats.put("msgThroughputIn", topicStats.getMsgThroughputIn());
            stats.put("msgThroughputOut", topicStats.getMsgThroughputOut());
            stats.put("backlogSize", topicStats.getBacklogSize());
            stats.put("publishRateIn", topicStats.getMsgRateIn());
            stats.put("status", "CONNECTED");
        } catch (PulsarAdminException e) {
            if (e.getStatusCode() == 404) {
                log.warn("토픽을 찾을 수 없습니다 (아직 생성되지 않음): {}", topic);
                stats.put("status", "NOT_FOUND");
                stats.put("message", "Topic has not been created yet");
            } else {
                log.error("토픽 통계 조회 실패: {}", topic, e);
                stats.put("status", "ERROR");
                stats.put("error", e.getMessage());
            }
        }
        return stats;
    }

    /**
     * 클러스터 브로커 헬스 체크
     */
    public boolean checkHealth() {
        try {
            pulsarAdmin.clusters().getClusters();
            return true;
        } catch (Exception e) {
            return false;
        }
    }
}
