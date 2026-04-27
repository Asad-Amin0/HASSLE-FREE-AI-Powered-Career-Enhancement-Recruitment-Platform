import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'resume_screen.dart';
import 'employer_dashboard_screen.dart';
import 'employer_jobs_screen.dart';
import 'jobs_screen.dart';
import 'profile_screen.dart';
import 'interview_screen.dart';
import 'company_profile_screen.dart';
import '../services/resume_service.dart';
import '../services/job_service.dart';

class MainDashboardScreen extends StatefulWidget {
  final bool isJobSeeker;
  const MainDashboardScreen({super.key, this.isJobSeeker = true});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late bool _isJobSeeker;
  String _userName = "";
  late AnimationController _bgAnimationController;
  StreamSubscription? _resumeSubscription;
  StreamSubscription? _jobSubscription;
  List<Map<String, dynamic>> _matchedJobs = [];
  List<String> _userSkills = [];
  bool _showNotifications = false;
  String? _profilePictureUrl;

  @override
  void initState() {
    super.initState();
    _isJobSeeker = widget.isJobSeeker;
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
    _subscribeToUserData();
    if (_isJobSeeker) _subscribeToJobRecommendations();
  }

  void _subscribeToUserData() {
    _resumeSubscription = ResumeService()
        .getLatestResumeAnalysisStream()
        .listen(
          (data) {
            if (data != null && data['name'] != null) {
              if (mounted) {
                setState(() {
                  _userName = data['name'];
                  _userSkills = List<String>.from(data['skills'] ?? []);
                  _profilePictureUrl = data['profilePictureUrl'];
                });
                // Re-subscribe job recommendations when skills update
                _subscribeToJobRecommendations();
              }
            }
          },
          onError: (error) {
            debugPrint('Error in Dashboard stream: $error');
          },
        );
  }

  void _subscribeToJobRecommendations() {
    _jobSubscription?.cancel();
    _jobSubscription = JobService().getAllJobsStream().listen((jobs) {
      if (!mounted) return;
      final matched = jobs.where((job) {
        final jobSkills = List<String>.from(job['requiredSkills'] ?? []);
        return jobSkills.any(
          (s) => _userSkills.any(
            (us) =>
                us.toLowerCase().contains(s.toLowerCase()) ||
                s.toLowerCase().contains(us.toLowerCase()),
          ),
        );
      }).toList();
      setState(() => _matchedJobs = matched);
    });
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    _resumeSubscription?.cancel();
    _jobSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1100) {
          return _buildMobileLayout(context);
        } else {
          return _buildWebLayout(context);
        }
      },
    );
  }

  Widget _buildWebLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark Slate
      body: Row(
        children: [
          Container(
            width: 260,
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B26F2), Color(0xFF9042F6)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HASSLE-FREE',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'AI Recruitment',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                if (_isJobSeeker) ...[
                  _buildSidebarItem(0, Icons.dashboard_rounded, 'Dashboard'),
                  _buildSidebarItem(1, Icons.business_center_outlined, 'Jobs'),
                  _buildSidebarItem(2, Icons.description_outlined, 'Resume'),
                  _buildSidebarItem(3, Icons.video_call_outlined, 'Interview'),
                  _buildSidebarItem(4, Icons.person_outline, 'Profile'),
                ] else ...[
                  _buildSidebarItem(0, Icons.dashboard_rounded, 'Dashboard'),
                  _buildSidebarItem(
                    1,
                    Icons.business_center_outlined,
                    'Job Postings',
                  ),
                  _buildSidebarItem(2, Icons.business_outlined, 'Company'),
                ],
                const Spacer(),
                _buildUpgradeCard(),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: const Color(0xFF020617), // Deep Dark Body
              child: _buildSelectedScreen(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedScreen() {
    if (!_isJobSeeker) {
      switch (_selectedIndex) {
        case 1:
          return const EmployerJobsScreen();
        case 2:
          return const CompanyProfileScreen();
        default:
          return const EmployerDashboardScreen();
      }
    }

    switch (_selectedIndex) {
      case 1:
        return const JobsScreen();
      case 2:
        return ResumeScreen(
          onNameExtracted: (name) {
            setState(() {
              _userName = name;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "Welcome, $_userName! Name extracted successfully.",
                ),
                backgroundColor: const Color(0xFF3B26F2),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          },
        );
      case 3:
        return InterviewScreen(skills: _userSkills);
      case 4:
        return const ProfileScreen();
      default:
        return Stack(
          children: [
            _buildLiveBackground(),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: JobService().getMyApplicationsFullStream(),
              builder: (context, snapshot) {
                final applications = snapshot.data ?? [];
                return SingleChildScrollView(
                  child: _buildDashboardContent(applications),
                );
              },
            ),
          ],
        );
    }
  }

  Widget _buildDashboardContent(List<Map<String, dynamic>> applications) {
    bool isMobile = MediaQuery.of(context).size.width < 1100;
    int approvedCount = applications
        .where((a) => a['status'] == 'approved')
        .length;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                children: [
                  // Notification Bell with badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: () => setState(
                          () => _showNotifications = !_showNotifications,
                        ),
                        child: CircleAvatar(
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          child: const Icon(
                            Icons.notifications_none,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (_matchedJobs.isNotEmpty)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF6366F1),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${_matchedJobs.length > 9 ? "9+" : _matchedJobs.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Profile avatar → tapping opens ProfileScreen
                  GestureDetector(
                    onTap: () => setState(
                      () => _selectedIndex = _isJobSeeker ? 4 : _selectedIndex,
                    ),
                    child: CircleAvatar(
                      backgroundImage:
                          _profilePictureUrl != null &&
                              _profilePictureUrl!.startsWith('data:image')
                          ? MemoryImage(
                              base64Decode(_profilePictureUrl!.split(',').last),
                            )
                          : NetworkImage(
                                  'https://api.dicebear.com/7.x/avataaars/png?seed=${_userName.isEmpty ? "default" : _userName}',
                                )
                                as ImageProvider,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Inline notification panel
          if (_showNotifications && _isJobSeeker) ...[
            const SizedBox(height: 16),
            _buildNotificationPanel(),
          ],
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            height: isMobile ? 240 : 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF6366F1),
                  Color(0xFF8B5CF6),
                  Color(0xFF06B6D4),
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: isMobile ? 24 : 40,
                  top: isMobile ? 24 : 40,
                  right: isMobile ? 24 : 300,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 14,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'AI-Powered Insights',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _userName.isNotEmpty
                            ? 'Welcome back, $_userName! 👋'
                            : 'Welcome back! 👋',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isMobile ? 28 : 42,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 60,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                Positioned(
                  top: -40,
                  right: -40,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -30,
                  left: 150,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Positioned(
                  bottom: isMobile ? 12 : 16,
                  left: isMobile ? 24 : 40,
                  right: isMobile ? 24 : 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildBannerStat(
                        applications.length.toString(),
                        'Applications',
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedIndex = 1;
                          });
                        },
                        icon: const Icon(
                          Icons.business_center_outlined,
                          size: 18,
                        ),
                        label: const Text(
                          'View Jobs',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          if (applications.isNotEmpty) ...[
            const Text(
              'Application Status',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: applications.length.clamp(0, 3),
              itemBuilder: (context, index) {
                final app = applications[index];
                return _buildApplicationStatusCard(app);
              },
            ),
            const SizedBox(height: 32),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recommended Jobs',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _selectedIndex = 1),
                child: const Text(
                  'See all',
                  style: TextStyle(color: Color(0xFF6366F1)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: JobService().getAllActiveJobsStream(),
            builder: (context, snapshot) {
              final jobs = snapshot.data ?? [];
              if (jobs.isEmpty) {
                return const Text(
                  'No recommended jobs yet',
                  style: TextStyle(color: Colors.white60),
                );
              }
              return SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: jobs.length.clamp(0, 5),
                  itemBuilder: (context, index) {
                    final job = jobs[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: _buildCompactJobCard(
                        job['title'] ?? 'Job Title',
                        job['company'] ?? 'Company',
                        job['location'] ?? 'Remote',
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          const Text(
            'Your Activity',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: isMobile ? 1 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: isMobile ? 2.8 : 2.5,
            children: [
              _buildStatCard(
                'Applications',
                applications.length.toString(),
                Icons.business_center,
                const Color(0xFF3B82F6),
                applications.isNotEmpty ? "Tracking" : "None yet",
              ),
              _buildStatCard(
                'Offers / Approved',
                approvedCount.toString(),
                Icons.check_circle_outline,
                const Color(0xFF22C55E),
                approvedCount > 0 ? 'Congratulations!' : 'Keep going!',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationStatusCard(Map<String, dynamic> app) {
    String status = app['status'] ?? 'pending';
    Color statusColor = _getStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              status == 'approved'
                  ? Icons.check_circle
                  : status == 'rejected'
                  ? Icons.cancel
                  : Icons.access_time_filled,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app['jobTitle'] ?? 'Job Title',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Applied on ${_formatTimestamp(app['appliedAt'])}',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'unknown date';
    final DateTime date = (timestamp as Timestamp).toDate();
    return '${date.day}/${date.month}/${date.year}';
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

  Widget _buildNotificationPanel() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Color(0xFF818CF8),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Jobs Matching Your Skills',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white54,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _showNotifications = false),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          // Job list
          if (_matchedJobs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No matching jobs yet.\nUpload your resume to get personalized recommendations!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ),
            )
          else
            ...(_matchedJobs.take(5).map((job) {
              final skills = List<String>.from(job['requiredSkills'] ?? []);
              final matchCount = skills
                  .where(
                    (s) => _userSkills.any(
                      (us) =>
                          us.toLowerCase().contains(s.toLowerCase()) ||
                          s.toLowerCase().contains(us.toLowerCase()),
                    ),
                  )
                  .length;
              return InkWell(
                onTap: () {
                  setState(() {
                    _showNotifications = false;
                    _selectedIndex = 1; // Navigate to Jobs tab
                  });
                },
                borderRadius: BorderRadius.circular(0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.business_center,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              job['title'] ?? 'Job Title',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${job['company'] ?? ''} • ${job['location'] ?? ''}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$matchCount match${matchCount == 1 ? '' : 'es'}',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            job['salaryRange'] ?? '',
                            style: const TextStyle(
                              color: Color(0xFF818CF8),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList()),
          // Footer
          if (_matchedJobs.length > 5)
            InkWell(
              onTap: () => setState(() {
                _showNotifications = false;
                _selectedIndex = 1;
              }),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Text(
                  'View all ${_matchedJobs.length} matching jobs →',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF818CF8),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          'HASSLE-FREE',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: const [],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF0F172A),
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white10)),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B26F2), Color(0xFF9042F6)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'HASSLE-FREE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildUpgradeCard(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndexMap(_selectedIndex),
        onTap: (index) {
          setState(() {
            _selectedIndex = _reverseIndexMap(index);
          });
        },
        backgroundColor: const Color(0xFF0F172A),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF6366F1),
        unselectedItemColor: Colors.grey,
        items: _isJobSeeker
            ? const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_outlined),
                  activeIcon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.description_outlined),
                  activeIcon: Icon(Icons.description),
                  label: 'Resume',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.business_center_outlined),
                  activeIcon: Icon(Icons.business_center),
                  label: 'Jobs',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.video_call_outlined),
                  activeIcon: Icon(Icons.video_call),
                  label: 'Interview',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ]
            : const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_outlined),
                  activeIcon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.business_center_outlined),
                  activeIcon: Icon(Icons.business_center),
                  label: 'Postings',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.business_outlined),
                  activeIcon: Icon(Icons.business),
                  label: 'Company',
                ),
              ],
      ),
      body: _buildSelectedScreen(),
    );
  }

  // Maps unified _selectedIndex to mobile bottom nav index
  int _selectedIndexMap(int index) {
    if (!_isJobSeeker) {
      if (index > 2) return 0;
      return index;
    }
    if (index == 0) return 0; // Dashboard
    if (index == 2) return 1; // Resume
    if (index == 1) return 2; // Jobs
    if (index == 3) return 3; // Interview
    if (index == 4) return 4; // Profile
    return 0;
  }

  // Maps mobile bottom nav index back to unified _selectedIndex
  int _reverseIndexMap(int mobileIndex) {
    if (!_isJobSeeker) return mobileIndex;
    if (mobileIndex == 0) return 0; // Dashboard
    if (mobileIndex == 1) return 2; // Resume
    if (mobileIndex == 2) return 1; // Jobs
    if (mobileIndex == 3) return 3; // Interview
    if (mobileIndex == 4) return 4; // Profile
    return 0;
  }

  Widget _buildUpgradeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upgrade to Pro',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const Text(
            'Get unlimited AI features',
            style: TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              minimumSize: const Size(double.infinity, 40),
            ),
            onPressed: _showUpgradeDialog,
            child: const Text(
              'Upgrade Now',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String title) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF3B26F2), Color(0xFF9042F6)],
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey,
              size: 22,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerStat(String value, String label) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveBackground() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _bgAnimationController,
        builder: (context, child) {
          return Stack(
            children: [
              Positioned(
                top: 100 + (20 * _bgAnimationController.value),
                left: -50 + (30 * _bgAnimationController.value),
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned(
                bottom: 80 - (30 * _bgAnimationController.value),
                right: -100 + (50 * _bgAnimationController.value),
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCompactJobCard(String title, String company, String location) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            company,
            style: const TextStyle(color: Colors.white60, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 14,
                color: Color(0xFF6366F1),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  location,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 50,
                spreadRadius: 10,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Choose Your Plan',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Unlock the full power of HASSLE-FREE AI',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.close,
                              color: Color(0xFF94A3B8),
                              size: 30,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Plans
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          bool isSmall =
                              MediaQuery.of(context).size.width < 900;
                          return Flex(
                            direction: isSmall
                                ? Axis.vertical
                                : Axis.horizontal,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: isSmall
                                ? CrossAxisAlignment.center
                                : CrossAxisAlignment.start,
                            children: [
                              _buildPlanCard(
                                title: 'Basic',
                                price: 'Free',
                                features: [
                                  '5 Resume Scans/mo',
                                  'Basic Mock Interview',
                                  'Standard Support',
                                ],
                                gradient: [
                                  const Color(0xFF334155),
                                  const Color(0xFF475569),
                                ],
                                isRecommended: false,
                              ),
                              const SizedBox(height: 24, width: 24),
                              _buildPlanCard(
                                title: 'Pro',
                                price: '\$19',
                                features: [
                                  'Unlimited Resume Scans',
                                  'Priority AI Interviews',
                                  'Skill Verification Badges',
                                  'Advanced Analytics',
                                ],
                                gradient: [
                                  const Color(0xFF6366F1),
                                  const Color(0xFF8B5CF6),
                                ],
                                isRecommended: true,
                              ),
                              const SizedBox(height: 24, width: 24),
                              _buildPlanCard(
                                title: 'Enterprise',
                                price: '\$49',
                                features: [
                                  'Custom AI Models',
                                  'Team Management',
                                  'API Access',
                                  '24/7 Dedicated Support',
                                ],
                                gradient: [
                                  const Color(0xFFF43F5E),
                                  const Color(0xFFFB923C),
                                ],
                                isRecommended: false,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required List<String> features,
    required List<Color> gradient,
    required bool isRecommended,
  }) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isRecommended
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isRecommended
              ? gradient[0].withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
          width: isRecommended ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isRecommended)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: gradient[0],
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'RECOMMENDED',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (price != 'Free')
                const Padding(
                  padding: EdgeInsets.only(bottom: 6, left: 4),
                  child: Text(
                    '/mo',
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 32),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: gradient[0],
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      f,
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: isRecommended
                    ? Colors.transparent
                    : Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isRecommended
                      ? BorderSide.none
                      : BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                ),
              ),
              child: Ink(
                decoration: isRecommended
                    ? BoxDecoration(
                        gradient: LinearGradient(colors: gradient),
                        borderRadius: BorderRadius.circular(12),
                      )
                    : null,
                child: Container(
                  alignment: Alignment.center,
                  child: Text(
                    'Get Started',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
