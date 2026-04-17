import 'package:flutter/material.dart';
import '../services/job_service.dart';
import 'post_job_screen.dart';
import '../widgets/resume_thematic_viewer.dart';

class EmployerJobsScreen extends StatelessWidget {
  const EmployerJobsScreen({super.key});

  void _deleteJob(BuildContext context, String jobId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Job Posting', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this job posting? This action cannot be undone.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await JobService().deleteJob(jobId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Job deleted successfully' : 'Failed to delete job'),
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
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: isMobile ? 24 : 40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Job Postings',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5),
                ),
                const SizedBox(height: 4),
                Text('View and manage all active job listings', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showPostJobDialog(context),
                    icon: const Icon(Icons.add, color: Colors.white, size: 20),
                    label: const Text('Post Job', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            )
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Job Postings',
                      style: TextStyle(
                        fontSize: 28, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      'View and manage all active job listings',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showPostJobDialog(context),
                icon: const Icon(Icons.add, color: Colors.white, size: 20),
                label: const Text('Post Job', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                return const Center(child: Text('Error loading jobs', style: TextStyle(color: Colors.red)));
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
          Icon(Icons.business_center, size: 80, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 24),
          Text(
            'No job postings yet', 
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.8))
          ),
          const SizedBox(height: 12),
          Text(
            'Create your first job listing to start attracting top talent.', 
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16)
          ),
        ],
      ),
    );
  }

  Widget _buildMobileJobsList(BuildContext context, List<Map<String, dynamic>> jobs) {
    return Column(
      children: jobs.map((job) => _buildJobCard(context, job, isWebGrid: false)).toList(),
    );
  }

  Widget _buildWebJobsGrid(BuildContext context, List<Map<String, dynamic>> jobs) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        mainAxisExtent: 240,
      ),
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        return _buildJobCard(context, jobs[index], isWebGrid: true);
      },
    );
  }

  Widget _buildJobCard(BuildContext context, Map<String, dynamic> job, {bool isWebGrid = false}) {
    final skills = List<String>.from(job['requiredSkills'] ?? []);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
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
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${job['type']} • ${job['location']} • ${job['experienceLevel']}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: job['status'] == 'active' ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      (job['status']?.toString() ?? 'active').toUpperCase(),
                      style: TextStyle(
                        color: job['status'] == 'active' ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _editJob(context, job),
                    icon: const Icon(Icons.edit_outlined, color: Colors.white54, size: 20),
                    tooltip: 'Edit Job',
                  ),
                  IconButton(
                    onPressed: () => _deleteJob(context, job['id']),
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    tooltip: 'Delete Job',
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.people_outline, color: Colors.indigoAccent, size: 16),
              const SizedBox(width: 8),
              Text(
                '${job['applicants'] ?? 0} Applicants',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _viewApplicants(context, job),
                child: const Text('View Applicants', style: TextStyle(color: Color(0xFF6366F1))),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            job['description'] ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
          ),
          isWebGrid ? const Spacer() : const SizedBox(height: 16),
          Row(
            children: [
              ...skills.take(3).map((s) => Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1), 
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(s, style: const TextStyle(fontSize: 12, color: Colors.white70)),
              )),
              if (skills.length > 3)
                Text('+${skills.length - 3}', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
              const Spacer(),
              Text(
                job['salaryRange'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6366F1), fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _viewResume(BuildContext context, Map<String, dynamic> applicant, String theme) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: ResumeThematicViewer(applicant: applicant, theme: theme),
      ),
    );
  }

  void _viewApplicants(BuildContext context, Map<String, dynamic> job) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))),
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
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                   Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Applicants for', style: TextStyle(color: Colors.white60, fontSize: 14)),
                      Text(job['title'], style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white)),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: JobService().getJobApplicantsStream(job['id']),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  final applicants = snapshot.data ?? [];
                  if (applicants.isEmpty) {
                    return const Center(child: Text('No applicants yet', style: TextStyle(color: Colors.white54)));
                  }
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: applicants.length,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemBuilder: (context, index) => _buildApplicantCard(context, applicants[index], job),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicantCard(BuildContext context, Map<String, dynamic> applicant, Map<String, dynamic> job) {
    final resume = applicant['resumeData'] ?? {};
    final skills = List<String>.from(resume['skills'] ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
                child: Text(applicant['seekerName']?[0] ?? '?', style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(applicant['seekerName'] ?? 'Anonymous', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(applicant['seekerEmail'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(applicant['status'] ?? 'pending').withValues(alpha: 0.1), 
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Match Score: 85%', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
              _buildStatusPicker(context, applicant),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: skills.take(4).map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6)),
              child: Text(s, style: const TextStyle(color: Colors.white60, fontSize: 10)),
            )).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _viewResume(context, applicant, job['resumeTheme'] ?? 'Modern'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1), 
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('View Resumes'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildStatusPicker(BuildContext context, Map<String, dynamic> applicant) {
    final statuses = ['pending', 'top listed', 'approved', 'rejected'];
    final currentStatus = applicant['status'] ?? 'pending';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: DropdownButton<String>(
        value: statuses.contains(currentStatus) ? currentStatus : 'pending',
        dropdownColor: const Color(0xFF0F172A),
        underline: const SizedBox(),
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white60, size: 18),
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        items: statuses.map((status) {
          return DropdownMenuItem(
            value: status,
            child: Text(status.toUpperCase()),
          );
        }).toList(),
        onChanged: (newStatus) async {
          if (newStatus != null && newStatus != currentStatus) {
            final success = await JobService().updateApplicationStatus(applicant['id'], newStatus);
            if (success && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Status updated to ${newStatus.toUpperCase()}')),
              );
            }
          }
        },
      ),
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
}
