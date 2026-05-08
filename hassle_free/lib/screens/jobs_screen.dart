import 'package:flutter/material.dart';
import '../services/job_service.dart';
import '../services/resume_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../features/mock_interview/screens/mock_interview_screen.dart';
import '../features/mock_interview/viewmodels/mock_interview_viewmodel.dart';
import 'dart:async';

class JobsScreen extends StatefulWidget {
  final bool isDarkMode;
  final String? initialSearchQuery;
  const JobsScreen({super.key, this.isDarkMode = true, this.initialSearchQuery});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  Color get _textColor => widget.isDarkMode ? Colors.white : Colors.black87;
  Color get _mutedText => widget.isDarkMode ? Colors.white60 : Colors.black54;
  Color get _cardBg =>
      widget.isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.white;
  Color get _cardBorder => widget.isDarkMode
      ? Colors.white.withValues(alpha: 0.05)
      : Colors.grey.shade300;

  final JobService _jobService = JobService();
  final ResumeService _resumeService = ResumeService();

  List<Map<String, dynamic>> _allJobs = [];
  List<Map<String, dynamic>> _filteredJobs = [];
  List<String> _userSkills = [];
  Map<String, dynamic>? _lastResumeData;
  Set<String> _appliedJobs = {};
  String _userName = "";
  bool _isLoading = true;
  String _searchQuery = "";
  StreamSubscription? _jobsSubscription;
  StreamSubscription? _resumeSubscription;
  late TextEditingController _searchController;

  // Filter values
  String _selectedType = 'All';
  String _selectedSalaryRange = 'All';

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialSearchQuery ?? "";
    _searchController = TextEditingController(text: _searchQuery);
    _startListening();
  }

  void _startListening() {
    setState(() => _isLoading = true);

    // Listen to resume changes
    _resumeSubscription = _resumeService.getLatestResumeAnalysisStream().listen(
      (data) {
        if (mounted) {
          setState(() {
            if (data != null) {
              _lastResumeData = data;
              _userSkills = List<String>.from(data['skills'] ?? []);
              _userName = data['name'] ?? "";
            }
            _processJobs();
          });
        }
      },
    );

    // Listen to job changes
    _jobsSubscription = _jobService.getAllActiveJobsStream().listen((jobs) {
      if (mounted) {
        setState(() {
          _allJobs = jobs;
          _processJobs();
          _isLoading = false;
        });
      }
    });

    // Listen to my applications to update "Apply" button status
    _jobService.getMyApplicationsStream().listen((appliedJobIds) {
      if (mounted) {
        setState(() {
          _appliedJobs = appliedJobIds.toSet();
        });
      }
    });
  }

  @override
  void dispose() {
    _jobsSubscription?.cancel();
    _resumeSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _processJobs() {
    _filteredJobs = _allJobs.map((job) {
      List<String> requiredSkills = List<String>.from(
        job['requiredSkills'] ?? [],
      );
      int score = _calculateMatchScore(_userSkills, requiredSkills);

      return {
        ...job,
        'matchScore': score,
        'tags': requiredSkills, // Map requiredSkills to tags for UI
        'isHot':
            score >= 90, // Example: jobs with high match are "hot" for the user
      };
    }).toList();

    // Sort by match score descending
    _filteredJobs.sort(
      (a, b) => (b['matchScore'] as int).compareTo(a['matchScore'] as int),
    );

    // Apply search filter if any
    if (_searchQuery.isNotEmpty) {
      _filteredJobs = _filteredJobs.where((job) {
        final title = job['title'].toString().toLowerCase();
        final company = job['company'].toString().toLowerCase();
        return title.contains(_searchQuery.toLowerCase()) ||
            company.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Apply Advanced Filters
    if (_selectedType != 'All') {
      _filteredJobs = _filteredJobs
          .where((job) => job['type'] == _selectedType)
          .toList();
    }

    // Salary filter is harder because it's a string, we'll do a simple range match if possible
    if (_selectedSalaryRange != 'All') {
      // Example: "$1000 - $2000"
      _filteredJobs = _filteredJobs.where((job) {
        final salary = job['salaryRange'] ?? "";
        return salary.contains(_selectedSalaryRange);
      }).toList();
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
          _buildHeader(isWeb),
          const SizedBox(height: 32),
          _buildSearchBar(),
          const SizedBox(height: 32),
          Text(
            isWeb ? 'Recommended for You' : 'Top Recommendations',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 20),
          _filteredJobs.isEmpty
              ? _buildEmptyState()
              : isWeb
              ? _buildWebJobGrid()
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredJobs.length,
                  itemBuilder: (context, index) =>
                      _buildJobCard(_filteredJobs[index]),
                ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isWeb) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _userName.isNotEmpty
                  ? 'Jobs for $_userName'
                  : 'Explore Opportunities',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            Text(
              _userSkills.isNotEmpty
                  ? 'Matched with ${_userSkills.length} skills from your resume'
                  : 'Upload your resume for better job matches',
              style: TextStyle(color: _mutedText),
            ),
          ],
        ),
        if (isWeb)
          ElevatedButton.icon(
            onPressed: () => _showFilterDialog(),
            icon: const Icon(Icons.filter_list, size: 18),
            label: const Text('Advanced Filter'),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.isDarkMode
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.shade200,
              foregroundColor: _textColor,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
      ],
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: widget.isDarkMode
              ? const Color(0xFF1E293B)
              : Colors.white,
          title: Text('Advanced Filters', style: TextStyle(color: _textColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFilterDropdown(
                'Job Type',
                _selectedType,
                ['All', 'Full-time', 'Part-time', 'Contract', 'Remote'],
                (val) => setDialogState(() => _selectedType = val!),
              ),
              const SizedBox(height: 16),
              _buildFilterDropdown(
                'Salary Range',
                _selectedSalaryRange,
                ['All', '\$500', '\$1000', '\$2000', '\$3000'],
                (val) => setDialogState(() => _selectedSalaryRange = val!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _processJobs();
                setState(() {});
                Navigator.pop(context);
              },
              child: const Text(
                'Apply Filters',
                style: TextStyle(color: Color(0xFF6366F1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: _mutedText, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            dropdownColor: widget.isDarkMode
                ? const Color(0xFF1E293B)
                : Colors.white,
            underline: const SizedBox(),
            items: items
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(e, style: TextStyle(color: _textColor)),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: widget.isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                ),
              ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            _processJobs();
          });
        },
        style: TextStyle(color: _textColor),
        decoration: InputDecoration(
          hintText: 'Search for jobs, companies, or keywords...',
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search, color: Color(0xFF6366F1)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: _mutedText, size: 20),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = "";
                      _processJobs();
                    });
                  },
                )
              : null,
          hintStyle: TextStyle(color: _mutedText),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.work_outline,
            size: 64,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'No jobs available right now'
                : 'No matching jobs found',
            style: TextStyle(color: _mutedText, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildWebJobGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredJobs.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        mainAxisExtent: 250,
      ),
      itemBuilder: (context, index) => _buildJobCard(_filteredJobs[index]),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    bool isHot = job['isHot'];
    int score = job['matchScore'];

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

    return Container(
      height: 250, // Added fixed height for mobile consistency
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder),
        boxShadow: widget.isDarkMode
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: job['image'] != null
                      ? Image.network(job['image'], fit: BoxFit.cover)
                      : Image.network(
                          'https://api.dicebear.com/7.x/initials/png?seed=${job['company']}',
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          job['title'],
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _textColor,
                          ),
                        ),
                        if (isHot)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'HOT',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${job['company']} • ${job['location']}',
                      style: TextStyle(color: _mutedText, fontSize: 14),
                    ),
                    if (expiryText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            color: Colors.orangeAccent,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            expiryText,
                            style: const TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _getScoreColor(score).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '$score%',
                      style: TextStyle(
                        color: _getScoreColor(score),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Match',
                      style: TextStyle(color: _mutedText, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              ...(job['tags'] as List<String>).map(
                (tag) => Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _cardBorder),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(fontSize: 12, color: _mutedText),
                  ),
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    job['salaryRange'] ?? 'Negotiable',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _mutedText,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildApplyButton(job),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApplyButton(Map<String, dynamic> job) {
    String jobId = job['id'];
    bool applied = _appliedJobs.contains(jobId);

    return ElevatedButton(
      onPressed: applied ? null : () => _handleApply(job),
      style: ElevatedButton.styleFrom(
        backgroundColor: applied ? Colors.white10 : const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(applied ? 'Applied' : 'Apply Now'),
    );
  }

  Future<void> _handleApply(Map<String, dynamic> job) async {
    if (_lastResumeData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload your resume first!')),
      );
      return;
    }

    int score = job['matchScore'] ?? 0;
    if (score < 40) {
      _showLowScoreWarning(score);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isDarkMode
            ? const Color(0xFF1E293B)
            : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Apply for ${job['title']}',
          style: TextStyle(color: _textColor, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Choose your application method:',
          style: TextStyle(color: _mutedText),
        ),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Apply with Resume Only'),
                  onPressed: () {
                    Navigator.pop(context);
                    _submitApplication(job, false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(
                      0xFF6366F1,
                    ).withValues(alpha: 0.1),
                    foregroundColor: const Color(0xFF818CF8),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.video_call_outlined),
                  label: const Text('Apply with Resume & Interview'),
                  onPressed: () {
                    Navigator.pop(context);
                    _submitApplication(job, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submitApplication(
    Map<String, dynamic> job,
    bool withInterview,
  ) async {
    if (withInterview) {
      // Navigate to Interview first, it will handle submission at the end
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final skills = List<String>.from(_lastResumeData!['skills'] ?? []);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider(
              create: (_) => MockInterviewViewModel(),
              child: MockInterviewScreen(
                userId: user.uid,
                jobRole: job['title'],
                skills: skills,
                resumeData: _lastResumeData,
                jobId: job['id'],
                jobDescription: job['description'] ?? "",
                isDarkMode: widget.isDarkMode,
                onExit: () => Navigator.of(context).pop(),
              ),

            ),
          ),
        );
      }
      return;
    }

    // Apply with Resume Only
    final success = await _jobService.applyForJob(
      jobId: job['id'],
      resumeData: _lastResumeData!,
    );

    if (success && mounted) {
      setState(() {
        _appliedJobs.add(job['id']);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully applied for ${job['title']}!')),
      );
    }
  }

  Color _getScoreColor(int score) {
    if (score >= 90) return Colors.green;
    if (score >= 80) return Colors.blue;
    if (score >= 70) return Colors.orange;
    return Colors.red;
  }

  void _showLowScoreWarning(int score) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            Text('Low Match Score', style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your current match score is $score%.',
              style: TextStyle(color: _textColor, fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text(
              'To ensure high-quality applications, a minimum match score of 40% is required to apply for this position.',
              style: TextStyle(color: _mutedText),
            ),
            const SizedBox(height: 16),
            Text(
              'Tip: Try updating your resume with relevant skills to improve your match score!',
              style: const TextStyle(color: Color(0xFF6366F1), fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
