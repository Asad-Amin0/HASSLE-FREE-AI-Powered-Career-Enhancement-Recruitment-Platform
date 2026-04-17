import 'package:flutter/material.dart';
import '../services/company_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class CompanyProfileScreen extends StatefulWidget {
  const CompanyProfileScreen({super.key});

  @override
  State<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends State<CompanyProfileScreen> {
  final CompanyService _companyService = CompanyService();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _industryController = TextEditingController();
  final _websiteController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _employeeCountController = TextEditingController();

  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _industryController.dispose();
    _websiteController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _employeeCountController.dispose();
    super.dispose();
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final success = await _companyService.updateCompanyProfile({
      'name': _nameController.text.trim(),
      'industry': _industryController.text.trim(),
      'website': _websiteController.text.trim(),
      'location': _locationController.text.trim(),
      'about': _descriptionController.text.trim(),
      'employeeCount': _employeeCountController.text.trim(),
    });

    setState(() {
      _isLoading = false;
      if (success) _isEditing = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Profile updated!' : 'Failed to update profile'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 1100;

    return StreamBuilder<Map<String, dynamic>>(
      stream: _companyService.getCompanyProfileStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
        }

        final profile = snapshot.data ?? {};
        if (!_isEditing) {
          _nameController.text = profile['name'] ?? '';
          _industryController.text = profile['industry'] ?? '';
          _websiteController.text = profile['website'] ?? '';
          _locationController.text = profile['location'] ?? '';
          _descriptionController.text = profile['about'] ?? '';
          _employeeCountController.text = profile['employeeCount'] ?? '';
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isMobile),
              const SizedBox(height: 32),
              _buildProfileContent(profile, isMobile),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Company Profile',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -1),
            ),
            Text(
              'Manage your company details and branding',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ],
        ),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () {
                if (_isEditing) {
                  _saveProfile();
                } else {
                  setState(() => _isEditing = true);
                }
              },
              icon: _isLoading 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(_isEditing ? Icons.save : Icons.edit, color: Colors.white, size: 20),
              label: Text(_isEditing ? 'Save Profile' : 'Edit Profile', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isEditing ? Colors.green : const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () => _handleLogout(context),
              icon: const Icon(Icons.logout, size: 20),
              label: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ],
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

  Widget _buildProfileContent(Map<String, dynamic> profile, bool isMobile) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Branding Card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              children: [
                // Cover
                Container(
                  height: 160,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFF06B6D4)]),
                  ),
                ),
                // Details
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildLogoPlaceholder(
                        (profile['name'] != null && profile['name'].toString().isNotEmpty)
                            ? profile['name'].toString()[0].toUpperCase()
                            : 'C',
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isEditing)
                              _buildInlineTextField(_nameController, 'Company Name', Icons.business)
                            else
                              Text(profile['name'] ?? 'Add Company Name', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(height: 8),
                            if (_isEditing)
                              _buildInlineTextField(_industryController, 'Industry', Icons.category_outlined)
                            else
                              Text(profile['industry'] ?? 'Industry not set', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Info Grid
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: isMobile ? 1 : 2,
                child: Column(
                  children: [
                    _buildInfoCard(
                      'About Company',
                      _isEditing 
                        ? _buildMultiLineTextField(_descriptionController, 'Describe your company...')
                        : Text(profile['about'] ?? 'No description provided.', style: const TextStyle(color: Colors.white70, height: 1.6)),
                    ),
                  ],
                ),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 32),
                Expanded(
                  child: Column(
                    children: [
                      _buildInfoCard(
                        'Details',
                        Column(
                          children: [
                            _buildInfoItem(Icons.public, 'Website', profile['website'], _websiteController),
                            const Divider(height: 32, color: Colors.white10),
                            _buildInfoItem(Icons.location_on_outlined, 'Headquarters', profile['location'], _locationController),
                            const Divider(height: 32, color: Colors.white10),
                            _buildInfoItem(Icons.people_outline, 'Company Size', profile['employeeCount'], _employeeCountController),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (isMobile) ...[
            const SizedBox(height: 32),
            _buildInfoCard(
              'Details',
              Column(
                children: [
                  _buildInfoItem(Icons.public, 'Website', profile['website'], _websiteController),
                  const Divider(height: 32, color: Colors.white10),
                  _buildInfoItem(Icons.location_on_outlined, 'Headquarters', profile['location'], _locationController),
                  const Divider(height: 32, color: Colors.white10),
                  _buildInfoItem(Icons.people_outline, 'Company Size', profile['employeeCount'], _employeeCountController),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogoPlaceholder(String initial) {
    return Transform.translate(
      offset: const Offset(0, -50),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF6366F1), width: 4),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10)],
        ),
        child: Center(
          child: Text(initial, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, Widget content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 24),
          content,
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String? value, TextEditingController controller) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 18, color: const Color(0xFF6366F1)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
              if (_isEditing)
                _buildInlineTextField(controller, label, null)
              else
                Text(value ?? 'Not set', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInlineTextField(TextEditingController controller, String hint, IconData? icon) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white24),
        prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF6366F1), size: 18) : null,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF6366F1))),
      ),
    );
  }

  Widget _buildMultiLineTextField(TextEditingController controller, String hint) {
    return TextFormField(
      controller: controller,
      maxLines: 5,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.03),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}
