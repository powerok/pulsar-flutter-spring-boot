import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/chat_message.dart';

class ApiService {
  static const String _baseUrl = 'http://10.0.2.2:8081/api'; // Android 에뮬레이터
  // 실제 기기: 'http://YOUR_PC_IP:8081/api'

  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    // 로깅 인터셉터
    _dio.interceptors.add(LogInterceptor(
      request: true,
      responseBody: true,
      error: true,
    ));

    // 에러 처리 인터셉터
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (DioException e, handler) {
        print('[API Error] ${e.type}: ${e.message}');
        handler.next(e);
      },
    ));
  }

  // ── 메시지 전송 ───────────────────────────
  Future<String?> sendMessage({
    required String roomId,
    required String senderId,
    required String senderName,
    required String content,
    String? messageId,
    String type = 'CHAT',
  }) async {
    try {
      final res = await _dio.post('/messages/send', data: {
        'messageId': messageId,
        'roomId': roomId,
        'senderId': senderId,
        'senderName': senderName,
        'content': content,
        'type': type,
      });
      if (res.data['success'] == true) {
        return res.data['data']['messageId'] as String?;
      }
    } catch (e) {
      print('[sendMessage] 오류: $e');
    }
    return null;
  }

  // ── 파일 업로드 ───────────────────────────
  Future<Map<String, dynamic>?> uploadFile({
    required String filePath,
    required String roomId,
    required String senderId,
    required String senderName,
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
        'roomId': roomId,
        'senderId': senderId,
        'senderName': senderName,
      });

      final res = await _dio.post(
        '/files/upload',
        data: formData,
        onSendProgress: onProgress,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );

      if (res.data['success'] == true) {
        return res.data['data'] as Map<String, dynamic>;
      }
    } catch (e) {
      print('[uploadFile] 오류: $e');
    }
    return null;
  }

  // ── 파일 다운로드 URL ─────────────────────
  Future<String?> getDownloadUrl(String fileId) async {
    try {
      final encoded = Uri.encodeComponent(fileId);
      final res = await _dio.get('/files/download/$encoded');
      if (res.data['success'] == true) {
        return res.data['data']['downloadUrl'] as String?;
      }
    } catch (e) {
      print('[getDownloadUrl] 오류: $e');
    }
    return null;
  }

  // ── 헬스 체크 ─────────────────────────────
  Future<bool> checkHealth() async {
    try {
      final res = await _dio.get('/health',
          options: Options(receiveTimeout: const Duration(seconds: 3)));
      return res.data['data']['status'] == 'UP';
    } catch (_) {
      return false;
    }
  }

  // ── 채팅 히스토리 조회 ─────────────────────
  Future<List<ChatMessage>> getChatHistory(String roomId) async {
    try {
      final res = await _dio.get('/rooms/$roomId/history');
      if (res.data['success'] == true) {
        final List list = res.data['data'];
        return list.map((m) => ChatMessage.fromJson(m)).toList();
      }
    } catch (e) {
      print('[getChatHistory] 오류: $e');
    }
    return [];
  }
}
