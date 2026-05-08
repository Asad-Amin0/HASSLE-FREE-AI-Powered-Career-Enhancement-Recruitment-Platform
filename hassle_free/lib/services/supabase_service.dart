import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  // IMPORTANT: Replace these with your actual Supabase project details
  static const String supabaseUrl = 'https://ckrxspznrmgwtefxldxn.supabase.co';

  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNrcnhzcHpucm1nd3RlZnhsZHhuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgxNTcwODIsImV4cCI6MjA5MzczMzA4Mn0.hBigbm3wo29h-usN0ZK5zv_cQDNNN5FlwqeKx20XDFs';


  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      _isInitialized = true;
      debugPrint('Supabase initialized successfully');
    } catch (e) {
      debugPrint('Supabase initialization failed: $e');
    }
  }

  Future<String?> uploadInterviewVideo({
    required String filePath,
    required String seekerId,
    required String jobId,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.mp4';
      final path = 'interviews/$seekerId/$jobId/$fileName';

      if (kIsWeb) {
        final response = await http.get(Uri.parse(filePath));
        final bytes = response.bodyBytes;
        await supabase.storage.from('interviews').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'video/mp4'),
        );
      } else {
        final file = File(filePath);
        await supabase.storage.from('interviews').upload(
          path,
          file,
          fileOptions: const FileOptions(contentType: 'video/mp4'),
        );
      }

      final String publicUrl = supabase.storage.from('interviews').getPublicUrl(path);
      debugPrint('Video uploaded to Supabase: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading video to Supabase: $e');
      return null;
    }
  }
}
