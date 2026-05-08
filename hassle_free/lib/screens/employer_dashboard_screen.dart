import 'package:flutter/material.dart';
import '../services/job_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';



import '../widgets/resume_thematic_viewer.dart';
import '../widgets/candidate_avatar.dart';
import 'post_job_screen.dart';
import '../widgets/hoverable_card.dart';
import '../utils/pdf_generator.dart';
import '../features/mock_interview/screens/interview_results_screen.dart';
import '../features/mock_interview/models/interview_session.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';


class EmployerDashboardScreen extends StatefulWidget {
  final bool isDarkMode;
  const EmployerDashboardScreen({super.key, this.isDarkMode = true});

  @override
  State<EmployerDashboardScreen> createState() => _EmployerDashboardScreenState();
}

class _EmployerDashboardScreenState extends State<EmployerDashboardScreen> {
  final Set<String> _selectedApplicantIds = {};

  Color get _textColor => widget.isDarkMode ? Colors.white : Colors.black87;
  Color get _mutedText => widget.isDarkMode ? Colors.white60 : Colors.black54;
  Color get _cardBg => widget.isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.white;
  Color get _cardBorder => widget.isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade300;
  bool get isDarkMode => widget.isDarkMode;
  late final JobService _jobService;
  late final Stream<Map<String, int>> _statsStream;
  late final Stream<List<Map<String, dynamic>>> _jobsStream;
  late final Stream<List<Map<String, dynamic>>> _applicantsStream;

  @override
  void initState() {
    super.initState();
    _jobService = JobService();
    _statsStream = _jobService.getEmployerStatsStream();
    _jobsStream = _jobService.getEmployerJobsStream();
    _applicantsStream = _jobService.getEmployerAllApplicantsStream();
  }

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

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        isMobile ? 20 : 32,
        isMobile ? 16 : 8, // Reduced top padding
        isMobile ? 20 : 32,
        isMobile ? 28 : 40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, isMobile),
          const SizedBox(height: 32),
          _buildSectionHeader('Your Activity'),
          const SizedBox(height: 16),

          StreamBuilder<Map<String, int>>(
            stream: _statsStream,
            builder: (context, snapshot) {
              final stats =
                  snapshot.data ?? {'activeJobs': 0, 'totalApplicants': 0};
              
              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: _applicantsStream,
                builder: (context, applicantSnapshot) {
                  final applicants = applicantSnapshot.data ?? [];
                  return StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _jobsStream,
                    builder: (context, jobSnapshot) {
                      final jobs = jobSnapshot.data ?? [];
                      
                      double totalScore = 0;
                      int count = 0;
                      
                      for (var a in applicants) {
                        final resumeData = a['resumeData'] ?? {};
                        final skills = List<String>.from(resumeData['skills'] ?? []);
                        final jobId = a['jobId'];
                        final job = jobs.firstWhere((j) => j['id'] == jobId, orElse: () => {});
                        final targetSkills = List<String>.from(job['requiredSkills'] ?? []);
                        
                        if (targetSkills.isNotEmpty) {
                          int matches = 0;
                          for (var target in targetSkills) {
                            if (skills.any((s) => s.toLowerCase().contains(target.toLowerCase()) || 
                                                 target.toLowerCase().contains(s.toLowerCase()))) {
                              matches++;
                            }
                          }
                          totalScore += (matches / targetSkills.length) * 100;
                          count++;
                        }
                      }
                      
                      final avgMatch = count == 0 ? 0 : (totalScore / count).round();
                      return _buildStatsRow(isMobile, stats, avgMatch: avgMatch);
                    },
                  );
                },
              );
            },
          ),

          const SizedBox(height: 32),

          Row(
            children: [
              const Icon(Icons.work_outline, color: Color(0xFF6366F1), size: 28),
              const SizedBox(width: 12),
              Text(
                'Your Job Postings',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _jobsStream,
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
              final allJobs = snapshot.data ?? [];
              if (allJobs.isEmpty) {
                return _buildEmptyState(context);
              }
              // Only show the latest job
              final latestJob = [allJobs.first];
              return _buildJobsList(isMobile, latestJob);
            },
          ),

          const SizedBox(height: 32),
          Text(
            'Your Top Applicants',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _textColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _jobsStream,
            builder: (context, jobSnapshot) {
              final jobs = jobSnapshot.data ?? [];

              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: _applicantsStream,
                builder: (context, applicantSnapshot) {
                  final allApplicants = applicantSnapshot.data ?? [];

                  // Matching logic: compare applicant skills with job requirements
                  List<Map<String, dynamic>> matchedCandidates = allApplicants
                      .map((a) {
                        final resumeData = a['resumeData'] ?? {};
                        final skills = List<String>.from(
                          resumeData['skills'] ?? [],
                        );

                        final jobId = a['jobId'];
                        final job = jobs.firstWhere((j) => j['id'] == jobId, orElse: () => {});
                        final targetSkills = List<String>.from(job['requiredSkills'] ?? []);

                        int matches = 0;
                        for (var target in targetSkills) {
                          if (skills.any(
                            (s) => s.toLowerCase().contains(target.toLowerCase()) || 
                                   target.toLowerCase().contains(s.toLowerCase()),
                          )) {
                            matches++;
                          }
                        }
                        double score = targetSkills.isEmpty
                            ? 100
                            : (matches / targetSkills.length.clamp(1, 100)) *
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


                  matchedCandidates.sort((a, b) {
                    final aTime = (a['appliedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                    final bTime = (b['appliedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                    return bTime.compareTo(aTime); // Newest first
                  });



                  if (matchedCandidates.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: _cardBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: _cardBorder),
                      ),
                      child: Center(
                        child: Text(
                          'No applicants yet',
                          style: TextStyle(color: _mutedText),
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
        color: _cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: [
          Icon(
            Icons.business_center_outlined,
            size: 64,
            color: _mutedText.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No job postings yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Post your first job to start receiving candidates',
            style: TextStyle(color: _mutedText),
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

        return InkWell(
          onTap: () => _viewApplicantsForJob(context, job),
          borderRadius: BorderRadius.circular(20),
          child: HoverableCard(
            child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _cardBorder),
              boxShadow: isDarkMode ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
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
                          job['title'] ?? 'Job Title',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${job['location'] ?? 'Remote'} • ${job['type'] ?? 'Full-time'}',
                          style: TextStyle(
                            color: _mutedText,
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
                  color: _textColor.withValues(alpha: 0.8),
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
                            color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            s,
                            style: TextStyle(
                              fontSize: 12,
                              color: _mutedText,
                            ),
                          ),
                        ),
                      ),
                  if (skills.length > 3)
                    Text(
                      '+${skills.length - 3} more',
                      style: TextStyle(
                        color: _mutedText,
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
        ),
      ),
    );
    },
  );
}

  void _deleteApplicant(String applicationId) async {
    if (applicationId.isEmpty) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text('Remove Applicant', style: TextStyle(color: _textColor)),
        content: Text('Are you sure you want to remove this applicant?', style: TextStyle(color: _mutedText)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await JobService().deleteApplication(applicationId);
    }
  }

  void _viewApplicantsForJob(BuildContext context, Map<String, dynamic> job) {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _mutedText.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Applicants for',
                          style: TextStyle(color: _mutedText, fontSize: 14),
                        ),
                        Text(
                          job['title'] ?? 'Job Post',
                          style: TextStyle(
                            color: _textColor,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: _textColor),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: JobService().getJobApplicantsStream(job['id']),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final applicants = snapshot.data ?? [];
                  if (applicants.isEmpty) {
                    return Center(
                      child: Text(
                        'No applicants yet for this position',
                        style: TextStyle(color: _mutedText),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: applicants.length,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemBuilder: (context, index) {
                      final applicant = applicants[index];
                      // Prepare data for ResumeThematicViewer
                      final resume = applicant['resumeData'] ?? {};
                      final Map<String, dynamic> applicantFormat = {
                        'seekerId': applicant['seekerId'] ?? '',
                        'seekerName': applicant['seekerName'] ?? 'Candidate',
                        'seekerEmail': applicant['seekerEmail'] ?? 'N/A',
                        'profilePictureUrl': applicant['profilePictureUrl'],
                        'resumeData': Map<String, dynamic>.from(resume is Map ? resume : {}),
                      };

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CandidateAvatar(
                                  seekerId: applicant['seekerId'] ?? '',
                                  seekerName: applicant['seekerName'] ?? '?',
                                  radius: 24,
                                  initialPictureUrl: applicant['profilePictureUrl'],
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        applicant['seekerName'] ?? 'Anonymous',
                                        style: TextStyle(
                                          color: _textColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        applicant['seekerEmail'] ?? '',
                                        style: TextStyle(color: _mutedText, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _deleteApplicant(applicant['applicationId'] ?? ''),
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    alignment: WrapAlignment.start,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => showDialog(
                                          context: context,
                                          builder: (context) => ResumeThematicViewer(
                                            applicant: applicantFormat,
                                            theme: 'Modern',
                                            primaryColor: const Color(0xFF6366F1),
                                          ),
                                        ),
                                        icon: const Icon(Icons.description_outlined, size: 18),
                                        label: const Text('View Profile'),
                                      ),
                                      if (applicant['interviewResult'] != null) ...[
                                        TextButton.icon(
                                          onPressed: () => _showInterviewResults(context, applicant),
                                          icon: const Icon(Icons.analytics_outlined, size: 18, color: Colors.orange),
                                          label: const Text('Results', style: TextStyle(color: Colors.orange)),
                                        ),
                                        if (applicant['interviewResult']['videoUrl'] != null)
                                          TextButton.icon(
                                            onPressed: () => _showInterviewVideo(
                                              context,
                                              applicant['interviewResult']['videoUrl'],
                                              applicant['seekerName'],
                                            ),
                                            icon: const Icon(Icons.play_circle_outline, size: 18, color: Colors.blueAccent),
                                            label: const Text('Watch', style: TextStyle(color: Colors.blueAccent)),
                                          ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildHeader(BuildContext context, bool isMobile) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recruitment Overview',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _textColor,
              letterSpacing: -1,
            ),
          ),
          Text(
            'Manage your job postings and top talent',
            style: TextStyle(color: _mutedText),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showPostJobDialog(context),
              icon: const Icon(Icons.post_add, color: Colors.white, size: 20),
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
              Text(
                'Recruitment Overview',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                  letterSpacing: -1,
                ),
              ),
              Text(
                'Manage your job postings and top talent',
                style: TextStyle(color: _mutedText),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _showPostJobDialog(context),
          icon: const Icon(Icons.post_add, color: Colors.white, size: 20),
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

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: _textColor,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildStatsRow(bool isMobile, Map<String, int> stats, {int avgMatch = 0}) {
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
                _generateDynamicTrend(stats['activeJobs']!.toDouble(), 8),
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                'Total Applicants',
                stats['totalApplicants'].toString(),
                Icons.people,
                Colors.purple,
                _generateDynamicTrend(stats['totalApplicants']!.toDouble(), 8),
                isBarChart: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatCard(
                'Avg. Match',
                '$avgMatch%',
                Icons.auto_awesome,
                Colors.green,
                _generateDynamicTrend(avgMatch.toDouble(), 8),
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
          _generateDynamicTrend(stats['activeJobs']!.toDouble(), 8),
          isBarChart: false,
        ),
        const SizedBox(width: 20),
        _buildStatCard(
          'Total Applicants',
          stats['totalApplicants'].toString(),
          Icons.people,
          Colors.purple,
          _generateDynamicTrend(stats['totalApplicants']!.toDouble(), 8),
          isBarChart: true,
        ),
        const SizedBox(width: 20),
        _buildStatCard(
          'Average Match',
          '$avgMatch%',
          Icons.auto_awesome,
          Colors.green,
          _generateDynamicTrend(avgMatch.toDouble(), 8),
          isBarChart: false,
        ),
      ],
    );
  }

  List<double> _generateDynamicTrend(double currentValue, int points) {
    final List<double> trend = [];
    // Always trend upwards to the current value
    for (int i = 0; i < points; i++) {
      double factor = (i + 1) / points;
      // Progressive growth towards currentValue
      double val = currentValue * factor;
      trend.add(val);
    }
    return trend;
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    List<double> dataPoints, {
    bool isBarChart = false,
  }) {
    return Expanded(
      child: HoverableCard(
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _cardBorder),
            boxShadow: isDarkMode ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Background Graphical Element
                Positioned(
                  bottom: -10,
                  left: 0,
                  right: 0,
                  height: 80,
                  child: CustomPaint(
                    painter: isBarChart
                        ? _BarChartPainter(dataPoints, color.withValues(alpha: 0.2))
                        : _MiniChartPainter(dataPoints, color.withValues(alpha: 0.3)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(icon, color: color, size: 20),
                          ),
                          Icon(Icons.trending_up, color: color.withValues(alpha: 0.5), size: 16),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                          letterSpacing: -1,
                        ),
                      ),
                      Text(
                        title.toUpperCase(),
                        style: TextStyle(
                          color: _mutedText,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBulkActions(List<Map<String, dynamic>> candidates) {
    bool allSelected = candidates.isNotEmpty &&
        candidates.every((c) => _selectedApplicantIds.contains(c['seekerId']));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          Checkbox(
            value: allSelected,
            activeColor: const Color(0xFF6366F1),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedApplicantIds.addAll(
                    candidates.map((c) => c['seekerId'] as String),
                  );
                } else {
                  _selectedApplicantIds.clear();
                }
              });
            },
          ),
          Text(
            'Select All Applicants',
            style: TextStyle(
              color: _textColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          if (_selectedApplicantIds.isNotEmpty)
            ElevatedButton.icon(
            onPressed: () => _handleBulkDownload(candidates),
              icon: const Icon(Icons.download_for_offline, size: 18),
              label: Text('Download (${_selectedApplicantIds.length})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
        ],
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
        children: [
          _buildBulkActions(candidates),
          ...candidates.take(5).map((c) {
            final skills = List<String>.from(c['skills'] ?? []);
            final score = '${c['matchScore']}%';
            final name = c['name'] ?? 'Candidate';
            final role = c['jobTitle'] ?? 'N/A';
            final isSelected = _selectedApplicantIds.contains(c['seekerId']);

            return HoverableCard(
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF6366F1).withValues(alpha: 0.5)
                        : _cardBorder,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: isSelected,
                          activeColor: const Color(0xFF6366F1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedApplicantIds.add(c['seekerId']);
                              } else {
                                _selectedApplicantIds.remove(c['seekerId']);
                              }
                            });
                          },
                        ),
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
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _textColor,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Applied for: $role',
                            style: TextStyle(
                              color: _mutedText,
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
                            color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            s,
                            style: TextStyle(
                              fontSize: 12,
                              color: _mutedText,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
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
                              primaryColor: const Color(0xFF6366F1),
                            ),
                          );
                        },
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const Text('View Profile'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                          foregroundColor: const Color(0xFF818CF8),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _handleDownload(c),
                        icon: const Icon(Icons.file_download_outlined, size: 18),
                        label: const Text('Resume'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                          foregroundColor: const Color(0xFF818CF8),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                          side: BorderSide(color: const Color(0xFF4F46E5).withValues(alpha: 0.2)),
                        ),
                      ),
                    ),
                    if (c['hasInterview'] == true && c['videoUrl'] != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showInterviewVideo(context, c['videoUrl'], c['seekerName'] ?? c['name']),

                          icon: const Icon(Icons.play_circle_outline, size: 18),
                          label: const Text('Watch'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.withValues(alpha: 0.1),
                            foregroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                            side: BorderSide(color: Colors.orange.withValues(alpha: 0.2)),
                          ),
                        ),
                      ),
                    ],
                    if (c['interviewResult'] != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showInterviewResults(context, c),
                          icon: const Icon(Icons.analytics_outlined, size: 18),
                          label: const Text('Results'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.withValues(alpha: 0.1),
                            foregroundColor: Colors.teal,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                            side: BorderSide(color: Colors.teal.withValues(alpha: 0.2)),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(width: 10),
                    IconButton(
                      onPressed: () => _handleDeleteApplication(c['id']),
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      tooltip: 'Delete Application',
                    ),
                  ],
                ),


              ],
            ),
          ),
          );
        }),
      ],
    );
  }

    // Web – full DataTable
    return Column(
      children: [
        _buildBulkActions(candidates),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _cardBorder),
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
                      _buildTableHeader('Select'),
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
        ),
      ],
    );
  }

  DataColumn _buildTableHeader(String label) {
    return DataColumn(
      label: Text(
        label,
        style: TextStyle(
          color: _mutedText,
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
    final isSelected = _selectedApplicantIds.contains(candidate['seekerId']);
    return DataRow(
      selected: isSelected,
      cells: [
        DataCell(
          Checkbox(
            value: isSelected,
            activeColor: const Color(0xFF6366F1),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedApplicantIds.add(candidate['seekerId']);
                } else {
                  _selectedApplicantIds.remove(candidate['seekerId']);
                }
              });
            },
          ),
        ),
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _textColor,
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
              color: _textColor.withValues(alpha: 0.8),
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
                      color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      s,
                      style: TextStyle(
                        fontSize: 11,
                        color: _mutedText,
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  onPressed: () {
                    final rawResumeData = candidate['resumeData'] ?? {};
                    // Ensure we have a proper Map<String, dynamic> to avoid type errors on Web
                    final Map<String, dynamic> resumeData = Map<String, dynamic>.from(rawResumeData is Map ? rawResumeData : {});
                    
                    final Map<String, dynamic> applicantFormat = {
                      'seekerId': candidate['seekerId'] ?? '',
                      'seekerName': candidate['seekerName'] ?? candidate['name'] ?? 'Candidate',
                      'seekerEmail': candidate['seekerEmail'] ?? 'N/A',
                      'profilePictureUrl': candidate['profilePictureUrl'],
                      'resumeData': resumeData,
                    };

                    showDialog(
                      context: context,
                      builder: (context) => ResumeThematicViewer(
                        applicant: applicantFormat,
                        theme: 'Modern',
                        primaryColor: const Color(0xFF6366F1),
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
                TextButton.icon(
                  onPressed: () => _handleDownload(candidate),
                  icon: const Icon(Icons.file_download_outlined, size: 18, color: Color(0xFF818CF8)),
                  label: const Text(
                    'Resume',
                    style: TextStyle(
                      color: Color(0xFF818CF8),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (candidate['hasInterview'] == true && candidate['videoUrl'] != null)
                  TextButton.icon(
                    onPressed: () => _showInterviewVideo(context, candidate['videoUrl'], candidate['seekerName'] ?? candidate['name']),
                    icon: const Icon(Icons.play_circle_outline, size: 18, color: Colors.orange),
                    label: const Text(
                      'Watch',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (candidate['interviewResult'] != null)
                  TextButton.icon(
                    onPressed: () => _showInterviewResults(context, candidate),
                    icon: const Icon(Icons.analytics_outlined, size: 18, color: Colors.teal),
                    label: const Text(
                      'Results',
                      style: TextStyle(
                        color: Colors.teal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: () => _handleDeleteApplication(candidate['id']),
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  tooltip: 'Delete Application',
                ),
              ],
            ),
          ),
        ),
      ],
    );

  }


  void _handleDownload(Map<String, dynamic> candidate) async {
    final name = candidate['name'] ?? 'Candidate';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Text('Generating PDF for $name...'),
          ],
        ),
        backgroundColor: const Color(0xFF6366F1),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      await PdfGenerator.generateAndDownloadResume(
        name: name,
        jobTitle: candidate['jobTitle'] ?? 'N/A',
        email: candidate['seekerEmail'] ?? 'N/A',
        resumeData: candidate['resumeData'] ?? {},
        seekerId: candidate['seekerId'],
      );
    } catch (e) {
      debugPrint('PDF generation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate PDF. Please restart the app.')),
        );
      }
    }
  }

  Future<void> _handleDeleteApplication(String? applicationId) async {
    if (applicationId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,

        title: Text('Delete Application?', style: TextStyle(color: _textColor)),
        content: Text('Are you sure you want to remove this candidate?', style: TextStyle(color: _mutedText)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _jobService.deleteApplication(applicationId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application removed')),
        );
      }
    }
  }

  void _handleBulkDownload(List<Map<String, dynamic>> candidates) async {
    final selectedCandidates = candidates.where((c) => _selectedApplicantIds.contains(c['seekerId'])).toList();
    
    if (selectedCandidates.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting bulk download of ${selectedCandidates.length} resumes...'),
        backgroundColor: const Color(0xFF6366F1),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      int count = 0;
      // Trigger individual downloads for each candidate
      for (var candidate in selectedCandidates) {
        count++;
        final name = candidate['seekerName'] ?? candidate['name'] ?? 'Candidate';
        
        // Update snackbar to show progress
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloading ($count/${selectedCandidates.length}): $name'),
              backgroundColor: const Color(0xFF6366F1),
              duration: const Duration(milliseconds: 1500),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        final resumeData = candidate['resumeData'] ?? {};
        await PdfGenerator.generateAndDownloadResume(
          name: name,
          jobTitle: candidate['jobTitle'] ?? 'N/A',
          email: candidate['seekerEmail'] ?? 'N/A',
          resumeData: resumeData,
          seekerId: candidate['seekerId'],
        );
        
        // Very long delay (3.0s) to bypass strict browser popup/print blockers
        // This is necessary on Web to ensure multiple files can be triggered sequentially.
        await Future.delayed(const Duration(milliseconds: 3000));
      }
      
      if (mounted) {
        setState(() {
          _selectedApplicantIds.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bulk download process completed. Please check your browser downloads.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Bulk PDF error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error during bulk download. Please check your browser popup settings.')),
        );
      }
    }
  }

  void _showInterviewResults(BuildContext context, Map<String, dynamic> candidate) {
    if (candidate['interviewResult'] == null) return;

    try {
      final session = InterviewSession.fromMap(candidate['interviewResult']);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InterviewResultsScreen(
            session: session,
            isDarkMode: widget.isDarkMode,
            onExit: () {
              // The results screen already handles the pop(),
              // so we don't need to do it again here.
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error loading interview results: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load interview results.')),
      );
    }
  }

  void _showInterviewVideo(BuildContext context, String videoUrl, String? seekerName) {
    showDialog(
      context: context,
      builder: (context) => _VideoPlayerDialog(videoUrl: videoUrl, seekerName: seekerName),
    );
  }
}

class _VideoPlayerDialog extends StatefulWidget {
  final String videoUrl;
  final String? seekerName;
  const _VideoPlayerDialog({required this.videoUrl, this.seekerName});

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    await _videoPlayerController.initialize();
    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      autoPlay: true,
      looping: false,
      aspectRatio: _videoPlayerController.value.aspectRatio,
      placeholder: Container(color: Colors.black),
      materialProgressColors: ChewieProgressColors(
        playedColor: const Color(0xFF6366F1),
        handleColor: const Color(0xFF6366F1),
        backgroundColor: Colors.grey,
        bufferedColor: Colors.white.withValues(alpha: 0.2),
      ),
    );
    setState(() {});
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Interview: ${widget.seekerName ?? "Seeker"}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            child: _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _videoPlayerController.value.aspectRatio,
                    child: Chewie(controller: _chewieController!),
                  )
                : const SizedBox(
                    height: 300,
                    child: Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))),
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _MiniChartPainter extends CustomPainter {
  final List<double> dataPoints;
  final Color color;

  _MiniChartPainter(this.dataPoints, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final path = Path();
    if (dataPoints.isEmpty) return;

    final double stepX = size.width / (dataPoints.length - 1);
    final double maxY = dataPoints.reduce((a, b) => a > b ? a : b);
    final double minY = dataPoints.reduce((a, b) => a < b ? a : b);
    final double range = maxY - minY == 0 ? 1 : maxY - minY;

    for (int i = 0; i < dataPoints.length; i++) {
      final double x = i * stepX;
      final double y = size.height - ((dataPoints[i] - minY) / range * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.4), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTRB(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BarChartPainter extends CustomPainter {
  final List<double> dataPoints;
  final Color color;

  _BarChartPainter(this.dataPoints, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    if (dataPoints.isEmpty) return;

    final double barWidth = size.width / (dataPoints.length * 1.5);
    final double spacing = barWidth / 2;
    final double maxY = dataPoints.reduce((a, b) => a > b ? a : b);

    for (int i = 0; i < dataPoints.length; i++) {
      final double x = i * (barWidth + spacing) + spacing;
      final double barHeight = (dataPoints[i] / maxY) * size.height;
      final double y = size.height - barHeight;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(4),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

