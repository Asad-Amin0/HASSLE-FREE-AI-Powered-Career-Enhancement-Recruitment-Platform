import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/interview_question.dart';

/// Connects to your Node.js RAG backend (index__1_.js style server)
/// or falls back to built-in professional question bank.
class RagQuestionService {
  // Updated to support multiple platforms (Web, Android Emulator, Desktop)
 static String get _backendUrl {
    return 'http://54.234.158.151:3000';
  }

  // ─── Built-in Professional Question Bank (RAG fallback) ───────────────────
  // These are stored here in the app so the interview always works offline.
  // In production, these come from your /ragAsk endpoint.
  static final Map<String, List<Map<String, dynamic>>> _questionBank = {
    'flutter': [
      {
        'id': 'fl_001',
        'question': 'Explain the difference between StatelessWidget and StatefulWidget in Flutter, and when you would choose one over the other.',
        'idealAnswer': 'StatelessWidget is immutable — it has no mutable state. StatefulWidget maintains a mutable State object.',
        'keyPhrases': ['immutable', 'mutable', 'setState', 'rebuild', 'State object'],
        'skill': 'Flutter',
        'difficulty': 'intermediate',
        'category': 'Technical',
      },
      {
        'id': 'fl_002',
        'question': 'What are keys in Flutter and when should we use them?',
        'idealAnswer': 'Keys preserve state when widgets move in the tree.',
        'keyPhrases': ['preserve state', 'ValueKey', 'ObjectKey', 'GlobalKey'],
        'skill': 'Flutter',
        'difficulty': 'intermediate',
        'category': 'Technical',
      },
      {
        'id': 'fl_003',
        'question': 'How do you handle state management in a large-scale Flutter application?',
        'idealAnswer': 'Using Provider, BLoC, or Riverpod to separate logic from UI.',
        'keyPhrases': ['Provider', 'BLoC', 'Riverpod', 'separation of concerns'],
        'skill': 'Flutter',
        'difficulty': 'advanced',
        'category': 'Architecture',
      },
      {
        'id': 'fl_004',
        'question': 'What are some ways to optimize Flutter app performance?',
        'idealAnswer': 'Use const constructors, avoid heavy builds, use RepaintBoundary.',
        'keyPhrases': ['const', 'RepaintBoundary', 'profiling'],
        'skill': 'Flutter',
        'difficulty': 'advanced',
        'category': 'Performance',
      },
    ],
    'javascript': [
      {
        'id': 'js_001',
        'question': 'What is the difference between "==" and "===" in JavaScript?',
        'idealAnswer': '== performs type coercion, while === checks both value and type.',
        'keyPhrases': ['coercion', 'value', 'type'],
        'skill': 'JavaScript',
        'difficulty': 'beginner',
        'category': 'Technical',
      },
      {
        'id': 'js_002',
        'question': 'Explain closures in JavaScript and provide a use case.',
        'idealAnswer': 'A closure is a function that remembers its outer variables even after the outer function has returned.',
        'keyPhrases': ['outer scope', 'encapsulation'],
        'skill': 'JavaScript',
        'difficulty': 'intermediate',
        'category': 'Technical',
      },
      {
        'id': 'js_003',
        'question': 'What is the Event Loop in JavaScript?',
        'idealAnswer': 'The mechanism that handles asynchronous callbacks in a single-threaded environment.',
        'keyPhrases': ['call stack', 'callback queue', 'microtasks'],
        'skill': 'JavaScript',
        'difficulty': 'advanced',
        'category': 'Technical',
      },
    ],
    'python': [
      {
        'id': 'py_001',
        'question': 'What is the difference between a list and a tuple in Python?',
        'idealAnswer': 'Lists are mutable, while tuples are immutable.',
        'keyPhrases': ['mutable', 'immutable'],
        'skill': 'Python',
        'difficulty': 'beginner',
        'category': 'Technical',
      },
      {
        'id': 'py_002',
        'question': 'Explain decorators in Python.',
        'idealAnswer': 'Decorators are a way to modify the behavior of a function or class.',
        'keyPhrases': ['wrapper', 'meta-programming'],
        'skill': 'Python',
        'difficulty': 'intermediate',
        'category': 'Technical',
      },
    ],
    'developer': [
      {
        'id': 'dev_001',
        'question': 'What is your preferred development workflow and why?',
        'idealAnswer': 'I prefer using Git-flow with continuous integration and peer reviews.',
        'keyPhrases': ['Git-flow', 'CI/CD', 'Code Review'],
        'skill': 'Development',
        'difficulty': 'intermediate',
        'category': 'Role',
      },
      {
        'id': 'dev_002',
        'question': 'How do you stay up-to-date with new technologies?',
        'idealAnswer': 'I follow tech blogs, attend webinars, and work on side projects.',
        'keyPhrases': ['continuous learning', 'side projects'],
        'skill': 'Learning',
        'difficulty': 'beginner',
        'category': 'Role',
      },
    ],
    'engineer': [
      {
        'id': 'eng_001',
        'question': 'How do you approach system design for scalability?',
        'idealAnswer': 'I look for bottlenecks, use load balancing, and ensure statelessness.',
        'keyPhrases': ['scalability', 'load balancing', 'bottlenecks'],
        'skill': 'System Design',
        'difficulty': 'advanced',
        'category': 'Role',
      },
    ],
    'general': [
      {
        'id': 'gen_001',
        'question': 'Tell me about a challenging technical problem you faced and how you solved it.',
        'idealAnswer': 'I once had a memory leak in a production app and used profiling tools to find it.',
        'keyPhrases': ['STAR', 'problem-solving', 'debugging'],
        'skill': 'Problem Solving',
        'difficulty': 'intermediate',
        'category': 'Behavioral',
      },
      {
        'id': 'gen_002',
        'question': 'Where do you see yourself in five years?',
        'idealAnswer': 'I hope to be in a senior role contributing to high-impact projects.',
        'keyPhrases': ['growth', 'contribution'],
        'skill': 'Career',
        'difficulty': 'beginner',
        'category': 'Behavioral',
      },
      {
        'id': 'gen_003',
        'question': 'How do you handle tight deadlines?',
        'idealAnswer': 'I prioritize tasks and communicate early if there are risks.',
        'keyPhrases': ['prioritization', 'communication'],
        'skill': 'Time Management',
        'difficulty': 'intermediate',
        'category': 'Behavioral',
      },
      {
        'id': 'gen_004',
        'question': 'What are your greatest strengths and weaknesses?',
        'idealAnswer': 'My strength is adaptability, and my weakness is perfectionism.',
        'keyPhrases': ['adaptability', 'perfectionism'],
        'skill': 'General',
        'difficulty': 'beginner',
        'category': 'Behavioral',
      },
    ],
  };

  Future<List<InterviewQuestion>> getQuestionsForSession({
    required String jobRole,
    required String jobDescription,
    required List<String> userSkills,
    int count = 4,
  }) async {
    // Try RAG backend first
    try {
      final questions = await _fetchFromBackend(
        jobRole: jobRole,
        jobDescription: jobDescription,
        skills: userSkills,
        count: count,
      );
      
      if (questions.isNotEmpty) {
        debugPrint('[RagQuestionService] Successfully fetched ${questions.length} questions from backend');
        return questions;
      }
      debugPrint('[RagQuestionService] Backend returned 0 questions, falling back to local bank');
    } catch (e) {
      debugPrint('[RagQuestionService] Backend error: $e. Using local fallback.');
    }

    // Fallback if backend fails or returns nothing
    return _getFromLocalBank(
      jobRole: jobRole,
      skills: userSkills,
      count: count,
    );
  }

  Future<List<InterviewQuestion>> _fetchFromBackend({
    required String jobRole,
    required String jobDescription,
    required List<String> skills,
    required int count,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_backendUrl/generateInterviewQuestions'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'jobRole': jobRole,
            'jobDescription': jobDescription,
            'skills': skills,
            'count': count,
            'sessionId': 'session_${DateTime.now().millisecondsSinceEpoch}',
          }),
        )
        .timeout(const Duration(seconds: 15)); // Increased timeout for AI generation

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> questionsJson = data['questions'] ?? [];
      final result = questionsJson.map((q) => InterviewQuestion.fromJson(q)).toList();
      return result.take(count).toList(); // Ensure we don't exceed count
    }
    throw Exception('Backend returned ${response.statusCode}');
  }

  List<InterviewQuestion> _getFromLocalBank({
    required String jobRole,
    required List<String> skills,
    required int count,
  }) {
    final List<InterviewQuestion> selected = [];

    // 1. Pick 2 questions based on Job Role (Job Name/Description context)
    final jobKeywords = jobRole.toLowerCase().split(' ');
    final jobQuestions = <Map<String, dynamic>>[];
    
    for (final word in jobKeywords) {
      final questions = _questionBank[word] ?? [];
      jobQuestions.addAll(questions);
    }
    
    if (jobQuestions.isEmpty) {
      jobQuestions.addAll(_questionBank['general'] ?? []);
    }
    
    jobQuestions.shuffle();
    for (var i = 0; i < (count ~/ 2) && i < jobQuestions.length; i++) {
      selected.add(InterviewQuestion.fromJson({
        'id': jobQuestions[i]['id'] ?? 'job_${i}_${DateTime.now().millisecondsSinceEpoch}',
        'questionText': jobQuestions[i]['question'],
        'idealAnswer': jobQuestions[i]['idealAnswer'],
        'skill': jobQuestions[i]['skill'],
        'category': jobQuestions[i]['category'],
        'difficulty': jobQuestions[i]['difficulty'],
        'ragConfidence': 0.88
      }));
    }

    // 2. Pick 2 questions based on Skills (Resume context)
    final skillKeys = _mapSkillsToKeys(skills);
    final skillQuestions = <Map<String, dynamic>>[];
    
    for (final key in skillKeys) {
      final questions = _questionBank[key] ?? [];
      for (final q in questions) {
        // Avoid adding the same question already selected
        if (!selected.any((s) => s.questionText == q['question'])) {
          skillQuestions.add(q);
        }
      }
    }
    
    skillQuestions.shuffle();
    for (final q in skillQuestions) {
      if (selected.length < count) {
        selected.add(InterviewQuestion.fromJson({
          'id': q['id'] ?? 'skill_${selected.length}_${DateTime.now().millisecondsSinceEpoch}',
          'questionText': q['question'],
          'idealAnswer': q['idealAnswer'],
          'skill': q['skill'],
          'category': q['category'],
          'difficulty': q['difficulty'],
          'ragConfidence': 0.9
        }));
      }
    }

    // Fill remainder with general if needed
    if (selected.length < count) {
      final general = _questionBank['general'] ?? [];
      general.shuffle();
      for (final q in general) {
        if (selected.length < count && !selected.any((s) => s.questionText == q['question'])) {
          selected.add(InterviewQuestion.fromJson({
            'id': q['id'] ?? 'gen_${selected.length}_${DateTime.now().millisecondsSinceEpoch}',
            'questionText': q['question'],
            'idealAnswer': q['idealAnswer'],
            'skill': q['skill'],
            'category': q['category'],
            'difficulty': q['difficulty'],
            'ragConfidence': 0.85
          }));
        }
      }
    }

    return selected.take(count).toList();
  }

  List<String> _mapSkillsToKeys(List<String> skills) {
    final Map<String, String> skillMap = {
      'flutter': 'flutter',
      'dart': 'flutter',
      'javascript': 'javascript',
      'js': 'javascript',
      'python': 'python',
      'py': 'python',
      'react': 'javascript',
      'node': 'javascript',
    };

    final List<String> keys = [];
    for (final skill in skills) {
      final normalized = skill.toLowerCase().trim();
      if (skillMap.containsKey(normalized)) {
        keys.add(skillMap[normalized]!);
      }
    }
    return keys.isEmpty ? ['general'] : keys;
  }
}
