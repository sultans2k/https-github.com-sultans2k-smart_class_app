import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../models/class_session.dart';
import '../services/gemini_service.dart';
import '../services/recording_service.dart';
import '../services/storage_service.dart';
import 'session_detail_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';


class HistoryScreen extends StatefulWidget {
  final UserRole role;
  const HistoryScreen({super.key, required this.role});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final StorageService _storage = StorageService();
  final RecordingService _recorder = RecordingService();
  final GeminiService _gemini = GeminiService();

  List<ClassSession> _sessions = [];
  bool _loading = true;

  // Track which session is currently being processed
  String? _processingId;
  String _processingStatus = '';

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _loading = true);
    final sessions = await _storage.loadSessions();
    setState(() {
      _sessions = sessions;
      _loading = false;
    });
  }

  // ── Transcribe ─────────────────────────────────────────────────────────────

  Future<void> _transcribe(ClassSession session) async {
    if (session.audioFilePath.isEmpty) {
      _showSnack('لا يوجد ملف صوتي لهذه الحصة.');
      return;
    }

    setState(() {
      _processingId = session.id;
      _processingStatus = 'جاري رفع الملف...';
    });

    try {
      final transcript = await _recorder.transcribeFile(
        session.audioFilePath,
        onProgress: (msg) {
          if (mounted) setState(() => _processingStatus = msg);
        },
      );

      final updated = session.copyWith(transcript: transcript);
      await _storage.updateSession(updated);
      await _loadSessions();
      _showSnack('✅ تم تحويل التسجيل إلى نص');
    } catch (e) {
      _showSnack('خطأ: $e');
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  // ── Summarize ──────────────────────────────────────────────────────────────

  Future<void> _summarize(ClassSession session) async {
    if (!session.hasTranscript) {
      _showSnack('يجب تحويل التسجيل إلى نص أولاً.');
      return;
    }

    setState(() {
      _processingId = session.id;
      _processingStatus = 'جاري توليد الملخص...';
    });

    try {
      final summary = await _gemini.summarizeTranscript(session.transcript);
      final updated = session.copyWith(summary: summary);
      await _storage.updateSession(updated);
      await _loadSessions();
      _showSnack('✅ تم توليد الملخص');
    } catch (e) {
      _showSnack('خطأ في الاتصال بالخادم: $e');
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> _delete(ClassSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الحصة', textAlign: TextAlign.right),
        content: Text('هل تريد حذف "${session.title}"؟',
            textAlign: TextAlign.right),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.recording),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _storage.deleteSession(session.id);
      _loadSessions();
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        title: const Column(
          children: [
            Text('سجل الحصص',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18)),
            Text('جميع الحصص المسجلة',
                style: TextStyle(color: Color(0xFF90CAF9), fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadSessions,
          ),
        ],
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
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _sessions.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _loadSessions,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _sessions.length,
                    itemBuilder: (_, i) =>
                        _buildCard(_sessions[i]),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_edu_rounded,
              size: 64, color: AppColors.divider),
          SizedBox(height: 16),
          Text('لا توجد حصص مسجلة',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500)),
          SizedBox(height: 6),
          Text('سجّل حصة من تبويب التسجيل',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildCard(ClassSession session) {
    final isProcessing = _processingId == session.id;
    final dateStr =
        DateFormat('d MMM y، hh:mm a', 'ar').format(session.date);

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 14),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────
          InkWell(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(18)),
            onTap: session.hasTranscript
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              SessionDetailScreen(session: session)),
                    ).then((_) => _loadSessions())
                : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Delete button on left
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.textSecondary, size: 20),
                    onPressed:
                        isProcessing ? null : () => _delete(session),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(session.title,
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 3),
                        Text(dateStr,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Status icon on right
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      session.hasSummary
                          ? Icons.auto_awesome_rounded
                          : session.hasTranscript
                              ? Icons.text_fields_rounded
                              : Icons.mic_rounded,
                      color: session.hasSummary
                          ? AppColors.accent
                          : session.hasTranscript
                              ? AppColors.success
                              : AppColors.primary,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Processing indicator ─────────────────────────────────────
          if (isProcessing)
            Container(
              width: double.infinity,
              color: AppColors.accent.withOpacity(0.06),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(_processingStatus,
                      style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(width: 10),
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        color: AppColors.accent, strokeWidth: 2),
                  ),
                ],
              ),
            ),

          // ── Status chips + action buttons ────────────────────────────
          Padding(
            padding:
                const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                // Chips row
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (session.hasSummary)
                      _chip(Icons.auto_awesome_rounded, 'يوجد ملخص',
                          AppColors.accent),
                    if (session.hasTranscript) ...[
                      if (session.hasSummary)
                        const SizedBox(width: 6),
                      _chip(Icons.text_fields_rounded, 'يوجد نص',
                          AppColors.success),
                    ],
                    if (session.hasAudio) ...[
                      if (session.hasTranscript)
                        const SizedBox(width: 6),
                      _chip(Icons.mic_rounded, session.formattedDuration,
                          AppColors.primary),
                    ],
                  ],
                ),
                const SizedBox(height: 10),

                // Action buttons
                if (!isProcessing)
                  Row(
                    children: [
                      // View detail (if transcript exists)
                      if (session.hasTranscript)
                        Expanded(
                          child: _actionBtn(
                            label: 'عرض',
                            icon: Icons.visibility_outlined,
                            color: AppColors.primary,
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => SessionDetailScreen(
                                      session: session)),
                            ).then((_) => _loadSessions()),
                          ),
                        ),

                      if (session.hasTranscript)
                        const SizedBox(width: 8),

                      // Transcribe button
                      if (!session.hasTranscript)
                        Expanded(
                          child: _actionBtn(
                            label: 'تحويل إلى نص',
                            icon: Icons.text_fields_rounded,
                            color: AppColors.accent,
                            onPressed: () => _transcribe(session),
                          ),
                        ),

                      if (session.hasTranscript &&
                          !session.hasSummary) ...[
                        Expanded(
                          child: _actionBtn(
                            label: 'توليد ملخص',
                            icon: Icons.auto_awesome_rounded,
                            color: AppColors.accent,
                            onPressed: () => _summarize(session),
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(color: color, fontSize: 11)),
          const SizedBox(width: 4),
          Icon(icon, size: 11, color: color),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 38,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          elevation: 0,
          padding:
              const EdgeInsets.symmetric(horizontal: 10),
        ),
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 15),
        label: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}
