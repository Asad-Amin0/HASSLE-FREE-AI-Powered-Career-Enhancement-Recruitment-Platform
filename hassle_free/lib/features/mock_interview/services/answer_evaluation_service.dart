import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/interview_question.dart';
import '../models/interview_result.dart';

class AnswerEvaluationService {
  // Updated to support multiple platforms (Web, Android Emulator, Desktop)
 static String get _backendUrl {
    return 'http://54.234.158.151:3000';
  }

  Future<InterviewResult> evaluate({
    required InterviewQuestion question,
    required String userAnswer,
  }) async {
    // Try backend evaluation (uses GPT-4o-mini like your RAG system)
    try {
      return await _evaluateWithBackend(question: question, userAnswer: userAnswer);
    } catch (e) {
      debugPrint('[AnswerEvaluationService] Backend unavailable, using local evaluation: $e');
      return _evaluateLocally(question: question, userAnswer: userAnswer);
    }
  }

  Future<InterviewResult> _evaluateWithBackend({
    required InterviewQuestion question,
    required String userAnswer,
  }) async {
    final response = await http.post(
      Uri.parse('$_backendUrl/evaluateAnswer'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'questionId': question.id,
        'questionText': question.questionText,
        'idealAnswer': question.idealAnswer,
        'keyPhrases': question.keyPhrases,
        'userAnswer': userAnswer,
        'skill': question.skill,
        'difficulty': question.difficulty,
      }),
    ).timeout(const Duration(seconds: 15)); // Increased timeout for AI evaluation

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return InterviewResult.fromJson({
        ...data,
        'questionId': question.id,
        'questionText': question.questionText,
        'userAnswer': userAnswer,
        'idealAnswer': question.idealAnswer,
        'answeredAt': DateTime.now().millisecondsSinceEpoch,
      });
    }
    throw Exception('Evaluation backend returned ${response.statusCode}');
  }

  /// Local evaluation using keyword matching (same algorithm as your JS RAG system)
  InterviewResult _evaluateLocally({
    required InterviewQuestion question,
    required String userAnswer,
  }) {
    final lowerAnswer = userAnswer.toLowerCase();
    final matched = <String>[];
    final missed = <String>[];

    for (final phrase in question.keyPhrases) {
      if (lowerAnswer.contains(phrase.toLowerCase())) {
        matched.add(phrase);
      } else {
        missed.add(phrase);
      }
    }

    // Score = matched / total key phrases, with length bonus
    final keywordScore = question.keyPhrases.isEmpty
        ? 0.5
        : matched.length / question.keyPhrases.length;

    // Length bonus: penalise very short answers
    final wordCount = userAnswer.trim().split(RegExp(r'\s+')).length;
    final lengthBonus = wordCount < 10 ? -0.15 : (wordCount > 30 ? 0.1 : 0.0);

    final score = (keywordScore + lengthBonus).clamp(0.0, 1.0);
    final passed = score >= 0.55;

    String feedback;
    String encouragement;

    if (score >= 0.8) {
      feedback = 'Excellent answer! You covered the key concepts well: ${matched.join(", ")}.';
      encouragement = 'Outstanding! You clearly understand this topic deeply.';
    } else if (score >= 0.55) {
      feedback = 'Good answer. You mentioned ${matched.join(", ")}. '
          'Consider also covering: ${missed.take(3).join(", ")}.';
      encouragement = 'Nice work! A bit more depth on the missed points will make you stand out.';
    } else {
      feedback = 'Your answer needs more detail. Key concepts to address: ${missed.take(4).join(", ")}.';
      encouragement = 'Keep practicing — this is a common interview topic. Review the ideal answer and try again.';
    }

    return InterviewResult(
      questionId: question.id,
      questionText: question.questionText,
      userAnswer: userAnswer,
      idealAnswer: question.idealAnswer,
      score: score,
      matchedPhrases: matched,
      missedPhrases: missed,
      feedback: feedback,
      encouragement: encouragement,
      passed: passed,
      answeredAt: DateTime.now(),
    );
  }
}
