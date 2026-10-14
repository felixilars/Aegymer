import 'package:flutter/material.dart';
import 'package:aegymer/presentation/welcome_page.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingSlideData> _slides = const [
    _OnboardingSlideData(
      icon: Icons.fitness_center_rounded,
      iconGradient: [Color(0xFF2563EB), Color(0xFF38BDF8)],
      tag: 'WORKOUT TRACKER',
      title: 'Training & Progressive Overload',
      description:
          'Log sets, weights, and reps with built-in rest timers, a plate calculator, and calorie estimates.',
      highlights: ['Auto Rest Timer', 'Plate Calculator', 'Calorie Calculation'],
    ),
    _OnboardingSlideData(
      icon: Icons.auto_graph_rounded,
      iconGradient: [Color(0xFF7C3AED), Color(0xFFA855F7)],
      tag: 'LOCAL ML',
      title: 'On-Device Autoregulation',
      description:
          'Track volume load and fatigue trends to get weight and rep recommendations based on past sessions.',
      highlights: ['Volume Load Analysis', 'Progressive Overload', 'Offline Processing'],
    ),
    _OnboardingSlideData(
      icon: Icons.restaurant_menu_rounded,
      iconGradient: [Color(0xFF059669), Color(0xFF10B981)],
      tag: 'NUTRITION',
      title: 'Nutrition & Daily Macros',
      description:
          'Calculate BMR, TDEE, and macro ratios with meal suggestions matched to your daily calorie target.',
      highlights: ['BMR & TDEE Engine', 'Macro Breakdown', 'Meal Planning'],
    ),
    _OnboardingSlideData(
      icon: Icons.lock_outline_rounded,
      iconGradient: [Color(0xFFEA580C), Color(0xFFF97316)],
      tag: 'PRIVACY FIRST',
      title: 'Private & Offline-First',
      description:
          'All workout and body data stays on your device. No account or sign-up required.',
      highlights: ['No Account Needed', 'Zero Data Tracking', 'Works 100% Offline'],
    ),
  ];

  void _navigateToSetup() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const WelcomePage(),
      ),
    );
  }

  void _onNext() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _navigateToSetup();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = theme.scaffoldBackgroundColor;
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.fitness_center_rounded,
                          color: primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Aegymer',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  if (_currentPage < _slides.length - 1)
                    TextButton(
                      onPressed: _navigateToSetup,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),

            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return _buildSlide(slide, isDark, primaryColor);
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 7,
                        width: isActive ? 26 : 7,
                        decoration: BoxDecoration(
                          color: isActive
                              ? primaryColor
                              : (isDark ? Colors.white24 : Colors.black12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentPage == _slides.length - 1
                                ? 'Set Up My Profile'
                                : 'Continue',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _currentPage == _slides.length - 1
                                ? Icons.arrow_forward_rounded
                                : Icons.chevron_right_rounded,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(_OnboardingSlideData slide, bool isDark, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 1),

          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: slide.iconGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: slide.iconGradient.first.withValues(alpha: 0.35),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Icon(
              slide.icon,
              size: 64,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: slide.iconGradient.first.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: slide.iconGradient.first.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              slide.tag,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: slide.iconGradient.first,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.25,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),

          Text(
            slide.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 20),

          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: slide.highlights.map((h) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 13,
                      color: slide.iconGradient.first,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      h,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _OnboardingSlideData {
  final IconData icon;
  final List<Color> iconGradient;
  final String tag;
  final String title;
  final String description;
  final List<String> highlights;

  const _OnboardingSlideData({
    required this.icon,
    required this.iconGradient,
    required this.tag,
    required this.title,
    required this.description,
    required this.highlights,
  });
}