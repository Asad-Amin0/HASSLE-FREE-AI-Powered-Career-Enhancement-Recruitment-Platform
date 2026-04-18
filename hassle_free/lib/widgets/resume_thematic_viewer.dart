import 'package:flutter/material.dart';
import 'candidate_avatar.dart';

class ResumeThematicViewer extends StatelessWidget {
  final Map<String, dynamic> applicant;
  final String theme;

  const ResumeThematicViewer({
    super.key,
    required this.applicant,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final resume = applicant['resumeData'] ?? {};

    switch (theme) {
      case 'Professional':
        return _buildProfessionalTheme(context, resume);
      case 'Creative':
        return _buildCreativeTheme(context, resume);
      case 'Modern':
      default:
        return _buildModernTheme(context, resume);
    }
  }

  // ─── Professional / Minimalist Theme ──────────────────────────────────────
  Widget _buildProfessionalTheme(
    BuildContext context,
    Map<String, dynamic> resume,
  ) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: const Text(
          'Professional Resume',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              applicant['seekerName']?.toUpperCase() ?? 'NAME',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w300,
                color: Colors.black,
                letterSpacing: 2,
              ),
            ),
            Text(
              applicant['seekerEmail'] ?? '',
              style: const TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const Divider(height: 40, color: Colors.black12, thickness: 1),

            _buildProfessionalSection(
              'EDUCATION',
              resume['education'] ?? 'N/A',
            ),
            const SizedBox(height: 30),
            _buildProfessionalSection(
              'EXPERIENCE',
              resume['experience'] ?? 'N/A',
            ),
            const SizedBox(height: 30),

            const Text(
              'SKILLS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: (List<String>.from(resume['skills'] ?? []))
                  .map(
                    (s) => Text(
                      s,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: const TextStyle(
            fontSize: 14,
            height: 1.6,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  // ─── Creative Theme ────────────────────────────────────────────────────────
  Widget _buildCreativeTheme(
    BuildContext context,
    Map<String, dynamic> resume,
  ) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFFEC4899),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                applicant['seekerName'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCreativeCard(
                    'About Me',
                    resume['summary'] ?? applicant['seekerEmail'] ?? '',
                    Colors.blueAccent,
                  ),
                  const SizedBox(height: 20),
                  _buildCreativeCard(
                    'Experience',
                    resume['experience'] ?? 'N/A',
                    Colors.orangeAccent,
                  ),
                  const SizedBox(height: 20),
                  _buildCreativeCard(
                    'Education',
                    resume['education'] ?? 'N/A',
                    Colors.greenAccent,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Skills',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: (List<String>.from(resume['skills'] ?? []))
                        .map(
                          (s) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: const Color(
                                  0xFFEC4899,
                                ).withValues(alpha: 0.3),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Text(
                              s,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFEC4899),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreativeCard(String title, String content, Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Modern Theme ──────────────────────────────────────────────────────────
  Widget _buildModernTheme(BuildContext context, Map<String, dynamic> resume) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Text(
          'Modern AI Resume',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 300,
            color: const Color(0xFF1E293B),
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CandidateAvatar(
                  seekerId: applicant['seekerId'] ?? '',
                  seekerName: applicant['seekerName'] ?? '?',
                  radius: 50,
                  initialPictureUrl:
                      applicant['profilePictureUrl'] ??
                      resume['profilePictureUrl'],
                ),
                const SizedBox(height: 24),
                Text(
                  applicant['seekerName'] ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  applicant['seekerEmail'] ?? '',
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 48),
                const Text(
                  'CORE SKILLS',
                  style: TextStyle(
                    color: Color(0xFF6366F1),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (List<String>.from(resume['skills'] ?? []))
                      .map(
                        (s) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            s,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModernSection(
                    'PROFESSIONAL EXPERIENCE',
                    resume['experience'] ?? 'N/A',
                  ),
                  const SizedBox(height: 48),
                  _buildModernSection(
                    'EDUCATION',
                    resume['education'] ?? 'N/A',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          content,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 15,
            height: 1.8,
          ),
        ),
      ],
    );
  }
}
