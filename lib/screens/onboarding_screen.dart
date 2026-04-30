import 'dart:async';

import 'package:flutter/material.dart';

/// Swipeable intro; no skip. Completes after the last slide is shown.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinished});

  final Future<void> Function() onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const List<String> _assetPaths = [
    'assets/onboarding/1.png',
    'assets/onboarding/2.png',
    'assets/onboarding/3.png',
    'assets/onboarding/4.png',
    'assets/onboarding/5.png',
    'assets/onboarding/6.png',
    'assets/onboarding/7.png',
  ];

  static const int _visibleCount = 7;

  final PageController _pageController = PageController();

  int _pageIndex = 0;
  bool _finishing = false;

  int get _counterNumerator =>
      _pageIndex >= _visibleCount - 1 ? _visibleCount : _pageIndex + 1;

  Future<void> _complete() async {
    if (_finishing) return;
    _finishing = true;
    try {
      await widget.onFinished();
    } finally {
      if (mounted) _finishing = false;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canPop = _pageIndex == 0;

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_pageIndex > 0) {
          await _pageController.previousPage(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _assetPaths.length,
              onPageChanged: (i) {
                setState(() => _pageIndex = i);
                if (i == _assetPaths.length - 1) {
                  unawaited(_complete());
                }
              },
              itemBuilder: (context, index) {
                return Image.asset(
                  _assetPaths[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  alignment: Alignment.center,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image_outlined,
                        color: Colors.white54, size: 48),
                  ),
                );
              },
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Text(
                        '$_counterNumerator / $_visibleCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
