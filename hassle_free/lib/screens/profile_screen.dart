import 'dart:async';
import 'package:flutter/material.dart';
import '../services/resume_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ResumeService _resumeService = ResumeService();
  String _name = "User";
  String _location = "Lahore, Punjab, Pakistan";
  String _education = "";
  String _experience = "";
  List<String> _skills = [];
  bool _isLoading = true;
  StreamSubscription? _resumeSubscription;

  final List<Map<String, dynamic>> _badges = [
    {'title': 'Top Technical', 'icon': Icons.code, 'color': Colors.blueAccent},
    {'title': 'Analytical Expert', 'icon': Icons.analytics, 'color': Colors.purpleAccent},
    {'title': 'Effective Communicator', 'icon': Icons.chat_bubble, 'color': Colors.greenAccent},
    {'title': 'Fast Learner', 'icon': Icons.bolt, 'color': Colors.orangeAccent},
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _subscribeToProfileData();
  }

  Future<void> _loadInitialData() async {
    final data = await _resumeService.getLatestResumeAnalysis();
    if (data != null && mounted) {
      setState(() {
        _name = data['name'] ?? "User";
        _location = data['location'] ?? "Lahore, Punjab, Pakistan";
        _education = data['education'] ?? "";
        _experience = data['experience'] ?? "";
        _skills = List<String>.from(data['skills'] ?? []);
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

    // Safety timeout to prevent infinite loading if the stream is silent
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _resumeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isWeb = MediaQuery.of(context).size.width >= 1100;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
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
          const Text(
            'Education Details',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          _buildEducationSection(),
          const SizedBox(height: 32),
          const Text(
            'Professional Experience',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          _buildExperienceSection(),
          const SizedBox(height: 32),
          const Text(
            'Achievements & Badges',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          _buildBadgeGrid(isWeb),
          const SizedBox(height: 32),
          const Text(
            'Technical Expertise',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          _buildSkillsSection(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(bool isWeb) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
            ),
            child: CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage('https://api.dicebear.com/7.x/avataaars/png?seed=$_name'),
              backgroundColor: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5),
                ),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.white.withValues(alpha: 0.5)),
                    const SizedBox(width: 4),
                    Text(_location, style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
                  ),
                  child: const Text(
                    'AI-Analyzed Candidate',
                    style: TextStyle(color: Color(0xFFA5B4FC), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildStatMini('12', 'Projects'),
                    const SizedBox(width: 32),
                    _buildStatMini('4.9', 'AI Rating'),
                    const SizedBox(width: 32),
                    _buildStatMini('24', 'Applied'),
                  ],
                ),
                if (!isWeb) ...[
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isWeb)
            Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _showEditProfileDialog,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit Profile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
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
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school_outlined, color: Color(0xFF6366F1), size: 24),
              const SizedBox(width: 12),
              const Text("Extracted Academic History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 20),
          ..._formatContent(_education.isEmpty ? "No education details found in the latest resume." : _education),
        ],
      ),
    );
  }

  Widget _buildExperienceSection() {
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
              const Icon(Icons.work_outline, color: Color(0xFF6366F1), size: 24),
              const SizedBox(width: 12),
              const Text("Extracted Working Experience", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 20),
          ..._formatContent(_experience.isEmpty ? "No experience details found in the latest resume." : _experience),
        ],
      ),
    );
  }

  List<Widget> _formatContent(String content) {
    if (content.isEmpty || content.startsWith("No ")) {
      return [Text(content, style: TextStyle(fontSize: 15, height: 1.6, color: Colors.white.withValues(alpha: 0.8)))];
    }

    List<String> lines = content.split('\n');
    return lines.map((line) {
      String cleanLine = line.trim();
      if (cleanLine.isEmpty) return const SizedBox(height: 8);

      // Regex for dates like "Feb 2025 - Apr 2025" or "2022 - 2026"
      final datePattern = RegExp(r'([A-Za-z]+ \d{4} - [A-Za-z]+ \d{4})|(\d{4}\s*-\s*\d{4})');
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
              Expanded(child: Text(titleStr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
              Text(dateStr, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        );
      }

      bool isBullet = cleanLine.startsWith('•') || cleanLine.startsWith('*') || cleanLine.startsWith('-');
      return Padding(
        padding: EdgeInsets.only(left: isBullet ? 12 : 0, bottom: 4),
        child: Text(
          cleanLine,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
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
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white)),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
      ],
    );
  }

  Widget _buildEmployabilityScore(bool isWeb) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Employability Score',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'AI-powered analysis of your technical profile and experience.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _buildScorePart('Technical', '9.2'),
                    const SizedBox(width: 32),
                    _buildScorePart('Soft Skills', '8.5'),
                    const SizedBox(width: 32),
                    _buildScorePart('Interview', '8.8'),
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
              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('8.8', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                Text('/ 10', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScorePart(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
      ],
    );
  }

  Widget _buildBadgeGrid(bool isWeb) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _badges.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWeb ? 4 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 2.5,
      ),
      itemBuilder: (context, index) {
        var b = _badges[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: (b['color'] as Color).withValues(alpha: 0.2), width: 1.5),
          ),
          child: Row(
            children: [
              Icon(b['icon'], color: b['color'], size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  b['title'],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
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
          .map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 14)),
                    if (_skills.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.verified, color: Color(0xFF6366F1), size: 16),
                    ],
                  ],
                ),
              ))
          .toList(),
    );
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _name);
    final locationController = TextEditingController(text: _location);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(color: Colors.white60),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: locationController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Location',
                labelStyle: TextStyle(color: Colors.white60),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              await _resumeService.updateProfile(
                name: nameController.text,
                location: locationController.text,
              );
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}


