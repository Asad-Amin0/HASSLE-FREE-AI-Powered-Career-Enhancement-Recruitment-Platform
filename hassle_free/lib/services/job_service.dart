import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class JobService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ─── Create a new job posting ──────────────────────────────────────────────
  Future<String?> postJob({
    required String title,
    required String company,
    required String location,
    required String salaryRange,
    required String type, // Full-time, Part-time, Contract, Remote
    required String description,
    required List<String> requiredSkills,
    String? experienceLevel,
    String? resumeTheme, // Professional, Creative, Modern
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('No user logged in, cannot post job');
      return null;
    }

    try {
      final docRef = await _db.collection('jobs').add({
        'title': title,
        'company': company,
        'location': location,
        'salaryRange': salaryRange,
        'type': type,
        'description': description,
        'requiredSkills': requiredSkills,
        'experienceLevel': experienceLevel ?? 'Any',
        'resumeTheme': resumeTheme ?? 'Modern',
        'employerId': user.uid,
        'employerEmail': user.email,
        'status': 'active',
        'applicants': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Job posted successfully: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Error posting job: $e');
      return null;
    }
  }

  // ─── Get all jobs posted by the current employer (real-time stream) ────────
  Stream<List<Map<String, dynamic>>> getEmployerJobsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _db
        .collection('jobs')
        .where('employerId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
          
          // Sort client-side to avoid needing a composite index in Firestore
          docs.sort((a, b) {
            final aTime = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            final bTime = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            return bTime.compareTo(aTime); // Descending
          });
          
          return docs;
        });
  }

  // ─── Get all active jobs (for job seekers) ────────────────────────────────
  Stream<List<Map<String, dynamic>>> getAllActiveJobsStream() {
    return _db
        .collection('jobs')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
          
          // Sort client-side to avoid needing a composite index in Firestore
          docs.sort((a, b) {
            final aTime = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            final bTime = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            return bTime.compareTo(aTime); // Descending
          });
          
          return docs;
        });
  }

  // ─── Alias used by dashboard notification system ──────────────────────────
  Stream<List<Map<String, dynamic>>> getAllJobsStream() => getAllActiveJobsStream();

  // ─── Get employer stats ───────────────────────────────────────────────────
  Stream<Map<String, int>> getEmployerStatsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value({
        'activeJobs': 0,
        'totalApplicants': 0,
      });
    }

    return _db
        .collection('jobs')
        .where('employerId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      int activeJobs = 0;
      int totalApplicants = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['status'] == 'active') {
          activeJobs++;
        }
        totalApplicants += (data['applicants'] as num? ?? 0).toInt();
      }

      return {
        'activeJobs': activeJobs,
        'totalApplicants': totalApplicants,
      };
    });
  }

  // ─── Delete a job posting ──────────────────────────────────────────────────
  Future<bool> deleteJob(String jobId) async {
    try {
      await _db.collection('jobs').doc(jobId).delete();
      debugPrint('Job deleted successfully: $jobId');
      return true;
    } catch (e) {
      debugPrint('Error deleting job: $e');
      return false;
    }
  }

  // ─── Update a job posting ─────────────────────────────────────────────────
  Future<bool> updateJob(String jobId, Map<String, dynamic> data) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _db.collection('jobs').doc(jobId).update(data);
      debugPrint('Job updated: $jobId');
      return true;
    } catch (e) {
      debugPrint('Error updating job: $e');
      return false;
    }
  }
  // ─── Apply for a job ──────────────────────────────────────────────────────
  Future<bool> applyForJob({
    required String jobId,
    required Map<String, dynamic> resumeData, // Pass the latest resume data
  }) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      // 0. Get job data to get employerId
      final jobDoc = await _db.collection('jobs').doc(jobId).get();
      final employerId = jobDoc.data()?['employerId'] as String?;
      final jobTitle = jobDoc.data()?['title'] as String? ?? 'Unknown Job';

      // 1. Add to applications collection
      await _db.collection('applications').add({
        'jobId': jobId,
        'jobTitle': jobTitle,
        'employerId': employerId,
        'seekerId': user.uid,
        'seekerName': resumeData['name'] ?? user.displayName ?? 'Job Seeker',
        'seekerEmail': user.email,
        'resumeData': resumeData,
        'status': 'pending',
        'appliedAt': FieldValue.serverTimestamp(),
      });

      // 2. Increment applicant count on job doc
      await _db.collection('jobs').doc(jobId).update({
        'applicants': FieldValue.increment(1),
      });

      debugPrint('Applied for job $jobId successfully');
      return true;
    } catch (e) {
      debugPrint('Error applying for job: $e');
      return false;
    }
  }

  // ─── Check if user already applied ────────────────────────────────────────
  Future<bool> hasApplied(String jobId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final snapshot = await _db
          .collection('applications')
          .where('jobId', isEqualTo: jobId)
          .where('seekerId', isEqualTo: user.uid)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking application status: $e');
      return false;
    }
  }

  // ─── Get applicants for a job (for employers) ─────────────────────────────
  Stream<List<Map<String, dynamic>>> getJobApplicantsStream(String jobId) {
    return _db
        .collection('applications')
        .where('jobId', isEqualTo: jobId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  // ─── Get my applied job IDs (for UI buttons) ─────────────────────────────
  Stream<List<String>> getMyApplicationsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _db
        .collection('applications')
        .where('seekerId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()['jobId'] as String).toList();
    });
  }

  // ─── Get my full application details (for job seekers) ─────────────────────
  Stream<List<Map<String, dynamic>>> getMyApplicationsFullStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _db
        .collection('applications')
        .where('seekerId', isEqualTo: user.uid)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> appsWithJobData = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        
        // Fetch the latest job title if missing or to ensure it's up to date
        try {
          final jobDoc = await _db.collection('jobs').doc(data['jobId']).get();
          if (jobDoc.exists) {
            data['jobTitle'] = jobDoc.data()?['title'] ?? data['jobTitle'] ?? 'Unknown Position';
            data['company'] = jobDoc.data()?['company'] ?? 'Unknown Company';
          }
        } catch (e) {
          debugPrint('Error fetching job details for application: $e');
        }
        
        appsWithJobData.add(data);
      }
      
      // Sort by appliedAt descending
      appsWithJobData.sort((a, b) {
        final aTime = (a['appliedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bTime = (b['appliedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        return bTime.compareTo(aTime);
      });
      
      return appsWithJobData;
    });
  }

  // ─── Update application status (for employers) ─────────────────────────────
  Future<bool> updateApplicationStatus(String applicationId, String status) async {
    try {
      await _db.collection('applications').doc(applicationId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Application $applicationId status updated to $status');
      return true;
    } catch (e) {
      debugPrint('Error updating application status: $e');
      return false;
    }
  }

  // ─── Get all applicants for any job posted by this employer ───────────────
  Stream<List<Map<String, dynamic>>> getEmployerAllApplicantsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _db
        .collection('applications')
        .where('employerId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }
}
