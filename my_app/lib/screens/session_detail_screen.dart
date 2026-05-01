import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../models/class_session.dart';

class SessionDetailScreen extends StatefulWidget {
  final ClassSession session;
  const SessionDetailScreen({super.key, required this.session});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم نسخ $label')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final dateStr = DateFormat('EEEE، d MMMM y', 'ar').format(s.date);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(s.title,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 17)),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.accent,
          indicatorWeight: 4,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(
                text: 'الملخص',
                icon: Icon(Icons.auto_awesome_rounded, size: 16)),
            Tab(
                text: 'النص الكامل',
                icon: Icon(Icons.text_fields_rounded, size: 16)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Meta bar
          Container(
            color: AppColors.primary.withOpacity(0.06),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _metaChip(Icons.timer_rounded, s.formattedDuration),
                const SizedBox(width: 12),
                _metaChip(Icons.calendar_today_rounded, dateStr),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildTab(
                  s.summary.isEmpty
                      ? 'لا يوجد ملخص لهذه الحصة.'
                      : s.summary,
                  'الملخص',
                  s.summary.isNotEmpty,
                ),
                _buildTab(
                  s.transcript.isEmpty
                      ? 'لا يوجد نص لهذه الحصة.'
                      : s.transcript,
                  'النص الكامل',
                  s.transcript.isNotEmpty,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(width: 4),
        Icon(icon, size: 14, color: AppColors.textSecondary),
      ],
    );
  }

  Widget _buildTab(String text, String label, bool canCopy) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (canCopy)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _copy(text, label),
                    icon: const Icon(Icons.copy_rounded,
                        size: 16, color: AppColors.primary),
                    label: const Text('نسخ',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              Text(
                text,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                    height: 1.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

