import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'dart:async';
import 'package:fitness_app/Features/onboarding/presentation/screens/gender_selection_screen.dart';
import 'package:fitness_app/Features/onboarding/presentation/screens/weight_goal_copy_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomScrollBehavior extends ScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics();
  }
}

class WeightHeightCopyScreen extends StatefulWidget {
  final bool isMetric;
  final int initialWeight;
  final String? gymGoal;
  final int? initialHeightInCm;

  const WeightHeightCopyScreen({
    super.key,
    required this.isMetric,
    required this.initialWeight,
    this.gymGoal,
    this.initialHeightInCm,
  });

  @override
  State<WeightHeightCopyScreen> createState() => _WeightHeightCopyScreenState();
}

class _WeightHeightCopyScreenState extends State<WeightHeightCopyScreen> {
  late ValueNotifier<int> selectedWeight;
  late ValueNotifier<int> selectedFeet;
  late ValueNotifier<int> selectedInches;
  late ValueNotifier<int> selectedDay;
  late ValueNotifier<int> selectedMonth;
  late ValueNotifier<int> selectedYear;
  late bool isMetric;
  late double currentWeight;
  final FocusNode _weightFocusNode = FocusNode();
  final FocusNode _feetFocusNode = FocusNode();
  final FocusNode _inchesFocusNode = FocusNode();
  final FocusNode _dayFocusNode = FocusNode();
  final FocusNode _monthFocusNode = FocusNode();
  final FocusNode _yearFocusNode = FocusNode();
  Timer? _autoRepeatTimer;
  static const Duration _initialDelay = Duration(milliseconds: 500);
  static const Duration _repeatInterval = Duration(milliseconds: 50);
  bool _isMiddleMouseDown = false;
  double _dragAccumulator = 0;

  @override
  void initState() {
    super.initState();
    isMetric = widget.isMetric;
    print(
        "Weight Height Screen: Initial Weight=${widget.initialWeight}, Metric=${isMetric}"); // Debug

    // Initialize with passed weight
    selectedWeight = ValueNotifier(widget.initialWeight);

    // Initialize date values IMMEDIATELY (not in async method)
    selectedDay = ValueNotifier(1);
    selectedMonth = ValueNotifier(1);
    selectedYear = ValueNotifier(2000);

    // CRITICAL FIX: Load height from SharedPreferences instead of using defaults
    _loadSavedHeight();
  }

  // CRITICAL FIX: Added method to load height from SharedPreferences
  Future<void> _loadSavedHeight() async {
    try {
      // If we have an initial height provided directly, use it first
      if (widget.initialHeightInCm != null) {
        print("Using provided height: ${widget.initialHeightInCm} cm");

        if (isMetric) {
          // For metric, use the value directly
          selectedFeet = ValueNotifier(widget.initialHeightInCm!);
          selectedInches = ValueNotifier(0); // Not used in metric
          print("Set metric height to: ${widget.initialHeightInCm} cm");
        } else {
          // For imperial, convert cm to feet and inches
          double inches = widget.initialHeightInCm! / 2.54;
          int feet = (inches / 12).floor();
          int remainingInches = (inches % 12).round();

          selectedFeet = ValueNotifier(feet);
          selectedInches = ValueNotifier(remainingInches);
          print(
              "Converted provided ${widget.initialHeightInCm} cm to $feet feet $remainingInches inches");
        }

        // Save this value to SharedPreferences for future use
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('user_height_cm', widget.initialHeightInCm!);
        await prefs.setDouble(
            'heightInCm', widget.initialHeightInCm!.toDouble());
        await prefs.setInt('height', widget.initialHeightInCm!);

        if (!isMetric) {
          // Save the original feet and inches
          double inches = widget.initialHeightInCm! / 2.54;
          int feet = (inches / 12).floor();
          int remainingInches = (inches % 12).round();
          await prefs.setInt('original_height_feet', feet);
          await prefs.setInt('original_height_inches', remainingInches);
        }

        return; // Exit early since we already set the height
      }

      // If no initial height was provided, load from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      print("Loading height from SharedPreferences...");

      // Debug all height values
      print("Current height values in SharedPreferences:");
      for (String key in [
        'user_height_cm',
        'heightInCm',
        'height_cm',
        'height',
        'original_height_feet',
        'original_height_inches'
      ]) {
        if (prefs.containsKey(key)) {
          if (key.contains('height') && key.contains('cm') || key == 'height') {
            print("$key: ${prefs.getInt(key) ?? prefs.getDouble(key)}");
          } else if (key.contains('feet') || key.contains('inches')) {
            print("$key: ${prefs.getInt(key)}");
          }
        } else {
          print("$key: not found");
        }
      }

      if (isMetric) {
        // For metric, load height in cm directly
        int? savedHeight = prefs.getInt('user_height_cm');
        if (savedHeight != null) {
          selectedFeet = ValueNotifier(savedHeight);
          print("Loaded metric height: $savedHeight cm");
        } else {
          // Try double value
          double? savedHeightDouble = prefs.getDouble('heightInCm');
          if (savedHeightDouble != null) {
            selectedFeet = ValueNotifier(savedHeightDouble.round());
            print(
                "Loaded metric height (from double): ${savedHeightDouble.round()} cm");
          } else {
            // Default if not found
            selectedFeet = ValueNotifier(170);
            print("No saved height found, using default: 170 cm");
          }
        }
        selectedInches = ValueNotifier(0); // Not used in metric
      } else {
        // For imperial, try to get original feet/inches first
        int? savedFeet = prefs.getInt('original_height_feet');
        int? savedInches = prefs.getInt('original_height_inches');

        if (savedFeet != null && savedInches != null) {
          selectedFeet = ValueNotifier(savedFeet);
          selectedInches = ValueNotifier(savedInches);
          print("Loaded imperial height: $savedFeet feet $savedInches inches");
        } else {
          // If original values not found, try to convert from cm
          int? savedHeightCm = prefs.getInt('user_height_cm');
          if (savedHeightCm != null) {
            // Convert cm to feet and inches
            double inches = savedHeightCm / 2.54;
            int feet = (inches / 12).floor();
            int remainingInches = (inches % 12).round();

            selectedFeet = ValueNotifier(feet);
            selectedInches = ValueNotifier(remainingInches);
            print(
                "Converted height from $savedHeightCm cm to $feet feet $remainingInches inches");
          } else {
            // Default if nothing found
            selectedFeet = ValueNotifier(5);
            selectedInches = ValueNotifier(7);
            print("No saved height found, using default: 5 feet 7 inches");
          }
        }
      }
    } catch (e) {
      print("Error loading height: $e");
      // Use defaults in case of error
      if (isMetric) {
        selectedFeet = ValueNotifier(170);
        selectedInches = ValueNotifier(0);
      } else {
        selectedFeet = ValueNotifier(5);
        selectedInches = ValueNotifier(7);
      }
    }
  }

  @override
  void dispose() {
    _autoRepeatTimer?.cancel();
    _weightFocusNode.dispose();
    _feetFocusNode.dispose();
    _inchesFocusNode.dispose();
    _dayFocusNode.dispose();
    _monthFocusNode.dispose();
    _yearFocusNode.dispose();
    selectedWeight.dispose();
    selectedFeet.dispose();
    selectedInches.dispose();
    selectedDay.dispose();
    selectedMonth.dispose();
    selectedYear.dispose();
    super.dispose();
  }

  void _startAutoRepeat(VoidCallback action) {
    action();
    _autoRepeatTimer?.cancel();
    _autoRepeatTimer = Timer(_initialDelay, () {
      _autoRepeatTimer = Timer.periodic(_repeatInterval, (_) => action());
    });
  }

  void _handleScroll(
      double delta, ValueNotifier<int> notifier, int min, int max) {
    if (delta < 0) {
      // Changed from > to < (scrolling up - should decrease)
      setState(() {
        if (notifier == selectedDay) {
          // Days handling
          if (notifier.value <= 1) {
            notifier.value = 31;
          } else {
            notifier.value--;
          }
        } else if (notifier == selectedMonth) {
          // Months handling
          if (notifier.value <= 1) {
            notifier.value = 12;
          } else {
            notifier.value--;
          }
        } else if (notifier == selectedYear) {
          // Years handling
          if (notifier.value <= 1900) {
            notifier.value = 2050;
          } else {
            notifier.value--;
          }
        }
      });
    } else if (delta > 0) {
      // Changed from < to > (scrolling down - should increase)
      setState(() {
        if (notifier == selectedDay) {
          // Days handling
          if (notifier.value >= 31) {
            notifier.value = 1;
          } else {
            notifier.value++;
          }
        } else if (notifier == selectedMonth) {
          // Months handling
          if (notifier.value >= 12) {
            notifier.value = 1;
          } else {
            notifier.value++;
          }
        } else if (notifier == selectedYear) {
          // Years handling
          if (notifier.value >= 2050) {
            notifier.value = 1900;
          } else {
            notifier.value++;
          }
        }
      });
    }
  }

  int getHeightInCm() {
    if (!isMetric) {
      // Convert feet and inches to cm for imperial
      int feet = selectedFeet.value;
      int inches = selectedInches.value;

      // CRITICAL FIX: Verify inches is in correct range (0-11)
      if (inches < 0 || inches > 11) {
        print(
            "WARNING: Fixing invalid inches value $inches to valid range (0-11)");
        inches = inches % 12;
      }

      double heightInCm = ((feet * 12 + inches) * 2.54);
      print(
          'Converting height: $feet feet $inches inches = ${heightInCm.toInt()} cm');
      return heightInCm.toInt();
    } else {
      // For metric, the height is already in cm
      return selectedFeet.value;
    }
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
                            value: 8 / 13,
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
                        'Tell us when you were born!',
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
              ],
            ),
          ),

          // White box at bottom
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
                onPressed: () {
                  print(
                      "Current unit system: ${isMetric ? 'Metric' : 'Imperial'}"); // Debug print
                  print("Height conversion debug:");
                  print(
                      "Feet to inches: ${selectedFeet.value} feet = ${selectedFeet.value * 12} inches");
                  print(
                      "Total inches: ${selectedFeet.value * 12 + selectedInches.value}");

                  // Calculate height first
                  final heightInCm = getHeightInCm();

                  // Print the result after calculation
                  print("Final cm: $heightInCm");

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GenderSelectionScreen(
                        isMetric: widget.isMetric,
                        initialWeight: selectedWeight.value,
                        selectedGender: null,
                        heightInCm: heightInCm,
                        birthDate: DateTime(
                          selectedYear.value,
                          selectedMonth.value,
                          selectedDay.value,
                        ),
                        gymGoal: widget.gymGoal,
                      ),
                    ),
                  );
                },
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

          // Main content with parametric numbers
          Positioned(
            top: MediaQuery.of(context).size.height * 0.35 + 70,
            left: 24,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Day picker
                    Expanded(
                      child: ScrollConfiguration(
                        behavior: CustomScrollBehavior(),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => _dayFocusNode.requestFocus(),
                            onVerticalDragUpdate: (details) {
                              _dragAccumulator += details.delta.dy * 0.1;
                              if (_dragAccumulator.abs() >= 1) {
                                _handleScroll(
                                    _dragAccumulator, selectedDay, 1, 31);
                                _dragAccumulator =
                                    0; // Reset accumulator after triggering scroll
                              }
                            },
                            child: Listener(
                              onPointerSignal: (pointerSignal) {
                                if (pointerSignal is PointerScrollEvent) {
                                  final speedFactor = 0.1;
                                  final adjustedDelta =
                                      pointerSignal.scrollDelta.dy *
                                          speedFactor;
                                  _handleScroll(
                                      adjustedDelta, selectedDay, 1, 31);
                                }
                              },
                              child: ValueListenableBuilder<int>(
                                valueListenable: selectedDay,
                                builder: (context, value, child) {
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${value == 31 ? 2 : value == 30 ? 1 : value + 2}',
                                        style: TextStyle(
                                          fontSize: 17,
                                          color: Colors.grey[300],
                                          fontWeight: FontWeight.normal,
                                          fontFamily: '.SF Pro Display',
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${value == 31 ? 1 : value + 1}',
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
                                          '$value',
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
                                        '${value == 1 ? 31 : value - 1}',
                                        style: TextStyle(
                                          fontSize: 17,
                                          color: Colors.grey[300],
                                          fontWeight: FontWeight.normal,
                                          fontFamily: '.SF Pro Display',
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${value == 1 ? 30 : value == 2 ? 31 : value - 2}',
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
                    const SizedBox(width: 5.6),
                    // Month picker
                    Expanded(
                      child: ScrollConfiguration(
                        behavior: CustomScrollBehavior(),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => _monthFocusNode.requestFocus(),
                            onVerticalDragUpdate: (details) {
                              _dragAccumulator += details.delta.dy * 0.05;
                              if (_dragAccumulator.abs() >= 1) {
                                _handleScroll(
                                    _dragAccumulator, selectedMonth, 1, 12);
                                _dragAccumulator =
                                    0; // Reset accumulator after triggering scroll
                              }
                            },
                            child: Listener(
                              onPointerSignal: (pointerSignal) {
                                if (pointerSignal is PointerScrollEvent) {
                                  final speedFactor = 0.05;
                                  final adjustedDelta =
                                      pointerSignal.scrollDelta.dy *
                                          speedFactor;
                                  _handleScroll(
                                      adjustedDelta, selectedMonth, 1, 12);
                                }
                              },
                              child: ValueListenableBuilder<int>(
                                valueListenable: selectedMonth,
                                builder: (context, value, child) {
                                  List<String> months = [
                                    'January',
                                    'February',
                                    'March',
                                    'April',
                                    'May',
                                    'June',
                                    'July',
                                    'August',
                                    'September',
                                    'October',
                                    'November',
                                    'December'
                                  ];
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        months[(value + 1) % 12],
                                        style: TextStyle(
                                          fontSize: 17,
                                          color: Colors.grey[300],
                                          fontWeight: FontWeight.normal,
                                          fontFamily: '.SF Pro Display',
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        months[value % 12],
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
                                          months[value - 1],
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
                                        months[(value - 2) % 12],
                                        style: TextStyle(
                                          fontSize: 17,
                                          color: Colors.grey[300],
                                          fontWeight: FontWeight.normal,
                                          fontFamily: '.SF Pro Display',
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        months[(value - 3) % 12],
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
                    const SizedBox(width: 5.6),
                    // Year picker
                    Expanded(
                      child: ScrollConfiguration(
                        behavior: CustomScrollBehavior(),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => _yearFocusNode.requestFocus(),
                            onVerticalDragUpdate: (details) {
                              _dragAccumulator += details.delta.dy * 0.1;
                              if (_dragAccumulator.abs() >= 1) {
                                _handleScroll(
                                    _dragAccumulator, selectedYear, 1900, 2050);
                                _dragAccumulator =
                                    0; // Reset accumulator after triggering scroll
                              }
                            },
                            child: Listener(
                              onPointerSignal: (pointerSignal) {
                                if (pointerSignal is PointerScrollEvent) {
                                  final speedFactor = 0.1;
                                  final adjustedDelta =
                                      pointerSignal.scrollDelta.dy *
                                          speedFactor;
                                  _handleScroll(
                                      adjustedDelta, selectedYear, 1900, 2050);
                                }
                              },
                              child: ValueListenableBuilder<int>(
                                valueListenable: selectedYear,
                                builder: (context, value, child) {
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${value + 2}',
                                        style: TextStyle(
                                          fontSize: 17,
                                          color: Colors.grey[300],
                                          fontWeight: FontWeight.normal,
                                          fontFamily: '.SF Pro Display',
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${value + 1}',
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
                                          '$value',
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
                                        '${value - 1}',
                                        style: TextStyle(
                                          fontSize: 17,
                                          color: Colors.grey[300],
                                          fontWeight: FontWeight.normal,
                                          fontFamily: '.SF Pro Display',
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${value - 2}',
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
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
