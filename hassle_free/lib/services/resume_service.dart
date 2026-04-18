import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

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
            'textPreview': textPreview,
            'overallScore': overallScore,
            'breakdown': breakdown,
            'badges': badges,
            'timestamp': FieldValue.serverTimestamp(),
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

  // Update profile details manually
  Future<void> updateProfile({
    String? name,
    String? location,
    String? profilePictureUrl,
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

      if (updateData.isNotEmpty) {
        await _db
            .collection('users')
            .doc(user.uid)
            .collection('resumes')
            .doc('latest')
            .update(updateData);
      }
      debugPrint('Profile updated successfully');
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
