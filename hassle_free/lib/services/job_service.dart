import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io' as io;
import 'package:http/http.dart' as http;
import 'supabase_service.dart';


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
    String? resumeColor, // Hex color for the theme
    required DateTime expiryDate,
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
        'resumeColor': resumeColor ?? 'ff6366f1',
        'employerId': user.uid,
        'employerEmail': user.email,
        'status': 'active',
        'applicants': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'expiryDate': Timestamp.fromDate(expiryDate),
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
          }).where((data) {
            DateTime expiryDate;
            if (data['expiryDate'] != null) {
              expiryDate = (data['expiryDate'] as Timestamp).toDate();
            } else if (data['createdAt'] != null) {
              expiryDate = (data['createdAt'] as Timestamp).toDate().add(const Duration(days: 30));
            } else {
              expiryDate = DateTime.now().add(const Duration(days: 30));
            }
            if (expiryDate.isBefore(DateTime.now())) {
              return false;
            }
            return true;
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
          }).where((data) {
            DateTime expiryDate;
            if (data['expiryDate'] != null) {
              expiryDate = (data['expiryDate'] as Timestamp).toDate();
            } else if (data['createdAt'] != null) {
              expiryDate = (data['createdAt'] as Timestamp).toDate().add(const Duration(days: 30));
            } else {
              expiryDate = DateTime.now().add(const Duration(days: 30));
            }
            if (expiryDate.isBefore(DateTime.now())) {
              return false;
            }
            return true;
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
        
        bool isExpired = false;
        DateTime expiryDate;
        if (data['expiryDate'] != null) {
          expiryDate = (data['expiryDate'] as Timestamp).toDate();
        } else if (data['createdAt'] != null) {
          expiryDate = (data['createdAt'] as Timestamp).toDate().add(const Duration(days: 30));
        } else {
          expiryDate = DateTime.now().add(const Duration(days: 30));
        }
        
        if (expiryDate.isBefore(DateTime.now())) {
          isExpired = true;
        }
        
        if (!isExpired && data['status'] == 'active') {
          activeJobs++;
        }
        if (!isExpired) {
          totalApplicants += (data['applicants'] as num? ?? 0).toInt();
        }
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
            data['expiryDate'] = jobDoc.data()?['expiryDate'];
            data['jobStatus'] = jobDoc.data()?['status'];
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

  // ─── Delete application (for employers) ─────────────────────────────
  Future<bool> deleteApplication(String applicationId) async {
    try {
      await _db.collection('applications').doc(applicationId).delete();
      debugPrint('Application $applicationId deleted');
      return true;
    } catch (e) {
      debugPrint('Error deleting application: $e');
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

  // ─── Save Interview Result ────────────────────────────────────────────────
  Future<bool> saveInterviewResult({
    required String jobId,
    required String seekerId,
    required Map<String, dynamic> resultData,
    String? videoUrl,
    Map<String, dynamic>? resumeData,
  }) async {
    try {
      final appQuery = await _db
          .collection('applications')
          .where('jobId', isEqualTo: jobId)
          .where('seekerId', isEqualTo: seekerId)
          .get();

      if (appQuery.docs.isEmpty) {
        // Create new application (Apply with Interview flow)
        final user = _auth.currentUser;
        await _db.collection('applications').add({
          'jobId': jobId,
          'seekerId': seekerId,
          'seekerName': resumeData?['name'] ?? user?.displayName ?? 'Anonymous',
          'seekerEmail': user?.email ?? 'No email',
          'resumeData': resumeData ?? {},
          'appliedAt': FieldValue.serverTimestamp(),
          'status': 'applied',
          'interviewResult': resultData,
          'hasInterview': true,
          'interviewStatus': 'completed',
          'overallScore': resultData['overallScore'] ?? 0.0,
          'interviewDate': FieldValue.serverTimestamp(),
          'videoUrl': videoUrl ?? resultData['videoUrl'],
        });
        debugPrint('New application created with interview for job $jobId');
      } else {
        // Update existing application
        final appId = appQuery.docs.first.id;
        await _db.collection('applications').doc(appId).update({
          'interviewResult': resultData,
          'hasInterview': true,
          'interviewStatus': 'completed',
          'overallScore': resultData['overallScore'] ?? 0.0,
          'interviewDate': FieldValue.serverTimestamp(),
          'videoUrl': videoUrl ?? resultData['videoUrl'],
        });
        debugPrint('Interview result updated for application $appId');
      }
      return true;
    } catch (e) {
      debugPrint('Error saving interview result: $e');
      return false;
    }
  }


  // ─── Check if user can take interview (2-hour limit) ──────────────────────
  Future<bool> canTakeInterviewToday({String? jobId}) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final twoHoursAgo = DateTime.now().subtract(const Duration(hours: 2));

      Query query = _db
          .collection('applications')
          .where('seekerId', isEqualTo: user.uid)
          .where('hasInterview', isEqualTo: true)
          .where('interviewDate', isGreaterThanOrEqualTo: Timestamp.fromDate(twoHoursAgo));
      
      if (jobId != null) {
        query = query.where('jobId', isEqualTo: jobId);
      }

      final snapshot = await query.get();
      return snapshot.docs.isEmpty;
    } catch (e) {
      debugPrint('Error checking interview limit: $e');
      return true; // Fallback to allow in case of error
    }
  }

  
  // ─── Upload Interview Video (Supabase) ───────────────────────────────────
  Future<String?> uploadInterviewVideo(String filePath, String seekerId, String jobId) async {
    try {
      // Switch from Firebase Storage to Supabase Storage as requested
      final supabaseUrl = await SupabaseService().uploadInterviewVideo(
        filePath: filePath,
        seekerId: seekerId,
        jobId: jobId,
      );
      
      if (supabaseUrl != null) {
        return supabaseUrl;
      }
      
      // Fallback to Firebase Storage if Supabase fails (optional safety)
      debugPrint('Supabase upload failed, attempting Firebase Storage fallback...');
      final storageRef = FirebaseStorage.instance.ref();
      final videoRef = storageRef.child('interviews/$seekerId/$jobId/${DateTime.now().millisecondsSinceEpoch}.mp4');
      
      if (kIsWeb) {
        final response = await http.get(Uri.parse(filePath));
        final bytes = response.bodyBytes;
        await videoRef.putData(bytes, SettableMetadata(contentType: 'video/mp4'));
      } else {
        await videoRef.putFile(io.File(filePath));
      }
      
      return await videoRef.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading interview video: $e');
      return null;
    }
  }

}
