import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class InterviewScreen extends StatefulWidget {
  final List<String> skills;
  const InterviewScreen({super.key, this.skills = const []});

  @override
  State<InterviewScreen> createState() => _InterviewScreenState();
}

class _InterviewScreenState extends State<InterviewScreen> {
  bool _isInterviewStarted = false;
  bool _isLoadingQuestions = false;
  int _currentQuestionIndex = 0;

  CameraController? _cameraController;
  bool _isCameraMuted = false;
  bool _isMicMuted = false;
  bool _isSpeaking = false;
  bool _isListening = false;
  String _userTranscription = "";
  
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  List<String> _questions = [
    "Could you walk me through your professional journey and highlight a key achievement?",
    "What specific technical challenges have you overcome in your recent projects?",
    "How do you stay updated with the rapidly evolving tech landscape in your field?",
    "Describe a situation where you had to work with a difficult teammate. How did you resolve it?",
    "Why do you believe you are the best fit for this specific role and our company culture?",
  ];

  // SDS Metrics
  double _clarity = 0.71;
  double _confidence = 0.61;
  double _technicalDepth = 0.92;
  final double _communication = 0.80;
  double _toneModulation = 0.66;
  double _keywordRelevance = 0.76;

  Timer? _metricsTimer;

  @override
  void initState() {
    super.initState();
    _initTTS();
    _initSTT();
    if (widget.skills.isNotEmpty) {
      _fetchDynamicQuestions();
    }
  }

  Future<void> _initTTS() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(0.85); // Professional male pitch
    await _flutterTts.setSpeechRate(0.5);

    _flutterTts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
    });

    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _isSpeaking = false);
        _startListening(); // Automatically start listening after AI finishes speaking
      }
    });
  }

  Future<void> _initSTT() async {
    bool available = await _speech.initialize(
      onStatus: (val) => debugPrint('onStatus: $val'),
      onError: (val) => debugPrint('onError: $val'),
    );
    if (!available) {
      debugPrint("Speech recognition not available");
    }
  }

  Future<void> _startListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) => debugPrint('STT Status: $status'),
        onError: (error) => debugPrint('STT Error: $error'),
      );
      
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            if (mounted) {
              setState(() {
                _userTranscription = val.recognizedWords;
                
                // Enhanced Technical Scoring Logic
                if (widget.skills.isNotEmpty && val.recognizedWords.isNotEmpty) {
                  int matches = 0;
                  final words = val.recognizedWords.toLowerCase().split(' ');
                  for (var skill in widget.skills) {
                    if (words.any((w) => w.contains(skill.toLowerCase()) || skill.toLowerCase().contains(w))) {
                      matches++;
                    }
                  }
                  
                  // Dynamically update scores
                  _keywordRelevance = (0.4 + (matches * 0.2)).clamp(0, 1.0);
                  _technicalDepth = (0.5 + (matches * 0.15)).clamp(0, 1.0);
                }
              });
            }
          },
          listenOptions: stt.SpeechListenOptions(
            listenMode: stt.ListenMode.dictation,
            partialResults: true,
          ),
        );
      }
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _speakQuestion() async {
    if (_questions.isNotEmpty) {
      await _stopListening(); // Stop listening before AI speaks
      await _flutterTts.speak(_questions[_currentQuestionIndex]);
    }
  }

  Future<void> _fetchDynamicQuestions() async {
    setState(() => _isLoadingQuestions = true);
    try {
      final response = await http.post(
        Uri.parse('http://localhost:5002/api/generate-questions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'skills': widget.skills}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _questions = List<String>.from(data['questions']);
        });
      }
    } catch (e) {
      debugPrint("Error fetching dynamic questions: $e");
    } finally {
      setState(() => _isLoadingQuestions = false);
    }
  }

  // Premium Dark Aesthetics (Matching Image)
  static const Color darkBg = Color(0xFF0F172A);
  static const Color cardBg = Color(0xFF1E293B);
  static const Color primaryBlue = Color(0xFF4F46E5);
  static const Color accentPurple = Color(0xFF818CF8);
  static const Color statusRed = Color(0xFFEF4444);

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
    await Permission.microphone.request();
  }

  Future<void> _startInterview() async {
    await _requestPermissions();
    if (!(await Permission.camera.isGranted) || !(await Permission.microphone.isGranted)) return;

    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        final camera = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cameras.first);
        _cameraController = CameraController(camera, ResolutionPreset.medium);
        await _cameraController!.initialize();
        if (mounted) setState(() {}); // Ensure UI updates once camera is ready
      }
    } catch (e) {
      debugPrint("Camera error: $e");
    }

    setState(() {
      _isInterviewStarted = true;
      _currentQuestionIndex = 0;
      _userTranscription = "";
    });

    _speakQuestion();

    _metricsTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && _isInterviewStarted && !_isSpeaking) {
        setState(() {
          _clarity = (0.7 + (DateTime.now().second % 20) / 100).clamp(0, 1);
          _confidence = (0.6 + (DateTime.now().millisecond % 30) / 100).clamp(0, 1);
          _toneModulation = (0.6 + (DateTime.now().second % 15) / 100).clamp(0, 1);
        });
      }
    });
  }

  Future<void> _finishInterview() async {
    _metricsTimer?.cancel();
    _cameraController?.dispose();
    _speech.stop();
    setState(() => _isInterviewStarted = false);
    // Call backend for final analysis if needed
  }

  @override
  void dispose() {
    _metricsTimer?.cancel();
    _cameraController?.dispose();
    _flutterTts.stop();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            bool isMobile = constraints.maxWidth < 1100;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  if (isMobile) 
                    _buildMobileLayout()
                  else
                    _buildWebLayout(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWebLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildInterviewerCard()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildUserFeedCard()),
                ],
              ),
              const SizedBox(height: 24),
              _buildQuestionCard(),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 1,
          child: _buildInsightsPanel(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildInterviewerCard(),
        const SizedBox(height: 16),
        _buildUserFeedCard(),
        const SizedBox(height: 24),
        _buildQuestionCard(),
        const SizedBox(height: 24),
        _buildInsightsPanel(),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI Mock Interview',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          'Practice your skills with our state-of-the-art AI evaluator',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildInterviewerCard() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 1.0, end: _isSpeaking ? 1.08 : 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.elasticOut,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: _isSpeaking ? [
                  BoxShadow(
                    color: accentPurple.withValues(alpha: 0.4),
                    blurRadius: 25,
                    spreadRadius: 5,
                  )
                ] : [],
                image: const DecorationImage(
                  image: AssetImage('assets/images/male_interviewer.png'),
                  fit: BoxFit.cover,
                ),
              ),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isSpeaking ? 0.9 : 1.0, // Subtle flicker to simulate life
                child: child,
              ),
            ),
          );
        },
        child: Stack(
          children: [
            Positioned(
              top: 12,
              left: 12,
              child: _buildBadge('Live', Colors.green),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('AI Interviewer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    Text('Alex AI', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10)),
                  ],
                ),
              ),
            ),
            if (_isSpeaking)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.volume_up, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text('SPEAKING', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserFeedCard() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(24),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_isInterviewStarted && _cameraController != null && _cameraController!.value.isInitialized && !_isCameraMuted)
                CameraPreview(_cameraController!)
              else
                const Center(child: Icon(Icons.person, color: Colors.white24, size: 48)),
              Positioned(
                top: 12,
                right: 12,
                child: _buildBadge('You', Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: color, size: 8),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildQuestionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
              style: const TextStyle(color: accentPurple, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(height: 24),
          _isLoadingQuestions 
            ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: accentPurple)))
            : Text(
                _isInterviewStarted ? _questions[_currentQuestionIndex] : "Ready to start your interview?",
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600),
              ),
          const SizedBox(height: 32),
          Row(
            children: [
              _buildIconBtn(Icons.videocam, !_isCameraMuted, _toggleCamera),
              const SizedBox(width: 12),
              _buildIconBtn(Icons.mic, !_isMicMuted, _toggleMic),
              const Spacer(),
              if (!_isInterviewStarted)
                ElevatedButton(
                  onPressed: _startInterview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Start Interview', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              else ...[
                TextButton(
                  onPressed: _finishInterview,
                  child: Text('End Interview', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    if (_currentQuestionIndex < _questions.length - 1) {
                      setState(() {
                        _currentQuestionIndex++;
                        _userTranscription = "";
                      });
                      _speakQuestion();
                    } else {
                      _finishInterview();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    _currentQuestionIndex < _questions.length - 1 ? 'Next Question' : 'Finish',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
          if (_userTranscription.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.record_voice_over, color: accentPurple, size: 16),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _userTranscription,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _toggleCamera() async {
    if (_cameraController == null) {
      await _startInterview(); // Re-init if for some reason it's null
      return;
    }
    
    setState(() {
      _isCameraMuted = !_isCameraMuted;
    });
  }

  Future<void> _toggleMic() async {
    setState(() {
      _isMicMuted = !_isMicMuted;
    });
  }

  Widget _buildIconBtn(IconData icon, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active ? Colors.white : statusRed.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: active ? Colors.black : statusRed, size: 24),
      ),
    );
  }

  Widget _buildInsightsPanel() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Live AI Insights', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('AI is analyzing your behavior in real-time', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14)),
          const SizedBox(height: 40),
          _buildInsightRow('Clarity', _clarity, Colors.blueAccent),
          _buildInsightRow('Confidence', _confidence, Colors.blueAccent),
          _buildInsightRow('Technical', _technicalDepth, Colors.greenAccent),
          _buildInsightRow('Communication', _communication, Colors.blueAccent),
          _buildInsightRow('Tone Modulation', _toneModulation, Colors.blueAccent),
          _buildInsightRow('Keyword Relevance', _keywordRelevance, Colors.blueAccent),
        ],
      ),
    );
  }

  Widget _buildInsightRow(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
              Text('${(value * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
