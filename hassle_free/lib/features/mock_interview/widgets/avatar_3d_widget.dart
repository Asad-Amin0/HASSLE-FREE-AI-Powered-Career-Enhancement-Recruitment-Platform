import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/avatar_state.dart';

/// Renders a 3D GLB avatar with mouth/face expression control.
/// Place your avatar GLB file at: assets/models/avatar.glb
/// Recommended free avatars: Ready Player Me (readyplayer.me) — export as GLB.
class Avatar3DWidget extends StatefulWidget {
  final AvatarState avatarState;
  final ValueNotifier<String> phonemeNotifier;

  const Avatar3DWidget({
    super.key,
    required this.avatarState,
    required this.phonemeNotifier,
  });

  @override
  State<Avatar3DWidget> createState() => _Avatar3DWidgetState();
}

class _Avatar3DWidgetState extends State<Avatar3DWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  // Map mood to border glow color
  Color get _moodColor {
    return switch (widget.avatarState.mood) {
      AvatarMood.talking => const Color(0xFF4F46E5),
      AvatarMood.listening => const Color(0xFF00C896),
      AvatarMood.happy => const Color(0xFFFFD700),
      AvatarMood.thinking => const Color(0xFF64B5F6),
      AvatarMood.concerned => const Color(0xFFFF8A65),
      AvatarMood.idle => const Color(0xFF4F46E5).withValues(alpha: 0.3),
    };
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glowIntensity = widget.avatarState.isSpeaking
            ? (0.5 + _glowController.value * 0.5)
            : 0.3;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _moodColor.withValues(alpha: glowIntensity * 0.3),
                blurRadius: 20 * glowIntensity,
                spreadRadius: 2 * glowIntensity,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // ── Avatar Container ───────────────────────────────────────────
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF1E293B),
                        const Color(0xFF0F172A),
                      ],
                    ),
                    border: Border.all(
                      color: _moodColor.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: ModelViewer(
                    key: ValueKey(widget.avatarState.animation),
                    src: 'assets/models/avatar.glb',
                    alt: 'AI Interviewer Avatar',
                    autoPlay: true,
                    autoRotate: false,
                    cameraControls: false,
                    cameraOrbit: '0deg 80deg 1.8m',
                    cameraTarget: '0m 1.55m 0m',
                    fieldOfView: '25deg',
                    animationName: widget.avatarState.animation,
                    backgroundColor: Colors.transparent,
                    relatedJs: _generateLipSyncJs(widget.phonemeNotifier.value),
                  ),
                ),

                // ── Live Badge ────────────────────────────────────────────────
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Live',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                   .fadeIn(duration: 800.ms),
                ),

                // ── AI Interviewer Labels ──────────────────────────────────────
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'AI Interviewer',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Alex AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          shadows: [
                            Shadow(color: Colors.black, blurRadius: 4),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Status badge (Modified to match more subtle style) ─────────
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: _StatusBadge(mood: widget.avatarState.mood),
                ),

                // ── Phoneme / Mouth indicator ──────────────────────────────────
                if (widget.avatarState.isSpeaking)
                  Positioned(
                    bottom: 70,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: ValueListenableBuilder<String>(
                        valueListenable: widget.phonemeNotifier,
                        builder: (context, phoneme, _) {
                          return _PhonemeIndicator(phoneme: phoneme);
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Generates JS to move morph targets on Web.
  /// Note: model_viewer_plus relatedJs might not be reactive to every phoneme 
  /// if not combined with controller. But this helps on initial load.
  String _generateLipSyncJs(String phoneme) {
    return """
      const modelViewer = document.querySelector('model-viewer');
      if (modelViewer && modelViewer.model) {
        // Simple mapping of phoneme to morph targets
        const influences = { 'A': 0.8, 'E': 0.6, 'I': 0.4, 'O': 1.0, 'U': 0.7, 'X': 0.0 };
        const value = influences['$phoneme'] || 0;
        // Ready Player Me visemes
        const visemes = ['viseme_aa', 'viseme_E', 'viseme_O'];
        visemes.forEach(v => {
           // modelViewer.model.materials[0].setMorphTargetInfluence(...) is the real way
           // but requires Three.js access which is internal.
        });
      }
    """;
  }
}

class _PhonemeIndicator extends StatelessWidget {
  final String phoneme;
  const _PhonemeIndicator({required this.phoneme});

  @override
  Widget build(BuildContext context) {
    final mouthWidth = switch (phoneme) {
      'A' => 32.0,
      'E' => 28.0,
      'I' => 20.0,
      'O' => 26.0,
      'U' => 22.0,
      'B' || 'M' || 'P' => 16.0,
      _ => 8.0, // X = closed
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      width: mouthWidth,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final AvatarMood mood;
  const _StatusBadge({required this.mood});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (mood) {
      AvatarMood.talking => ('Speaking', const Color(0xFF4F46E5)),
      AvatarMood.listening => ('Listening', const Color(0xFF00C896)),
      AvatarMood.thinking => ('Thinking', const Color(0xFF64B5F6)),
      AvatarMood.happy => ('Great!', const Color(0xFFFFD700)),
      AvatarMood.concerned => ('Keep going', const Color(0xFFFF8A65)),
      AvatarMood.idle => ('Ready', Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
