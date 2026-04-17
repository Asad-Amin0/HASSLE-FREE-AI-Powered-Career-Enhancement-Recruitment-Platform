import 'package:flutter/material.dart';
import '../services/job_service.dart';

class PostJobScreen extends StatefulWidget {
  final Map<String, dynamic>? job;
  const PostJobScreen({super.key, this.job});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _jobService = JobService();

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
  final List<String> _resumeThemes = ['Professional', 'Creative', 'Modern'];

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
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _companyController,
                      label: 'Company Name',
                      hint: 'Your company',
                      icon: Icons.business,
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
              _buildDropdown(
                label: 'Required Resume Theme',
                value: _selectedTheme,
                items: _resumeThemes,
                onChanged: (val) => setState(() => _selectedTheme = val!),
                icon: Icons.palette_outlined,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _salaryController,
                label: 'Salary Range',
                hint: 'e.g. \$80k - \$100k or PKR 200k - 300k',
                icon: Icons.attach_money,
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
          style: const TextStyle(color: Colors.white),
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
}
