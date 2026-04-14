import 'package:flutter/material.dart';

// ── API Configuration ────────────────────────────────────────────────────────
// const String kElevenLabsApiKey = '';
// const String kElevenLabsVoiceId = 'pNInz6obpgDQGcFmaJgB'; // Adam (free tier)
// const String kElevenLabsModelId = 'eleven_multilingual_v2';

// const String kOllamaModel = 'qwen2:1.5b';

const String kGeminiApiKey = '';

const int kMaxRecordingMinutes = 60;

// ── Color Palette ────────────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF0D47A1);
  static const Color primaryLight = Color(0xFF1565C0);
  static const Color accent = Color(0xFF00B0FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF0F4F8);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color userBubble = Color(0xFF1565C0);
  static const Color aiBubble = Color(0xFFE8EFF7);
  static const Color textPrimary = Color(0xFF0D1B2A);
  static const Color textSecondary = Color(0xFF546E7A);
  static const Color divider = Color(0xFFCFD8DC);
  static const Color recording = Color(0xFFE53935);
  static const Color success = Color(0xFF43A047);
  static const Color warning = Color(0xFFFFA726);
}

// ── Text Styles ───────────────────────────────────────────────────────────────
class AppTextStyles {
  AppTextStyles._();

  static const TextStyle heading = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 22,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );
}
