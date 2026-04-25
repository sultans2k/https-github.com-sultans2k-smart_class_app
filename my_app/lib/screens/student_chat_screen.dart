import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../constants.dart';
import '../models/chat_message.dart';
import '../services/elevenlabs_service.dart';
import '../services/gemini_service.dart';
import '../widgets/waveform_visualizer.dart';
import 'package:firebase_auth/firebase_auth.dart';


class StudentChatScreen extends StatefulWidget {
  final UserRole role;
  const StudentChatScreen({super.key, required this.role});

  @override
  State<StudentChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<StudentChatScreen> {
  final SpeechToText _stt = SpeechToText();
  final ElevenLabsService _tts = ElevenLabsService();
  final ScrollController _scrollCtrl = ScrollController();
  final GeminiService _gemini = GeminiService();


  bool _speechEnabled = false;
  String _currentWords = '';
  bool _isLoading = false;
  bool _isAiSpeaking = false;

  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _tts.onSpeakingChanged((v) {
      if (mounted) setState(() => _isAiSpeaking = v);
    });
  }

  Future<void> _initSpeech() async {
    _speechEnabled = await _stt.initialize(
      onStatus: (_) => setState(() {}),
      onError: (_) => setState(() {}),
    );
    setState(() {});
  }

  // ── Speech ─────────────────────────────────────────────────────────────────

  void _startListening() async {
    await _tts.stop();
    setState(() {
      _isAiSpeaking = false;
      _currentWords = '';
    });
    await _stt.listen(
      onResult: (result) {
        setState(() => _currentWords = result.recognizedWords);
        if (result.finalResult && !_isLoading) {
          _send(result.recognizedWords);
        }
      },
      localeId: 'ar-SA',
    );
    setState(() {});
  }

  void _stopListening() async {
    await _stt.stop();
    setState(() {});
  }

  // ── Chat ───────────────────────────────────────────────────────────────────

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    await _stt.stop();

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _currentWords = '';
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final reply = await _gemini.chat(text);
      setState(() => _messages.add(ChatMessage(text: reply, isUser: false)));
      _scrollToBottom();
      await _tts.speak(reply);
    } catch (e) {
      setState(
        () => _messages.add(
          ChatMessage(text: 'خطأ في الاتصال: $e', isUser: false),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
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

  @override
  void dispose() {
    _tts.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _buildBubble(_messages[i]),
                  ),
          ),
          _buildBottomPanel(),
        ],
      ),
      floatingActionButton: _buildMicButton(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 0,
      centerTitle: true,
      title: const Column(
        children: [
          Text(
            'المساعد الذكي',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          Text(
            'اسأل أي سؤال',
            style: TextStyle(color: Color(0xFF90CAF9), fontSize: 12),
          ),
        ],
      ),
         leading: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11.0),
        child: GestureDetector(
          onTap: () {
            // Fetch the currently logged-in user from Firebase
            final currentUser = FirebaseAuth.instance.currentUser;
            final email = currentUser?.email ?? 'لا يوجد بريد إلكتروني';

            // Display the email to the user
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('الحساب الحالي: $email'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppColors.accent,
                duration: const Duration(seconds: 3),
              ),
            );
          },
          child: CircleAvatar(
            backgroundColor: Colors.white24,
            child: Icon(widget.role.icon, color: Colors.white, size: 22),
          ),
        ),
      ),
      actions: [
        if (_messages.isNotEmpty)
          IconButton(
            icon: const Icon(
              Icons.delete_sweep_outlined,
              color: Colors.white70,
            ),
            tooltip: 'مسح المحادثة',
            onPressed: () => setState(() => _messages.clear()),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.record_voice_over,
                size: 38,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'اضغط على الميكروفون للبدء',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? AppColors.userBubble : AppColors.aiBubble,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          msg.text,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: isUser ? Colors.white : AppColors.textPrimary,
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 52,
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2.5,
                    ),
                  )
                : WaveformVisualizer(
                    isActive: _isAiSpeaking || _stt.isListening,
                    activeColor: _stt.isListening
                        ? AppColors.recording
                        : AppColors.accent,
                  ),
          ),
          if (_currentWords.isNotEmpty && !_isLoading)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
              child: Text(
                _currentWords,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          const SizedBox(height: 70),
        ],
      ),
    );
  }

  Widget _buildMicButton() {
    final listening = _stt.isListening;
    return FloatingActionButton.extended(
      onPressed: !_speechEnabled || _isLoading
          ? null
          : (listening ? _stopListening : _startListening),
      backgroundColor: listening ? AppColors.recording : AppColors.primary,
      icon: Icon(
        listening ? Icons.stop_rounded : Icons.mic_rounded,
        color: Colors.white,
      ),
      label: Text(
        listening ? 'إيقاف' : 'تحدث',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}