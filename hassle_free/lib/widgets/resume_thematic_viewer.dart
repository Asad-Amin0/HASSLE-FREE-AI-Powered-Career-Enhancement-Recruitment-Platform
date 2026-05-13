import 'package:flutter/material.dart';
import 'candidate_avatar.dart';

class ResumeThematicViewer extends StatelessWidget {
  final Map<String, dynamic> applicant;
  final String theme;
  final Color primaryColor;

  const ResumeThematicViewer({
    super.key,
    required this.applicant,
    required this.theme,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final resume = applicant['resumeData'] ?? {};

    switch (theme) {
      case 'Professional':
        return _buildProfessionalTheme(context, resume);
      case 'Creative':
        return _buildCreativeTheme(context, resume);
      case 'ATS-Optimized':
        return _buildATSTheme(context, resume);
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
      body: Row(
        children: [
          Container(
            width: 250,
            color: primaryColor,
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const SizedBox(height: 40),
                CandidateAvatar(
                  seekerId: applicant['seekerId'] ?? '',
                  seekerName: applicant['seekerName'] ?? '?',
                  radius: 60,
                  initialPictureUrl: applicant['profilePictureUrl'] ?? resume['profilePictureUrl'],
                ),
                const SizedBox(height: 24),
                Text(
                  applicant['seekerName']?.toUpperCase() ?? 'NAME',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                Text(
                  applicant['seekerEmail'] ?? '',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                _buildSidebarSection('DETAILS', resume),
                const SizedBox(height: 30),
                _buildSidebarSection('SKILLS', resume),
                const SizedBox(height: 30),
                _buildSidebarSection('CERTIFICATES', resume),
                const SizedBox(height: 30),
                _buildBadgesSidebar(resume),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildSectionTitle('PROFILE', primaryColor),
                   Text(resume['summary'] ?? 'N/A', style: const TextStyle(color: Colors.black87, height: 1.6)),
                   const SizedBox(height: 40),
                   _buildSectionTitle('EXPERIENCE', primaryColor),
                   Text(resume['experience'] ?? 'N/A', style: const TextStyle(color: Colors.black87, height: 1.6)),
                   const SizedBox(height: 40),
                   _buildSectionTitle('EDUCATION', primaryColor),
                   Text(resume['education'] ?? 'N/A', style: const TextStyle(color: Colors.black87, height: 1.6)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarSection(String title, Map<String, dynamic> resume) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 14)),
        const Divider(color: Colors.white24, thickness: 1, height: 20),
        if (title == 'SKILLS')
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (List<String>.from(resume['skills'] ?? [])).map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
              child: Text(s, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            )).toList(),
          )
        else if (title == 'CERTIFICATES')
           Text(
            (List<String>.from(resume['certificates'] ?? [])).join(', '),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          )
        else
           Text(applicant['seekerEmail'] ?? 'N/A', style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildBadgesSidebar(Map<String, dynamic> resume) {
    final badges = List<String>.from(resume['badges'] ?? []);
    if (badges.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('BADGES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 14)),
        const Divider(color: Colors.white24, thickness: 1, height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: badges.map((b) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            ),
            child: Text(b, style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Container(height: 2, width: 40, color: color),
        const SizedBox(height: 16),
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
            backgroundColor: primaryColor,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                applicant['seekerName'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
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
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 32),
                  _buildCreativeCard(
                    'Certificates',
                    (List<String>.from(resume['certificates'] ?? [])).join('\n'),
                    Colors.purpleAccent,
                  ),
                  const SizedBox(height: 20),
                  _buildBadgesCreative(resume),
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

  Widget _buildBadgesCreative(Map<String, dynamic> resume) {
    final badges = List<String>.from(resume['badges'] ?? []);
    if (badges.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Achievements',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: badges.map((b) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars, color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                Text(b, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
              ],
            ),
          )).toList(),
        ),
      ],
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
                Text(
                  'CORE SKILLS',
                  style: TextStyle(
                    color: primaryColor,
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
                const SizedBox(height: 32),
                Text(
                  'CERTIFICATES',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 16),
                ... (List<String>.from(resume['certificates'] ?? [])).map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    '• $c',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                )),
                const SizedBox(height: 32),
                _buildBadgesModern(resume),
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
          height: 4,
          width: 40,
          decoration: BoxDecoration(
            color: primaryColor,
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

  Widget _buildBadgesModern(Map<String, dynamic> resume) {
    final badges = List<String>.from(resume['badges'] ?? []);
    if (badges.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AWARDS',
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: badges.map((b) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Text(b, style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
          )).toList(),
        ),
      ],
    );
  }

  // ─── ATS Optimized Theme ──────────────────────────────────────────────────
  Widget _buildATSTheme(BuildContext context, Map<String, dynamic> resume) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: const Text('ATS Optimized Resume', style: TextStyle(color: Colors.black)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(applicant['seekerName'] ?? '', style: TextStyle(color: primaryColor, fontSize: 24, fontWeight: FontWeight.bold)),
            Text(applicant['seekerEmail'] ?? '', style: const TextStyle(color: Colors.black, fontSize: 14)),
            const SizedBox(height: 24),
            _buildATSViewerSection('EXPERIENCE', resume['experience'] ?? 'N/A'),
            _buildATSViewerSection('EDUCATION', resume['education'] ?? 'N/A'),
            _buildATSViewerSection('CERTIFICATES', (List<String>.from(resume['certificates'] ?? [])).join(', ')),
            _buildATSViewerSection('SKILLS', (List<String>.from(resume['skills'] ?? [])).join(', ')),
            if ((List<String>.from(resume['badges'] ?? [])).isNotEmpty)
              _buildATSViewerSection('VERIFIED BADGES', (List<String>.from(resume['badges'] ?? [])).join(' | ')),
          ],
        ),
      ),
    );
  }

  Widget _buildATSViewerSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
        const Divider(color: Colors.black, thickness: 1.5),
        Text(content, style: const TextStyle(color: Colors.black, fontSize: 14, height: 1.4)),
        const SizedBox(height: 24),
      ],
    );
  }
}


