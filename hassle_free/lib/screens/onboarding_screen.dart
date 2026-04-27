import 'package:flutter/material.dart';
import '../models/onboarding_data.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: 'Smart Resume\nEnhancement',
      description: 'Unlock your potential with our AI-driven resume builder that highlights your best skills.',
      icon: Icons.description_outlined,
      gradient: [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
    ),
    OnboardingData(
      title: 'AI Mock\nInterviews',
      description: 'Practice with our intelligent interviewer and receive real-time feedback to ace your meetings.',
      icon: Icons.video_call_outlined,
      gradient: [const Color(0xFF8B5CF6), const Color(0xFFD946EF)],
    ),
    OnboardingData(
      title: 'Smart Job\nMatching',
      description: 'Connect with your dream career through our precision-engineered AI job matching algorithm.',
      icon: Icons.rocket_launch_outlined,
      gradient: [const Color(0xFFD946EF), const Color(0xFF6366F1)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWeb = size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // Background decorative glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _pages[_currentPage].gradient[0].withValues(alpha: 0.1),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (int page) {
                      setState(() {
                        _currentPage = page;
                      });
                    },
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      return SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Icon Container with Gradient & Shadow
                              Container(
                                height: isWeb ? 280 : 200,
                                width: isWeb ? 280 : 200,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: _pages[index].gradient,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(isWeb ? 60 : 40),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _pages[index].gradient[0].withValues(alpha: 0.3),
                                      blurRadius: 30,
                                      offset: const Offset(0, 15),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Icon(
                                    _pages[index].icon,
                                    size: isWeb ? 120 : 80,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 60),
                              Text(
                                _pages[index].title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isWeb ? 48 : 36,
                                  fontWeight: FontWeight.w900,
                                  height: 1.1,
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                _pages[index].description,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: const Color(0xFF94A3B8),
                                  fontSize: isWeb ? 20 : 16,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                // Bottom Section
                Container(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _pages.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 8),
                            height: 10,
                            width: _currentPage == index ? 30 : 10,
                            decoration: BoxDecoration(
                              color: _currentPage == index 
                                  ? _pages[_currentPage].gradient[0]
                                  : const Color(0xFF334155),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),
                      
                      // Action Buttons
                      SizedBox(
                        width: isWeb ? 400 : double.infinity,
                        height: 64,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _pages[_currentPage].gradient,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: _pages[_currentPage].gradient[0].withValues(alpha: 0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              if (_currentPage < _pages.length - 1) {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 600),
                                  curve: Curves.easeInOutQuart,
                                );
                              } else {
                                Navigator.pushReplacement(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
                                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                      return FadeTransition(opacity: animation, child: child);
                                    },
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Text(
                              _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      if (_currentPage < _pages.length - 1)
                        TextButton(
                          onPressed: () {
                            _pageController.animateToPage(
                              _pages.length - 1,
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeInOutQuart,
                            );
                          },
                          child: const Text(
                            'Skip',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
