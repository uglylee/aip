import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../models/provider_model.dart';
import '../models/role.dart';
import 'settings_screen.dart';
import 'providers_screen.dart';
import 'roles_screen.dart';
import 'dart:convert';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});
  @override State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final msgCtrl = TextEditingController();
  final scrollCtrl = ScrollController();
  final ImagePicker _picker = ImagePicker();
  List<Map<String, dynamic>> chatHistory = [];
  List<File> _pendingImages = [];
  bool isStreaming = false;
  String streamingText = '';
  String streamingThinking = '';
  bool thinkingDone = false;
  String currentRolePrompt = '';
  String currentRoleName = '默认';
  String currentRoleId = 'default';
  List<AIProvider> providers = [];
  String currentProviderId = 'agnes';
  bool enableThinking = true;
  String inputText = '';
  bool _settingsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    msgCtrl.addListener(() {
      if (msgCtrl.text != inputText) setState(() => inputText = msgCtrl.text);
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    providers = await AIProvider.loadAll();
    currentProviderId = prefs.getString('current_provider_id') ?? 'agnes';
    enableThinking = prefs.getBool('enable_thinking') ?? true;
    final roleId = prefs.getString('current_role_id') ?? 'default';
    var rolesStr = prefs.getString('roles');
    List<Role> roles = Role.defaults();
    if (rolesStr != null) {
      try {
        roles = (jsonDecode(rolesStr) as List).map((e) => Role(id: e['id'], name: e['name'], systemPrompt: e['systemPrompt'] ?? '', deletable: e['deletable'] ?? true)).toList();
        final defaults = Role.defaults();
        bool updated = false;
        for (final d in defaults) {
          final idx = roles.indexWhere((r) => r.id == d.id);
          if (idx >= 0 && roles[idx].systemPrompt != d.systemPrompt) { roles[idx] = d; updated = true; }
          else if (idx < 0) { roles.add(d); updated = true; }
        }
        if (updated) await prefs.setString('roles', jsonEncode(roles.map((r) => {'id': r.id, 'name': r.name, 'systemPrompt': r.systemPrompt, 'deletable': r.deletable}).toList()));
      } catch (_) {}
    }
    final currentRole = roles.firstWhere((r) => r.id == roleId, orElse: () => roles.first);
    currentRolePrompt = currentRole.systemPrompt;
    currentRoleName = currentRole.name;
    final roleChanged = roleId != currentRoleId;
    currentRoleId = roleId;
    if (roleChanged || !_settingsLoaded) { _settingsLoaded = true; await _loadChatHistory(roleId); }
    else { setState(() {}); }
  }

  Future<void> _loadChatHistory(String roleId) async {
    final prefs = await SharedPreferences.getInstance();
    final historyStr = prefs.getString('chat_history_$roleId');
    if (historyStr != null) { try { chatHistory = (jsonDecode(historyStr) as List).cast<Map<String, dynamic>>(); } catch (_) { chatHistory = []; } }
    else { chatHistory = []; }
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_history_$currentRoleId', jsonEncode(chatHistory));
  }

  void _pickImage() async {
    final files = await _picker.pickMultiImage(imageQuality: 50, maxWidth: 1024, maxHeight: 1024);
    if (files.isNotEmpty) setState(() { for (final f in files) { if (_pendingImages.length < 4) _pendingImages.add(File(f.path)); } });
  }

  void _removePendingImage(int index) => setState(() => _pendingImages.removeAt(index));

  void sendMessage() async {
    if ((msgCtrl.text.trim().isEmpty && _pendingImages.isEmpty) || isStreaming) return;
    final text = msgCtrl.text.trim();
    msgCtrl.clear();
    final imagesToSend = List<File>.from(_pendingImages);
    setState(() { _pendingImages = []; isStreaming = true; streamingText = ''; streamingThinking = ''; thinkingDone = false; });
    _scrollToBottom();

    final List<String> imageUrls = [];
    for (final file in imagesToSend) { final url = await ApiService.uploadFile(file); if (url != null) imageUrls.add(url); }

    final userMsg = <String, dynamic>{'role': 'user', 'content': text};
    if (imageUrls.isNotEmpty) userMsg['images'] = imageUrls;
    setState(() => chatHistory.add(userMsg));
    _scrollToBottom();

    final provider = providers.firstWhere((p) => p.id == currentProviderId, orElse: () => providers.first);
    final prefs = await SharedPreferences.getInstance();
    final selectedModel = prefs.getString('model_${provider.id}') ?? provider.model;

    final messages = <Map<String, dynamic>>[];
    if (currentRolePrompt.isNotEmpty) messages.add({'role': 'system', 'content': currentRolePrompt});
    for (final m in chatHistory) {
      final msg = <String, dynamic>{'role': m['role'], 'content': m['content'] ?? ''};
      if (m['images'] != null) msg['images'] = m['images'];
      messages.add(msg);
    }

    try {
      final stream = ApiService.chatStream(messages: messages, apiBase: provider.apiBase, apiKey: provider.apiKey, model: selectedModel, enableThinking: enableThinking);
      await for (final chunk in stream) {
        if (chunk.startsWith('§REASONING§')) { setState(() => streamingThinking += chunk.substring(11)); }
        else {
          final trimmed = chunk.replaceAll(RegExp(r'\n{2,}'), '\n').trim();
          if (trimmed.isEmpty) continue;
          if (!thinkingDone) setState(() => thinkingDone = true);
          setState(() => streamingText += chunk);
        }
        _scrollToBottom();
      }
      setState(() { chatHistory.add({'role': 'assistant', 'content': streamingText, 'thinking': streamingThinking}); streamingText = ''; streamingThinking = ''; thinkingDone = false; isStreaming = false; });
      _saveChatHistory();
    } catch (e) {
      setState(() { chatHistory.add({'role': 'assistant', 'content': '错误: $e'}); isStreaming = false; streamingText = ''; streamingThinking = ''; thinkingDone = false; });
      _saveChatHistory();
    }
  }

  void _clearChat() { setState(() { chatHistory.clear(); streamingText = ''; streamingThinking = ''; }); _saveChatHistory(); }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollCtrl.hasClients) scrollCtrl.animateTo(scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 100), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('AI 助手', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(currentRoleName, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.smart_toy), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RolesScreen())).then((_) => _loadSettings())),
          IconButton(icon: const Icon(Icons.settings), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())).then((_) => _loadSettings())),
          IconButton(icon: const Icon(Icons.delete_sweep), onPressed: _clearChat),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: chatHistory.isEmpty && streamingText.isEmpty
              ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.auto_awesome, size: 64, color: Color(0xFF1DA1F2)),
                  SizedBox(height: 16),
                  Text('AI 助手', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('问我任何问题', style: TextStyle(color: Colors.grey)),
                ]))
              : ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(12),
                  itemCount: chatHistory.length + (isStreaming ? 1 : 0),
                  itemBuilder: (ctx, i) {
                    if (i == chatHistory.length) return _buildStreamingBubble();
                    final msg = chatHistory[i];
                    final isUser = msg['role'] == 'user';
                    final thinking = msg['thinking'] as String? ?? '';
                    final images = (msg['images'] as List?)?.cast<String>() ?? [];
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                        child: Column(
                          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            if (!isUser && thinking.isNotEmpty) _ThinkingBox(thinking: thinking),
                            if (images.isNotEmpty)
                              Padding(padding: const EdgeInsets.only(bottom: 4), child: Wrap(spacing: 4, runSpacing: 4, children: images.map((url) =>
                                ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network('${ApiService.baseUrl}$url', width: 120, height: 120, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(width: 120, height: 120, color: Colors.grey[200], child: const Icon(Icons.broken_image, color: Colors.grey)))),
                              ).toList())),
                            if (msg['content'] != null && (msg['content'] as String).trim().isNotEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: isUser ? const Color(0xFF1DA1F2) : Colors.grey[100], borderRadius: BorderRadius.circular(16)),
                                child: Text((msg['content'] as String).replaceAll(RegExp(r'\n{3,}'), '\n\n').trim(), style: TextStyle(color: isUser ? Colors.white : Colors.black)),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        _buildInputArea(),
      ]),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_pendingImages.isNotEmpty)
          SizedBox(
            height: 70, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _pendingImages.length, itemBuilder: (ctx, i) => Stack(children: [
              Padding(padding: const EdgeInsets.only(right: 8), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_pendingImages[i], width: 70, height: 70, fit: BoxFit.cover))),
              Positioned(top: 0, right: 4, child: GestureDetector(onTap: () => _removePendingImage(i), child: Container(decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), padding: const EdgeInsets.all(2), child: const Icon(Icons.close, color: Colors.white, size: 14)))),
            ])),
          ),
        Row(children: [
          IconButton(icon: const Icon(Icons.image_outlined, color: Color(0xFF1DA1F2), size: 22), onPressed: isStreaming ? null : _pickImage, padding: const EdgeInsets.all(8)),
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20)),
              child: TextField(
                controller: msgCtrl,
                decoration: const InputDecoration(hintText: '给 AI 发消息', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 8), isDense: true),
                style: const TextStyle(fontSize: 14),
                maxLines: 1,
                enabled: !isStreaming,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.mic, color: Color(0xFF1DA1F2), size: 22),
            padding: const EdgeInsets.all(8),
            onPressed: isStreaming ? null : () async {
              final input = await showDialog<String>(
                context: context,
                builder: (ctx) {
                  final ctrl = TextEditingController();
                  return AlertDialog(
                    contentPadding: const EdgeInsets.all(16),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('语音输入', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: '点击键盘🎤按钮说话')),
                      const SizedBox(height: 8),
                      const Text('使用键盘自带语音输入', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ]),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                      TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('确定')),
                    ],
                  );
                },
              );
              if (input != null && input.trim().isNotEmpty) {
                msgCtrl.text = input;
                setState(() => inputText = input);
              }
            },
          ),
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ((inputText.trim().isNotEmpty || _pendingImages.isNotEmpty) && !isStreaming) ? const Color(0xFF1DA1F2) : Colors.grey[300],
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 18),
              padding: EdgeInsets.zero,
              onPressed: ((inputText.trim().isNotEmpty || _pendingImages.isNotEmpty) && !isStreaming) ? sendMessage : null,
            ),
          ),
        ]),
      ]),
    );
  }

  Future<String?> showTextInputDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('语音输入'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: '请使用键盘语音输入按钮')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('确定')),
        ],
      ),
    );
  }

  Widget _buildStreamingBubble() {
    final hasThinking = streamingThinking.isNotEmpty;
    final hasText = streamingText.isNotEmpty;
    final showThinking = hasThinking && enableThinking;
    if (!showThinking && !hasText) {
      return Align(alignment: Alignment.centerLeft, child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4), padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(16)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 8),
          Text(enableThinking ? '思考中...' : '回复中...', style: const TextStyle(color: Colors.grey)),
        ]),
      ));
    }
    return Align(alignment: Alignment.centerLeft, child: Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (showThinking) _ThinkingBox(thinking: streamingThinking, isStreaming: !thinkingDone),
        if (hasText) Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(16)), child: Text(streamingText.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim())),
      ]),
    ));
  }
}

class _ThinkingBox extends StatefulWidget {
  final String thinking;
  final bool isStreaming;
  const _ThinkingBox({required this.thinking, this.isStreaming = false});
  @override State<_ThinkingBox> createState() => _ThinkingBoxState();
}

class _ThinkingBoxState extends State<_ThinkingBox> {
  late bool _expanded;
  @override void initState() { super.initState(); _expanded = widget.isStreaming; }
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(color: const Color(0xFFF8F8F0), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE8E8D8))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              const Text('💭', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(widget.isStreaming ? '思考中...' : '思考过程', style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
              const Spacer(),
              if (widget.isStreaming) SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.grey[400]))
              else Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 20, color: Colors.grey[500]),
            ]),
          ),
        ),
        if (_expanded) ...[const Divider(height: 1), Padding(padding: const EdgeInsets.all(12), child: Text(widget.thinking, style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.5)))],
      ]),
    );
  }
}
