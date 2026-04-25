import 'package:google_generative_ai/google_generative_ai.dart';
import '../constants.dart';
import '../prompts/gemini_prompts.dart';
import 'dart:async';

class GeminiException implements Exception {
  final String message;
  final Object? cause;
  GeminiException(this.message, {this.cause});

  @override
  String toString() => 'GeminiException: $message${cause != null ? ' — $cause' : ''}';
}

class GeminiService {
  static const int _maxContextChars = 12000;
  static const Duration _timeout = Duration(seconds: 45);

  GenerativeModel _buildModel(String systemInstruction) {
    return GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: kGeminiApiKey,
      systemInstruction: Content.system(systemInstruction),
    );
  }

  String _truncate(String text, {int maxChars = _maxContextChars}) {
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars)}\n\n[... تم اقتطاع المحتوى لتجاوزه الحد المسموح ...]';
  }

  Future<String> chat(
    String userMessage, {
    String? pdfContext,
    ChatSession? session,
  }) async {
    if (userMessage.trim().isEmpty) return 'الرسالة فارغة.';

    final systemPrompt = pdfContext != null
        ? GeminiPrompts.chatWithContext(_truncate(pdfContext))
        : GeminiPrompts.chatBasic;

    try {
      if (session != null) {
        // multi-turn: استخدم الجلسة الموجودة
        final response = await session
            .sendMessage(Content.text(userMessage))
            .timeout(_timeout);
        return response.text?.trim() ?? 'لم يتم إنشاء استجابة.';
      }

      // single-turn
      final model = _buildModel(systemPrompt);
      final response = await model
          .generateContent([Content.text(userMessage)])
          .timeout(_timeout);
      return response.text?.trim() ?? 'لم يتم إنشاء استجابة.';
    } on TimeoutException {
      throw GeminiException('انتهت مهلة الاتصال بـ Gemini.');
    } catch (e) {
      throw GeminiException('فشل طلب المحادثة', cause: e);
    }
  }

  /// Starts a persistent chat session (for multi-turn student Q&A).
  ChatSession startSession({String? pdfContext}) {
    final systemPrompt = pdfContext != null
        ? GeminiPrompts.chatWithContext(_truncate(pdfContext))
        : GeminiPrompts.chatBasic;
    return _buildModel(systemPrompt).startChat();
  }

  /// Summarize transcript, optionally cross-referenced with curriculum PDF.
  Future<String> summarizeTranscript(
    String transcript, {
    String? pdfContext,
  }) async {
    if (transcript.trim().isEmpty) return 'لا يوجد نص للتلخيص.';

    final systemPrompt = pdfContext != null
        ? GeminiPrompts.summarizeWithContext
        : GeminiPrompts.summarizeBasic;

    final userContent = pdfContext != null
        ? 'محتوى المنهج:\n${_truncate(pdfContext)}\n\n---\nنص الحصة:\n$transcript'
        : 'لخص هذا النص:\n\n$transcript';

    try {
      final model = _buildModel(systemPrompt);
      final response = await model
          .generateContent([Content.text(userContent)])
          .timeout(_timeout);
      return response.text?.trim() ?? 'لم يتم إنشاء ملخص.';
    } on TimeoutException {
      throw GeminiException('انتهت مهلة التلخيص.');
    } catch (e) {
      throw GeminiException('فشل طلب التلخيص', cause: e);
    }
  }
}