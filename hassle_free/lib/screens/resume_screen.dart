import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import '../services/resume_service.dart';

class ResumeScreen extends StatefulWidget {
  final Function(String)? onNameExtracted;
  const ResumeScreen({super.key, this.onNameExtracted});

  @override
  State<ResumeScreen> createState() => _ResumeScreenState();
}

class _ResumeScreenState extends State<ResumeScreen> {
  bool _isUploading = false;
  bool _isAnalyzed = false;
  double _uploadProgress = 0.0;

  String _filename = "";
  String _category = "Software Engineer";
  String _extractedName = "";
  List<String> _skills = [];
  String _experience = "";
  String _education = "";
  String _textPreview = "";
  final ResumeService _resumeService = ResumeService();

  @override
  void initState() {
    super.initState();
    _loadPreviousAnalysis();
  }

  Future<void> _loadPreviousAnalysis() async {
    final data = await _resumeService.getLatestResumeAnalysis();
    if (data != null && mounted) {
      if (mounted) {
        setState(() {
          _isAnalyzed = true;
          _filename = data['filename'] ?? "";
          _category = data['category'] ?? "Unknown";
          _extractedName = data['name'] ?? "User";
          _skills = List<String>.from(data['skills'] ?? []);
          _experience = data['experience'] ?? "";
          _education = data['education'] ?? "";
          _textPreview = data['textPreview'] ?? "";
        });
        if (widget.onNameExtracted != null) {
          widget.onNameExtracted!(_extractedName);
        }
      }
    }
  }

  Future<void> _pickAndUploadResume() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx'],
      withData: true,
    );

    if (result != null) {
      PlatformFile file = result.files.first;
      setState(() {
        _isUploading = true;
        _isAnalyzed = false;
        _uploadProgress = 0.1;
        _filename = file.name;
      });

      try {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('http://localhost:5002/api/upload-resume'),
        );
        if (file.bytes != null) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'resume',
              file.bytes!,
              filename: file.name,
            ),
          );
        }

        var streamedResponse = await request.send();
        setState(() => _uploadProgress = 0.7);
        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          var data = json.decode(response.body);
          var score = data['score'] ?? {};

          if (mounted) {
            setState(() {
              _isUploading = false;
              _isAnalyzed = true;
              _uploadProgress = 1.0;
              _category = data['category'] ?? "Unknown";
              _extractedName = data['name'] ?? "User";
              _skills = List<String>.from(data['skills'] ?? []);
              _experience = data['experience'] ?? "";
              _education = data['education'] ?? "";
              _textPreview = data['text_preview'] ?? "";
            });
            if (widget.onNameExtracted != null) {
              widget.onNameExtracted!(_extractedName);
            }

            await _resumeService.saveResumeAnalysis(
              filename: _filename,
              category: _category,
              name: _extractedName,
              skills: _skills,
              experience: _experience,
              education: _education,
              textPreview: _textPreview,
              overallScore: (score['overall_score'] as num?)?.toDouble(),
              breakdown: score['breakdown'],
              badges: List<String>.from(score['badges'] ?? []),
            );
          }
        }
      } catch (e) {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildHeroBanner(),
            const SizedBox(height: 32),
            LayoutBuilder(
              builder: (context, constraints) {
                bool isWide = constraints.maxWidth > 1000;
                return isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: _buildLeftColumn()),
                          const SizedBox(width: 24),
                          Expanded(flex: 2, child: _buildRightColumn()),
                        ],
                      )
                    : Column(
                        children: [
                          _buildLeftColumn(),
                          const SizedBox(height: 24),
                          _buildRightColumn(),
                        ],
                      );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftColumn() {
    return Column(
      children: [
        _buildUploadCard(),
        if (_isAnalyzed) ...[
          const SizedBox(height: 24),
          _buildResultSectionCard("Experience", _experience, Icons.work),
          const SizedBox(height: 24),
          _buildResultSectionCard("Education", _education, Icons.school),
        ],
      ],
    );
  }

  Widget _buildRightColumn() {
    return _isAnalyzed
        ? _buildCandidateOverview()
        : _buildEmptyResultsPlaceholder();
  }

  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resume Analysis',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Let AI extract and visualize your professional profile',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSectionCard(String title, String content, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blueAccent, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ..._formatContent(content),
        ],
      ),
    );
  }

  List<Widget> _formatContent(String content) {
    if (content.isEmpty || content.contains("No history found")) {
      return [
        const Text(
          "No profile data found.",
          style: TextStyle(color: Colors.white38),
        ),
      ];
    }

    List<String> lines = content.split('\n');
    return lines.map((line) {
      String cleanLine = line.trim();
      if (cleanLine.isEmpty) return const SizedBox(height: 8);

      // Regex for dates like "Feb 2025 - Apr 2025" or "2022 - 2026"
      final datePattern = RegExp(
        r'([A-Za-z]+ \d{4} - [A-Za-z]+ \d{4})|(\d{4}\s*-\s*\d{4})',
      );
      final match = datePattern.firstMatch(cleanLine);

      if (match != null) {
        String dateStr = match.group(0)!;
        String titleStr = cleanLine.replaceFirst(dateStr, '').trim();
        // Remove trailing separators
        titleStr = titleStr.replaceAll(RegExp(r'[|]\s*$'), '').trim();

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  titleStr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                dateStr,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        );
      }

      // Bullets or subheaders
      bool isBullet =
          cleanLine.startsWith('•') ||
          cleanLine.startsWith('*') ||
          cleanLine.startsWith('-');
      return Padding(
        padding: EdgeInsets.only(left: isBullet ? 12 : 0, bottom: 4),
        child: Text(
          cleanLine,
          style: TextStyle(
            color: cleanLine.contains("Learned & Achieved")
                ? Colors.white
                : Colors.white70,
            fontSize: 14,
            height: 1.4,
            fontWeight: cleanLine.contains("Learned & Achieved")
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
      );
    }).toList();
  }

  Widget _buildCandidateOverview() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Candidate Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          _buildInfoRow(Icons.person, "Name:", _extractedName),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.category, "Role:", _category),
          const SizedBox(height: 32),
          const Text(
            'Technical Skills',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: _skills.map((s) => _buildSkillTag(s)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 18),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkillTag(String skill) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        skill.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildUploadCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upload Resume',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          _isUploading
              ? LinearProgressIndicator(
                  value: _uploadProgress,
                  color: Colors.blueAccent,
                )
              : _isAnalyzed
              ? Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.greenAccent),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Successfully Analyzed!",
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _isAnalyzed = false),
                      child: const Text(
                        "Reset",
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  ],
                )
              : ElevatedButton(
                  onPressed: _pickAndUploadResume,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text(
                    "Select File",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildEmptyResultsPlaceholder() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Text(
          "Upload a resume to see analysis",
          style: TextStyle(color: Colors.white24),
        ),
      ),
    );
  }
}
