import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'resume_screen.dart';
import 'employer_dashboard_screen.dart';
import 'employer_jobs_screen.dart';
import 'jobs_screen.dart';
import 'profile_screen.dart';
import 'package:provider/provider.dart';
import '../features/mock_interview/screens/mock_interview_screen.dart';
import '../features/mock_interview/viewmodels/mock_interview_viewmodel.dart';
import '../providers/theme_provider.dart';

import 'company_profile_screen.dart';
import 'login_screen.dart';
import '../services/resume_service.dart';
import '../services/job_service.dart';
import '../services/auth_service.dart';
import '../services/company_service.dart';
import '../widgets/resume_thematic_viewer.dart';
import '../widgets/candidate_avatar.dart';

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
  String _userCategory = "Software Engineer";

  bool _showNotifications = false;
  bool get _isDarkMode => context.watch<ThemeProvider>().isDarkMode;
  String? _profilePictureUrl;
  int _totalEmployerApplicants = 0;
  List<Map<String, dynamic>> _employerApplicants = [];
  StreamSubscription? _employerApplicantsSubscription;
  StreamSubscription? _companySubscription;
  late MockInterviewViewModel _mockInterviewViewModel;
  String? _selectedJobTitle;

  Color get _bgColor =>
      _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  Color get _textColor => _isDarkMode ? Colors.white : Colors.black87;
  Color get _cardBg =>
      _isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.white;
  Color get _cardBorder =>
      _isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300;
  Color get _skyBlue => const Color(0xFF0EA5E9);
  Color get _mutedText => _isDarkMode ? Colors.white54 : Colors.black54;
  Color get _iconColor => _isDarkMode ? Colors.white : Colors.black87;

  @override
  void initState() {
    super.initState();
    _isJobSeeker = widget.isJobSeeker;
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
    _loadNavigationState();
    _subscribeToUserData();
    _mockInterviewViewModel = MockInterviewViewModel();
    if (_isJobSeeker) {
      _subscribeToJobRecommendations();
    } else {
      _subscribeToEmployerApplicants();
    }
  }

  Future<void> _loadNavigationState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _selectedIndex = prefs.getInt('dashboard_index') ?? 0;
      });
    }
  }

  Future<void> _saveNavigationState(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dashboard_index', index);
  }

  void _updateSelectedIndex(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _saveNavigationState(index);
  }

  void _subscribeToUserData() {
    if (_isJobSeeker) {
      _resumeSubscription = ResumeService()
          .getLatestResumeAnalysisStream()
          .listen(
            (data) {
              if (data != null && data['name'] != null) {
                if (mounted) {
                  setState(() {
                    _userName = data['name'];
                    _userSkills = List<String>.from(data['skills'] ?? []);
                    _userCategory = data['category'] ?? "Software Engineer";
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
    } else {
      _companySubscription = CompanyService().getCompanyProfileStream().listen(
        (data) {
          if (mounted) {
            setState(() {
              _userName = data['name'] ?? "Employer";
              _profilePictureUrl = data['logoUrl'] ?? data['profilePictureUrl'];
            });
          }
        },
        onError: (error) {
          debugPrint('Error in Company stream: $error');
        },
      );
    }
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

  void _subscribeToEmployerApplicants() {
    _employerApplicantsSubscription?.cancel();
    _employerApplicantsSubscription = JobService()
        .getEmployerAllApplicantsStream()
        .listen((applicants) {
      if (!mounted) return;
      setState(() {
        _employerApplicants = applicants;
        _totalEmployerApplicants = applicants.length;
      });
    });
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    _mockInterviewViewModel.dispose();
    _resumeSubscription?.cancel();
    _jobSubscription?.cancel();
    _employerApplicantsSubscription?.cancel();
    _companySubscription?.cancel();
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
      backgroundColor: _bgColor,
      body: Row(
        children: [
          Container(
            width: 280,
            color: _bgColor,
            child: Column(
              children: [
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B26F2), Color(0xFF9042F6)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'HASSLE-FREE',
                      style: TextStyle(
                        color: _textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        letterSpacing: 1,
                      ),
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
              color: _isDarkMode
                  ? const Color(0xFF020617)
                  : const Color(0xFFF1F5F9),
              child: Column(
                children: [
                  _buildTopHeader(),
                  Expanded(
                    child: Stack(
                      children: [
                        _buildSelectedScreen(),
                        if (_showNotifications)
                          Positioned(
                            top: 10,
                            right: 32,
                            child: SizedBox(
                              width: 400,
                              child: _buildNotificationPanel(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
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
          return EmployerJobsScreen(isDarkMode: _isDarkMode);
        case 2:
          return CompanyProfileScreen(isDarkMode: _isDarkMode);
        default:
          return EmployerDashboardScreen(isDarkMode: _isDarkMode);
      }
    }

    switch (_selectedIndex) {
      case 1:
        return JobsScreen(isDarkMode: _isDarkMode, initialSearchQuery: _selectedJobTitle);
      case 2:
        return ResumeScreen(
          isDarkMode: _isDarkMode,
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
        return ChangeNotifierProvider.value(
          value: _mockInterviewViewModel,
          child: MockInterviewScreen(
            key: const ValueKey('mock_interview_screen'),
            userId: AuthService().currentUser?.uid ?? "demo_user",
            jobRole: _userCategory,
            skills: _userSkills,
            isDarkMode: _isDarkMode,
            onExit: () {
              _mockInterviewViewModel.reset();
              _updateSelectedIndex(0);
            },

          ),
        );

      case 4:
        return ProfileScreen(isDarkMode: _isDarkMode);
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
    final approvedApps = applications
        .where((a) => a['status'] == 'approved')
        .toList();
    int approvedCount = approvedApps.length;
    String approvedNames = approvedApps.isNotEmpty
        ? approvedApps.map((a) => a['jobTitle'] ?? 'Job').join(', ')
        : 'Keep going!';

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                          _updateSelectedIndex(1);
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
            Text(
              'Recent Activity',
              style: TextStyle(
                color: _textColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: applications.length.clamp(0, 3),
              itemBuilder: (context, index) {
                final app = applications[index];
                return InkWell(
                  onTap: () {
                    // Check if job is expired
                    bool isExpired = false;
                    if (app['expiryDate'] != null) {
                      final expiryDate = (app['expiryDate'] as Timestamp).toDate();
                      if (expiryDate.isBefore(DateTime.now())) {
                        isExpired = true;
                      }
                    }
                    if (app['jobStatus'] == 'inactive') {
                      isExpired = true;
                    }

                    if (isExpired) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('This job posting has expired or is no longer active.'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    setState(() {
                      _selectedJobTitle = app['jobTitle'];
                    });
                    _updateSelectedIndex(1);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: _buildApplicationStatusCard(app),
                );
              },
            ),
            const SizedBox(height: 32),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Applications',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedJobTitle = null;
                  });
                  _updateSelectedIndex(1);
                },
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
                return Text(
                  'No recommended jobs yet',
                  style: TextStyle(color: _mutedText),
                );
              }
              return SizedBox(
                height: 150,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: jobs.length.clamp(0, 5),
                  itemBuilder: (context, index) {
                    final job = jobs[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedJobTitle = job['title'];
                          });
                          _updateSelectedIndex(1);
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: _buildCompactJobCard(
                          job['title'] ?? 'Job Title',
                          job['company'] ?? 'Company',
                          job['location'] ?? 'Remote',
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          _buildSectionHeader('Your Activity'),
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
                _generateDynamicTrend(applications.length.toDouble(), 8),
              ),
              _buildStatCard(
                'Offers / Approved',
                approvedCount.toString(),
                Icons.check_circle_outline,
                const Color(0xFF22C55E),
                approvedNames,
                _generateDynamicTrend(approvedCount.toDouble(), 8),
                isBarChart: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<double> _generateDynamicTrend(double currentValue, int points) {
    final List<double> trend = [];
    // Always trend upwards to the current value
    for (int i = 0; i < points; i++) {
      double factor = (i + 1) / points;
      // Add a bit of "organic" wobble but keep it strictly below or equal to currentValue
      double val = currentValue * factor;
      trend.add(val);
    }
    return trend;
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: _textColor,
      ),
    );
  }

  void _showApplicantProfile(Map<String, dynamic> app) {
    setState(() => _showNotifications = false);
    final applicantFormat = {
      'seekerName': app['seekerName'] ?? 'Candidate',
      'seekerEmail': app['seekerEmail'] ?? 'Contact information hidden',
      'resumeData': app['resumeData'] ?? {},
      'profilePictureUrl': app['profilePictureUrl'],
      'seekerId': app['seekerId'],
    };
    showDialog(
      context: context,
      builder: (context) => ResumeThematicViewer(
        applicant: applicantFormat,
        theme: 'Modern',
        primaryColor: const Color(0xFF6366F1),
      ),
    );
  }

  void _showAllApplicantsDialog() {
    setState(() => _showNotifications = false);
    showModalBottomSheet(
      context: context,
      backgroundColor: _bgColor,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
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
                  Text(
                    'All Applicants',
                    style: TextStyle(
                      color: _textColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
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
              child: ListView.builder(
                controller: scrollController,
                itemCount: _employerApplicants.length,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemBuilder: (context, index) {
                  final app = _employerApplicants[index];
                  return _buildApplicantCardInDialog(app);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicantCardInDialog(Map<String, dynamic> app) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDarkMode ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CandidateAvatar(
                seekerId: app['seekerId'] ?? '',
                seekerName: app['seekerName'] ?? '?',
                radius: 24,
                initialPictureUrl: app['profilePictureUrl'],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app['seekerName'] ?? 'Candidate',
                      style: TextStyle(
                        color: _textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      app['seekerEmail'] ?? '',
                      style: TextStyle(color: _mutedText, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'PENDING',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showApplicantProfile(app),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text('View Resume'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyNotification(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.notifications_none,
                color: _mutedText.withValues(alpha: 0.2), size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(color: _mutedText, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(
    String title,
    String subtitle,
    IconData icon,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: _textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: _mutedText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicationStatusCard(Map<String, dynamic> app) {
    String status = app['status'] ?? 'pending';
    Color statusColor = _getStatusColor(status);

    return _HoverableCard(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cardBorder),
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
                    style: TextStyle(
                      color: _textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Applied on ${_formatTimestamp(app['appliedAt'])}',
                    style: TextStyle(color: _mutedText, fontSize: 12),
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
            if (app['expiryDate'] != null && (app['expiryDate'] as Timestamp).toDate().isBefore(DateTime.now()))
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'EXPIRED',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
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
        color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isDarkMode ? Colors.white10 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isJobSeeker ? 'AI Job Matches' : 'New Candidates',
                  style: TextStyle(
                    color: _textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: _mutedText, size: 20),
                  onPressed: () => setState(() => _showNotifications = false),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  if (_isJobSeeker) ...[
                    if (_matchedJobs.isEmpty)
                      _buildEmptyNotification('No matches yet')
                    else
                      ...(_matchedJobs.take(5).map((job) {
                        return _buildNotificationItem(
                          job['title'] ?? 'Position',
                          job['company'] ?? 'Company',
                          Icons.auto_awesome,
                          const Color(0xFF6366F1),
                          () => _updateSelectedIndex(1),
                        );
                      })),
                  ] else ...[
                    if (_employerApplicants.isEmpty)
                      _buildEmptyNotification('No applicants yet')
                    else
                      ...(_employerApplicants.take(5).map((app) {
                        return _buildNotificationItem(
                          app['seekerName'] ?? 'Candidate',
                          'Applied for ${app['jobTitle']}',
                          Icons.person_add_outlined,
                          const Color(0xFF22C55E),
                          () => _showApplicantProfile(app),
                        );
                      })),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextButton(
              onPressed: () {
                if (_isJobSeeker) {
                  setState(() => _showNotifications = false);
                  _updateSelectedIndex(1);
                } else {
                  _showAllApplicantsDialog();
                }
              },
              child: Text(
                _isJobSeeker ? 'View All Jobs' : 'View All Applicants',
                style: const TextStyle(color: Color(0xFF6366F1)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: _iconColor),
        title: Text(
          _isJobSeeker ? 'Applicant Dashboard' : 'Employer Dashboard',
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: _selectedIndex == 0
            ? [
                IconButton(
                  onPressed: () {
                    context.read<ThemeProvider>().toggleTheme();
                  },
                  icon: Icon(
                    _isDarkMode
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                  ),
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      onPressed: () => setState(
                        () => _showNotifications = !_showNotifications,
                      ),
                      icon: const Icon(Icons.notifications_none),
                    ),
                    if ((_isJobSeeker && _matchedJobs.isNotEmpty) ||
                        (!_isJobSeeker && _totalEmployerApplicants > 0))
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFF6366F1),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            _isJobSeeker
                                ? '${_matchedJobs.length}'
                                : '$_totalEmployerApplicants',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    if (_isJobSeeker) {
                      _updateSelectedIndex(4);
                    } else {
                      _updateSelectedIndex(2);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16, left: 8),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF6366F1),
                      backgroundImage: _profilePictureUrl != null &&
                              _profilePictureUrl!.isNotEmpty
                          ? (_profilePictureUrl!.startsWith('data:image')
                              ? MemoryImage(
                                  base64Decode(
                                      _profilePictureUrl!.split(',').last),
                                )
                              : NetworkImage(_profilePictureUrl!)
                                  as ImageProvider)
                          : null,
                      child: (_profilePictureUrl == null ||
                              _profilePictureUrl!.isEmpty)
                          ? Text(
                              _userName.isNotEmpty
                                  ? _userName[0].toUpperCase()
                                  : "C",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ]
            : [],
      ),
      drawer: Drawer(
        backgroundColor: _bgColor,
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: _cardBorder)),
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
                    Text(
                      'HASSLE-FREE',
                      style: TextStyle(
                        color: _textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text(
                'Logout',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () async {
                await AuthService().signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
            const SizedBox(height: 10),
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
          final newIndex = _reverseIndexMap(index);
          if (newIndex == 1) {
            setState(() {
              _selectedJobTitle = null;
            });
          }
          _updateSelectedIndex(newIndex);
        },
        backgroundColor: _bgColor,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _skyBlue,
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
      body: Stack(
        children: [
          _buildSelectedScreen(),
          if (_showNotifications)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: _buildNotificationPanel(),
            ),
        ],
      ),
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

  Widget _buildTopHeader() {
    bool isMobile = MediaQuery.of(context).size.width < 1100;
    if (isMobile || _selectedIndex != 0) {
      return const SizedBox.shrink(); // Handled in AppBar for mobile or not on dashboard
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            children: [
              // Theme Toggle Button
              GestureDetector(
                onTap: () {
                  context.read<ThemeProvider>().toggleTheme();
                },
                child: CircleAvatar(
                  backgroundColor: _isDarkMode
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.shade200,
                  child: Icon(
                    _isDarkMode
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    color: _iconColor,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Notification Bell
              Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: () => setState(
                      () => _showNotifications = !_showNotifications,
                    ),
                    child: CircleAvatar(
                      backgroundColor: _isDarkMode
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.grey.shade200,
                      child: Icon(Icons.notifications_none, color: _iconColor),
                    ),
                  ),
                  if ((_isJobSeeker && _matchedJobs.isNotEmpty) ||
                      (!_isJobSeeker && _totalEmployerApplicants > 0))
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
                          _isJobSeeker
                              ? '${_matchedJobs.length > 9 ? "9+" : _matchedJobs.length}'
                              : '${_totalEmployerApplicants > 9 ? "9+" : _totalEmployerApplicants}',
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
              // Profile avatar
              GestureDetector(
                onTap: () {
                  if (_isJobSeeker) {
                    _updateSelectedIndex(4);
                  } else {
                    _updateSelectedIndex(2);
                  }
                },
                child: CircleAvatar(
                  backgroundColor: const Color(0xFF6366F1),
                  backgroundImage: _profilePictureUrl != null && _profilePictureUrl!.isNotEmpty
                      ? (_profilePictureUrl!.startsWith('data:image')
                          ? MemoryImage(base64Decode(_profilePictureUrl!.split(',').last))
                          : NetworkImage(_profilePictureUrl!) as ImageProvider)
                      : null,
                  child: (_profilePictureUrl == null || _profilePictureUrl!.isEmpty)
                      ? Text(
                          _userName.isNotEmpty ? _userName[0].toUpperCase() : "C",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _isDarkMode
            ? null
            : const LinearGradient(
                colors: [Color(0xFFF0F9FF), Color(0xFFE0F2FE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: _isDarkMode ? _cardBg : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isDarkMode ? _cardBorder : const Color(0xFFBAE6FD),
          width: _isDarkMode ? 1 : 1.5,
        ),
        boxShadow: _isDarkMode
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upgrade to Pro',
            style: TextStyle(fontWeight: FontWeight.bold, color: _textColor),
          ),
          Text(
            'Get unlimited AI features',
            style: TextStyle(fontSize: 12, color: _mutedText),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _skyBlue,
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
      onTap: () {
        if (index == 1) {
          setState(() {
            _selectedJobTitle = null;
          });
        }
        _updateSelectedIndex(index);
      },
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
    List<double> dataPoints, {
    bool isBarChart = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardBorder),
        boxShadow: _isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              bottom: -10,
              left: 0,
              right: 0,
              height: 50,
              child: CustomPaint(
                painter: isBarChart
                    ? _BarChartPainter(dataPoints, color.withValues(alpha: 0.2))
                    : _MiniChartPainter(
                        dataPoints,
                        color.withValues(alpha: 0.3),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
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
                            style: TextStyle(color: _mutedText, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            value,
                            style: TextStyle(
                              color: _textColor,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: color, size: 18),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(Icons.trending_up, color: color, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
    return _HoverableCard(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        width: 220,
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _cardBorder),
          boxShadow: _isDarkMode
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: _textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              company,
              style: TextStyle(color: _mutedText, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 14, color: _skyBlue),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    location,
                    style: TextStyle(color: _mutedText, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _bgColor,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _isDarkMode
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.8),
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Choose Your Plan',
                                style: TextStyle(
                                  color: _textColor,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Unlock the full power of HASSLE-FREE AI',
                                style: TextStyle(
                                  color: _mutedText,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.close,
                              color: _mutedText,
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
        color: _isDarkMode
            ? (isRecommended
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.02))
            : (isRecommended
                  ? gradient[0].withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isRecommended
              ? gradient[0].withValues(alpha: 0.5)
              : (_isDarkMode
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.shade300),
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
            style: TextStyle(
              color: _textColor,
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
                style: TextStyle(
                  color: _textColor,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (price != 'Free')
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, left: 4),
                  child: Text('/mo', style: TextStyle(color: _mutedText)),
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
                      style: TextStyle(
                        color: _textColor.withValues(alpha: 0.8),
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
                      : BorderSide(color: _textColor.withValues(alpha: 0.2)),
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
      final double y =
          size.height - ((dataPoints[i] - minY) / range * size.height);
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

class _HoverableCard extends StatefulWidget {
  final Widget child;

  const _HoverableCard({required this.child});

  @override
  State<_HoverableCard> createState() => _HoverableCardState();
}

class _HoverableCardState extends State<_HoverableCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0.0, _isHovered ? -5.0 : 0.0, 0.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: widget.child,
      ),
    );
  }
}
