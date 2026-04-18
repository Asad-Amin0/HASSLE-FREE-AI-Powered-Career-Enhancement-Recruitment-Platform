import 'package:flutter/material.dart';
import '../services/job_service.dart';
import '../widgets/resume_thematic_viewer.dart';
import '../widgets/candidate_avatar.dart';
import 'post_job_screen.dart';

class EmployerDashboardScreen extends StatelessWidget {
  const EmployerDashboardScreen({super.key});

  void _showPostJobDialog(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 1100;

    if (isMobile) {
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => const PostJobScreen(),
        ),
      );
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(16),
          child: PostJobScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 1100;
    final jobService = JobService();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 32,
        vertical: isMobile ? 28 : 40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, isMobile),
          const SizedBox(height: 32),

          StreamBuilder<Map<String, int>>(
            stream: jobService.getEmployerStatsStream(),
            builder: (context, snapshot) {
              final stats =
                  snapshot.data ?? {'activeJobs': 0, 'totalApplicants': 0};
              return _buildStatsRow(isMobile, stats);
            },
          ),

          const SizedBox(height: 32),

          const Text(
            'Your Job Postings',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),

          StreamBuilder<List<Map<String, dynamic>>>(
            stream: jobService.getEmployerJobsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                );
              }
              if (snapshot.hasError) {
                return const Text(
                  'Error loading jobs',
                  style: TextStyle(color: Colors.red),
                );
              }
              final jobs = snapshot.data ?? [];
              if (jobs.isEmpty) {
                return _buildEmptyState(context);
              }
              return _buildJobsList(isMobile, jobs);
            },
          ),

          const SizedBox(height: 32),
          const Text(
            'Your Top Applicants',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: jobService.getEmployerJobsStream(),
            builder: (context, jobSnapshot) {
              final jobs = jobSnapshot.data ?? [];
              final List<String> employerSkills = jobs
                  .expand((j) => List<String>.from(j['requiredSkills'] ?? []))
                  .toSet()
                  .toList();

              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: jobService.getEmployerAllApplicantsStream(),
                builder: (context, applicantSnapshot) {
                  final allApplicants = applicantSnapshot.data ?? [];

                  // Matching logic: compare applicant skills with job requirements
                  List<Map<String, dynamic>> matchedCandidates = allApplicants
                      .map((a) {
                        final resumeData = a['resumeData'] ?? {};
                        final skills = List<String>.from(
                          resumeData['skills'] ?? [],
                        );

                        int matches = 0;
                        for (var s in skills) {
                          if (employerSkills.any(
                            (es) => es.toLowerCase() == s.toLowerCase(),
                          )) {
                            matches++;
                          }
                        }
                        double score = skills.isEmpty
                            ? 0
                            : (matches / employerSkills.length.clamp(1, 100)) *
                                  100;

                        return {
                          ...a,
                          'name': a['seekerName'],
                          'jobTitle': a['jobTitle'] ?? 'Unknown Position',
                          'category': resumeData['category'] ?? 'Professional',
                          'skills': skills,
                          'matchScore': score.toStringAsFixed(0),
                          'profilePictureUrl': resumeData['profilePictureUrl'],
                          'seekerId': a['seekerId'],
                        };
                      })
                      .toList();

                  matchedCandidates.sort(
                    (a, b) => double.parse(
                      b['matchScore'],
                    ).compareTo(double.parse(a['matchScore'])),
                  );

                  if (matchedCandidates.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Center(
                        child: Text(
                          'No applicants yet',
                          style: TextStyle(color: Colors.white60),
                        ),
                      ),
                    );
                  }
                  return _buildCandidateTable(
                    context,
                    isMobile,
                    matchedCandidates,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.business_center_outlined,
            size: 64,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No job postings yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Post your first job to start receiving candidates',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildJobsList(bool isMobile, List<Map<String, dynamic>> jobs) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        final job = jobs[index];
        final skills = List<String>.from(job['requiredSkills'] ?? []);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job['title'] ?? 'Unknown Title',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${job['type']} • ${job['location']} • ${job['experienceLevel']}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: job['status'] == 'active'
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      (job['status']?.toString() ?? 'active').toUpperCase(),
                      style: TextStyle(
                        color: job['status'] == 'active'
                            ? Colors.green
                            : Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                job['description'] ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ...skills
                      .take(3)
                      .map(
                        (s) => Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            s,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                  if (skills.length > 3)
                    Text(
                      '+${skills.length - 3} more',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  const Spacer(),
                  Text(
                    job['salaryRange'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recruitment Overview',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          Text(
            'Manage your job postings and top talent',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showPostJobDialog(context),
              icon: const Icon(Icons.add, color: Colors.white, size: 20),
              label: const Text(
                'Post a New Job',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recruitment Overview',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
              Text(
                'Manage your job postings and top talent',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _showPostJobDialog(context),
          icon: const Icon(Icons.add, color: Colors.white, size: 20),
          label: const Text(
            'Post a New Job',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(bool isMobile, Map<String, int> stats) {
    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              _buildStatCard(
                'Active Jobs',
                stats['activeJobs'].toString(),
                Icons.business_center,
                Colors.blue,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                'Total Applicants',
                stats['totalApplicants'].toString(),
                Icons.people,
                Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatCard(
                'Avg. Match',
                '84%',
                Icons.auto_awesome,
                Colors.green,
              ),
            ],
          ),
        ],
      );
    }
    return Row(
      children: [
        _buildStatCard(
          'Active Jobs',
          stats['activeJobs'].toString(),
          Icons.business_center,
          Colors.blue,
        ),
        const SizedBox(width: 20),
        _buildStatCard(
          'Total Applicants',
          stats['totalApplicants'].toString(),
          Icons.people,
          Colors.purple,
        ),
        const SizedBox(width: 20),
        _buildStatCard(
          'Average Match',
          '84%',
          Icons.auto_awesome,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 20),
            Text(
              value,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -1,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCandidateTable(
    BuildContext context,
    bool isMobile,
    List<Map<String, dynamic>> candidates,
  ) {
    if (isMobile) {
      return Column(
        children: candidates.take(5).map((c) {
          final skills = List<String>.from(c['skills'] ?? []);
          final score = '${c['matchScore']}%';
          final name = c['name'] ?? 'Candidate';
          final role = c['jobTitle'] ?? 'N/A';
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CandidateAvatar(
                      seekerId: c['seekerId'] ?? '',
                      seekerName: name,
                      radius: 20,
                      initialPictureUrl: c['profilePictureUrl'],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Applied for: $role',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        score,
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: skills
                      .take(4)
                      .map(
                        (s) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            s,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final applicantFormat = {
                        'seekerName': c['seekerName'] ?? name,
                        'seekerEmail':
                            c['seekerEmail'] ?? 'Contact information hidden',
                        'resumeData': c['resumeData'] ?? {},
                        'profilePictureUrl': c['profilePictureUrl'],
                        'seekerId': c['seekerId'],
                      };
                      showDialog(
                        context: context,
                        builder: (context) => ResumeThematicViewer(
                          applicant: applicantFormat,
                          theme: 'Modern',
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(
                        0xFF6366F1,
                      ).withValues(alpha: 0.2),
                      foregroundColor: const Color(0xFF818CF8),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'View Profile',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    // Web – full DataTable
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                columnSpacing: 40,
                horizontalMargin: 24,
                headingRowHeight: 64,
                dataRowMinHeight: 76,
                dataRowMaxHeight: 76,
                columns: [
                  _buildTableHeader('Candidate Name'),
                  _buildTableHeader('Applied For'),
                  _buildTableHeader('Skills'),
                  _buildTableHeader('Match'),
                  _buildTableHeader('Action'),
                ],
                rows: candidates.take(5).map((c) {
                  final skills = List<String>.from(c['skills'] ?? []);
                  return _buildCandidateRow(
                    context,
                    c['name'] ?? 'Candidate',
                    c['jobTitle'] ?? 'N/A',
                    skills,
                    '${c['matchScore']}%',
                    c,
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  DataColumn _buildTableHeader(String label) {
    return DataColumn(
      label: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    );
  }

  DataRow _buildCandidateRow(
    BuildContext context,
    String name,
    String role,
    List<String> skills,
    String score,
    Map<String, dynamic> candidate,
  ) {
    return DataRow(
      cells: [
        DataCell(
          Row(
            children: [
              CandidateAvatar(
                seekerId: candidate['seekerId'] ?? '',
                seekerName: name,
                radius: 18,
                initialPictureUrl: candidate['profilePictureUrl'],
              ),
              const SizedBox(width: 14),
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        DataCell(
          Text(
            role,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 15,
            ),
          ),
        ),
        DataCell(
          Row(
            children: skills
                .take(3)
                .map(
                  (s) => Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      s,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              score,
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        DataCell(
          TextButton(
            onPressed: () {
              // Correctly pass the nested resumeData instead of the entire document as resumeData
              final applicantFormat = {
                'seekerName': candidate['seekerName'] ?? name,
                'seekerEmail':
                    candidate['seekerEmail'] ?? 'Contact information hidden',
                'resumeData': candidate['resumeData'] ?? {},
                'profilePictureUrl': candidate['profilePictureUrl'],
                'seekerId': candidate['seekerId'],
              };

              showDialog(
                context: context,
                builder: (context) => ResumeThematicViewer(
                  applicant: applicantFormat,
                  theme: 'Modern',
                ),
              );
            },
            child: const Text(
              'View Profile',
              style: TextStyle(
                color: Color(0xFF818CF8),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
