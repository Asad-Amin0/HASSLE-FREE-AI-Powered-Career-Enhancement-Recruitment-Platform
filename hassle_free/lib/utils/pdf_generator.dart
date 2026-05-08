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
  }) async {
    final pdf = pw.Document();
    _addResumePage(pdf, name, jobTitle, email, resumeData);

    final fileName = "Resume_${name.replaceAll(' ', '_')}.pdf";
    
    if (kIsWeb) {
      // On Web, sharePdf triggers a direct download without opening the print dialog
      // This is much more reliable for bulk downloads
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

  static Future<void> generateBulkResumes(List<Map<String, dynamic>> candidates) async {
    final pdf = pw.Document();
    
    for (var c in candidates) {
      final name = c['name'] ?? 'Candidate';
      final jobTitle = c['jobTitle'] ?? 'N/A';
      final email = c['seekerEmail'] ?? 'N/A';
      final resumeData = c['resumeData'] ?? {};
      
      _addResumePage(pdf, name, jobTitle, email, resumeData);
    }

    final dateStr = DateTime.now().toString().split(' ')[0];
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: "Bulk_Resumes_$dateStr.pdf",
    );
  }

  static void _addResumePage(pw.Document pdf, String name, String jobTitle, String email, Map<String, dynamic> resumeData) {
    final skills = List<String>.from(resumeData['skills'] ?? []);
    final experience = resumeData['experience'] ?? 'No experience details provided.';
    final education = resumeData['education'] ?? 'No education details provided.';
    final category = resumeData['category'] ?? 'Professional';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: const pw.BoxDecoration(color: PdfColors.indigo),
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
              pw.SizedBox(height: 30),

              // Skills
              pw.Text("TECHNICAL SKILLS", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo)),
              pw.Divider(color: PdfColors.grey),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 10),
                child: pw.Text(skills.join("  |  "), style: const pw.TextStyle(fontSize: 12)),
              ),
              pw.SizedBox(height: 20),

              // Experience
              pw.Text("PROFESSIONAL EXPERIENCE", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo)),
              pw.Divider(color: PdfColors.grey),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 10),
                child: pw.Text(experience, style: const pw.TextStyle(fontSize: 11, lineSpacing: 2)),
              ),
              pw.SizedBox(height: 20),

              // Education
              pw.Text("ACADEMIC HISTORY", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo)),
              pw.Divider(color: PdfColors.grey),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 10),
                child: pw.Text(education, style: const pw.TextStyle(fontSize: 11, lineSpacing: 2)),
              ),

              pw.Spacer(),
              pw.Divider(color: PdfColors.grey),
              pw.Align(
                alignment: pw.Alignment.center,
                child: pw.Text("Generated by Hassle-Free AI Career Platform", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
              ),
            ],
          );
        },
      ),
    );
  }
}
