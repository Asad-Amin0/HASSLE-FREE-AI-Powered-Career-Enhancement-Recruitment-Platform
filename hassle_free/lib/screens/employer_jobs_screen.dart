import 'package:flutter/material.dart';
import '../services/job_service.dart';
import 'post_job_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/resume_thematic_viewer.dart';
import '../widgets/hoverable_card.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';


class EmployerJobsScreen extends StatelessWidget {
  final bool isDarkMode;
  const EmployerJobsScreen({super.key, this.isDarkMode = false});

  Color get _textColor => isDarkMode ? Colors.white : Colors.black87;
  Color get _mutedText => isDarkMode ? Colors.white60 : Colors.black54;
  Color get _cardBg => isDarkMode ? const Color(0xFF1E293B) : Colors.white;
  Color get _cardBorder =>
      isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300;
  Color get _bgColor =>
      isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

  void _deleteJob(BuildContext context, String jobId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text('Delete Job Posting', style: TextStyle(color: _textColor)),
        content: Text(
          'Are you sure you want to delete this job posting? This action cannot be undone.',
          style: TextStyle(color: _mutedText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await JobService().deleteJob(jobId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Job deleted successfully' : 'Failed to delete job',
            ),
            backgroundColor: success ? Colors.green : Colors.redAccent,
          ),
        );
      }
    }
  }

  void _editJob(BuildContext context, Map<String, dynamic>? job) {
    bool isMobile = MediaQuery.of(context).size.width < 1100;

    if (isMobile) {
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => PostJobScreen(job: job),
        ),
      );
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: PostJobScreen(job: job),
        ),
      );
    }
  }

  void _showPostJobDialog(BuildContext context) {
    _editJob(context, null);
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 1100;
    final jobService = JobService();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 32,
        isMobile ? 12 : 8, // Reduced top padding
        isMobile ? 16 : 32,
        isMobile ? 24 : 40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Job Postings',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'View and manage all active job listings',
                  style: TextStyle(color: _mutedText, fontSize: 14),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showPostJobDialog(context),
                    icon: const Icon(Icons.add, color: Colors.white, size: 20),
                    label: const Text(
                      'Post Job',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Job Postings',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                          letterSpacing: -1,
                        ),
                      ),
                      Text(
                        'View and manage all active job listings',
                        style: TextStyle(color: _mutedText),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showPostJobDialog(context),
                  icon: const Icon(Icons.add, color: Colors.white, size: 20),
                  label: const Text(
                    'Post Job',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 32),

          StreamBuilder<List<Map<String, dynamic>>>(
            stream: jobService.getEmployerJobsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                  ),
                );
              }
              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    'Error loading jobs',
                    style: TextStyle(color: Colors.red),
                  ),
                );
              }
              final jobs = snapshot.data ?? [];
              if (jobs.isEmpty) {
                return _buildEmptyState(context);
              }

              if (isMobile) {
                return _buildMobileJobsList(context, jobs);
              }
              return _buildWebJobsGrid(context, jobs);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(60),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.business_center,
            size: 80,
            color: _mutedText.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 24),
          Text(
            'No job postings yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Create your first job listing to start attracting top talent.',
            style: TextStyle(color: _mutedText, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileJobsList(
    BuildContext context,
    List<Map<String, dynamic>> jobs,
  ) {
    return Column(
      children: jobs
          .map((job) => _buildJobCard(context, job, isWebGrid: false))
          .toList(),
    );
  }

  Widget _buildWebJobsGrid(
    BuildContext context,
    List<Map<String, dynamic>> jobs,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        mainAxisExtent: 260,
      ),
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        return _buildJobCard(context, jobs[index], isWebGrid: true);
      },
    );
  }

  Widget _buildJobCard(
    BuildContext context,
    Map<String, dynamic> job, {
    bool isWebGrid = false,
  }) {
    final skills = List<String>.from(job['requiredSkills'] ?? []);

    bool isExpired = false;
    String expiryText = '';
    try {
      DateTime expiryDate;
      if (job['expiryDate'] != null) {
        final expiryTimestamp = job['expiryDate'] as Timestamp;
        expiryDate = expiryTimestamp.toDate();
      } else if (job['createdAt'] != null) {
        final createdTimestamp = job['createdAt'] as Timestamp;
        expiryDate = createdTimestamp.toDate().add(const Duration(days: 30));
      } else {
        expiryDate = DateTime.now().add(const Duration(days: 30));
      }

      if (expiryDate.isBefore(DateTime.now())) {
        isExpired = true;
      }

      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      expiryText =
          'Expires: ${expiryDate.day} ${months[expiryDate.month - 1]} ${expiryDate.year}, ${expiryDate.hour.toString().padLeft(2, '0')}:${expiryDate.minute.toString().padLeft(2, '0')}';
    } catch (_) {}

    final statusText = isExpired
        ? 'EXPIRED'
        : (job['status']?.toString() ?? 'active').toUpperCase();
    final statusColor = isExpired
        ? Colors.redAccent
        : (job['status'] == 'active' ? Colors.green : Colors.orange);

    return HoverableCard(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(isWebGrid ? 24 : 16),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _cardBorder),
          boxShadow: isDarkMode
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            color: Colors.orangeAccent,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              expiryText,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(
                                color: Colors.orangeAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isWebGrid ? 12 : 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: isWebGrid ? 12 : 11,
                        ),
                      ),
                    ),
                    SizedBox(width: isWebGrid ? 8 : 4),
                    IconButton(
                      padding: isWebGrid ? const EdgeInsets.all(8) : EdgeInsets.zero,
                      constraints: isWebGrid ? null : const BoxConstraints(),
                      onPressed: () => _editJob(context, job),
                      icon: Icon(
                        Icons.edit_outlined,
                        color: _mutedText,
                        size: isWebGrid ? 20 : 18,
                      ),
                      tooltip: 'Edit Job',
                    ),
                    SizedBox(width: isWebGrid ? 0 : 4),
                    IconButton(
                      padding: isWebGrid ? const EdgeInsets.all(8) : EdgeInsets.zero,
                      constraints: isWebGrid ? null : const BoxConstraints(),
                      onPressed: () => _deleteJob(context, job['id']),
                      icon: Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                        size: isWebGrid ? 20 : 18,
                      ),
                      tooltip: 'Delete Job',
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: isWebGrid ? 16 : 12),
            Row(
              children: [
                const Icon(
                  Icons.people_outline,
                  color: Colors.indigoAccent,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  '${job['applicants'] ?? 0} Applicants',
                  style: TextStyle(
                    color: _textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _viewApplicants(context, job),
                  child: const Text(
                    'View Applicants',
                    style: TextStyle(color: Color(0xFF6366F1)),
                  ),
                ),
              ],
            ),
            SizedBox(height: isWebGrid ? 16 : 12),
            Text(
              job['description'] ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _textColor.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
            isWebGrid ? const Spacer() : SizedBox(height: isWebGrid ? 16 : 12),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ...skills
                          .take(isWebGrid ? 3 : 2)
                          .map(
                            (s) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                s,
                                style: TextStyle(fontSize: 11, color: _mutedText),
                              ),
                            ),
                          ),
                      if (skills.length > (isWebGrid ? 3 : 2))
                        Text(
                          '+${skills.length - (isWebGrid ? 3 : 2)}',
                          style: TextStyle(color: _mutedText, fontSize: 11),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  job['salaryRange'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6366F1),
                    fontSize: isWebGrid ? 16 : 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _viewResume(
    BuildContext context,
    Map<String, dynamic> applicant,
    String theme,
    Color primaryColor,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: ResumeThematicViewer(
          applicant: applicant,
          theme: theme,
          primaryColor: primaryColor,
        ),
      ),
    );
  }

  void _viewApplicants(BuildContext context, Map<String, dynamic> job) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _bgColor,
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
                  Column(
                    children: [
                      Text(
                        'Applicants for',
                        style: TextStyle(color: _mutedText, fontSize: 14),
                      ),
                      Text(
                        job['title'],
                        style: TextStyle(
                          color: _textColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
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
                        'No applicants yet',
                        style: TextStyle(color: _mutedText),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: applicants.length,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemBuilder: (context, index) =>
                        _buildApplicantCard(context, applicants[index], job),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicantCard(
    BuildContext context,
    Map<String, dynamic> applicant,
    Map<String, dynamic> job,
  ) {
    final resume = applicant['resumeData'] ?? {};
    final skills = List<String>.from(resume['skills'] ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
                child: Text(
                  applicant['seekerName']?[0] ?? '?',
                  style: const TextStyle(
                    color: Color(0xFF6366F1),
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(
                    applicant['status'] ?? 'pending',
                  ).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  (applicant['status'] ?? 'pending').toString().toUpperCase(),
                  style: TextStyle(
                    color: _getStatusColor(applicant['status'] ?? 'pending'),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          MediaQuery.of(context).size.width < 600
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Match Score: ${_calculateMatchScore(skills, List<String>.from(job['requiredSkills'] ?? []))}%',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        if (applicant['hasInterview'] == true) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.stars, color: Colors.orange, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'Interview: ${(applicant['overallScore'] * 100).round()}%',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Change Status:',
                          style: TextStyle(
                            color: _mutedText,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        _buildStatusPicker(context, applicant),
                      ],
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Match Score: ${_calculateMatchScore(skills, List<String>.from(job['requiredSkills'] ?? []))}%',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    if (applicant['hasInterview'] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.stars, color: Colors.orange, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Interview Score: ${(applicant['overallScore'] * 100).round()}%',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    _buildStatusPicker(context, applicant),
                  ],
                ),

          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: skills
                .take(4)
                .map(
                  (s) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      s,
                      style: TextStyle(color: _mutedText, fontSize: 10),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final theme = job['resumeTheme'] ?? 'Modern';
                    final colorHex = job['resumeColor'] ?? 'ff6366f1';
                    final primaryColor = Color(int.parse(colorHex, radix: 16));
                    _viewResume(context, applicant, theme, primaryColor);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('View Resumes'),
                ),
              ),
              if (applicant['hasInterview'] == true && applicant['videoUrl'] != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showInterviewVideo(context, applicant['videoUrl'], applicant['seekerName']),
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Watch Interview'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),

        ],
      ),
    );
  }

  Widget _buildStatusPicker(
    BuildContext context,
    Map<String, dynamic> applicant,
  ) {
    final statuses = ['pending', 'top listed', 'approved', 'rejected'];
    final currentStatus = applicant['status'] ?? 'pending';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _cardBorder),
      ),
      child: DropdownButton<String>(
        value: statuses.contains(currentStatus) ? currentStatus : 'pending',
        dropdownColor: _cardBg,
        underline: const SizedBox(),
        icon: Icon(Icons.arrow_drop_down, color: _mutedText, size: 18),
        style: TextStyle(
          color: _textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        items: statuses.map((status) {
          return DropdownMenuItem(
            value: status,
            child: Text(status.toUpperCase()),
          );
        }).toList(),
        onChanged: (newStatus) async {
          if (newStatus != null && newStatus != currentStatus) {
            final success = await JobService().updateApplicationStatus(
              applicant['id'],
              newStatus,
            );
            if (success && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Status updated to ${newStatus.toUpperCase()}'),
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _showInterviewVideo(BuildContext context, String videoUrl, String? seekerName) {
    showDialog(
      context: context,
      builder: (context) => _VideoPlayerDialog(videoUrl: videoUrl, seekerName: seekerName),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'top listed':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  int _calculateMatchScore(List<String> userSkills, List<String> targetSkills) {
    if (targetSkills.isEmpty) return 100;
    if (userSkills.isEmpty) return 0;

    int matches = 0;
    for (var target in targetSkills) {
      if (userSkills.any(
        (user) =>
            user.toLowerCase().contains(target.toLowerCase()) ||
            target.toLowerCase().contains(user.toLowerCase()),
      )) {
        matches++;
      }
    }
    return ((matches / targetSkills.length) * 100).round();
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

