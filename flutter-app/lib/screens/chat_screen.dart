import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../providers/chat_provider.dart';

const _avatarColors = [
  Color(0xFF6C63FF), Color(0xFFFF6584), Color(0xFF43D98C),
  Color(0xFFFFD166), Color(0xFF06D6A0), Color(0xFFEF476F),
  Color(0xFF118AB2), Color(0xFFF77F00),
];

class ChatScreen extends ConsumerStatefulWidget {
  final ChatRoom room;
  const ChatScreen({super.key, required this.room});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textCtrl   = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode  = FocusNode();
  bool _showAttach  = false;

  @override
  void initState() {
    super.initState();
    _textCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    setState(() {});
    await ref.read(chatControllerProvider).sendMessage(text);
    _scrollToBottom();
  }

  Future<void> _pickFile() async {
    setState(() => _showAttach = false);
    final result = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (result?.files.single.path != null) {
      await ref.read(chatControllerProvider)
          .sendFile(result!.files.single.path!, result.files.single.extension);
    }
  }

  Future<void> _pickImage({required ImageSource source}) async {
    setState(() => _showAttach = false);
    final picker = ImagePicker();
    final img = await picker.pickImage(source: source, imageQuality: 85);
    if (img != null) {
      await ref.read(chatControllerProvider).sendFile(img.path, 'image/jpeg');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile  = ref.watch(userProfileProvider);
    final msgMap   = ref.watch(messagesProvider);
    final messages = msgMap[widget.room.id] ?? [];
    final progress = ref.watch(uploadProgressProvider);

    // 새 메시지 왔을 때 자동 스크롤
    ref.listen(messagesProvider, (_, __) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text(widget.room.icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.room.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Text(
                  'room-${widget.room.id}',
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showRoomInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── 업로드 프로그레스 ──────────────
          if (progress > 0)
            LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFF1A1D27),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF6C63FF)),
              minHeight: 3,
            ),

          // ── 메시지 목록 ───────────────────
          Expanded(
            child: messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final msg = messages[i];
                      final isOwn = msg.senderId == profile?.id;
                      final showDate = i == 0 ||
                          !_isSameDay(messages[i - 1].timestamp, msg.timestamp);
                      return Column(
                        children: [
                          if (showDate) _buildDateDivider(msg.timestamp),
                          _buildMessageBubble(msg, isOwn),
                        ],
                      );
                    },
                  ),
          ),

          // ── 첨부파일 버튼 트레이 ──────────
          if (_showAttach) _buildAttachTray(),

          // ── 입력창 ───────────────────────
          _buildInputArea(),
        ],
      ),
    );
  }

  // ── 빈 상태 ──────────────────────────────
  Widget _buildEmptyState() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(widget.room.icon, style: const TextStyle(fontSize: 52)),
      const SizedBox(height: 12),
      Text('${widget.room.name} 채팅방에 오신 것을 환영합니다!',
          style: const TextStyle(color: Colors.white70, fontSize: 15)),
      const SizedBox(height: 6),
      Text('첫 번째 메시지를 보내보세요 👋',
          style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13)),
    ]),
  );

  // ── 날짜 구분선 ──────────────────────────
  Widget _buildDateDivider(DateTime dt) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(children: [
      const Expanded(child: Divider(color: Color(0xFF2E3350))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text(
          DateFormat('yyyy년 M월 d일', 'ko').format(dt),
          style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
        ),
      ),
      const Expanded(child: Divider(color: Color(0xFF2E3350))),
    ]),
  );

  // ── 메시지 버블 ──────────────────────────
  Widget _buildMessageBubble(ChatMessage msg, bool isOwn) {
    if (msg.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF22263A),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(msg.content,
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isOwn) ...[
            _buildAvatar(msg.senderId, msg.senderName),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment:
                isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isOwn)
                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 3),
                  child: Text(msg.senderName,
                      style: TextStyle(color: Colors.white.withOpacity(0.5),
                          fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              msg.isFile || msg.isImage
                  ? _buildFileBubble(msg, isOwn)
                  : _buildTextBubble(msg, isOwn),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('HH:mm').format(msg.timestamp),
                    style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10),
                  ),
                  if (isOwn) ...[
                    const SizedBox(width: 4),
                    Icon(
                      msg.status == 'SENDING' ? Icons.access_time
                          : msg.status == 'FAILED' ? Icons.error_outline
                          : Icons.done_all,
                      size: 12,
                      color: msg.status == 'FAILED'
                          ? const Color(0xFFFF6584)
                          : Colors.white.withOpacity(0.3),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (isOwn) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTextBubble(ChatMessage msg, bool isOwn) => Container(
    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(
      color: isOwn ? const Color(0xFF6C63FF) : const Color(0xFF22263A),
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(16),
        topRight: const Radius.circular(16),
        bottomLeft: Radius.circular(isOwn ? 16 : 4),
        bottomRight: Radius.circular(isOwn ? 4 : 16),
      ),
    ),
    child: Text(msg.content,
        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
  );

  Widget _buildFileBubble(ChatMessage msg, bool isOwn) => GestureDetector(
    onTap: () async {
      if (msg.fileUrl != null) {
        final uri = Uri.parse(msg.fileUrl!);
        if (await canLaunchUrl(uri)) launchUrl(uri);
      }
    },
    child: Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOwn ? const Color(0xFF6C63FF) : const Color(0xFF22263A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_getFileEmoji(msg.fileType), style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(msg.fileName ?? '파일',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600,
                        fontSize: 13),
                    overflow: TextOverflow.ellipsis),
                if (msg.fileSize != null)
                  Text(msg.fileSize!,
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                Text('탭하여 열기 ↗',
                    style: TextStyle(color: Colors.white.withOpacity(0.6),
                        fontSize: 11, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildAvatar(String userId, String name) {
    final colorIdx = userId.hashCode.abs() % _avatarColors.length;
    return CircleAvatar(
      radius: 14,
      backgroundColor: _avatarColors[colorIdx],
      child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white, fontSize: 11,
              fontWeight: FontWeight.bold)),
    );
  }

  // ── 첨부 트레이 ──────────────────────────
  Widget _buildAttachTray() => Container(
    color: const Color(0xFF1A1D27),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _attachBtn('📷', '카메라', () => _pickImage(source: ImageSource.camera)),
        _attachBtn('🖼', '갤러리', () => _pickImage(source: ImageSource.gallery)),
        _attachBtn('📁', '파일', _pickFile),
        _attachBtn('✕', '닫기', () => setState(() => _showAttach = false)),
      ],
    ),
  );

  Widget _attachBtn(String icon, String label, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(icon, style: const TextStyle(fontSize: 26)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
      ]),
    ),
  );

  // ── 입력 영역 ─────────────────────────────
  Widget _buildInputArea() => Container(
    color: const Color(0xFF1A1D27),
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
    child: SafeArea(
      top: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            icon: Icon(
              _showAttach ? Icons.close : Icons.attach_file,
              color: _showAttach
                  ? const Color(0xFF6C63FF)
                  : Colors.white.withOpacity(0.4),
            ),
            onPressed: () => setState(() => _showAttach = !_showAttach),
          ),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: const Color(0xFF22263A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF2E3350)),
              ),
              child: TextField(
                controller: _textCtrl,
                focusNode: _focusNode,
                maxLines: null,
                maxLength: 1000,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '메시지를 입력하세요...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  counterText: '',
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _textCtrl.text.trim().isEmpty ? null : _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: _textCtrl.text.trim().isEmpty
                    ? const Color(0xFF22263A)
                    : const Color(0xFF6C63FF),
                borderRadius: BorderRadius.circular(21),
              ),
              child: Icon(
                Icons.send_rounded,
                color: _textCtrl.text.trim().isEmpty
                    ? Colors.white.withOpacity(0.2)
                    : Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  // ── 방 정보 바텀시트 ──────────────────────
  void _showRoomInfo() => showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1A1D27),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4,
            decoration: BoxDecoration(color: const Color(0xFF2E3350),
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Text('${widget.room.icon} ${widget.room.name}',
            style: const TextStyle(color: Colors.white, fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        _infoRow('Pulsar 토픽', widget.room.topic),
        _infoRow('구독 방식', 'Shared'),
        _infoRow('메시지 보관', '7일'),
      ]),
    ),
  );

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
        const Spacer(),
        Flexible(child: Text(value,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis)),
      ],
    ),
  );

  String _getFileEmoji(String? type) {
    if (type == null) return '📄';
    if (type.startsWith('image/')) return '🖼';
    if (type.startsWith('video/')) return '🎬';
    if (type.startsWith('audio/')) return '🎵';
    if (type.contains('pdf'))      return '📕';
    if (type.contains('zip') || type.contains('rar')) return '🗜';
    return '📄';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
