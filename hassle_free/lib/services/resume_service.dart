import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'job_service.dart';

class ResumeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Save resume analysis to Firestore
  Future<void> saveResumeAnalysis({
    required String filename,
    required String category,
    required String name,
    required List<String> skills,
    required String experience,
    required String education,
    required List<String> certificates,
    required String textPreview,
    double? overallScore,
    Map<String, dynamic>? breakdown,
    List<String>? badges,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('No user logged in, cannot save resume analysis');
      return;
    }

    try {
      await _db
          .collection('users')
          .doc(user.uid)
          .collection('resumes')
          .doc('latest')
          .set({
            'filename': filename,
            'category': category,
            'name': name,
            'skills': skills,
            'experience': experience,
            'education': education,
            'certificates': certificates,
            'textPreview': textPreview,
            'overallScore': overallScore,
            'breakdown': breakdown,
            'badges': badges,
            'timestamp': FieldValue.serverTimestamp(),
          });
      
      // Sync to all existing applications
      await JobService().updateUserApplicationsResume(user.uid, {
        'filename': filename,
        'category': category,
        'name': name,
        'skills': skills,
        'experience': experience,
        'education': education,
        'certificates': certificates,
        'textPreview': textPreview,
        'overallScore': overallScore,
        'breakdown': breakdown,
        'badges': badges,
      });

      debugPrint('Resume analysis saved to Firestore for user: ${user.uid}');
    } catch (e) {
      debugPrint('Error saving resume analysis: $e');
    }
  }

  // Get the latest resume analysis from Firestore
  Future<Map<String, dynamic>?> getLatestResumeAnalysis() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _db
          .collection('users')
          .doc(user.uid)
          .collection('resumes')
          .doc('latest')
          .get();
      if (doc.exists) {
        return doc.data();
      }
    } catch (e) {
      debugPrint('Error fetching resume analysis: $e');
    }
    return null;
  }

  // Get a real-time stream of the latest resume analysis
  Stream<Map<String, dynamic>?> getLatestResumeAnalysisStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _db
        .collection('users')
        .doc(user.uid)
        .collection('resumes')
        .doc('latest')
        .snapshots()
        .map((snapshot) => snapshot.exists ? snapshot.data() : null);
  }

  Future<void> updateProfile({
    String? name,
    String? location,
    String? profilePictureUrl,
    String? education,
    String? experience,
    List<String>? skills,
    List<String>? certificates,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final Map<String, dynamic> updateData = {};
      if (name != null) updateData['name'] = name;
      if (location != null) updateData['location'] = location;
      if (profilePictureUrl != null) {
        updateData['profilePictureUrl'] = profilePictureUrl;
      }
      if (education != null) updateData['education'] = education;
      if (experience != null) updateData['experience'] = experience;
      if (skills != null) updateData['skills'] = skills;
      if (certificates != null) updateData['certificates'] = certificates;

      // Recalculate score if key fields are updated
      if (education != null || experience != null || skills != null || certificates != null) {
        // Fetch current data for fields not being updated
        final current = await getLatestResumeAnalysis();
        final finalEdu = education ?? current?['education'] ?? "";
        final finalExp = experience ?? current?['experience'] ?? "";
        final finalSkills = skills ?? List<String>.from(current?['skills'] ?? []);
        final finalCerts = certificates ?? List<String>.from(current?['certificates'] ?? []);

        // Heuristic Scoring logic (Total 100)
        // Skills: 30% (1.5 points per skill, max 30)
        // Experience: 30% (based on content, max 30)
        // Education: 20% total
        // - 4-year degree (BS/Bachelor): 10
        // - 2-year degree (College/Associate): 10
        // Certificates: 10% (max 4) or 20% (if > 4)
        
        double skillScore = (finalSkills.length * 1.5).clamp(0.0, 30.0);
        double expScore = (finalExp.length / 25.0).clamp(0.0, 30.0);
        
        double eduScore = 0.0;
        String eduLower = finalEdu.toLowerCase();
        if (eduLower.contains('bachelor') || eduLower.contains('bs') || 
            eduLower.contains('b.e') || eduLower.contains('btech')) {
          eduScore += 10.0;
        }
        if (eduLower.contains('associate') || eduLower.contains('2 year') || 
            eduLower.contains('college') || eduLower.contains('intermediate')) {
          eduScore += 10.0;
        }
        // Bolster with Master/PhD if under 20
        if (eduScore < 20 && (eduLower.contains('master') || eduLower.contains('ms ') || eduLower.contains('phd'))) {
          eduScore = (eduScore + 5.0).clamp(0.0, 20.0);
        }

        double certScore = 0.0;
        if (finalCerts.length > 4) {
          certScore = (finalCerts.length * 4.0).clamp(0.0, 20.0);
        } else {
          certScore = (finalCerts.length * 2.5).clamp(0.0, 10.0);
        }
        
        double overall = skillScore + expScore + eduScore + certScore;
        updateData['overallScore'] = double.parse(overall.toStringAsFixed(1));
        updateData['breakdown'] = {
          'skills': double.parse(skillScore.toStringAsFixed(1)),
          'experience': double.parse(expScore.toStringAsFixed(1)),
          'education': double.parse(eduScore.toStringAsFixed(1)),
          'certificates': double.parse(certScore.toStringAsFixed(1)),
        };

        // Update badges based on new score
        List<String> badges = List<String>.from(current?['badges'] ?? []);
        if (overall >= 85 && !badges.contains('Highly Employable')) {
          badges.add('Highly Employable');
        }
        if (finalSkills.length >= 8 && !badges.contains('Top Skilled')) {
          badges.add('Top Skilled');
        }
        if (finalCerts.isNotEmpty && !badges.contains('Certified Expert')) {
          badges.add('Certified Expert');
        }
        updateData['badges'] = badges;
      }

      if (updateData.isNotEmpty) {
        await _db
            .collection('users')
            .doc(user.uid)
            .collection('resumes')
            .doc('latest')
            .update(updateData);
        
        // Fetch full updated data to sync applications
        final updatedResume = await getLatestResumeAnalysis();
        if (updatedResume != null) {
          await JobService().updateUserApplicationsResume(user.uid, updatedResume);
        }
      }
      debugPrint('Profile, Certificates and Score updated successfully');
    } catch (e) {
      debugPrint('Error updating profile: $e');
    }
  }

  // Get all candidate resumes across the platform (for employers)
  Stream<List<Map<String, dynamic>>> getAllCandidatesStream() {
    return _db
        .collectionGroup('resumes')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            data['userId'] =
                doc.reference.parent.parent?.id; // Extract userId from path
            return data;
          }).toList(),
        );
  }
}
