import 'interview_question.dart';
import 'interview_result.dart';

enum InterviewStatus { notStarted, inProgress, avatarSpeaking, userAnswering, evaluating, completed }

class InterviewSession {
  final String sessionId;
  final String userId;
  final String jobRole;
  final List<String> skills;           // Skills pulled from parsed resume
  final List<InterviewQuestion> questions;
  final List<InterviewResult> results;
  int currentQuestionIndex;
  InterviewStatus status;
  int totalPoints;
  DateTime startedAt;
  DateTime? completedAt;
  String? videoUrl;

  InterviewSession({
    required this.sessionId,
    required this.userId,
    required this.jobRole,
    required this.skills,
    required this.questions,
    this.results = const [],
    this.currentQuestionIndex = 0,
    this.status = InterviewStatus.notStarted,
    this.totalPoints = 0,
    required this.startedAt,
    this.completedAt,
    this.videoUrl,
  });

  factory InterviewSession.fromMap(Map<String, dynamic> map) {
    return InterviewSession(
      sessionId: map['sessionId'] ?? '',
      userId: map['userId'] ?? '',
      jobRole: map['jobRole'] ?? '',
      skills: List<String>.from(map['skills'] ?? []),
      questions: [], // Questions might not be needed for results viewing
      results: (map['results'] as List?)?.map((r) => InterviewResult.fromJson(r)).toList() ?? [],
      totalPoints: map['totalPoints'] ?? 0,
      startedAt: DateTime.fromMillisecondsSinceEpoch(map['startedAt'] ?? 0),
      completedAt: map['completedAt'] != null ? DateTime.fromMillisecondsSinceEpoch(map['completedAt']) : null,
      videoUrl: map['videoUrl'],
      status: InterviewStatus.completed,
    );
  }

  int get totalQuestions => questions.length;
  bool get isCompleted => results.length >= totalQuestions || status == InterviewStatus.completed;
  double get progressPercent =>
      totalQuestions == 0 ? 0 : results.length / totalQuestions;

  InterviewQuestion? get currentQuestion =>
      currentQuestionIndex < questions.length ? questions[currentQuestionIndex] : null;

  double get overallScore =>
      results.isEmpty ? 0 : results.map((r) => r.score).reduce((a, b) => a + b) / results.length;

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'userId': userId,
      'jobRole': jobRole,
      'skills': skills,
      'overallScore': overallScore,
      'totalPoints': totalPoints,
      'results': results.map((r) => r.toMap()).toList(),
      'startedAt': startedAt.millisecondsSinceEpoch,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'videoUrl': videoUrl,
    };
  }
}
