import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart';

class PdfGenerator {
  static Future<void> generateAndDownloadResume({
    required String name,
    required String jobTitle,
    required String email,
    required Map<String, dynamic> resumeData,
    String? seekerId,
    String theme = 'Modern',
    PdfColor primaryColor = PdfColors.indigo,
  }) async {
    final pdf = pw.Document();
    _addResumePage(pdf, name, jobTitle, email, resumeData, theme: theme, primaryColor: primaryColor);

    final fileName = "Resume_${name.replaceAll(' ', '_')}.pdf";
    
    if (kIsWeb) {
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: fileName,
      );
    } else {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: fileName,
      );
    }
  }

  static Future<void> generateBulkResumes(List<Map<String, dynamic>> candidates, {String theme = 'Modern', PdfColor primaryColor = PdfColors.indigo}) async {
    final pdf = pw.Document();
    
    for (var c in candidates) {
      final name = c['name'] ?? 'Candidate';
      final jobTitle = c['jobTitle'] ?? 'N/A';
      final email = c['seekerEmail'] ?? 'N/A';
      final resumeData = c['resumeData'] ?? {};
      
      _addResumePage(pdf, name, jobTitle, email, resumeData, theme: theme, primaryColor: primaryColor);
    }

    final dateStr = DateTime.now().toString().split(' ')[0];
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: "Bulk_Resumes_$dateStr.pdf",
    );
  }

  static void _addResumePage(
    pw.Document pdf,
    String name,
    String jobTitle,
    String email,
    Map<String, dynamic> resumeData, {
    String theme = 'Modern',
    PdfColor primaryColor = PdfColors.indigo,
  }) {
    final skills = List<String>.from(resumeData['skills'] ?? []);
    final experience = _sanitizeText(resumeData['experience'] ?? 'No experience details provided.');
    final education = _sanitizeText(resumeData['education'] ?? 'No education details provided.');
    final certificates = List<String>.from(resumeData['certificates'] ?? []);
    final badges = List<String>.from(resumeData['badges'] ?? []);
    final category = resumeData['category'] ?? 'Professional';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          switch (theme) {
            case 'Professional':
              return _buildProfessionalLayout(name, jobTitle, email, resumeData, skills, experience, education, certificates, badges, category, primaryColor);
            case 'Creative':
              return _buildCreativeLayout(name, jobTitle, email, resumeData, skills, experience, education, certificates, badges, category, primaryColor);
            case 'ATS-Optimized':
              return _buildATSLayout(name, jobTitle, email, resumeData, skills, experience, education, certificates, badges, category);
            case 'Modern':
            default:
              return _buildModernLayout(name, jobTitle, email, resumeData, skills, experience, education, certificates, badges, category, primaryColor);
          }
        },
      ),
    );
  }

  static pw.Widget _buildModernLayout(String name, String jobTitle, String email, Map<String, dynamic> resumeData, List<String> skills, String experience, String education, List<String> certificates, List<String> badges, String category, PdfColor primaryColor) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header
        pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(color: primaryColor),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    name.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.Text(
                    jobTitle,
                    style: const pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(email, style: const pw.TextStyle(color: PdfColors.white)),
                  pw.Text(category, style: const pw.TextStyle(color: PdfColors.grey300)),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 20),
        _buildBadgesSection(badges),
        _buildSectionTitle("TECHNICAL SKILLS", primaryColor),
        pw.Text(skills.join("  |  "), style: const pw.TextStyle(fontSize: 11)),
        pw.SizedBox(height: 15),
        if (certificates.isNotEmpty) ...[
          _buildSectionTitle("CERTIFICATIONS", primaryColor),
          ...certificates.map((c) => pw.Bullet(text: c, style: const pw.TextStyle(fontSize: 11))),
          pw.SizedBox(height: 15),
        ],
        _buildSectionTitle("PROFESSIONAL EXPERIENCE", primaryColor),
        pw.Text(experience, style: const pw.TextStyle(fontSize: 11, lineSpacing: 2)),
        pw.SizedBox(height: 15),
        _buildSectionTitle("ACADEMIC HISTORY", primaryColor),
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Text(education.isEmpty ? "No education details provided." : education, style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.2)),
        ),
        _buildFooter(),
      ],
    );
  }

  static pw.Widget _buildProfessionalLayout(String name, String jobTitle, String email, Map<String, dynamic> resumeData, List<String> skills, String experience, String education, List<String> certificates, List<String> badges, String category, PdfColor primaryColor) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Sidebar
        pw.Container(
          width: 150,
          color: primaryColor,
          padding: const pw.EdgeInsets.all(20),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(name.toUpperCase(), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              pw.Text(jobTitle, style: pw.TextStyle(fontSize: 12, color: PdfColor(1, 1, 1, 0.7))),
              pw.SizedBox(height: 30),
              pw.Text("CONTACT", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              pw.Divider(color: PdfColor(1, 1, 1, 0.3)),
              pw.Text(email, style: pw.TextStyle(fontSize: 10, color: PdfColor(1, 1, 1, 0.7))),
              pw.SizedBox(height: 30),
              pw.Text("SKILLS", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              pw.Divider(color: PdfColor(1, 1, 1, 0.3)),
              ...skills.map((s) => pw.Bullet(text: s, style: pw.TextStyle(fontSize: 10, color: PdfColor(1, 1, 1, 0.7)))),
              pw.SizedBox(height: 30),
              if (badges.isNotEmpty) ...[
                pw.Text("BADGES", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                pw.Divider(color: PdfColor(1, 1, 1, 0.3)),
                ...badges.map((b) => pw.Bullet(text: b, bulletColor: PdfColors.amber, style: const pw.TextStyle(fontSize: 10, color: PdfColors.amber))),
              ],
            ],
          ),
        ),
        // Main Content
        pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.all(30),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildSectionTitle("SUMMARY", primaryColor),
                pw.Text(resumeData['summary'] ?? "Professional $jobTitle with expertise in ${skills.take(3).join(', ')}.", style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.5)),
                pw.SizedBox(height: 30),
                _buildSectionTitle("EXPERIENCE", primaryColor),
                pw.Text(experience, style: const pw.TextStyle(fontSize: 11, lineSpacing: 2)),
                pw.SizedBox(height: 30),
                if (certificates.isNotEmpty) ...[
                  _buildSectionTitle("CERTIFICATIONS", primaryColor),
                  ...certificates.map((c) => pw.Bullet(text: c, style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.5))),
                  pw.SizedBox(height: 30),
                ],
                _buildSectionTitle("EDUCATION", primaryColor),
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 5),
                  child: pw.Text(education.isEmpty ? "No education details provided." : education, style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.5)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildCreativeLayout(String name, String jobTitle, String email, Map<String, dynamic> resumeData, List<String> skills, String experience, String education, List<String> certificates, List<String> badges, String category, PdfColor primaryColor) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Stylish Header (Reduced height)
        pw.Container(
          height: 80,
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 30, vertical: 10),
          decoration: pw.BoxDecoration(
            color: primaryColor,
            borderRadius: const pw.BorderRadius.only(bottomRight: pw.Radius.circular(40)),
          ),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(name, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              pw.Text(jobTitle, style: const pw.TextStyle(fontSize: 14, color: PdfColors.white, letterSpacing: 1.5)),
            ],
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(20),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 2,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle("PROFILE", primaryColor),
                    pw.Text(resumeData['summary'] ?? "${experience.split('.')[0]}.", style: const pw.TextStyle(fontSize: 8.5, height: 1.1)),
                    pw.SizedBox(height: 10),
                    _buildSectionTitle("EXPERIENCE", primaryColor),
                    pw.Text(experience, style: const pw.TextStyle(fontSize: 8.5, lineSpacing: 1.1)),
                    pw.SizedBox(height: 10),
                    _buildSectionTitle("EDUCATION", primaryColor),
                    pw.Text(education.isEmpty ? "No academic history provided." : education, style: const pw.TextStyle(fontSize: 8.5)),
                  ],
                ),
              ),
              pw.SizedBox(width: 40),
              pw.Expanded(
                flex: 1,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle("SKILLS", primaryColor),
                    ...skills.map((s) => pw.Bullet(text: s, style: const pw.TextStyle(fontSize: 8))),
                    pw.SizedBox(height: 15),
                    if (badges.isNotEmpty) ...[
                      _buildSectionTitle("BADGES", primaryColor),
                      ...badges.map((b) => pw.Bullet(text: b, bulletColor: PdfColors.orange, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.orange))),
                      pw.SizedBox(height: 15),
                    ],
                    if (certificates.isNotEmpty) ...[
                      _buildSectionTitle("CERTIFICATES", primaryColor),
                      ...certificates.map((c) => pw.Bullet(text: c, style: const pw.TextStyle(fontSize: 8))),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildATSLayout(String name, String jobTitle, String email, Map<String, dynamic> resumeData, List<String> skills, String experience, String education, List<String> certificates, List<String> badges, String category) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(40),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Center(child: pw.Text(name, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
          pw.Center(child: pw.Text("$jobTitle | $email", style: const pw.TextStyle(fontSize: 11))),
          pw.SizedBox(height: 30),
          pw.Text("SUMMARY", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Divider(thickness: 0.5),
          pw.Text(resumeData['summary'] ?? "Candidate seeking $jobTitle role.", style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 20),
          pw.Text("SKILLS", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Divider(thickness: 0.5),
          pw.Text(skills.join(", "), style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 20),
          pw.Text("EXPERIENCE", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Divider(thickness: 0.5),
          pw.Text(experience, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 20),
          pw.Text("EDUCATION", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Divider(thickness: 0.5),
          pw.Text(education.isEmpty ? "No education details recorded." : education, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  static pw.Widget _buildSectionTitle(String title, PdfColor color) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: color)),
        pw.Divider(color: PdfColors.grey300, thickness: 0.5),
        pw.SizedBox(height: 4),
      ],
    );
  }

  static pw.Widget _buildBadgesSection(List<String> badges) {
    if (badges.isEmpty) return pw.SizedBox.shrink();
    return pw.Column(
      children: [
        pw.Row(
          children: [
            pw.Text("AI VERIFIED BADGES: ", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800)),
            pw.Text(badges.join("  •  "), style: const pw.TextStyle(fontSize: 10, color: PdfColors.orange600)),
          ],
        ),
        pw.SizedBox(height: 15),
      ],
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey),
        pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Text("Generated by Hassle-Free AI Career Platform", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
        ),
      ],
    );
  }

  static String _sanitizeText(String text) {
    if (text.isEmpty) return "";
    // Replace problematic characters with safe alternatives
    return text
        .replaceAll('•', '-')
        .replaceAll('●', '-')
        .replaceAll('▪', '-')
        .replaceAll('✓', '[v]')
        .replaceAll('★', '*')
        .replaceAll('·', '-')
        .replaceAll('|', ' / ') // Vertical bars often fail
        .replaceAll('▯', ' - ') // Special separators
        .replaceAll('–', '-') // En dash
        .replaceAll('—', '-') // Em dash
        .replaceAll('…', '...')
        .replaceAll('▶', ' > ')
        .replaceAll('►', ' > ')
        .replaceAll('✔', '[v]')
        .replaceAll('✅', '[v]')
        .replaceAll('✨', '*')
        .replaceAll('–', '-') // Duplicate dash replace for safety
        .replaceAll('\r', '') // Clean up windows line endings
        .trim();
  }
}
