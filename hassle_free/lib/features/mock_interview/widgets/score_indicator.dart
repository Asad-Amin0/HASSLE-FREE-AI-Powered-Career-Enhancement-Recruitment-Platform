import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../models/interview_result.dart';

class ScoreIndicator extends StatelessWidget {
  final InterviewResult result;
  final double margin;

  const ScoreIndicator({super.key, required this.result, this.margin = 20});

  Color get _scoreColor {
    if (result.score >= 0.75) return const Color(0xFF00C896);
    if (result.score >= 0.55) return const Color(0xFFFFD700);
    return const Color(0xFFFF6B6B);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: margin, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _scoreColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Score row
          Row(
            children: [
              CircularPercentIndicator(
                radius: 36,
                lineWidth: 6,
                percent: result.score,
                center: Text(
                  '${(result.score * 100).round()}%',
                  style: TextStyle(
                    color: _scoreColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                progressColor: _scoreColor,
                backgroundColor: Colors.white10,
                circularStrokeCap: CircularStrokeCap.round,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.passed ? '✅ Good Answer' : '⚠️ Needs Improvement',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.encouragement,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Feedback
          Text(
            result.feedback,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 12),

          // Matched phrases
          if (result.matchedPhrases.isNotEmpty) ...[
            const Text('Covered:', style: TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: result.matchedPhrases.map((p) => _Chip(label: p, color: const Color(0xFF00C896))).toList(),
            ),
          ],

          // Missed phrases
          if (result.missedPhrases.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Could improve:', style: TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: result.missedPhrases.take(4).map((p) => _Chip(label: p, color: const Color(0xFFFF8A65))).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }
}
