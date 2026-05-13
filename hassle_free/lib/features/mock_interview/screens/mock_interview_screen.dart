import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/interview_question.dart';

import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../utils/navigator_utils.dart';


import 'package:gap/gap.dart';
import '../viewmodels/mock_interview_viewmodel.dart';
import '../models/interview_session.dart';
import '../widgets/avatar_3d_widget.dart';
import '../widgets/waveform_recorder.dart';
import '../widgets/score_indicator.dart';
import '../models/avatar_state.dart';
import 'interview_results_screen.dart';
import 'package:camera/camera.dart';

class MockInterviewScreen extends StatefulWidget {
  final String userId;
  final String jobRole;
  final List<String> skills; // Pulled from user's parsed resume
  final bool isDarkMode;
  final String? jobId;
  final String jobDescription;
  final Map<String, dynamic>? resumeData;
  final VoidCallback? onExit;


  const MockInterviewScreen({
    super.key,
    required this.userId,
    required this.jobRole,
    required this.skills,
    this.isDarkMode = false,
    this.jobId,
    this.jobDescription = "",
    this.resumeData,
    this.onExit,
  });


  @override
  State<MockInterviewScreen> createState() => _MockInterviewScreenState();
}

class _MockInterviewScreenState extends State<MockInterviewScreen> with WidgetsBindingObserver {
  bool _navigatedToResults = false;
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  late MockInterviewViewModel _vm;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _vm = Provider.of<MockInterviewViewModel>(context, listen: false);
  }

  Future<void> _startRecording() async {
    if (_cameraController == null || !_isCameraInitialized || _isRecording) return;
    try {
      await _cameraController!.startVideoRecording();
      setState(() => _isRecording = true);
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<String?> _stopRecording() async {
    if (_cameraController == null || !_isRecording) return null;
    try {
      final file = await _cameraController!.stopVideoRecording();
      setState(() => _isRecording = false);
      debugPrint('Recording saved to: ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      return null;
    }
  }

  Color get _bgColor => widget.isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  Color get _textColor => widget.isDarkMode ? Colors.white : Colors.black87;
  Color get _cardBorder => widget.isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300;
  Color get _mutedText => widget.isDarkMode ? Colors.white70 : Colors.black54;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (_isCameraInitialized) return;
    
    try {
      debugPrint('Attempting to detect cameras...');
      List<CameraDescription> cameras = await availableCameras();
      
      // On Web, availableCameras() might return empty if permissions are not yet granted.
      // We can try to wait a bit and retry once.
      if (cameras.isEmpty) {
        debugPrint('No cameras found, retrying in 1 second...');
        await Future.delayed(const Duration(seconds: 1));
        cameras = await availableCameras();
      }

      if (cameras.isEmpty) {
        debugPrint('Still no cameras detected.');
        if (mounted) {
          setState(() {
            _isCameraInitialized = false;
          });
        }
        return;
      }

      
      debugPrint('Found ${cameras.length} cameras. Selecting front camera if available.');
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      
      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: true,
        imageFormatGroup: kIsWeb ? null : ImageFormatGroup.jpeg,
      );
      
      await _cameraController!.initialize();
      debugPrint('CameraController initialized successfully.');
      
      // Give it a tiny moment to stabilize the stream
      await Future.delayed(const Duration(milliseconds: 200));
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('CRITICAL: Camera initialization failed: $e');
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _handleInterruption();
    }
  }

  void _handleInterruption() {
    if (!_vm.isCompleted && _vm.session != null) {
      _vm.stopAll();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Interview stopped because you switched screens.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      _vm.endInterview();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _vm.stopAll(notify: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Consumer<MockInterviewViewModel>(
        builder: (context, vm, _) {
          if (vm.isCompleted &&
              vm.session?.status == InterviewStatus.completed &&
              !_navigatedToResults) {
            
            _navigatedToResults = true;
            
            // Show loading overlay or handle it in the UI below
            _stopRecording().then((path) async {
              // Wait for the full end-to-end saving (Supabase upload + Firestore save)
              await vm.endInterview(videoPath: path);
              
              if (!mounted) return;
              
              // ONLY navigate after we are 100% sure the data is saved
              navigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder: (_) => InterviewResultsScreen(
                    session: vm.session!,
                    isDarkMode: widget.isDarkMode,
                    onExit: widget.onExit,
                    onRestart: widget.jobId == null ? () {
                      setState(() => _navigatedToResults = false);
                      vm.startSession(
                        userId: widget.userId,
                        jobRole: widget.jobRole,
                        skills: widget.skills,
                        resumeData: widget.resumeData,
                        jobId: widget.jobId,
                        jobDescription: widget.jobDescription,
                      );
                    } : null,
                  ),
                ),
              );
            });
          }

          return Stack(
            children: [
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                      children: [
                        _buildHeader(vm),
                        Expanded(
                          child: vm.isLoading 
                            ? _buildLoading() 
                            : (vm.session == null ? _buildStartScreen(vm) : _buildInterviewLayout(vm)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (vm.isLoading && vm.isCompleted)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Color(0xFF4F46E5)),
                        const Gap(20),
                        const Text(
                          'Saving your interview recording\nand results to Supabase...',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );

        },
      ),
    );
  }

  Widget _buildHeader(MockInterviewViewModel vm) {
    final session = vm.session;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _confirmExit(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _cardBorder,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.close, color: _mutedText, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.jobRole,
                  style: TextStyle(
                    color: _textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                if (session != null)
                  Text(
                    'Question ${session.currentQuestionIndex + 1} of ${session.totalQuestions}',
                    style: TextStyle(color: _mutedText, fontSize: 12),
                  ),
              ],
            ),
          ),
          if (session != null && session.status != InterviewStatus.completed)
            TextButton.icon(
              onPressed: () => _confirmEndInterview(vm),
              icon: Icon(_isRecording ? Icons.videocam_off : Icons.stop_circle_outlined, color: Colors.redAccent, size: 18),
              label: Text(_isRecording ? 'Stop recording' : 'End', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          const SizedBox(width: 8),
          if (session != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.4)),
              ),
              child: Text(
                '${session.totalPoints} pts',
                style: const TextStyle(
                  color: Color(0xFF4F46E5),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStartScreen(MockInterviewViewModel vm) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mic_none_rounded, color: Color(0xFF4F46E5), size: 60),
            ),
            const Gap(32),
            Text(
              'Ready to begin?',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _textColor),
            ),
            const Gap(16),
            if (vm.error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
                    const Gap(12),
                    Expanded(
                      child: Text(
                        vm.error!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ).animate().shake(),
            Text(
              'Your AI interviewer is ready to evaluate your skills in ${widget.jobRole}.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _mutedText, fontSize: 16, height: 1.5),
            ),
            const Gap(40),
            SizedBox(
              width: 280,
              height: 60,
              child: ElevatedButton(
                onPressed: () async {
                  // Try to initialize if not already done
                  if (!_isCameraInitialized) {
                    await _initializeCamera();
                  }

                  if (!mounted) return;

                  if (!_isCameraInitialized) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Camera unavailable. Proceeding with audio-only interview.'),
                        backgroundColor: Colors.orange,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }

                  vm.startSession(
                    userId: widget.userId,
                    jobRole: widget.jobRole,
                    skills: widget.skills,
                    resumeData: widget.resumeData,
                    jobId: widget.jobId,
                    jobDescription: widget.jobDescription,
                  );

                  _startRecording();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 8,
                  shadowColor: const Color(0xFF4F46E5).withValues(alpha: 0.5),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.video_call_rounded),
                    Gap(8),
                    Text('Start Video Interview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const Gap(24),
            Text(
              'Ensure you are in a quiet environment.',
              style: TextStyle(color: _mutedText, fontSize: 12),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, curve: Curves.easeOut);
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Color(0xFF4F46E5)),
          const Gap(20),
          Text(
            'Preparing your interview questions\nusing AI & RAG system...',
            textAlign: TextAlign.center,
            style: TextStyle(color: _mutedText, fontSize: 14),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }

  Widget _buildInterviewLayout(MockInterviewViewModel vm) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: Column(
        children: [
          _buildProgressBar(vm),
          const Gap(24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: LayoutBuilder(
              builder: (context, box) {
                final bool isSmall = box.maxWidth < 600;
                return AspectRatio(
                  aspectRatio: isSmall ? 1 / 1.5 : 16 / 6,
                  child: isSmall 
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(flex: 3, child: _buildAvatar(vm)),
                          const Gap(8),
                          Expanded(flex: 2, child: _buildCameraPreview()),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _buildAvatar(vm)),
                          const Gap(16),
                          Expanded(child: _buildCameraPreview()),
                        ],
                      ),
                );
              }
            ),
          ),
          const Gap(24),
          _buildInterviewBody(vm),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_isCameraInitialized || _cameraController == null || !_cameraController!.value.isInitialized) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _cardBorder),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off_rounded, color: Colors.white24, size: 48),
              SizedBox(height: 12),
              Text('Camera Offline', style: TextStyle(color: Colors.white24, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
        color: Colors.black,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: _cameraController!.value.aspectRatio,
                child: CameraPreview(_cameraController!),
              ),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      const Text('Live', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),


            if (_isRecording)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeOut(duration: 500.ms),
                      const SizedBox(width: 8),
                      const Text('REC', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }


  Widget _buildInterviewBody(MockInterviewViewModel vm) {
    if (vm.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(vm.error!, textAlign: TextAlign.center, style: TextStyle(color: _textColor)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => vm.startSession(userId: widget.userId, jobRole: widget.jobRole, skills: widget.skills),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWeb = constraints.maxWidth > 700;
        return Column(
          children: [
            if (vm.avatarState.currentText.isNotEmpty) _buildSubtitle(vm.avatarState.currentText),
            const Gap(12),
            if (isWeb && vm.lastResult != null && vm.session?.status != InterviewStatus.userAnswering)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (vm.currentQuestion != null)
                      Expanded(child: _buildQuestionCard(vm.currentQuestion!, horizontalMargin: 0)),
                    const Gap(16),
                    Expanded(child: ScoreIndicator(result: vm.lastResult!, margin: 0)),
                  ],
                ),
              )
            else ...[
              if (vm.currentQuestion != null) _buildQuestionCard(vm.currentQuestion!),
              const Gap(12),
              if (vm.lastResult != null && vm.session?.status != InterviewStatus.userAnswering)
                ScoreIndicator(result: vm.lastResult!).animate().slideY(
                  begin: 0.2, duration: 500.ms, curve: Curves.easeOut,
                ),
            ],
            if (vm.session?.status == InterviewStatus.userAnswering) ...[
              WaveformRecorder(
                isListening: vm.isListening,
                transcript: vm.partialTranscript.isNotEmpty ? vm.partialTranscript : vm.finalTranscript,
                onStop: () => vm.stopListening(),
                onSkip: () => vm.skipQuestion(),
                onRetry: () => vm.retryListening(),
              ).animate().fadeIn(duration: 400.ms),
              const Gap(16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: (vm.remainingSeconds <= 5 ? Colors.redAccent : _textColor).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (vm.remainingSeconds <= 5 ? Colors.redAccent : const Color(0xFF4F46E5)).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 18,
                      color: vm.remainingSeconds <= 5 ? Colors.redAccent : const Color(0xFF4F46E5),
                    ),
                    const Gap(8),
                    Text(
                      'Time remaining: ${vm.remainingSeconds}s',
                      style: TextStyle(
                        color: vm.remainingSeconds <= 5 ? Colors.redAccent : _textColor,
                        fontWeight: FontWeight.bold, fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ).animate(target: vm.remainingSeconds <= 5 ? 1 : 0).shake(hz: 4, curve: Curves.easeInOut),
              const Gap(8),
            ],
            if (vm.isEvaluating)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(color: Color(0xFF4F46E5), strokeWidth: 2),
                    ),
                    const Gap(12),
                    Text('Evaluating your answer...', style: TextStyle(color: _mutedText)),
                  ],
                ),
              ),
            const Gap(20),
          ],
        );
      },
    );
  }

  Widget _buildAvatar(MockInterviewViewModel vm) {
    return Selector<MockInterviewViewModel, (AvatarState, ValueNotifier<String>)>(
      selector: (_, vm) => (vm.avatarState, vm.phonemeNotifier),
      builder: (context, data, _) {
        return Avatar3DWidget(avatarState: data.$1, phonemeNotifier: data.$2);
      },
    );
  }

  Widget _buildProgressBar(MockInterviewViewModel vm) {
    final progress = vm.session?.progressPercent ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress, minHeight: 4, backgroundColor: _cardBorder,
          valueColor: const AlwaysStoppedAnimation(Color(0xFF4F46E5)),
        ),
      ),
    );
  }

  Widget _buildSubtitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 120),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _textColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cardBorder),
        ),
        child: SingleChildScrollView(
          child: Text(
            text, textAlign: TextAlign.center,
            style: TextStyle(color: _textColor, fontSize: 14, height: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(InterviewQuestion q, {double horizontalMargin = 20}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalMargin),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [
              const Color(0xFF4F46E5).withValues(alpha: 0.15),
              widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _SkillBadge(skill: q.skill),
                const Spacer(),
                _DifficultyBadge(difficulty: q.difficulty),
              ],
            ),
            const Gap(12),
            Text(
              q.questionText,
              style: TextStyle(color: _textColor, fontSize: 16, fontWeight: FontWeight.w600, height: 1.5),
            ),
            const Gap(8),
            Text('Category: ${q.category}', style: TextStyle(color: _mutedText, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  void _confirmEndInterview(MockInterviewViewModel vm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        title: Text('End Interview?', style: TextStyle(color: _textColor)),
        content: Text(
          'Are you sure you want to end the interview now? You will see results for the questions you have completed.',
          style: TextStyle(color: _mutedText),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Continue Interview')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final path = await _stopRecording();
              vm.endInterview(videoPath: path);
            },
            child: const Text('End Now', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _confirmExit(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        title: Text('Exit Interview?', style: TextStyle(color: _textColor)),
        content: Text('Your progress will be lost.', style: TextStyle(color: _mutedText)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _vm.stopAll(notify: false);
              if (widget.onExit != null) {
                widget.onExit!(); 
              } else {
                Navigator.of(context).popUntil((r) => r.isFirst);
              }
            },
            child: const Text('Exit', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

class _SkillBadge extends StatelessWidget {
  final String skill;
  const _SkillBadge({required this.skill});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(skill, style: const TextStyle(color: Color(0xFF4F46E5), fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  final String difficulty;
  const _DifficultyBadge({required this.difficulty});
  Color get _color => switch (difficulty) {
    'advanced' => const Color(0xFFFF6B6B),
    'intermediate' => const Color(0xFFFFD700),
    _ => const Color(0xFF00C896),
  };
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: _color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(
        difficulty[0].toUpperCase() + difficulty.substring(1),
        style: TextStyle(color: _color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
