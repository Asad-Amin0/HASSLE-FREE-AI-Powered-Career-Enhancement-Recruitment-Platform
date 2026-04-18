import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CandidateAvatar extends StatelessWidget {
  final String seekerId;
  final String seekerName;
  final double radius;
  final String? initialPictureUrl;

  const CandidateAvatar({
    super.key,
    required this.seekerId,
    required this.seekerName,
    this.radius = 20,
    this.initialPictureUrl,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(seekerId)
          .collection('resumes')
          .doc('latest')
          .snapshots(),
      builder: (context, snapshot) {
        String? profilePic = initialPictureUrl;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null && data['profilePictureUrl'] != null) {
            profilePic = data['profilePictureUrl'];
          }
        }

        return Container(
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            ),
          ),
          child: CircleAvatar(
            radius: radius,
            backgroundImage:
                profilePic != null && profilePic.startsWith('data:image')
                ? MemoryImage(base64Decode(profilePic.split(',').last))
                : NetworkImage(
                        'https://api.dicebear.com/7.x/avataaars/png?seed=$seekerName',
                      )
                      as ImageProvider,
          ),
        );
      },
    );
  }
}
