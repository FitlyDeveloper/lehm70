import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'dart:async';
import 'package:fitness_app/Features/onboarding/presentation/screens/next_intro_screen_5.dart';
import 'package:fitness_app/Features/onboarding/presentation/screens/weight_height_copy_screen.dart';
import 'package:fitness_app/Features/onboarding/presentation/screens/gender_selection_screen.dart';

class CustomScrollBehavior extends ScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics();
  }
}

class NextIntroScreen4 extends StatefulWidget {
  final bool isMetric;
  final int initialWeight;
  final String? gymGoal;

  const NextIntroScreen4({
    super.key,
    required this.isMetric,
    required this.initialWeight,
    this.gymGoal,
  });

  @override
  State<NextIntroScreen4> createState() => _NextIntroScreen4State();
}

class _NextIntroScreen4State extends State<NextIntroScreen4> {
  // Keep the ValueNotifiers as we might use them for the new implementation:
  late ValueNotifier<int> selectedWeight;
  late ValueNotifier<int> selectedFeet;
  late ValueNotifier<int> selectedInches;
  bool isMetric = false;
  final FocusNode _weightFocusNode = FocusNode();
  final FocusNode _feetFocusNode = FocusNode();
  final FocusNode _inchesFocusNode = FocusNode();
  Timer? _autoRepeatTimer;
  static const Duration _initialDelay = Duration(milliseconds: 500);
  static const Duration _repeatInterval = Duration(milliseconds: 50);
  bool _isMiddleMouseDown = false;
  double _dragAccumulator = 0;

  @override
  void initState() {
    super.initState();
    selectedWeight = ValueNotifier(widget.initialWeight);
    selectedFeet = ValueNotifier(widget.isMetric ? 170 : 5);
    selectedInches = ValueNotifier(7);
  }

  @override
  void dispose() {
    _autoRepeatTimer?.cancel();
    _weightFocusNode.dispose();
    _feetFocusNode.dispose();
    _inchesFocusNode.dispose();
    selectedWeight.dispose();
    selectedFeet.dispose();
    selectedInches.dispose();
    super.dispose();
  }

  void _startAutoRepeat(VoidCallback action) {
    action(); // Immediate first action
    _autoRepeatTimer?.cancel();
    _autoRepeatTimer = Timer(_initialDelay, () {
      _autoRepeatTimer = Timer.periodic(_repeatInterval, (_) => action());
    });
  }

  void _handleScroll(
      double delta, ValueNotifier<int> notifier, int min, int max) {
    if (delta > 0) {
      // Scrolling down - should increase
      setState(() {
        if (_isMiddleMouseDown) {
          notifier.value = (notifier.value + 10).clamp(min, max);
        } else {
          if (notifier == selectedFeet) {
            if (isMetric) {
              // For metric (cm)
              notifier.value = notifier.value >= 250 ? 0 : notifier.value + 1;
            } else {
              // For imperial (feet)
              notifier.value = notifier.value >= 8 ? 0 : notifier.value + 1;
            }
          }
          // For inches
          else if (notifier == selectedInches) {
            notifier.value = notifier.value >= 11 ? 0 : notifier.value + 1;
          }
          // For weight
          else {
            notifier.value = notifier.value >= (isMetric ? 300 : 700)
                ? 0
                : notifier.value + 1;
          }
        }
      });
    } else if (delta < 0) {
      // Scrolling up - should decrease
      setState(() {
        if (_isMiddleMouseDown) {
          notifier.value = (notifier.value - 10).clamp(min, max);
        } else {
          if (notifier == selectedFeet) {
            if (isMetric) {
              // For metric (cm)
              notifier.value = notifier.value <= 0 ? 250 : notifier.value - 1;
            } else {
              // For imperial (feet)
              notifier.value = notifier.value <= 0 ? 8 : notifier.value - 1;
            }
          }
          // For inches
          else if (notifier == selectedInches) {
            notifier.value = notifier.value <= 0 ? 11 : notifier.value - 1;
          }
          // For weight
          else {
            notifier.value = notifier.value <= 0
                ? (isMetric ? 300 : 700)
                : notifier.value - 1;
          }
        }
      });
    }
  }

  int _lbsToKg(int lbs) {
    return (lbs * 0.453592).round();
  }

  int _kgToLbs(int kg) {
    return (kg * 2.20462).round();
  }

  int _ftInToCm(int feet, int inches) {
    return ((feet * 12 + inches) * 2.54).round();
  }

  void _cmToFtIn(int cm) {
    double inches = cm / 2.54;
    int feet = (inches / 12).floor();
    int remainingInches = (inches % 12).round();
    selectedFeet.value = feet;
    selectedInches.value = remainingInches;
  }

  void _handleNavigation() {
    // Calculate height first - using the current selectedFeet and selectedInches values
    final heightInCm = isMetric
        ? selectedFeet.value // Already in cm for metric
        : _ftInToCm(selectedFeet.value,
            selectedInches.value); // Convert total inches to cm

    print(
        "Navigation: Selected height=${isMetric ? selectedFeet.value : '${selectedFeet.value}ft ${selectedInches.value}in'}, converted to $heightInCm cm"); // Debug

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NextIntroScreen5(
          isMetric: isMetric,
          selectedWeight: selectedWeight.value,
          gymGoal: widget.gymGoal,
          heightInCm: heightInCm, // Pass the calculated height
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Box 4 (background with gradient)
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white
                      .withOpacity(0.95), // Slightly transparent white at top
                  const Color(0xFFF5F5F7).withOpacity(
                      0.92), // Apple's typical light gray, slightly transparent
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),

          // Add a subtle overlay for the glass effect
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.white.withOpacity(0.05), // Very subtle white overlay
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
                            value: 6 / 13,
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
                        'Weight & Height',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          height: 1.21,
                          fontFamily: '.SF Pro Display',
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'This helps us personalize your plan.',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                          fontFamily: '.SF Pro Display',
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 148.41),
                // Weight and Height headers
                Row(
                  children: [
                    // Weight label
                    Container(
                      width: (MediaQuery.of(context).size.width - 52) / 3,
                      child: Padding(
                        padding: EdgeInsets.only(left: 44.85),
                        child: Text(
                          'Weight',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                            fontFamily: '.SF Pro Display',
                          ),
                        ),
                      ),
                    ),
                    Container(width: 4),
                    // Height label
                    Container(
                      width: (MediaQuery.of(context).size.width - 52) * 2 / 3,
                      child: Padding(
                        padding: EdgeInsets.only(left: 126.72),
                        child: Text(
                          'Height',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                            fontFamily: '.SF Pro Display',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),

          // Box 5 (white box at bottom)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: MediaQuery.of(context).size.height * 0.148887,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95), // Slightly transparent
                borderRadius: BorderRadius.zero,
              ),
            ),
          ),

          // Box 6 (black button)
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

          // Main content should be back in its original position
          Positioned(
            top: MediaQuery.of(context).size.height * 0.467556,
            left: 24,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Weight and Height headers
                Row(
                  children: [
                    // Weight picker
                    Expanded(
                      child: Transform.translate(
                        offset: Offset(isMetric ? -29.4 : 0, 0),
                        child: ScrollConfiguration(
                          behavior: CustomScrollBehavior(),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Container(
                              height: 160,
                              child: GestureDetector(
                                onTap: () => _weightFocusNode.requestFocus(),
                                onVerticalDragUpdate: (details) {
                                  _dragAccumulator += details.delta.dy * 0.1;
                                  if (_dragAccumulator.abs() >= 1) {
                                    _handleScroll(
                                        _dragAccumulator,
                                        selectedWeight,
                                        0,
                                        isMetric ? 300 : 700);
                                    _dragAccumulator = 0;
                                  }
                                },
                                onPanUpdate: (details) {
                                  _dragAccumulator += details.delta.dy * 0.1;
                                  if (_dragAccumulator.abs() >= 1) {
                                    _handleScroll(
                                        _dragAccumulator,
                                        selectedWeight,
                                        0,
                                        isMetric ? 300 : 700);
                                    _dragAccumulator = 0;
                                  }
                                },
                                child: Listener(
                                  onPointerDown: (event) {
                                    if (event.buttons == kMiddleMouseButton) {
                                      setState(() {
                                        _isMiddleMouseDown = true;
                                      });
                                    }
                                  },
                                  onPointerUp: (event) {
                                    setState(() {
                                      _isMiddleMouseDown = false;
                                    });
                                  },
                                  onPointerSignal: (pointerSignal) {
                                    if (pointerSignal is PointerScrollEvent) {
                                      _dragAccumulator +=
                                          pointerSignal.scrollDelta.dy * 0.1;
                                      if (_dragAccumulator.abs() >= 1) {
                                        _handleScroll(
                                            _dragAccumulator,
                                            selectedWeight,
                                            0,
                                            isMetric ? 300 : 700);
                                        _dragAccumulator = 0;
                                      }
                                    }
                                  },
                                  child: ValueListenableBuilder<int>(
                                    valueListenable: selectedWeight,
                                    builder: (context, value, child) {
                                      final maxWeight = isMetric ? 300 : 700;
                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${value >= maxWeight - 1 ? 1 : value >= maxWeight - 2 ? 0 : value + 2} ${isMetric ? 'kg' : 'lb'}',
                                            style: TextStyle(
                                              fontSize: 17,
                                              color: Colors.grey[300],
                                              fontWeight: FontWeight.normal,
                                              fontFamily: '.SF Pro Display',
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${value >= maxWeight ? 0 : value + 1} ${isMetric ? 'kg' : 'lb'}',
                                            style: TextStyle(
                                              fontSize: 17,
                                              color: Colors.grey[300],
                                              fontWeight: FontWeight.normal,
                                              fontFamily: '.SF Pro Display',
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            height: 40,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              border: Border(
                                                top: BorderSide(
                                                    color: Colors.grey[200]!),
                                                bottom: BorderSide(
                                                    color: Colors.grey[200]!),
                                              ),
                                            ),
                                            child: Text(
                                              '$value ${isMetric ? 'kg' : 'lb'}',
                                              style: const TextStyle(
                                                fontSize: 17,
                                                color: Colors.black,
                                                fontWeight: FontWeight.w600,
                                                fontFamily: '.SF Pro Display',
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${value <= 0 ? maxWeight : value - 1} ${isMetric ? 'kg' : 'lb'}',
                                            style: TextStyle(
                                              fontSize: 17,
                                              color: Colors.grey[300],
                                              fontWeight: FontWeight.normal,
                                              fontFamily: '.SF Pro Display',
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${value <= 1 ? maxWeight - 1 : value <= 0 ? maxWeight - 2 : value - 2} ${isMetric ? 'kg' : 'lb'}',
                                            style: TextStyle(
                                              fontSize: 17,
                                              color: Colors.grey[300],
                                              fontWeight: FontWeight.normal,
                                              fontFamily: '.SF Pro Display',
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5.6),
                    // Feet picker
                    Expanded(
                      child: Transform.translate(
                        offset: Offset(isMetric ? -12.25 : 35, 0),
                        child: ScrollConfiguration(
                          behavior: CustomScrollBehavior(),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Container(
                              height: 160,
                              child: GestureDetector(
                                onTap: () => _feetFocusNode.requestFocus(),
                                onVerticalDragUpdate: (details) {
                                  _dragAccumulator += details.delta.dy * 0.1;
                                  if (_dragAccumulator.abs() >= 1) {
                                    _handleScroll(_dragAccumulator,
                                        selectedFeet, 0, isMetric ? 250 : 8);
                                    _dragAccumulator = 0;
                                  }
                                },
                                onPanUpdate: (details) {
                                  _dragAccumulator += details.delta.dy * 0.1;
                                  if (_dragAccumulator.abs() >= 1) {
                                    _handleScroll(_dragAccumulator,
                                        selectedFeet, 0, isMetric ? 250 : 8);
                                    _dragAccumulator = 0;
                                  }
                                },
                                child: Listener(
                                  onPointerDown: (event) {
                                    if (event.buttons == kMiddleMouseButton) {
                                      setState(() {
                                        _isMiddleMouseDown = true;
                                      });
                                    }
                                  },
                                  onPointerUp: (event) {
                                    setState(() {
                                      _isMiddleMouseDown = false;
                                    });
                                  },
                                  onPointerSignal: (pointerSignal) {
                                    if (pointerSignal is PointerScrollEvent) {
                                      _dragAccumulator +=
                                          pointerSignal.scrollDelta.dy * 0.1;
                                      if (_dragAccumulator.abs() >= 1) {
                                        _handleScroll(
                                            _dragAccumulator,
                                            selectedFeet,
                                            0,
                                            isMetric ? 250 : 8);
                                        _dragAccumulator = 0;
                                      }
                                    }
                                  },
                                  child: ValueListenableBuilder<int>(
                                    valueListenable: selectedFeet,
                                    builder: (context, value, child) {
                                      if (isMetric) {
                                        // For metric (cm)
                                        return Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '${value >= 249 ? 0 : value >= 248 ? 250 : value + 2} ${isMetric ? 'cm' : 'ft'}',
                                              style: TextStyle(
                                                fontSize: 17,
                                                color: Colors.grey[300],
                                                fontWeight: FontWeight.normal,
                                                fontFamily: '.SF Pro Display',
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${value >= 250 ? 0 : value + 1} ${isMetric ? 'cm' : 'ft'}',
                                              style: TextStyle(
                                                fontSize: 17,
                                                color: Colors.grey[300],
                                                fontWeight: FontWeight.normal,
                                                fontFamily: '.SF Pro Display',
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              height: 40,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  top: BorderSide(
                                                      color: Colors.grey[200]!),
                                                  bottom: BorderSide(
                                                      color: Colors.grey[200]!),
                                                ),
                                              ),
                                              child: Text(
                                                '$value ${isMetric ? 'cm' : 'ft'}',
                                                style: const TextStyle(
                                                  fontSize: 17,
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.w600,
                                                  fontFamily: '.SF Pro Display',
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${value <= 0 ? 250 : value - 1} ${isMetric ? 'cm' : 'ft'}',
                                              style: TextStyle(
                                                fontSize: 17,
                                                color: Colors.grey[300],
                                                fontWeight: FontWeight.normal,
                                                fontFamily: '.SF Pro Display',
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${value <= 1 ? 250 : value <= 0 ? 249 : value - 2} ${isMetric ? 'cm' : 'ft'}',
                                              style: TextStyle(
                                                fontSize: 17,
                                                color: Colors.grey[300],
                                                fontWeight: FontWeight.normal,
                                                fontFamily: '.SF Pro Display',
                                              ),
                                            ),
                                          ],
                                        );
                                      } else {
                                        // Keep existing imperial (feet) display logic
                                        return Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '${value == 8 ? 0 : value + 2} ${isMetric ? 'cm' : 'ft'}',
                                              style: TextStyle(
                                                fontSize: 17,
                                                color: Colors.grey[300],
                                                fontWeight: FontWeight.normal,
                                                fontFamily: '.SF Pro Display',
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${value == 8 ? 0 : value == 7 ? 8 : value + 1} ${isMetric ? 'cm' : 'ft'}',
                                              style: TextStyle(
                                                fontSize: 17,
                                                color: Colors.grey[300],
                                                fontWeight: FontWeight.normal,
                                                fontFamily: '.SF Pro Display',
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              height: 40,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  top: BorderSide(
                                                      color: Colors.grey[200]!),
                                                  bottom: BorderSide(
                                                      color: Colors.grey[200]!),
                                                ),
                                              ),
                                              child: Text(
                                                '$value ${isMetric ? 'cm' : 'ft'}',
                                                style: const TextStyle(
                                                  fontSize: 17,
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.w600,
                                                  fontFamily: '.SF Pro Display',
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${value == 0 ? 8 : value - 1} ${isMetric ? 'cm' : 'ft'}',
                                              style: TextStyle(
                                                fontSize: 17,
                                                color: Colors.grey[300],
                                                fontWeight: FontWeight.normal,
                                                fontFamily: '.SF Pro Display',
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${value == 0 ? 7 : value == 1 ? 8 : value - 2} ${isMetric ? 'cm' : 'ft'}',
                                              style: TextStyle(
                                                fontSize: 17,
                                                color: Colors.grey[300],
                                                fontWeight: FontWeight.normal,
                                                fontFamily: '.SF Pro Display',
                                              ),
                                            ),
                                          ],
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Only show inches picker when not in metric mode
                    if (!isMetric) ...[
                      const SizedBox(width: 5.6),
                      // Inches picker
                      Expanded(
                        child: ScrollConfiguration(
                          behavior: CustomScrollBehavior(),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Container(
                              height: 160,
                              child: GestureDetector(
                                onTap: () => _inchesFocusNode.requestFocus(),
                                onVerticalDragUpdate: (details) {
                                  _dragAccumulator += details.delta.dy * 0.1;
                                  if (_dragAccumulator.abs() >= 1) {
                                    _handleScroll(_dragAccumulator,
                                        selectedInches, 0, 11);
                                    _dragAccumulator = 0;
                                  }
                                },
                                onPanUpdate: (details) {
                                  _dragAccumulator += details.delta.dy * 0.1;
                                  if (_dragAccumulator.abs() >= 1) {
                                    _handleScroll(_dragAccumulator,
                                        selectedInches, 0, 11);
                                    _dragAccumulator = 0;
                                  }
                                },
                                child: Listener(
                                  onPointerDown: (event) {
                                    if (event.buttons == kMiddleMouseButton) {
                                      setState(() {
                                        _isMiddleMouseDown = true;
                                      });
                                    }
                                  },
                                  onPointerUp: (event) {
                                    setState(() {
                                      _isMiddleMouseDown = false;
                                    });
                                  },
                                  onPointerSignal: (pointerSignal) {
                                    if (pointerSignal is PointerScrollEvent) {
                                      _dragAccumulator +=
                                          pointerSignal.scrollDelta.dy * 0.1;
                                      if (_dragAccumulator.abs() >= 1) {
                                        _handleScroll(_dragAccumulator,
                                            selectedInches, 0, 11);
                                        _dragAccumulator = 0;
                                      }
                                    }
                                  },
                                  child: ValueListenableBuilder<int>(
                                    valueListenable: selectedInches,
                                    builder: (context, value, child) {
                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${value == 11 ? 1 : value == 10 ? 0 : value + 2} ${isMetric ? 'cm' : 'in'}',
                                            style: TextStyle(
                                              fontSize: 17,
                                              color: Colors.grey[300],
                                              fontWeight: FontWeight.normal,
                                              fontFamily: '.SF Pro Display',
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${value == 11 ? 0 : value + 1} ${isMetric ? 'cm' : 'in'}',
                                            style: TextStyle(
                                              fontSize: 17,
                                              color: Colors.grey[300],
                                              fontWeight: FontWeight.normal,
                                              fontFamily: '.SF Pro Display',
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            height: 40,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              border: Border(
                                                top: BorderSide(
                                                    color: Colors.grey[200]!),
                                                bottom: BorderSide(
                                                    color: Colors.grey[200]!),
                                              ),
                                            ),
                                            child: Text(
                                              '$value ${isMetric ? 'cm' : 'in'}',
                                              style: const TextStyle(
                                                fontSize: 17,
                                                color: Colors.black,
                                                fontWeight: FontWeight.w600,
                                                fontFamily: '.SF Pro Display',
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${value == 0 ? 11 : value - 1} ${isMetric ? 'cm' : 'in'}',
                                            style: TextStyle(
                                              fontSize: 17,
                                              color: Colors.grey[300],
                                              fontWeight: FontWeight.normal,
                                              fontFamily: '.SF Pro Display',
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${value == 0 ? 10 : value == 1 ? 11 : value - 2} ${isMetric ? 'cm' : 'in'}',
                                            style: TextStyle(
                                              fontSize: 17,
                                              color: Colors.grey[300],
                                              fontWeight: FontWeight.normal,
                                              fontFamily: '.SF Pro Display',
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Add this as a new Positioned widget in the Stack, after the header content
          Positioned(
            top: MediaQuery.of(context).size.height * 0.31,
            left: 0,
            right: 0,
            child: Padding(
              padding: EdgeInsets.only(
                  left: MediaQuery.of(context).size.width * 0.22),
              child: Container(
                width: 200,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      'Imperial',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: isMetric ? Color(0xFF9E9E9E) : Colors.black,
                        fontFamily: '.SF Pro Display',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: isMetric,
                      onChanged: (value) {
                        setState(() {
                          if (value != isMetric) {
                            // Only convert if actually changing units
                            if (value) {
                              // Converting to metric
                              selectedWeight.value =
                                  _lbsToKg(selectedWeight.value);
                              int newHeight = _ftInToCm(
                                  selectedFeet.value, selectedInches.value);
                              selectedFeet.value =
                                  newHeight; // In metric mode, this stores cm
                              selectedInches.value =
                                  0; // Not used in metric mode
                            } else {
                              // Converting to imperial
                              selectedWeight.value =
                                  _kgToLbs(selectedWeight.value);
                              _cmToFtIn(selectedFeet
                                  .value); // This will update both feet and inches
                            }
                          }
                          isMetric = value;
                        });
                      },
                      activeColor: Colors.black,
                      activeTrackColor: Colors.black,
                      inactiveTrackColor: Colors.grey[200],
                      trackOutlineColor:
                          MaterialStateProperty.all(Colors.black),
                      thumbColor: MaterialStateProperty.resolveWith((states) {
                        if (states.contains(MaterialState.selected)) {
                          return Colors.white;
                        }
                        return Colors.black;
                      }),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Metric',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: isMetric ? Colors.black : Color(0xFF9E9E9E),
                        fontFamily: '.SF Pro Display',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
