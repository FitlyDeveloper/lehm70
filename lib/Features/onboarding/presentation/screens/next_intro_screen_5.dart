import 'package:flutter/material.dart';
import 'package:fitness_app/Features/onboarding/presentation/screens/next_intro_screen.dart';
import 'package:fitness_app/Features/onboarding/presentation/screens/gender_selection_screen.dart';
import 'package:fitness_app/Features/onboarding/presentation/screens/weight_height_copy_screen.dart';
import 'package:fitness_app/Features/onboarding/presentation/screens/weight_goal_copy_screen.dart';
import 'package:fitness_app/Features/onboarding/presentation/screens/questions/basic_info_screen.dart';

class NextIntroScreen5 extends StatefulWidget {
  final bool isMetric;
  final int selectedWeight;
  final String? gymGoal;
  final int heightInCm;

  const NextIntroScreen5({
    super.key,
    required this.isMetric,
    required this.selectedWeight,
    required this.heightInCm,
    this.gymGoal,
  });

  @override
  State<NextIntroScreen5> createState() => _NextIntroScreen5State();
}

class _NextIntroScreen5State extends State<NextIntroScreen5> {
  int? selectedIndex; // Track selected option
  String? selectedGoal;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background gradient
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  Colors.grey[100]!.withOpacity(0.9),
                ],
              ),
            ),
          ),

          // Header content (back arrow and progress bar)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.07),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.black, size: 24),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 40),
                          child: const LinearProgressIndicator(
                            value: 7 / 13,
                            minHeight: 2,
                            backgroundColor: Color(0xFFE5E5EA),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 21.2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Achieve your goals\n2x faster with Fitly!',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          height: 1.21,
                          fontFamily: '.SF Pro Display',
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Add this after the header content and before the bottom white box
          Positioned(
            top: MediaQuery.of(context).size.height * 0.35,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: [
                    const Color(0xFFF0F1F3)
                        .withRed(250), // Increased red tint from 245 to 250
                    const Color(0xFFF0F1F3), // Original color in middle
                    const Color(0xFFF0F1F3)
                        .withGreen(250), // Increased green tint from 245 to 250
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              height: MediaQuery.of(context).size.height * 0.33,
              child: Center(
                // Center the image
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  height: MediaQuery.of(context).size.height * 0.28,
                  child: Image.asset(
                    'assets/images/hourglass.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),

          // Bottom white box and button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: MediaQuery.of(context).size.height * 0.148887,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.zero,
              ),
            ),
          ),

          // Add this before the closing of Stack
          Positioned(
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).size.height * 0.06,
            child: Container(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.0689,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(28),
              ),
              child: TextButton(
                onPressed: _handleNavigation,
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    fontFamily: '.SF Pro Display',
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleNavigation() {
    // Print debug info before navigation
    print(
        "NextIntroScreen5: Passing height=${widget.heightInCm}cm to WeightHeightCopyScreen");

    // Navigate to the WeightHeightCopyScreen which handles both weight/height and birthdate
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WeightHeightCopyScreen(
          isMetric: widget.isMetric,
          initialWeight: widget.selectedWeight,
          gymGoal: widget.gymGoal,
          initialHeightInCm:
              widget.heightInCm, // Pass the height parameter from this screen
        ),
      ),
    );
  }

  Widget _buildOption(String text, {required int index}) {
    final isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedIndex = index;
          selectedGoal = text;
        });
      },
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : const Color(0xFFF0F1F3),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.black,
              fontFamily: '.SF Pro Display',
            ),
          ),
        ),
      ),
    );
  }
}
