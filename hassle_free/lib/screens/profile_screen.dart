import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/resume_service.dart';
import '../services/job_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool isDarkMode;
  const ProfileScreen({super.key, this.isDarkMode = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Color get _textColor => Colors.white;
  Color get _mutedText => Colors.white70;
  Color get _headingColor => widget.isDarkMode ? Colors.white : Colors.black87;
  Color get _cardBg => widget.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFF0EA5E9);
  Color get _cardBorder => widget.isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.transparent;
  Color get _skyBlueBox => widget.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFF0EA5E9);

  final ResumeService _resumeService = ResumeService();
  final JobService _jobService = JobService();
  final AuthService _authService = AuthService();
  String _name = "User";
  String _location = "Lahore, Punjab, Pakistan";
  String _education = "";
  String _experience = "";
  List<String> _skills = [];
  List<String> _certificates = [];
  bool _isLoading = true;
  StreamSubscription? _resumeSubscription;
  StreamSubscription? _appsSubscription;

  // AI Scoring Data
  double _overallScore = 0.0;
  Map<String, dynamic> _breakdown = {};
  List<String> _userBadges = [];
  int _appliedCount = 0;
  String? _profilePictureUrl;

  final Map<String, Map<String, dynamic>> _badgeDefinitions = {
    'Highly Employable': {'icon': Icons.verified, 'color': Colors.amberAccent},
    'Top Skilled': {'icon': Icons.bolt, 'color': Colors.blueAccent},
    'Technical Specialist': {
      'icon': Icons.settings,
      'color': Colors.purpleAccent,
    },
    'Great Communicator': {
      'icon': Icons.chat_bubble,
      'color': Colors.greenAccent,
    },
    'Fast Learner': {'icon': Icons.auto_awesome, 'color': Colors.orangeAccent},
    'Analytical Expert': {'icon': Icons.analytics, 'color': Colors.tealAccent},
  };

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _subscribeToProfileData();
  }

  Future<void> _loadInitialData() async {
    // 1. Get account data (name from signup)
    final userData = await _authService.getUserData();
    if (userData != null && mounted) {
      setState(() {
        _name = userData['name'] ?? "User";
        _location = userData['location'] ?? "Lahore, Punjab, Pakistan";
      });
    }

    // 2. Get resume analysis
    final data = await _resumeService.getLatestResumeAnalysis();
    if (data != null && mounted) {
      setState(() {
        // Only override if name was empty in account
        if (_name == "User" || _name.isEmpty) {
          _name = data['name'] ?? "User";
        }
        _location = data['location'] ?? "Lahore, Punjab, Pakistan";
        _education = data['education'] ?? "";
        _experience = data['experience'] ?? "";
        _skills = List<String>.from(data['skills'] ?? []);
        _overallScore = (data['overallScore'] as num?)?.toDouble() ?? 0.0;
        _breakdown = data['breakdown'] ?? {};
        _userBadges = List<String>.from(data['badges'] ?? []);
        _certificates = List<String>.from(data['certificates'] ?? []);
        _isLoading = false;
      });
    }
  }

  void _subscribeToProfileData() {
    _resumeSubscription = _resumeService.getLatestResumeAnalysisStream().listen(
      (data) {
        if (mounted) {
          setState(() {
            if (data != null) {
              _name = data['name'] ?? "User";
              _location = data['location'] ?? "Lahore, Punjab, Pakistan";
              _education = data['education'] ?? "";
              _experience = data['experience'] ?? "";
              _skills = List<String>.from(data['skills'] ?? []);
              _overallScore = (data['overallScore'] as num?)?.toDouble() ?? 0.0;
              _breakdown = data['breakdown'] ?? {};
              _userBadges = List<String>.from(data['badges'] ?? []);
              _certificates = List<String>.from(data['certificates'] ?? []);
            }
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        debugPrint('Error in Profile Screen stream: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );

    _appsSubscription = _jobService.getMyApplicationsStream().listen((apps) {
      if (mounted) {
        setState(() {
          _appliedCount = apps.length;
        });
      }
    });

    // Also get profile picture
    _resumeService.getLatestResumeAnalysis().then((data) {
      if (data != null && mounted) {
        setState(() {
          _profilePictureUrl = data['profilePictureUrl'];
        });
      }
    });
  }

  @override
  void dispose() {
    _resumeSubscription?.cancel();
    _appsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isWeb = MediaQuery.of(context).size.width >= 1100;

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6366F1)),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWeb ? 32 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(isWeb),
          const SizedBox(height: 32),
          _buildEmployabilityScore(isWeb),
          const SizedBox(height: 32),
          Text(
            'Education Details',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _headingColor,
            ),
          ),
          const SizedBox(height: 16),
          _buildEducationSection(),
          const SizedBox(height: 32),
          Text(
            'Professional Experience',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _headingColor,
            ),
          ),
          const SizedBox(height: 16),
          _buildExperienceSection(),
          const SizedBox(height: 32),
          Text(
            'Achievements & Badges',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _headingColor,
            ),
          ),
          const SizedBox(height: 16),
          _buildBadgeGrid(isWeb),
          const SizedBox(height: 32),
          Text(
            'Technical Expertise',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _headingColor,
            ),
          ),
          const SizedBox(height: 16),
          _buildSkillsSection(),
          const SizedBox(height: 32),
          Text(
            'Certifications',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _headingColor,
            ),
          ),
          const SizedBox(height: 16),
          _buildCertificatesSection(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(bool isWeb) {
    Widget profileInfo = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            ),
          ),
          child: Stack(
            children: [
              CircleAvatar(
                radius: isWeb ? 50 : 40,
                backgroundImage:
                    _profilePictureUrl != null &&
                        _profilePictureUrl!.startsWith('data:image')
                    ? MemoryImage(
                        base64Decode(_profilePictureUrl!.split(',').last),
                      )
                    : NetworkImage(
                            'https://api.dicebear.com/7.x/avataaars/png?seed=$_name',
                          )
                          as ImageProvider,
                backgroundColor: widget.isDarkMode ? const Color(0xFF0F172A) : Colors.white,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickProfilePicture,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF6366F1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: isWeb ? 32 : 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _name,
                style: TextStyle(
                  fontSize: isWeb ? 32 : 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _location,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: isWeb ? 14 : 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  'AI-Analyzed Candidate',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFFA5B4FC),
                    fontSize: isWeb ? 13 : 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _buildStatMini(
                    (_overallScore / 20.0).toStringAsFixed(1),
                    'AI Rating',
                  ),
                  SizedBox(width: isWeb ? 32 : 20),
                  _buildStatMini(_appliedCount.toString(), 'Applied'),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.all(isWeb ? 32 : 20),
      decoration: BoxDecoration(
        color: _skyBlueBox,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: widget.isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: isWeb
          ? Row(
              children: [
                Expanded(child: profileInfo),
                const SizedBox(width: 32),
                Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _showEditProfileDialog,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit Profile'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 18,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _handleLogout(context),
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Logout'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 36,
                          vertical: 18,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Column(
              children: [
                profileInfo,
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showEditProfileDialog,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _handleLogout(context),
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Logout'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _handleLogout(BuildContext context) async {
    await AuthService().signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Widget _buildEducationSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: widget.isDarkMode ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.school_outlined,
                color: Color(0xFF6366F1),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                "Extracted Academic History",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ..._formatContent(
            _education.isEmpty
                ? "No education details found in the latest resume."
                : _education,
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: widget.isDarkMode ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.work_outline,
                color: Color(0xFF6366F1),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                "Extracted Working Experience",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ..._formatContent(
            _experience.isEmpty
                ? "No experience details found in the latest resume."
                : _experience,
          ),
        ],
      ),
    );
  }

  List<Widget> _formatContent(String content) {
    if (content.isEmpty || content.startsWith("No ")) {
      return [
        Text(
          content,
          style: TextStyle(
            fontSize: 15,
            height: 1.6,
            color: _mutedText,
          ),
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
        titleStr = titleStr.replaceAll(RegExp(r'[|]\s*$'), '').trim();

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  titleStr,
                  style: TextStyle(
                    color: _textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                dateStr,
                style: TextStyle(color: _mutedText, fontSize: 13),
              ),
            ],
          ),
        );
      }

      bool isBullet =
          cleanLine.startsWith('•') ||
          cleanLine.startsWith('*') ||
          cleanLine.startsWith('-');
      return Padding(
        padding: EdgeInsets.only(left: isBullet ? 12 : 0, bottom: 4),
        child: Text(
          cleanLine,
          style: TextStyle(
            color: _mutedText,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      );
    }).toList();
  }

  Widget _buildStatMini(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: _textColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: _mutedText,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildEmployabilityScore(bool isWeb) {
    return Container(
      padding: EdgeInsets.all(isWeb ? 32 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.isDarkMode 
              ? [const Color(0xFF6366F1), const Color(0xFF8B5CF6)]
              : [const Color(0xFF2563EB), const Color(0xFF0EA5E9)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: isWeb
          ? Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Employability Score',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'AI-powered analysis of your technical profile and experience.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          _buildScorePart(
                            'Experience',
                            (_breakdown['experience'] ?? 0.0).toString(),
                          ),
                          const SizedBox(width: 32),
                          _buildScorePart(
                            'Education',
                            (_breakdown['education'] ?? 0.0).toString(),
                          ),
                          const SizedBox(width: 32),
                          _buildScorePart(
                            'Skills',
                            (_breakdown['skills'] ?? 0.0).toString(),
                          ),
                          const SizedBox(width: 32),
                          _buildScorePart(
                            'Certs',
                            (_breakdown['certificates'] ?? 0.0).toString(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _overallScore.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        '/ 100',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Employability Score',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'AI-powered analysis of your profile.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      height: 80,
                      width: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _overallScore.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            '/ 100',
                            style: TextStyle(color: Colors.white70, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildScorePart(
                      'Experience',
                      (_breakdown['experience'] ?? 0.0).toString(),
                    ),
                    _buildScorePart(
                      'Education',
                      (_breakdown['education'] ?? 0.0).toString(),
                    ),
                    _buildScorePart(
                      'Skills',
                      (_breakdown['skills'] ?? 0.0).toString(),
                    ),
                    _buildScorePart(
                      'Certs',
                      (_breakdown['certificates'] ?? 0.0).toString(),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildScorePart(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildBadgeGrid(bool isWeb) {
    if (_userBadges.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cardBorder),
        ),
        child: Center(
          child: Text(
            "No badges earned yet. Complete your profile to earn badges!",
            style: TextStyle(color: _mutedText, fontSize: 14),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _userBadges.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWeb ? 4 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 2.5,
      ),
      itemBuilder: (context, index) {
        var badgeName = _userBadges[index];
        var def =
            _badgeDefinitions[badgeName] ??
            {'icon': Icons.stars, 'color': Colors.grey};

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isDarkMode ? (def['color'] as Color).withValues(alpha: 0.2) : Colors.grey.shade300,
              width: 1.5,
            ),
            boxShadow: widget.isDarkMode ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
          ),
          child: Row(
            children: [
              Icon(def['icon'], color: def['color'], size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  badgeName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: _textColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSkillsSection() {
    final skillsToShow = _skills.isEmpty ? ['No skills extracted'] : _skills;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: skillsToShow
          .map(
            (s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _cardBorder),
                boxShadow: widget.isDarkMode ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _textColor,
                      fontSize: 14,
                    ),
                  ),
                  if (_skills.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.verified,
                      color: Color(0xFF6366F1),
                      size: 16,
                    ),
                  ],
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildCertificatesSection() {
    final certsToShow =
        _certificates.isEmpty ? ['No certifications added'] : _certificates;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children:
          certsToShow.map((c) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _cardBorder),
                boxShadow:
                    widget.isDarkMode
                        ? null
                        : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 5,
                          ),
                        ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    c,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _textColor,
                      fontSize: 14,
                    ),
                  ),
                  if (_certificates.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.card_membership,
                      color: Color(0xFF6366F1),
                      size: 16,
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
    );
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _name);
    final locationController = TextEditingController(text: _location);
    final educationController = TextEditingController(text: _education);
    final experienceController = TextEditingController(text: _experience);
    final skillsController = TextEditingController(text: _skills.join(', '));
    final certificatesController =
        TextEditingController(text: _certificates.join(', '));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor:
            widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        title: Text(
          'Update Professional Profile',
          style: TextStyle(
            color: _headingColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildEditField('Name', nameController, Icons.person_outline),
                const SizedBox(height: 16),
                _buildEditField(
                  'Location',
                  locationController,
                  Icons.location_on_outlined,
                ),
                const SizedBox(height: 16),
                _buildEditField(
                  'Education',
                  educationController,
                  Icons.school_outlined,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                _buildEditField(
                  'Experience',
                  experienceController,
                  Icons.work_outline,
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                _buildEditField(
                  'Skills (comma separated)',
                  skillsController,
                  Icons.bolt_outlined,
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                _buildEditField(
                  'Certificates (comma separated)',
                  certificatesController,
                  Icons.card_membership_outlined,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              List<String> updatedSkills =
                  skillsController.text
                      .split(',')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .toList();

              List<String> updatedCerts =
                  certificatesController.text
                      .split(',')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .toList();

              await _resumeService.updateProfile(
                name: nameController.text,
                location: locationController.text,
                education: educationController.text,
                experience: experienceController.text,
                skills: updatedSkills,
                certificates: updatedCerts,
              );
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEditField(
    String label,
    TextEditingController controller,
    IconData icon, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: _headingColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _mutedText, fontSize: 14),
        prefixIcon: Icon(icon, color: const Color(0xFF6366F1), size: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
        ),
        filled: true,
        fillColor: widget.isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.shade50,
      ),
    );
  }

  Future<void> _pickProfilePicture() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result != null && result.files.first.bytes != null) {
      final bytes = result.files.first.bytes!;
      final base64Image = 'data:image/png;base64,${base64Encode(bytes)}';

      await _resumeService.updateProfile(profilePictureUrl: base64Image);

      setState(() {
        _profilePictureUrl = base64Image;
      });
    }
  }
}
