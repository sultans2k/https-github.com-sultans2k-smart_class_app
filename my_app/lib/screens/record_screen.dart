import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../constants.dart';
import '../models/class_session.dart';
import '../services/recording_service.dart';
import '../services/storage_service.dart';
import '../widgets/waveform_visualizer.dart';
import 'package:firebase_auth/firebase_auth.dart';


enum _Step { idle, recording, saving, done }

class RecordScreen extends StatefulWidget {
  final UserRole role;
  const RecordScreen({super.key, required this.role});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen>
    with TickerProviderStateMixin {
  final RecordingService _recorder = RecordingService();
  final StorageService _storage = StorageService();
  final _uuid = const Uuid();

  _Step _step = _Step.idle;

  // Timer
  Timer? _timer;
  int _elapsedSeconds = 0;
  final int _maxSeconds = kMaxRecordingMinutes * 60;

  // Saved session info
  String? _savedTitle;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween(
      begin: 0.92,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  // ── Timer ──────────────────────────────────────────────────────────────────

  void _startTimer() {
    _elapsedSeconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
      if (_elapsedSeconds >= _maxSeconds) _stopAndSave();
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  // ── Recording ──────────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    final started = await _recorder.startRecording();
    if (!started) {
      _showSnack('تعذّر بدء التسجيل. تحقق من إذن الميكروفون.');
      return;
    }
    setState(() {
      _step = _Step.recording;
      _savedTitle = null;
    });
    _startTimer();
  }

  Future<void> _stopAndSave() async {
    _stopTimer();
    setState(() => _step = _Step.saving);

    final path = await _recorder.stopRecording();

    if (path == null) {
      _showSnack('لم يتم العثور على الملف الصوتي.');
      setState(() => _step = _Step.idle);
      return;
    }

    // Ask for session title
    final title = await _showTitleDialog();

    final session = ClassSession(
      id: _uuid.v4(),
      date: DateTime.now(),
      title: title.trim().isEmpty
          ? 'حصة ${_formatDate(DateTime.now())}'
          : title.trim(),
      duration: Duration(seconds: _elapsedSeconds),
      audioFilePath: path,
      // transcript & summary are empty — done later from history screen
    );

    await _storage.saveSession(session);

    setState(() {
      _step = _Step.done;
      _savedTitle = session.title;
    });
  }

  void _reset() {
    setState(() {
      _step = _Step.idle;
      _elapsedSeconds = 0;
      _savedTitle = null;
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _formatTime(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<String> _showTitleDialog() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('اسم الحصة', textAlign: TextAlign.right),
        content: TextField(
          controller: ctrl,
          textAlign: TextAlign.right,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'مثال: رياضيات - الفصل الثالث',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('تخطي'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result ?? '';
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
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
            Text(
              'تسجيل الحصة',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            Text(
              'حتى 60 دقيقة',
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
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMainCard(),
              if (_step == _Step.done) ...[
                const SizedBox(height: 16),
                _buildDoneCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          children: [
            _buildIcon(),
            const SizedBox(height: 24),
            _buildLabel(),
            const SizedBox(height: 24),
            if (_step == _Step.recording) ...[
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _elapsedSeconds / _maxSeconds,
                  minHeight: 6,
                  backgroundColor: AppColors.divider,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _elapsedSeconds / _maxSeconds > 0.85
                        ? AppColors.recording
                        : AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'متبقي: ${_formatTime(_maxSeconds - _elapsedSeconds)}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: WaveformVisualizer(
                  isActive: true,
                  activeColor: AppColors.recording,
                  maxHeight: 40,
                  barCount: 13,
                ),
              ),
              const SizedBox(height: 20),
            ],
            _buildButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    if (_step == _Step.saving) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.accent.withOpacity(0.1),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: AppColors.accent,
            strokeWidth: 3,
          ),
        ),
      );
    }

    if (_step == _Step.done) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.success.withOpacity(0.1),
        ),
        child: const Icon(
          Icons.check_circle_outline_rounded,
          size: 52,
          color: AppColors.success,
        ),
      );
    }

    return ScaleTransition(
      scale: _step == _Step.recording
          ? _pulseAnim
          : const AlwaysStoppedAnimation(1.0),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _step == _Step.recording
              ? AppColors.recording.withOpacity(0.12)
              : AppColors.primary.withOpacity(0.08),
          border: Border.all(
            color: _step == _Step.recording
                ? AppColors.recording
                : AppColors.primary.withOpacity(0.3),
            width: 2.5,
          ),
        ),
        child: Icon(
          _step == _Step.recording ? Icons.mic_rounded : Icons.mic_none_rounded,
          size: 48,
          color: _step == _Step.recording
              ? AppColors.recording
              : AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildLabel() {
    switch (_step) {
      case _Step.idle:
        return const Column(
          children: [
            Text(
              'اضغط لبدء تسجيل الحصة',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'سيتم حفظ التسجيل تلقائياً',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        );

      case _Step.recording:
        return Column(
          children: [
            Text(
              _formatTime(_elapsedSeconds),
              style: const TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w800,
                color: AppColors.recording,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '● جاري التسجيل',
              style: TextStyle(color: AppColors.recording, fontSize: 14),
            ),
          ],
        );

      case _Step.saving:
        return const Column(
          children: [
            Text(
              'جاري حفظ التسجيل...',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'يرجى الانتظار',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        );

      case _Step.done:
        return Column(
          children: [
            const Text(
              'تم الحفظ بنجاح',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'مدة الحصة: ${_formatTime(_elapsedSeconds)}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        );
    }
  }

  Widget _buildButton() {
    switch (_step) {
      case _Step.idle:
        return _bigButton(
          label: 'بدء التسجيل',
          icon: Icons.fiber_manual_record_rounded,
          color: AppColors.primary,
          onPressed: _startRecording,
        );
      case _Step.recording:
        return _bigButton(
          label: 'إيقاف وحفظ',
          icon: Icons.stop_rounded,
          color: AppColors.recording,
          onPressed: _stopAndSave,
        );
      case _Step.saving:
        return const SizedBox.shrink();
      case _Step.done:
        return _bigButton(
          label: 'تسجيل حصة جديدة',
          icon: Icons.add_rounded,
          color: AppColors.primary,
          onPressed: _reset,
        );
    }
  }

  Widget _bigButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildDoneCard() {
    return Card(
      elevation: 1,
      color: const Color(0xFFF0FFF4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFA5D6A7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  _savedTitle ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.folder_open_rounded,
                  color: AppColors.success,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            const Text(
              'يمكنك الآن الذهاب إلى "السجل" لتحويل التسجيل إلى نص وتوليد الملخص',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
