import 'package:flutter/material.dart';
import '../services/job_service.dart';
import '../services/company_service.dart';

class PostJobScreen extends StatefulWidget {
  final Map<String, dynamic>? job;
  const PostJobScreen({super.key, this.job});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _jobService = JobService();
  final _companyService = CompanyService();

  @override
  void initState() {
    super.initState();
    if (widget.job != null) {
      _titleController.text = widget.job!['title'] ?? '';
      _companyController.text = widget.job!['company'] ?? '';
      _locationController.text = widget.job!['location'] ?? '';
      _salaryController.text = widget.job!['salaryRange'] ?? '';
      _descriptionController.text = widget.job!['description'] ?? '';
      _selectedJobType = widget.job!['type'] ?? 'Full-time';
      _selectedExperience = widget.job!['experienceLevel'] ?? 'Mid-Level';
      _selectedTheme = widget.job!['resumeTheme'] ?? 'Modern';
      if (widget.job!['requiredSkills'] != null) {
        _skills.addAll(List<String>.from(widget.job!['requiredSkills']));
      }
    } else {
      _loadCompanyData();
    }
  }

  Future<void> _loadCompanyData() async {
    final profile = await _companyService.getCompanyProfile();
    if (profile.isNotEmpty) {
      setState(() {
        _companyController.text = profile['name'] ?? '';
        if (_locationController.text.isEmpty) {
          _locationController.text = profile['location'] ?? '';
        }
      });
    }
  }

  final _titleController = TextEditingController();
  final _companyController = TextEditingController();
  final _locationController = TextEditingController();
  final _salaryController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _selectedJobType = 'Full-time';
  final List<String> _jobTypes = ['Full-time', 'Part-time', 'Contract', 'Remote', 'Internship'];

  String _selectedExperience = 'Mid-Level';
  final List<String> _experienceLevels = ['Entry-Level', 'Mid-Level', 'Senior', 'Lead', 'Manager'];

  String _selectedTheme = 'Modern';
  Color _selectedThemeColor = const Color(0xFF6366F1);
  final List<String> _resumeThemes = ['Professional', 'Modern', 'Creative', 'ATS-Optimized'];
  final List<Color> _themeColors = [
    const Color(0xFF1E293B), // Charcoal
    const Color(0xFF0D9488), // Teal
    const Color(0xFF3B82F6), // Blue
    const Color(0xFF1E3A8A), // Navy
    const Color(0xFF0EA5E9), // Sky
    const Color(0xFFA8A29E), // Taupe
    const Color(0xFFF59E0B), // Orange
    const Color(0xFFE11D48), // Rose
  ];

  DateTime _selectedExpiryDate = DateTime.now().add(const Duration(days: 30));

  final List<String> _skills = [];
  final _skillController = TextEditingController();

  bool _isLoading = false;

  void _addSkill() {
    final skill = _skillController.text.trim();
    if (skill.isNotEmpty && !_skills.contains(skill)) {
      setState(() {
        _skills.add(skill);
        _skillController.clear();
      });
    }
  }

  void _removeSkill(String skill) {
    setState(() {
      _skills.remove(skill);
    });
  }

  Future<void> _submitJob() async {
    if (!_formKey.currentState!.validate()) return;
    if (_skills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one required skill.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    bool success = false;
    String? message;

    if (widget.job != null) {
      // Update existing job
      success = await _jobService.updateJob(widget.job!['id'], {
        'title': _titleController.text.trim(),
        'company': _companyController.text.trim(),
        'location': _locationController.text.trim(),
        'salaryRange': _salaryController.text.trim(),
        'type': _selectedJobType,
        'description': _descriptionController.text.trim(),
        'requiredSkills': _skills,
        'experienceLevel': _selectedExperience,
        'resumeTheme': _selectedTheme,
        'resumeColor': _selectedThemeColor.toARGB32().toRadixString(16),
        'expiryDate': _selectedExpiryDate,
      });
      message = success ? 'Job updated successfully!' : 'Failed to update job.';
    } else {
      // Post new job
      final jobId = await _jobService.postJob(
        title: _titleController.text.trim(),
        company: _companyController.text.trim(),
        location: _locationController.text.trim(),
        salaryRange: _salaryController.text.trim(),
        type: _selectedJobType,
        description: _descriptionController.text.trim(),
        requiredSkills: _skills,
        experienceLevel: _selectedExperience,
        resumeTheme: _selectedTheme,
        resumeColor: _selectedThemeColor.toARGB32().toRadixString(16),
        expiryDate: _selectedExpiryDate,
      );
      success = jobId != null;
      message = success ? 'Job posted successfully!' : 'Failed to post job.';
    }

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteJob() async {
    if (widget.job == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Job Posting', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this job posting?', style: TextStyle(color: Colors.white70)),
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
      setState(() => _isLoading = true);
      final success = await _jobService.deleteJob(widget.job!['id']);
      setState(() => _isLoading = false);
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Job deleted successfully'), backgroundColor: Colors.green),
          );
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete job'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _companyController.dispose();
    _locationController.dispose();
    _salaryController.dispose();
    _descriptionController.dispose();
    _skillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 1100;

    Widget mainContent = Scaffold(
      backgroundColor: isMobile ? const Color(0xFF0F172A) : Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.job != null ? 'Edit Job Posting' : 'Post a New Job', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: Icon(isMobile ? Icons.arrow_back : Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Basic Information'),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _titleController,
                label: 'Job Title',
                hint: 'e.g. Senior Flutter Developer',
                icon: Icons.work_outline,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _companyController,
                      label: 'Company Name',
                      hint: 'Your company',
                      icon: Icons.business,
                      readOnly: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _locationController,
                      label: 'Location',
                      hint: 'e.g. Remote, Lahore',
                      icon: Icons.location_on_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildDropdown(
                      label: 'Job Type',
                      value: _selectedJobType,
                      items: _jobTypes,
                      onChanged: (val) => setState(() => _selectedJobType = val!),
                      icon: Icons.access_time,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDropdown(
                      label: 'Experience Level',
                      value: _selectedExperience,
                      items: _experienceLevels,
                      onChanged: (val) => setState(() => _selectedExperience = val!),
                      icon: Icons.star_border,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Expanded(
                    child: _buildThemeSelector(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDatePicker(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _salaryController,
                label: 'Salary Range',
                hint: 'e.g. 50,000 PKR - 100,000 PKR or 1.5 - 2.5 Lacs',
                icon: Icons.payments_outlined,
              ),
              const SizedBox(height: 32),
              
              _buildSectionHeader('Requirements & Description'),
              const SizedBox(height: 16),
              _buildSkillsInput(),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _descriptionController,
                label: 'Job Description',
                hint: 'Describe the role, responsibilities, and benefits in detail...',
                icon: Icons.description_outlined,
                maxLines: 6,
              ),
              const SizedBox(height: 40),
              
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitJob,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          widget.job != null ? 'Update Job' : 'Post Job',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),
              if (widget.job != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _deleteJob,
                    icon: const Icon(Icons.delete_outline, size: 20),
                    label: const Text('Delete Job Posting'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );

    if (isMobile) return mainContent;

    return Container(
      width: 800,
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: mainContent,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 2,
          width: 40,
          color: const Color(0xFF6366F1),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          readOnly: readOnly,
          style: TextStyle(color: readOnly ? Colors.white60 : Colors.white),
          validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
            prefixIcon: maxLines == 1 ? Icon(icon, color: const Color(0xFF6366F1), size: 20) : null,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
            ),
            errorStyle: const TextStyle(color: Colors.redAccent),
          ),
        ),
      ],
    );
  }

  Widget _buildThemeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Required Resume Theme',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _showThemePicker,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                const Icon(Icons.palette_outlined, color: Color(0xFF6366F1), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedTheme,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showThemePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.only(top: 12),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              const Text('Choose Resume Template', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Selected theme will be required for applicants', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
              const SizedBox(height: 24),
              
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.55, // Taller cards for better visibility
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _resumeThemes.length,
                  itemBuilder: (context, index) {
                    final theme = _resumeThemes[index];
                    final isSelected = _selectedTheme == theme;

                    return StatefulBuilder(
                      builder: (context, setInnerState) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _selectedTheme = theme);
                                Navigator.pop(context);
                              },
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? _selectedThemeColor : Colors.white.withValues(alpha: 0.05), 
                                    width: 2
                                  ),
                                  color: Colors.white.withValues(alpha: 0.03),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: _buildResumePreview(theme, isSelected ? _selectedThemeColor : Colors.black87),
                                      ),
                                      
                                      // Selection Overlay
                                      if (isSelected)
                                        Container(
                                          decoration: BoxDecoration(
                                            color: _selectedThemeColor.withValues(alpha: 0.1),
                                          ),
                                        ),
                                      
                                      if (isSelected)
                                        Positioned(
                                          top: 12,
                                          right: 12,
                                          child: Icon(Icons.check_circle, color: _selectedThemeColor, size: 24),
                                        ),
                                        
                                      Positioned(
                                        bottom: 12,
                                        left: 12,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.5),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.remove_red_eye_outlined, color: Colors.white70, size: 12),
                                              const SizedBox(width: 4),
                                              Text('Preview', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Color Palette Picker
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _themeColors.map((color) {
                                bool isColorSelected = isSelected && _selectedThemeColor == color;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedTheme = theme;
                                        _selectedThemeColor = color;
                                      });
                                      setInnerState(() {}); // Update the preview color
                                    },
                                    child: Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isColorSelected ? Colors.white : Colors.transparent,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(theme, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text(
                            _getThemeDescription(theme),
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildResumePreview(String theme, Color primaryColor) {
    switch (theme) {
      case 'Professional':
        return _buildProfessionalPreview(primaryColor);
      case 'Modern':
        return _buildModernPreview(primaryColor);
      case 'Creative':
        return _buildCreativePreview(primaryColor);
      case 'ATS-Optimized':
        return _buildATSPreview(primaryColor);
      default:
        return _buildModernPreview(primaryColor);
    }
  }





  Widget _buildProfessionalPreview(Color primaryColor) {
    return Container(
      color: Colors.white,
      child: Row(
        children: [
          Container(
            width: 45,
            color: primaryColor,
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                const CircleAvatar(radius: 10, backgroundColor: Colors.white24, child: Icon(Icons.person, size: 10, color: Colors.white)),
                const SizedBox(height: 8),
                const Text('Sophie Walton', style: TextStyle(color: Colors.white, fontSize: 4, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                _buildSidebarItem('Details'),
                _buildSidebarItem('Skills'),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Profile', style: TextStyle(color: primaryColor, fontSize: 6, fontWeight: FontWeight.bold)),
                  _buildDummyText(4),
                  const SizedBox(height: 8),
                  Text('Employment History', style: TextStyle(color: primaryColor, fontSize: 6, fontWeight: FontWeight.bold)),
                  _buildDummyText(6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernPreview(Color primaryColor) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 15, width: double.infinity, color: primaryColor.withValues(alpha: 0.1)),
          const SizedBox(height: 8),
          Text('ALEXA REED', style: TextStyle(color: primaryColor, fontSize: 8, fontWeight: FontWeight.bold)),
          const Text('DIGITAL MARKETING MANAGER', style: TextStyle(color: Colors.black54, fontSize: 4)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildDummyText(10)),
              const SizedBox(width: 8),
              Container(width: 30, height: 60, color: Colors.grey[100]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCreativePreview(Color primaryColor) {
    return Container(
      color: primaryColor.withValues(alpha: 0.05),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          CircleAvatar(radius: 15, backgroundColor: primaryColor),
          const SizedBox(height: 8),
          Text('JORDAN SMITH', style: TextStyle(color: primaryColor, fontSize: 7, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: List.generate(6, (i) => Container(width: 20, height: 4, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)))),
          ),
          const SizedBox(height: 12),
          _buildDummyText(5),
        ],
      ),
    );
  }

  Widget _buildATSPreview(Color primaryColor) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('JOHN DOE', style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.bold)),
          const Text('Software Engineer | 123-456-7890 | email@example.com', style: TextStyle(color: Colors.black87, fontSize: 3.5)),
          const SizedBox(height: 8),
          _buildATSSection('SUMMARY', primaryColor),
          _buildATSSection('EXPERIENCE', primaryColor),
          _buildATSSection('EDUCATION', primaryColor),
        ],
      ),
    );
  }





  Widget _buildATSSection(String title, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: primaryColor, fontSize: 5, fontWeight: FontWeight.bold)),
        Divider(height: 4, thickness: 1, color: primaryColor),
        _buildDummyText(4),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildSidebarItem(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 3.5, fontWeight: FontWeight.bold)),
          Container(height: 1, width: 20, color: Colors.white12),
        ],
      ),
    );
  }

  Widget _buildDummyText(int lines) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(lines, (i) => Padding(
        padding: const EdgeInsets.only(bottom: 1.5),
        child: Container(
          height: 1.5,
          width: i == lines - 1 ? 40 : double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      )),
    );
  }


  String _getThemeDescription(String theme) {
    switch (theme) {
      case 'Professional': return 'Ideal for Doctors, Lawyers & Executives.';
      case 'Modern': return 'Best for IT, Tech & Software roles.';
      case 'Creative': return 'Perfect for Designers & Marketing.';
      case 'ATS-Optimized': return 'Standard for Engineering & Corporate.';
      default: return 'Professional resume template.';
    }
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF6366F1), size: 20),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
          ),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSkillsInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Required Skills',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _skillController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g. Flutter, Dart, Firebase',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                  prefixIcon: const Icon(Icons.code, color: Color(0xFF6366F1), size: 20),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onFieldSubmitted: (_) => _addSkill(),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: IconButton(
                onPressed: _addSkill,
                icon: const Icon(Icons.add, color: Color(0xFF6366F1)),
                tooltip: 'Add Skill',
              ),
            ),
          ],
        ),
        if (_skills.isNotEmpty) const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _skills.map((skill) {
            return Chip(
              label: Text(skill, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              backgroundColor: const Color(0xFF6366F1), // Using primary clear color
              deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white),
              onDeleted: () => _removeSkill(skill),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Expiry Date',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedExpiryDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: Color(0xFF6366F1),
                      onPrimary: Colors.white,
                      surface: Color(0xFF1E293B),
                      onSurface: Colors.white,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() {
                _selectedExpiryDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
              });
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.calendar_today_outlined, color: Color(0xFF6366F1), size: 20),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            child: Text(
              '${_selectedExpiryDate.day}/${_selectedExpiryDate.month}/${_selectedExpiryDate.year}',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}
