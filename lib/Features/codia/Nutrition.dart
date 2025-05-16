import 'package:flutter/material.dart';
import '../codia/codia_page.dart' as main_codia;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

// Create a global RouteObserver that will be used by the app
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class CodiaPage extends StatefulWidget {
  // Add parameters to receive nutrition data
  final Map<String, dynamic>? nutritionData;
  // Always accept a scan ID parameter, defaulting to a generated value if none provided
  final String scanId;

  const CodiaPage(
      {super.key, this.nutritionData, this.scanId = 'default_nutrition_id'});

  @override
  State<StatefulWidget> createState() => _CodiaPage();
}

class _CodiaPage extends State<CodiaPage>
    with WidgetsBindingObserver, RouteAware {
  // Define color constants with the specified hex codes
  final Color yellowColor = const Color(0xFFF3D960);
  final Color redColor = const Color(0xFFDA7C7C);
  final Color greenColor = const Color(0xFF78C67A);

  // Maps for nutrition values storage
  late Map<String, NutrientInfo> vitamins = {};
  late Map<String, NutrientInfo> minerals = {};
  late Map<String, NutrientInfo> other = {};

  // The unique ID for this scan, used in SharedPreferences keys
  late String _scanId;

  // Track whether data was loaded successfully
  bool _dataLoaded = false;

  // Flag to track if there are unsaved changes
  bool _hasUnsavedChanges = false;

  // Track nutrient counts
  int vitaminCount = 0;
  int mineralCount = 0;
  int otherCount = 0;

  // Timer to periodically save data while screen is visible
  Timer? _autoSaveTimer;

  // Helper method to extract numeric values from strings like "10 mg"
  double _extractNumericValue(String valueString) {
    if (valueString == null || valueString.isEmpty) {
      return 0.0;
    }

    try {
      // First try direct parsing if it's a clean number
      double? directValue = double.tryParse(valueString);
      if (directValue != null) {
        return directValue;
      }

      // Handle ranges like "10-15mg" - take the average
      if (valueString.contains('-')) {
        List<String> parts = valueString.split('-');
        if (parts.length == 2) {
          double first = 0.0;
          double second = 0.0;

          // Extract numeric parts with regex
          RegExp numericRegex = RegExp(r'(\d+\.?\d*)');

          Match? firstMatch = numericRegex.firstMatch(parts[0]);
          if (firstMatch != null && firstMatch.group(1) != null) {
            first = double.parse(firstMatch.group(1)!);
          }

          Match? secondMatch = numericRegex.firstMatch(parts[1]);
          if (secondMatch != null && secondMatch.group(1) != null) {
            second = double.parse(secondMatch.group(1)!);
          }

          return (first + second) / 2;
        }
      }

      // Handle fractions like "1/2"
      if (valueString.contains('/')) {
        List<String> fractionParts = valueString.split('/');
        if (fractionParts.length == 2) {
          double? numerator = double.tryParse(fractionParts[0].trim());
          double? denominator = double.tryParse(fractionParts[1].trim());
          if (numerator != null && denominator != null && denominator != 0) {
            return numerator / denominator;
          }
        }
      }

      // Extract numeric part from any string with units
      RegExp numericRegex = RegExp(r'(\d+\.?\d*)');
      Match? match = numericRegex.firstMatch(valueString);
      if (match != null && match.group(1) != null) {
        return double.parse(match.group(1)!);
      }

      return 0.0;
    } catch (e) {
      print('Error extracting numeric value from $valueString: $e');
      return 0.0;
    }
  }

  // Helper method to parse current value from formatted strings like "10/20 mg"
  double _parseCurrentValue(String formattedValue) {
    try {
      if (formattedValue == null || formattedValue.isEmpty) {
        return 0.0;
      }

      // Split by forward slash if it contains one (like "10/20 mg")
      if (formattedValue.contains('/')) {
        String currentPart = formattedValue.split('/')[0].trim();
        return _extractNumericValue(currentPart);
      }

      // Otherwise just extract the numeric part
      return _extractNumericValue(formattedValue);
    } catch (e) {
      print('Error parsing current value from $formattedValue: $e');
      return 0.0;
    }
  }

  // Helper method to update a vitamin with a specific value
  void _updateVitaminWithValue(String vitaminKey, double amount) {
    try {
      if (!vitamins.containsKey(vitaminKey)) {
        print('Vitamin key not found: $vitaminKey');
        return;
      }

      String unit = vitaminKey.contains('A') ||
              vitaminKey.contains('D') ||
              vitaminKey.contains('B7') ||
              vitaminKey.contains('B9') ||
              vitaminKey.contains('B12') ||
              vitaminKey.contains('K')
          ? 'mcg'
          : 'mg';

      // Get the existing vitamin info
      NutrientInfo info = vitamins[vitaminKey]!;

      // Extract current target value from the existing string
      String valueText = info.value;
      double targetValue = 0.0;

      if (valueText.contains('/')) {
        List<String> parts = valueText.split('/');
        if (parts.length > 1) {
          // Extract target value after the slash
          String targetText = parts[1];
          targetValue = _extractNumericValue(targetText);
        }
      }

      // Make sure target is at least 1.0
      if (targetValue <= 0) targetValue = getDefaultTargetFor(vitaminKey);

      // Update the vitamin with new value
      double progress = amount / targetValue;
      int percentage = (progress * 100).round();
      String formattedValue =
          "${amount.toStringAsFixed(1)}/${targetValue.toStringAsFixed(1)} $unit";

      vitamins[vitaminKey] = NutrientInfo(
        name: vitaminKey,
        value: formattedValue,
        percent: "$percentage%",
        progress: progress,
        progressColor: _getColorBasedOnProgress(progress),
        hasInfo: info.hasInfo,
      );

      // Mark that we have unsaved changes
      _hasUnsavedChanges = true;

      print('Updated vitamin $vitaminKey with value $amount $unit');
    } catch (e) {
      print('Error updating vitamin $vitaminKey: $e');
    }
  }

  // Helper method to update a mineral with a specific value
  void _updateMineralWithValue(String mineralKey, double amount) {
    try {
      if (!minerals.containsKey(mineralKey)) {
        print('Mineral key not found: $mineralKey');
        return;
      }

      String unit = mineralKey == 'Chromium' ||
              mineralKey == 'Copper' ||
              mineralKey == 'Iodine' ||
              mineralKey == 'Molybdenum' ||
              mineralKey == 'Selenium'
          ? 'mcg'
          : 'mg';

      // Get the existing mineral info
      NutrientInfo info = minerals[mineralKey]!;

      // Extract current target value from the existing string
      String valueText = info.value;
      double targetValue = 0.0;

      if (valueText.contains('/')) {
        List<String> parts = valueText.split('/');
        if (parts.length > 1) {
          // Extract target value after the slash
          String targetText = parts[1];
          targetValue = _extractNumericValue(targetText);
        }
      }

      // Make sure target is at least 1.0
      if (targetValue <= 0) targetValue = getDefaultTargetFor(mineralKey);

      // Update the mineral with new value
      double progress = amount / targetValue;
      int percentage = (progress * 100).round();
      String formattedValue =
          "${amount.toStringAsFixed(1)}/${targetValue.toStringAsFixed(1)} $unit";

      minerals[mineralKey] = NutrientInfo(
        name: mineralKey,
        value: formattedValue,
        percent: "$percentage%",
        progress: progress,
        progressColor: _getColorBasedOnProgress(progress),
        hasInfo: info.hasInfo,
      );

      // Mark that we have unsaved changes
      _hasUnsavedChanges = true;

      print('Updated mineral $mineralKey with value $amount $unit');
    } catch (e) {
      print('Error updating mineral $mineralKey: $e');
    }
  }

  // Helper method to update an other nutrient with a specific value
  void _updateOtherNutrientWithValue(String nutrientKey, double amount) {
    try {
      if (!other.containsKey(nutrientKey)) {
        print('Other nutrient key not found: $nutrientKey');
        return;
      }

      String unit = 'g';
      if (nutrientKey == 'Cholesterol' ||
          nutrientKey == 'Sodium' ||
          nutrientKey == 'Potassium' ||
          nutrientKey == 'Omega-3') {
        unit = 'mg';
      }

      // Get the existing nutrient info
      NutrientInfo info = other[nutrientKey]!;

      // Extract current target value from the existing string
      String valueText = info.value;
      double targetValue = 0.0;

      if (valueText.contains('/')) {
        List<String> parts = valueText.split('/');
        if (parts.length > 1) {
          // Extract target value after the slash
          String targetText = parts[1];
          targetValue = _extractNumericValue(targetText);
        }
      }

      // Make sure target is at least 1.0
      if (targetValue <= 0) targetValue = getDefaultTargetFor(nutrientKey);

      // Update the nutrient with new value
      double progress = amount / targetValue;
      int percentage = (progress * 100).round();
      String formattedValue =
          "${amount.toStringAsFixed(1)}/${targetValue.toStringAsFixed(1)} $unit";

      other[nutrientKey] = NutrientInfo(
        name: nutrientKey,
        value: formattedValue,
        percent: "$percentage%",
        progress: progress,
        progressColor: _getColorBasedOnProgress(progress),
        hasInfo: info.hasInfo,
      );

      // Mark that we have unsaved changes
      _hasUnsavedChanges = true;

      print('Updated other nutrient $nutrientKey with value $amount $unit');
    } catch (e) {
      print('Error updating other nutrient $nutrientKey: $e');
    }
  }

  // Helper method to get default target values for nutrients
  double getDefaultTargetFor(String nutrientKey) {
    // Default values based on common RDAs
    switch (nutrientKey) {
      case 'Vitamin A':
        return 900.0;
      case 'Vitamin C':
        return 90.0;
      case 'Vitamin D':
        return 20.0;
      case 'Vitamin E':
        return 15.0;
      case 'Vitamin K':
        return 120.0;
      case 'Vitamin B1':
        return 1.2;
      case 'Vitamin B2':
        return 1.3;
      case 'Vitamin B3':
        return 16.0;
      case 'Vitamin B5':
        return 5.0;
      case 'Vitamin B6':
        return 1.7;
      case 'Vitamin B7':
        return 30.0;
      case 'Vitamin B9':
        return 400.0;
      case 'Vitamin B12':
        return 2.4;
      case 'Calcium':
        return 1000.0;
      case 'Iron':
        return 18.0;
      case 'Magnesium':
        return 400.0;
      case 'Zinc':
        return 11.0;
      case 'Selenium':
        return 55.0;
      case 'Copper':
        return 900.0;
      case 'Manganese':
        return 2.3;
      case 'Fiber':
        return 25.0;
      case 'Cholesterol':
        return 300.0;
      case 'Sodium':
        return 2300.0;
      case 'Potassium':
        return 3500.0;
      case 'Saturated Fats':
        return 20.0;
      case 'Omega-3':
        return 1100.0;
      case 'Omega-6':
        return 14.0;
      default:
        return 100.0;
    }
  }

  // Helper method to process a single other nutrient from multiple possible keys
  void _processSingleOtherNutrient(Map<String, dynamic> data,
      String nutrientKey, List<String> possibleKeys) {
    try {
      // Check each possible key
      for (String keyToCheck in possibleKeys) {
        // Check in root object
        if (data.containsKey(keyToCheck)) {
          double amount = _extractNumericValue(data[keyToCheck].toString());
          if (amount > 0) {
            _updateOtherNutrientWithValue(nutrientKey, amount);
            print(
                'Found $nutrientKey: $amount using key $keyToCheck directly in data');
            return; // Stop after finding first match
          }
        }

        // Check in lower case
        String lowerKey = keyToCheck.toLowerCase();
        if (data.containsKey(lowerKey)) {
          double amount = _extractNumericValue(data[lowerKey].toString());
          if (amount > 0) {
            _updateOtherNutrientWithValue(nutrientKey, amount);
            print('Found $nutrientKey: $amount using lowercase key $lowerKey');
            return; // Stop after finding first match
          }
        }

        // Check in 'other' object if it exists
        if (data.containsKey('other') && data['other'] is Map) {
          Map<String, dynamic> otherData = data['other'];
          if (otherData.containsKey(keyToCheck)) {
            double amount =
                _extractNumericValue(otherData[keyToCheck].toString());
            if (amount > 0) {
              _updateOtherNutrientWithValue(nutrientKey, amount);
              print('Found $nutrientKey: $amount in other.${keyToCheck}');
              return; // Stop after finding first match
            }
          }

          // Check lowercase in 'other'
          if (otherData.containsKey(lowerKey)) {
            double amount =
                _extractNumericValue(otherData[lowerKey].toString());
            if (amount > 0) {
              _updateOtherNutrientWithValue(nutrientKey, amount);
              print('Found $nutrientKey: $amount in other.${lowerKey}');
              return; // Stop after finding first match
            }
          }
        }
      }
    } catch (e) {
      print('Error processing other nutrient $nutrientKey: $e');
    }
  }

  // Load personalized nutrient targets
  Future<void> _loadNutrientTargets() async {
    try {
      print('Loading personalized nutrient targets...');
      final prefs = await SharedPreferences.getInstance();

      // Check if targets have been calculated
      String? calculationDate =
          prefs.getString('nutrient_targets_calculated_date');
      if (calculationDate != null) {
        print(
            'Using personalized targets from calculation date: $calculationDate');

        // Process vitamins first
        vitamins.forEach((key, info) {
          String prefsKey = key.toLowerCase().replaceAll(' ', '_');

          // Try to load from SharedPreferences with various key formats
          double? storedTarget = prefs.getDouble('vitamin_target_$prefsKey');

          if (storedTarget != null) {
            double currentValue = _parseCurrentValue(info.value);
            String unit = key.contains('A') ||
                    key.contains('D') ||
                    key.contains('B7') ||
                    key.contains('B9') ||
                    key.contains('B12') ||
                    key.contains('K')
                ? 'mcg'
                : 'mg';

            // Update with personalized target
            double progress = currentValue / storedTarget;
            int percentage = (progress * 100).round();
            vitamins[key] = NutrientInfo(
              name: key,
              value: "$currentValue/$storedTarget $unit",
              percent: "$percentage%",
              progress: progress,
              progressColor: _getColorBasedOnProgress(progress),
              hasInfo: info.hasInfo,
            );

            print('Loaded personalized target for $key: $storedTarget $unit');
          }
        });

        // Process minerals
        minerals.forEach((key, info) {
          String prefsKey = key.toLowerCase().replaceAll(' ', '_');

          // Try to load from SharedPreferences
          double? storedTarget = prefs.getDouble('mineral_target_$prefsKey');

          if (storedTarget != null) {
            double currentValue = _parseCurrentValue(info.value);
            String unit = key == 'Chromium' ||
                    key == 'Copper' ||
                    key == 'Iodine' ||
                    key == 'Molybdenum' ||
                    key == 'Selenium'
                ? 'mcg'
                : 'mg';

            // Update with personalized target
            double progress = currentValue / storedTarget;
            int percentage = (progress * 100).round();
            minerals[key] = NutrientInfo(
              name: key,
              value: "$currentValue/$storedTarget $unit",
              percent: "$percentage%",
              progress: progress,
              progressColor: _getColorBasedOnProgress(progress),
              hasInfo: info.hasInfo,
            );

            print('Loaded personalized target for $key: $storedTarget $unit');
          }
        });

        // Process other nutrients
        other.forEach((key, info) {
          String prefsKey = key.toLowerCase().replaceAll(' ', '_');

          // Try nutrient targets
          double? storedTarget = prefs.getDouble('nutrient_target_$prefsKey');

          if (storedTarget != null) {
            double currentValue = _parseCurrentValue(info.value);
            String unit = key == 'Cholesterol' ||
                    key == 'Sodium' ||
                    key == 'Potassium' ||
                    key == 'Omega-3'
                ? 'mg'
                : 'g';

            // Update with personalized target
            double progress = currentValue / storedTarget;
            int percentage = (progress * 100).round();
            other[key] = NutrientInfo(
              name: key,
              value: "$currentValue/$storedTarget $unit",
              percent: "$percentage%",
              progress: progress,
              progressColor: _getColorBasedOnProgress(progress),
              hasInfo: info.hasInfo,
            );

            print('Loaded personalized target for $key: $storedTarget $unit');
          }
        });

        print('Successfully loaded all personalized nutrient targets');
      } else {
        print('No personalized targets found - using defaults');
      }
    } catch (e) {
      print('Error loading nutrient targets: $e');
    }
  }

  @override
  void initState() {
    super.initState();

    // Register as a lifecycle observer
    WidgetsBinding.instance.addObserver(this);

    // Initialize scan ID - this is critical for data persistence
    // Always use the widget's scanId directly - it's now non-nullable with a default
    _scanId = widget.scanId;

    print('Nutrition screen initialized with scan ID: $_scanId');

    // Initialize default nutrient values
    _initializeDefaultValues();

    // Immediately try to load data from the global key first
    _tryLoadFromGlobalKey().then((success) {
      if (!success) {
        // If global key fails, start regular data loading process
        _loadData();
      }

      // Load personalized targets for all nutrients after data is loaded
      _loadNutrientTargets();
    });

    // Set up periodic auto-save
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_hasUnsavedChanges) {
        _saveNutritionData();
        _hasUnsavedChanges = false;
      }
    });

    // Pre-save any data that came from widget.nutritionData to ensure it's not lost
    if (widget.nutritionData != null && widget.nutritionData!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _saveToFoodCardStorage(widget.nutritionData!);
      });
    }
  }

  // Helper method to immediately try loading from the global permanent key
  Future<bool> _tryLoadFromGlobalKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // First, try to load data specific to this food scan ID (highest priority)
      if (_scanId.startsWith('food_nutrition_')) {
        // Try food-specific storage paths
        String? foodSpecificData =
            prefs.getString('food_nutrition_data_$_scanId') ??
                prefs.getString('nutrition_data_$_scanId');

        if (foodSpecificData != null && foodSpecificData.isNotEmpty) {
          try {
            Map<String, dynamic> loadedData = jsonDecode(foodSpecificData);
            print('Successfully loaded food-specific data for $_scanId');

            // Process the data
            if (_processLoadedNutritionData(loadedData)) {
              // Update UI if data was loaded successfully
              if (mounted) {
                setState(() {
                  _dataLoaded = true;
                });
              }

              // Immediately save to ensure consistent formats but preserve the specific scan ID
              await _saveNutritionData(useGlobalKey: false);

              return true;
            }
          } catch (e) {
            print('Error processing food-specific nutrition data: $e');
          }
        }
      }

      // Only use the global key if we're not dealing with a food-specific scan
      if (!_scanId.startsWith('food_nutrition_')) {
        // Try to load from the global permanent key
        String? globalData = prefs.getString('PERMANENT_GLOBAL_NUTRITION_DATA');

        if (globalData != null && globalData.isNotEmpty) {
          try {
            Map<String, dynamic> loadedData = jsonDecode(globalData);
            print(
                'Successfully loaded data from PERMANENT_GLOBAL_NUTRITION_DATA');

            // If this global data has a scanId, update our scanId to match
            if (loadedData.containsKey('scanId')) {
              _scanId = loadedData['scanId'];
              print('Updated scan ID from global data: $_scanId');
            }

            // Process the data
            if (_processLoadedNutritionData(loadedData)) {
              // Update UI if data was loaded successfully
              if (mounted) {
                setState(() {
                  _dataLoaded = true;
                });
              }

              // Immediately save to ensure consistent formats and redundant storage
              await _saveNutritionData();

              return true;
            }
          } catch (e) {
            print('Error processing global nutrition data: $e');
          }
        }
      }

      return false;
    } catch (e) {
      print('Error loading from global key: $e');
      return false;
    }
  }

  // Helper method to save nutrition data to FoodCardOpen format
  Future<void> _saveToFoodCardStorage(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Create a container object with the scan ID and data
      Map<String, dynamic> storageData = {
        'scanId': _scanId,
        'lastSaved': DateTime.now().millisecondsSinceEpoch,
        'nutritionData': data
      };

      // Save the data to multiple keys for redundancy
      String json = jsonEncode(storageData);

      // Save to food-specific keys (not global)
      if (_scanId.startsWith('food_nutrition_')) {
        // For food-specific scan IDs, avoid using the global key
        await prefs.setString('nutrition_data_$_scanId', json);
        await prefs.setString('food_nutrition_data_$_scanId', json);

        // Extract food name to save with alternative key
        try {
          List<String> parts = _scanId.split('_');
          if (parts.length >= 3) {
            String foodName = parts.sublist(2, parts.length - 1).join('_');
            await prefs.setString('food_nutrition_$foodName', json);
          }
        } catch (e) {
          print('Error extracting food name from scan ID: $e');
        }
      } else {
        // Only use the global key for non-food specific scan IDs
        await prefs.setString('PERMANENT_GLOBAL_NUTRITION_DATA', json);
        await prefs.setString('nutrition_data_$_scanId', json);
      }

      // Also update the master scan ID
      await prefs.setString('current_nutrition_scan_id', _scanId);

      // Process data into our format
      _updateNutrientValuesFromData(data);

      print(
          'Saved nutrition data from widget to food card storage with ID: $_scanId');
    } catch (e) {
      print('Error saving to food card storage: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route changes
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    // Cancel auto-save timer
    _autoSaveTimer?.cancel();

    // Unregister lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    // Unsubscribe from route observer
    routeObserver.unsubscribe(this);

    // Save current data state to ensure no data is lost
    if (_dataLoaded) {
      _saveNutritionData();
    }

    super.dispose();
  }

  // Called when this route is pushed on top of another route
  @override
  void didPush() {
    // This route is now the top-most route on navigator
  }

  // Called when another route is pushed on top of this route
  @override
  void didPushNext() {
    // User is navigating away from this screen to another screen
    if (_dataLoaded) {
      _saveNutritionData();
    }
  }

  // Called when this route is popped off the navigator
  @override
  void didPop() {
    // This route is being popped off the navigator
    if (_dataLoaded) {
      _saveNutritionData();
    }
  }

  // Called when another route is popped and this route shows up
  @override
  void didPopNext() {
    // User returned to this screen from another screen
    _reloadSavedData();
  }

  // Handle app lifecycle changes to ensure data isn't lost
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App is going to background or inactive, save current data
      if (_dataLoaded) {
        _saveNutritionData();
      }
    } else if (state == AppLifecycleState.resumed) {
      // App came back to foreground, reload data to ensure consistency
      _reloadSavedData();
    } else if (state == AppLifecycleState.detached) {
      // App is being terminated, save data urgently
      if (_dataLoaded) {
        _saveNutritionData();
      }
    }
  }

  // Separate method to handle all async loading
  Future<void> _loadData() async {
    try {
      await _initializeNutrientData();
      if (mounted) {
        setState(() {
          print("Refreshing UI after data initialized");
          _dataLoaded = true;
        });
      }

      // Force an immediate save after loading to ensure data is immediately persisted
      if (_dataLoaded) {
        await _saveNutritionData();
        print("Initial data save completed after loading");
      }
    } catch (e) {
      print("Error loading nutrition data: $e");

      // Attempt recovery by using the global nutrition data
      try {
        final prefs = await SharedPreferences.getInstance();
        String? globalData = prefs.getString('global_nutrition_data');

        if (globalData != null && globalData.isNotEmpty) {
          print("Attempting recovery using global nutrition data");
          Map<String, dynamic> loadedData = jsonDecode(globalData);

          // Update scan ID to match the loaded data to maintain consistency
          if (loadedData.containsKey('scanId')) {
            _scanId = loadedData['scanId'];
            print("Updated scan ID to match recovered data: $_scanId");
          }

          _processLoadedNutritionData(loadedData);

          if (mounted) {
            setState(() {
              _dataLoaded = true;
              print("Recovery successful - UI refreshed with global data");
            });
          }

          // Save the recovered data to ensure it's properly stored
          await _saveNutritionData();
        }
      } catch (recoveryError) {
        print("Error during recovery attempt: $recoveryError");
      }
    }
  }

  // Method to reload saved data - ULTRA RELIABLE
  Future<void> _reloadSavedData() async {
    try {
      if (!mounted) return;

      final prefs = await SharedPreferences.getInstance();

      // ALWAYS try the global permanent key first
      String? savedData = prefs.getString('PERMANENT_GLOBAL_NUTRITION_DATA');

      // If not found by global key, try scan-specific key
      if (savedData == null || savedData.isEmpty) {
        savedData = prefs.getString('food_nutrition_data_$_scanId');
      }

      // Process the data if found
      if (savedData != null && savedData.isNotEmpty) {
        try {
          Map<String, dynamic> loadedData = jsonDecode(savedData);

          // Reset data structures to avoid stale data
          _initializeDefaultValues();

          // Process the loaded data
          _processLoadedNutritionData(loadedData);

          if (mounted) {
            setState(() {
              _dataLoaded = true;
            });

            // Re-save to ensure consistent storage format
            await _saveNutritionData();
          }
        } catch (e) {
          print('Error processing loaded nutrition data: $e');
        }
      } else if (widget.nutritionData != null &&
          widget.nutritionData!.isNotEmpty) {
        // If we have widget data, use it as a fallback
        _updateNutrientValuesFromData(widget.nutritionData!);

        if (mounted) {
          setState(() {
            _dataLoaded = true;
          });
        }

        // Save this data
        await _saveNutritionData();
      }
    } catch (e) {
      print('Error during data reload: $e');
    }
  }

  // Helper method to process loaded nutrition data
  bool _processLoadedNutritionData(Map<String, dynamic> loadedData) {
    try {
      // Process data in direct vitamins/minerals/other format
      if (loadedData.containsKey('vitamins')) {
        Map<String, dynamic> vitaminData = loadedData['vitamins'];
        vitaminData.forEach((key, value) {
          if (vitamins.containsKey(key) && value is Map) {
            double progress = 0.0;
            if (value.containsKey('progress')) {
              progress = value['progress'] is double
                  ? value['progress']
                  : double.tryParse(value['progress'].toString()) ?? 0.0;
            }

            Color progressColor = _getColorBasedOnProgress(progress);
            vitamins[key] = NutrientInfo(
              name: value['name'] ?? key,
              value: value['value'] ?? '0/0 g',
              percent: value['percent'] ?? '0%',
              progress: progress,
              progressColor: progressColor,
              hasInfo: value['hasInfo'] ?? false,
            );
          }
        });
      }

      // Process minerals
      if (loadedData.containsKey('minerals')) {
        Map<String, dynamic> mineralData = loadedData['minerals'];
        mineralData.forEach((key, value) {
          if (minerals.containsKey(key) && value is Map) {
            double progress = 0.0;
            if (value.containsKey('progress')) {
              progress = value['progress'] is double
                  ? value['progress']
                  : double.tryParse(value['progress'].toString()) ?? 0.0;
            }

            Color progressColor = _getColorBasedOnProgress(progress);
            minerals[key] = NutrientInfo(
              name: value['name'] ?? key,
              value: value['value'] ?? '0/0 g',
              percent: value['percent'] ?? '0%',
              progress: progress,
              progressColor: progressColor,
              hasInfo: value['hasInfo'] ?? false,
            );
          }
        });
      }

      // Process other nutrients
      if (loadedData.containsKey('other')) {
        Map<String, dynamic> otherData = loadedData['other'];
        otherData.forEach((key, value) {
          if (other.containsKey(key) && value is Map) {
            double progress = 0.0;
            if (value.containsKey('progress')) {
              progress = value['progress'] is double
                  ? value['progress']
                  : double.tryParse(value['progress'].toString()) ?? 0.0;
            }

            Color progressColor = _getColorBasedOnProgress(progress);
            other[key] = NutrientInfo(
              name: value['name'] ?? key,
              value: value['value'] ?? '0/0 g',
              percent: value['percent'] ?? '0%',
              progress: progress,
              progressColor: progressColor,
              hasInfo: value['hasInfo'] ?? false,
            );
          }
        });
      }

      return true;
    } catch (e) {
      print('Error in _processLoadedNutritionData: $e');
      return false;
    }
  }

  // Helper method to process a nutrient category (vitamins, minerals, other)
  void _processNutrientCategory(
      dynamic categoryData, Map<String, NutrientInfo> targetMap) {
    if (categoryData is! Map) return;

    Map<String, dynamic> data = categoryData as Map<String, dynamic>;
    data.forEach((key, value) {
      if (targetMap.containsKey(key) && value is Map) {
        double progress = 0.0;
        if (value.containsKey('progress')) {
          progress = value['progress'] is double
              ? value['progress']
              : double.tryParse(value['progress'].toString()) ?? 0.0;
        }

        Color progressColor = _getColorBasedOnProgress(progress);
        targetMap[key] = NutrientInfo(
          name: value['name'] ?? key,
          value: value['value'] ?? '0/0 g',
          percent: value['percent'] ?? '0%',
          progress: progress,
          progressColor: progressColor,
          hasInfo: value['hasInfo'] ?? false,
        );
      }
    });
  }

  // Initialize nutrient data for all categories (vitamins, minerals, other)
  Future<void> _initializeNutrientData() async {
    // First initialize all nutrients with default values
    _initializeDefaultValues();

    // Also load any saved data from past runs
    final prefs = await SharedPreferences.getInstance();
    String? savedData;

    // DIAGNOSTIC: Print the scan ID being used to load data
    print('\n====== LOADING NUTRIENT DATA ======');
    print('Current scan ID: $_scanId');

    // For food-specific scan IDs, prioritize food-specific data
    if (_scanId.startsWith('food_nutrition_')) {
      // Try food-specific keys first
      savedData = prefs.getString('food_nutrition_data_$_scanId') ??
          prefs.getString('nutrition_data_$_scanId');

      if (savedData != null && savedData.isNotEmpty) {
        print(
            '✓ FOUND FOOD-SPECIFIC DATA using ID: $_scanId (${savedData.length} bytes)');
      } else {
        // Extract food name as fallback
        try {
          List<String> parts = _scanId.split('_');
          if (parts.length >= 3) {
            String foodName = parts.sublist(2, parts.length - 1).join('_');
            savedData = prefs.getString('food_nutrition_$foodName');

            if (savedData != null && savedData.isNotEmpty) {
              print(
                  '✓ FOUND FOOD-SPECIFIC DATA using food name: $foodName (${savedData.length} bytes)');
            }
          }
        } catch (e) {
          print('Error extracting food name from scan ID: $e');
        }
      }
    } else {
      // Try multiple key formats to find saved data with highest priority first
      List<String> possibleDataKeys = [
        // Direct food scan ID format
        'nutrition_data_$_scanId', // Primary storage key
        'backup_nutrition_$_scanId', // Backup for redundancy
        'nutrition_${_scanId}_final', // Final backup storage
        'simple_nutrition_$_scanId', // Simplified emergency format

        // Extract food name from scan ID for alternative lookup
        'food_nutrition_${_scanId.replaceFirst('food_nutrition_', '')}', // By food name
      ];

      print('CHECKING for data using keys:');
      for (String key in possibleDataKeys) {
        print('- $key');
      }

      // Try each possible key to find saved data
      for (String key in possibleDataKeys) {
        savedData = prefs.getString(key);
        if (savedData != null && savedData.isNotEmpty) {
          print('✓ FOUND DATA using key: $key (${savedData.length} bytes)');
          break;
        }
      }

      // Fallback to global storage if no specific data found
      if (savedData == null || savedData.isEmpty) {
        savedData = prefs.getString('PERMANENT_GLOBAL_NUTRITION_DATA');
        if (savedData != null && savedData.isNotEmpty) {
          print('✓ FOUND DATA in global storage (${savedData.length} bytes)');
        }
      }
    }

    bool loadedExistingData = false;

    // If we found saved data, use it
    if (savedData != null && savedData.isNotEmpty) {
      try {
        Map<String, dynamic> data = jsonDecode(savedData);

        // Check if this is the new format with nutritionData field
        if (data.containsKey('nutritionData') &&
            data['nutritionData'] is Map<String, dynamic>) {
          print('Loading newer data format with nutritionData field');
          _updateNutrientValuesFromData(data['nutritionData']);
          loadedExistingData = true;
        }
        // Otherwise check for vitamins/minerals direct format
        else if (data.containsKey('vitamins') ||
            data.containsKey('minerals') ||
            data.containsKey('other')) {
          // Process vitamins
          if (data.containsKey('vitamins')) {
            Map<String, dynamic> vitaminData = data['vitamins'];
            vitaminData.forEach((key, value) {
              if (vitamins.containsKey(key) && value is Map) {
                vitamins[key] = NutrientInfo(
                  name: value['name'] ?? key,
                  value: value['value'] ?? '0/0 g',
                  percent: value['percent'] ?? '0%',
                  progress: value['progress'] is double
                      ? value['progress']
                      : double.tryParse(value['progress'].toString()) ?? 0.0,
                  progressColor: _getColorBasedOnProgress(value['progress']
                          is double
                      ? value['progress']
                      : double.tryParse(value['progress'].toString()) ?? 0.0),
                );
              }
            });
          }

          // Process minerals
          if (data.containsKey('minerals')) {
            Map<String, dynamic> mineralData = data['minerals'];
            mineralData.forEach((key, value) {
              if (minerals.containsKey(key) && value is Map) {
                minerals[key] = NutrientInfo(
                  name: value['name'] ?? key,
                  value: value['value'] ?? '0/0 g',
                  percent: value['percent'] ?? '0%',
                  progress: value['progress'] is double
                      ? value['progress']
                      : double.tryParse(value['progress'].toString()) ?? 0.0,
                  progressColor: _getColorBasedOnProgress(value['progress']
                          is double
                      ? value['progress']
                      : double.tryParse(value['progress'].toString()) ?? 0.0),
                );
              }
            });
          }

          // Process other nutrients
          if (data.containsKey('other')) {
            Map<String, dynamic> otherData = data['other'];
            otherData.forEach((key, value) {
              if (other.containsKey(key) && value is Map) {
                other[key] = NutrientInfo(
                  name: value['name'] ?? key,
                  value: value['value'] ?? '0/0 g',
                  percent: value['percent'] ?? '0%',
                  progress: value['progress'] is double
                      ? value['progress']
                      : double.tryParse(value['progress'].toString()) ?? 0.0,
                  progressColor: _getColorBasedOnProgress(value['progress']
                          is double
                      ? value['progress']
                      : double.tryParse(value['progress'].toString()) ?? 0.0),
                );
              }
            });
          }

          loadedExistingData = true;
          print('SUCCESSFULLY LOADED saved nutrition data');
        }
      } catch (e) {
        print('Error loading saved nutrition data: $e');
      }
    }

    // If no saved data OR we have widget data, use that (prioritize new data)
    if (!loadedExistingData ||
        (widget.nutritionData != null && widget.nutritionData!.isNotEmpty)) {
      if (widget.nutritionData != null && widget.nutritionData!.isNotEmpty) {
        print('Using nutrition data from widget parameter');
        _updateNutrientValuesFromData(widget.nutritionData!);

        // Also SAVE this data immediately to ensure it's not lost
        // For food-specific IDs, don't save to global key to avoid overwriting other foods' data
        await _saveNutritionData(
            useGlobalKey: !_scanId.startsWith('food_nutrition_'));
      } else if (!loadedExistingData) {
        // Last resort, try to get data from NutritionTracker
        print('No saved data or widget data, trying NutritionTracker');
        await _loadDataFromNutritionTracker();
      }
    }

    // Load nutrient targets from SharedPreferences
    await _loadNutrientTargets();

    // Save after loading and refreshing targets - preserve food-specific data
    await _saveNutritionData(
        useGlobalKey: !_scanId.startsWith('food_nutrition_'));
  }

  Future<void> _loadDataFromNutritionTracker() async {
    try {
      // Access the NutritionTracker singleton through the main_codia module
      final nutritionTracker = main_codia.NutritionTracker();

      print("Loading nutrition data from tracker:");
      print("- Protein: ${nutritionTracker.currentProtein}g");
      print("- Fat: ${nutritionTracker.currentFat}g");
      print("- Carbs: ${nutritionTracker.currentCarb}g");
      print("- Calories: ${nutritionTracker.consumedCalories}kcal");

      // We're not including protein, fat, or carbs in the detailed nutrition screen anymore
      // Save the updated data
      await _saveNutritionData();
    } catch (e) {
      print("Error loading data from NutritionTracker: $e");
    }
  }

  // Initialize default values for vitamins, minerals, and other nutrients
  void _initializeDefaultValues() {
    print("Initializing default nutrient values...");

    // VITAMINS
    vitamins = {
      'Vitamin A': NutrientInfo(
          name: 'Vitamin A',
          value: '0/700 mcg',
          percent: '0%',
          progress: 0.0,
          progressColor: Colors.red),
      'Vitamin C': NutrientInfo(
          name: 'Vitamin C',
          value: '0/75 mg',
          percent: '0%',
          progress: 0.0,
          progressColor: Colors.red),
      'Vitamin D': NutrientInfo(
          name: 'Vitamin D',
          value: '0/15 mcg',
          percent: '0%',
          progress: 0.0,
          progressColor: Colors.red),
      'Vitamin E': NutrientInfo(
          name: 'Vitamin E',
          value: '0/15 mg',
          percent: '0%',
          progress: 0.0,
          progressColor: Colors.red),
      'Vitamin K': NutrientInfo(
          name: 'Vitamin K',
          value: '0/90 mcg',
          percent: '0%',
          progress: 0.0,
          progressColor: Colors.red),
      'Vitamin B1': NutrientInfo(
          name: 'Vitamin B1',
          value: '0/1.1 mg',
          percent: '0%',
          progress: 0.0,
          progressColor: Colors.red),
      'Vitamin B2': NutrientInfo(
          name: 'Vitamin B2',
          value: '0/1.1 mg',
          percent: '0%',
          progress: 0.0,
          progressColor: Colors.red),
      'Vitamin B3': NutrientInfo(
          name: 'Vitamin B3',
          value: '0/14 mg',
          percent: '0%',
          progress: 0.0,
          progressColor: Colors.red),
      'Vitamin B5': NutrientInfo(
          name: 'Vitamin B5',
          value: '0/5 mg',
          percent: '0%',
          progress: 0.0,
          progressColor: Colors.red),
      'Vitamin B6': NutrientInfo(
          name: 'Vitamin B6',
          value: '0/1.3 mg',
          percent: '0%',
          progress: 0.0,
          progressColor: Colors.red),
      'Vitamin B7': NutrientInfo(
          name: 'Vitamin B7',
          value: '0/30 mcg',
          percent: '0%',
          progress: 0.0,
          progressColor: Colors.red),
      'Vitamin B9': NutrientInfo(
          name: 'Vitamin B9',
          value: '0/400 mcg',
          percent: '0%',
          progress: 0.0,
          progressColor: Colors.red),
      'Vitamin B12': NutrientInfo(
          name: 'Vitamin B12',
          value: '0/2.4 mcg',
          percent: '0%',
          progress: 0.0,
          progressColor: Colors.red),
    };

    // MINERALS
    minerals = {
      'Calcium': NutrientInfo(
          name: 'Calcium',
          value: '0/1000 mg',
          percent: '0%',
          progress: 0.0,
          progressColor: Colors.red),
      'Chloride': NutrientInfo(
          name: 'Chloride',
          value: '0/2300 mg',
          percent: '0%',
          progress: 0.0,
          progressColor: Colors.red),
      'Chromium': NutrientInfo(
          name: 'Chromium',
          value: '0/35 mcg',
          percent: '0%',
          progress: 0.0,
          progressColor: Colors.red),
      'Copper': NutrientInfo(
          name: 'Copper',
          value: '0/900 mcg',
          percent: '0%',
          progress: 0.0,
          progressColor: Colors.red),
      'Fluoride': NutrientInfo(
          name: 'Fluoride',
          value: '0/4 mg',
          percent: '0%',
          progress: 0.0,
          progressColor: Colors.red),
      'Iodine': NutrientInfo(
          name: 'Iodine',
          value: '0/150 mcg',
          percent: '0%',
          progress: 0.0,
          progressColor: Colors.red),
      'Iron': NutrientInfo(
          name: 'Iron',
          value: '0/18 mg',
          percent: '0%',
          progress: 0.0,
          progressColor: Colors.red),
      'Magnesium': NutrientInfo(
          name: 'Magnesium',
          value: '0/400 mg',
          percent: '0%',
          progress: 0.0,
          progressColor: Colors.red),
      'Manganese': NutrientInfo(
          name: 'Manganese',
          value: '0/2.3 mg',
          percent: '0%',
          progress: 0.0,
          progressColor: Colors.red),
      'Molybdenum': NutrientInfo(
          name: 'Molybdenum',
          value: '0/45 mcg',
          percent: '0%',
          progress: 0.0,
          progressColor: Colors.red),
      'Phosphorus': NutrientInfo(
          name: 'Phosphorus',
          value: '0/700 mg',
          percent: '0%',
          progress: 0.0,
          progressColor: Colors.red),
      'Potassium': NutrientInfo(
          name: 'Potassium',
          value: '0/3500 mg',
          percent: '0%',
          progress: 0.0,
          progressColor: Colors.red),
      'Selenium': NutrientInfo(
          name: 'Selenium',
          value: '0/55 mcg',
          percent: '0%',
          progress: 0.0,
          progressColor: Colors.red),
      'Sodium': NutrientInfo(
          name: 'Sodium',
          value: '0/2300 mg',
          percent: '0%',
          progress: 0.0,
          progressColor: Colors.red),
      'Zinc': NutrientInfo(
          name: 'Zinc',
          value: '0/11 mg',
          percent: '0%',
          progress: 0.0,
          progressColor: Colors.red),
    };

    // OTHER NUTRIENTS
    other = {
      'Fiber': NutrientInfo(
          name: 'Fiber',
          value: '0/30 g',
          percent: '0%',
          progress: 0.0,
          progressColor: Colors.red),
      'Cholesterol': NutrientInfo(
          name: 'Cholesterol',
          value: '0/300 mg',
          percent: '0%',
          progress: 0.0,
          progressColor: Colors.red),
      'Sugar': NutrientInfo(
          name: 'Sugar',
          value: '0/50 g',
          percent: '0%',
          progress: 0.0,
          progressColor: Colors.red),
      'Saturated Fats': NutrientInfo(
          name: 'Saturated Fats',
          value: '0/22 g',
          percent: '0%',
          progress: 0.0,
          progressColor: Colors.red),
      'Omega-3': NutrientInfo(
          name: 'Omega-3',
          value: '0/1500 mg',
          percent: '0%',
          progress: 0.0,
          progressColor: Colors.red),
      'Omega-6': NutrientInfo(
          name: 'Omega-6',
          value: '0/14 g',
          percent: '0%',
          progress: 0.0,
          progressColor: Colors.red),
    };

    // Set the counters for each category
    vitaminCount = vitamins.length;
    mineralCount = minerals.length;
    otherCount = other.length;
  }

  // Diagnostic function to print all available nutrient target keys
  Future<void> _printAvailableNutrientTargetKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      print('\n========== AVAILABLE NUTRIENT TARGET KEYS ==========');

      // Get all keys
      Set<String> allKeys = prefs.getKeys();

      // Filter keys related to nutrient targets
      List<String> targetKeys = allKeys
          .where((key) =>
              key.contains('target_') ||
              key.contains('vitamin_') ||
              key.contains('mineral_'))
          .toList();

      // Sort the keys for easier reading
      targetKeys.sort();

      // Print all target keys and their values
      for (String key in targetKeys) {
        var value = prefs.get(key);
        print('$key = $value');
      }

      print('=================================================\n');
    } catch (e) {
      print('Error printing nutrient target keys: $e');
    }
  }

  // Update nutrient values from data provided by SnapFood or other sources
  void _updateNutrientValuesFromData(Map<String, dynamic> data) {
    print('Updating nutrient values from data, keys: ${data.keys.toList()}');

    // FIRST - let's check for values directly in the root object
    // This is how SnapFood.dart is sending the data
    Map<String, String> rootKeyToVitaminMap = {
      // Direct vitamin mapping from SnapFood API response
      'vitamin_a': 'Vitamin A',
      'vitamin_c': 'Vitamin C',
      'vitamin_d': 'Vitamin D',
      'vitamin_e': 'Vitamin E',
      'vitamin_k': 'Vitamin K',
      'vitamin_b1': 'Vitamin B1',
      'vitamin_b2': 'Vitamin B2',
      'vitamin_b3': 'Vitamin B3',
      'vitamin_b5': 'Vitamin B5',
      'vitamin_b6': 'Vitamin B6',
      'vitamin_b7': 'Vitamin B7',
      'vitamin_b9': 'Vitamin B9',
      'vitamin_b12': 'Vitamin B12',
    };

    // Process root level vitamins (direct format from SnapFood)
    try {
      rootKeyToVitaminMap.forEach((apiKey, vitaminKey) {
        if (data.containsKey(apiKey) && vitamins.containsKey(vitaminKey)) {
          double amount = _extractNumericValue(data[apiKey].toString());
          if (amount > 0) {
            _updateVitaminWithValue(vitaminKey, amount);
            print('Found $vitaminKey: $amount mg directly in root data');
          }
        }
      });
    } catch (e) {
      print('Error processing direct root vitamins: $e');
    }

    // Process root level minerals (direct format from SnapFood)
    Map<String, String> rootKeyToMineralMap = {
      // Direct mineral mapping from SnapFood API response
      'calcium': 'Calcium',
      'chloride': 'Chloride',
      'chromium': 'Chromium',
      'copper': 'Copper',
      'fluoride': 'Fluoride',
      'iodine': 'Iodine',
      'iron': 'Iron',
      'magnesium': 'Magnesium',
      'manganese': 'Manganese',
      'molybdenum': 'Molybdenum',
      'phosphorus': 'Phosphorus',
      'potassium': 'Potassium',
      'selenium': 'Selenium',
      'sodium': 'Sodium',
      'zinc': 'Zinc',
    };

    try {
      rootKeyToMineralMap.forEach((apiKey, mineralKey) {
        if (data.containsKey(apiKey) && minerals.containsKey(mineralKey)) {
          double amount = _extractNumericValue(data[apiKey].toString());
          if (amount > 0) {
            _updateMineralWithValue(mineralKey, amount);
            print('Found $mineralKey: $amount mg directly in root data');
          }
        }
      });
    } catch (e) {
      print('Error processing direct root minerals: $e');
    }

    // Process root level other nutrients (direct format from SnapFood)
    Map<String, String> rootKeyToOtherMap = {
      'fiber': 'Fiber',
      'cholesterol': 'Cholesterol',
      'sugar': 'Sugar',
      'saturated_fat': 'Saturated Fats',
      'saturated_fats': 'Saturated Fats', // Add this to match API response
      'omega_3': 'Omega-3',
      'omega_6': 'Omega-6',
    };

    try {
      rootKeyToOtherMap.forEach((apiKey, nutrientKey) {
        if (data.containsKey(apiKey) && other.containsKey(nutrientKey)) {
          double amount = _extractNumericValue(data[apiKey].toString());
          if (amount > 0) {
            _updateOtherNutrientWithValue(nutrientKey, amount);
            print('Found $nutrientKey: $amount directly in root data');
          }
        }
      });
    } catch (e) {
      print('Error processing direct root other nutrients: $e');
    }

    // Process each nutrient individually to prevent one error affecting others
    _processSingleOtherNutrient(data, 'Cholesterol', ['cholesterol', 'chol']);
    _processSingleOtherNutrient(
        data, 'Fiber', ['fiber', 'dietary_fiber', 'dietary fiber', 'fibre']);
    _processSingleOtherNutrient(
        data, 'Sugar', ['sugar', 'sugars', 'total_sugar', 'total sugar']);
    _processSingleOtherNutrient(
        data, 'Saturated Fats', ['saturated_fat', 'saturated fat', 'sat_fat']);
    _processSingleOtherNutrient(
        data, 'Omega-3', ['omega_3', 'omega 3', 'omega3']);
    _processSingleOtherNutrient(
        data, 'Omega-6', ['omega_6', 'omega 6', 'omega6']);

    // Check for structured nutrients (how the API is designed to return data)
    try {
      // Process vitamins from the 'vitamins' category
      if (data.containsKey('vitamins') && data['vitamins'] is Map) {
        Map<String, dynamic> vitaminData = data['vitamins'];
        print('Processing structured vitamins: ${vitaminData.keys.toList()}');

        // Map API keys to our display keys
        Map<String, String> vitaminKeyMap = {
          'vitamin_a': 'Vitamin A',
          'vitamin_c': 'Vitamin C',
          'vitamin_d': 'Vitamin D',
          'vitamin_e': 'Vitamin E',
          'vitamin_k': 'Vitamin K',
          'vitamin_b1': 'Vitamin B1',
          'vitamin_b2': 'Vitamin B2',
          'vitamin_b3': 'Vitamin B3',
          'vitamin_b5': 'Vitamin B5',
          'vitamin_b6': 'Vitamin B6',
          'vitamin_b7': 'Vitamin B7',
          'vitamin_b9': 'Vitamin B9',
          'vitamin_b12': 'Vitamin B12',
        };

        vitaminKeyMap.forEach((apiKey, displayKey) {
          if (vitaminData.containsKey(apiKey) &&
              vitamins.containsKey(displayKey)) {
            double amount =
                _extractNumericValue(vitaminData[apiKey].toString());
            if (amount > 0) {
              _updateVitaminWithValue(displayKey, amount);
              print('Found $displayKey: $amount from structured vitamins data');
            }
          }
        });
      }

      // Process minerals from the 'minerals' category
      if (data.containsKey('minerals') && data['minerals'] is Map) {
        Map<String, dynamic> mineralData = data['minerals'];
        print('Processing structured minerals: ${mineralData.keys.toList()}');

        // Map API keys to our display keys
        Map<String, String> mineralKeyMap = {
          'calcium': 'Calcium',
          'chloride': 'Chloride',
          'chromium': 'Chromium',
          'copper': 'Copper',
          'fluoride': 'Fluoride',
          'iodine': 'Iodine',
          'iron': 'Iron',
          'magnesium': 'Magnesium',
          'manganese': 'Manganese',
          'molybdenum': 'Molybdenum',
          'phosphorus': 'Phosphorus',
          'potassium': 'Potassium',
          'selenium': 'Selenium',
          'sodium': 'Sodium',
          'zinc': 'Zinc',
        };

        mineralKeyMap.forEach((apiKey, displayKey) {
          if (mineralData.containsKey(apiKey) &&
              minerals.containsKey(displayKey)) {
            double amount =
                _extractNumericValue(mineralData[apiKey].toString());
            if (amount > 0) {
              _updateMineralWithValue(displayKey, amount);
              print('Found $displayKey: $amount from structured minerals data');
            }
          }
        });
      }

      // Process other nutrients from the 'other' category
      if (data.containsKey('other') && data['other'] is Map) {
        Map<String, dynamic> otherData = data['other'];
        print(
            'Processing structured other nutrients: ${otherData.keys.toList()}');

        // Map API keys to our display keys
        Map<String, String> otherKeyMap = {
          'fiber': 'Fiber',
          'cholesterol': 'Cholesterol',
          'sugar': 'Sugar',
          'saturated_fat': 'Saturated Fats',
          'saturated_fats': 'Saturated Fats',
          'omega_3': 'Omega-3',
          'omega_6': 'Omega-6',
        };

        otherKeyMap.forEach((apiKey, displayKey) {
          if (otherData.containsKey(apiKey) && other.containsKey(displayKey)) {
            double amount = _extractNumericValue(otherData[apiKey].toString());
            if (amount > 0) {
              _updateOtherNutrientWithValue(displayKey, amount);
              print(
                  'Found $displayKey: $amount from structured other nutrients data');
            }
          }
        });
      }
    } catch (e) {
      print('Error processing structured nutrients: $e');
    }

    // Look for nutrients in additionalNutrients format (from FoodCardOpen)
    try {
      if (data.containsKey('additionalNutrients') &&
          data['additionalNutrients'] is Map) {
        Map<String, dynamic> additionalNutrients = data['additionalNutrients'];
        print(
            'Processing additionalNutrients: ${additionalNutrients.keys.toList()}');

        // Process all nutrients from additionalNutrients
        additionalNutrients.forEach((key, value) {
          String lowercaseKey = key.toLowerCase();

          // Check if this is a vitamin
          for (var entry in rootKeyToVitaminMap.entries) {
            if (lowercaseKey.contains(entry.key) &&
                vitamins.containsKey(entry.value)) {
              double amount = _extractNumericValue(value.toString());
              if (amount > 0) {
                _updateVitaminWithValue(entry.value, amount);
                print('Found ${entry.value}: $amount from additionalNutrients');
              }
              return; // Skip to next nutrient
            }
          }

          // Check if this is a mineral
          for (var entry in rootKeyToMineralMap.entries) {
            if (lowercaseKey.contains(entry.key) &&
                minerals.containsKey(entry.value)) {
              double amount = _extractNumericValue(value.toString());
              if (amount > 0) {
                _updateMineralWithValue(entry.value, amount);
                print('Found ${entry.value}: $amount from additionalNutrients');
              }
              return; // Skip to next nutrient
            }
          }

          // Check if this is another nutrient
          for (var entry in rootKeyToOtherMap.entries) {
            if (lowercaseKey.contains(entry.key) &&
                other.containsKey(entry.value)) {
              double amount = _extractNumericValue(value.toString());
              if (amount > 0) {
                _updateOtherNutrientWithValue(entry.value, amount);
                print('Found ${entry.value}: $amount from additionalNutrients');
              }
              return; // Skip to next nutrient
            }
          }
        });
      }
    } catch (e) {
      print('Error processing additionalNutrients: $e');
    }
  }

  // ... existing code ...

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Add WillPopScope to intercept back button presses
      onWillPop: () async {
        // Save data before allowing navigation
        await _saveNutritionData();

        // Double-save to the global key for extra reliability
        try {
          final prefs = await SharedPreferences.getInstance();

          // Create a data object with nutrition data
          Map<String, dynamic> nutritionData = {
            'scanId': _scanId,
            'lastSaved': DateTime.now().millisecondsSinceEpoch,
            'vitamins':
                Map.fromEntries(vitamins.entries.map((e) => MapEntry(e.key, {
                      'name': e.value.name,
                      'value': e.value.value,
                      'percent': e.value.percent,
                      'progress': e.value.progress,
                      'hasInfo': e.value.hasInfo,
                    }))),
            'minerals':
                Map.fromEntries(minerals.entries.map((e) => MapEntry(e.key, {
                      'name': e.value.name,
                      'value': e.value.value,
                      'percent': e.value.percent,
                      'progress': e.value.progress,
                      'hasInfo': e.value.hasInfo,
                    }))),
            'other': Map.fromEntries(other.entries.map((e) => MapEntry(e.key, {
                  'name': e.value.name,
                  'value': e.value.value,
                  'percent': e.value.percent,
                  'progress': e.value.progress,
                  'hasInfo': e.value.hasInfo,
                }))),
          };

          String json = jsonEncode(nutritionData);
          await prefs.setString('PERMANENT_GLOBAL_NUTRITION_DATA', json);
        } catch (e) {
          print('Error during extra save: $e');
        }

        return true;
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/background4.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with back button and title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 29)
                        .copyWith(top: 16, bottom: 8.5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Back button
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.black, size: 24),
                          onPressed: () async {
                            // Save nutrition data before navigation
                            await _saveNutritionData();

                            // Double-save to the global key for extra reliability
                            try {
                              final prefs =
                                  await SharedPreferences.getInstance();

                              // Create a data object with nutrition data
                              Map<String, dynamic> nutritionData = {
                                'scanId': _scanId,
                                'lastSaved':
                                    DateTime.now().millisecondsSinceEpoch,
                                'vitamins': Map.fromEntries(vitamins.entries
                                    .map((e) => MapEntry(e.key, {
                                          'name': e.value.name,
                                          'value': e.value.value,
                                          'percent': e.value.percent,
                                          'progress': e.value.progress,
                                          'hasInfo': e.value.hasInfo,
                                        }))),
                                'minerals': Map.fromEntries(minerals.entries
                                    .map((e) => MapEntry(e.key, {
                                          'name': e.value.name,
                                          'value': e.value.value,
                                          'percent': e.value.percent,
                                          'progress': e.value.progress,
                                          'hasInfo': e.value.hasInfo,
                                        }))),
                                'other': Map.fromEntries(
                                    other.entries.map((e) => MapEntry(e.key, {
                                          'name': e.value.name,
                                          'value': e.value.value,
                                          'percent': e.value.percent,
                                          'progress': e.value.progress,
                                          'hasInfo': e.value.hasInfo,
                                        }))),
                              };

                              String json = jsonEncode(nutritionData);
                              await prefs.setString(
                                  'PERMANENT_GLOBAL_NUTRITION_DATA', json);
                            } catch (e) {
                              print('Error during extra save: $e');
                            }

                            if (mounted) {
                              Navigator.pop(context);
                            }
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),

                        // In-Depth Nutrition title
                        const Text(
                          'In-Depth Nutrition',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'SF Pro',
                            color: Colors.black,
                          ),
                        ),

                        // Empty space to balance the header
                        const SizedBox(width: 24),
                      ],
                    ),
                  ),

                  // Slim gray divider line
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 29),
                    height: 1,
                    color: const Color(0xFFBDBDBD),
                  ),

                  const SizedBox(height: 20),

                  // Vitamins Section
                  _buildNutrientSection(
                    title: "Vitamins",
                    count: "${_countNonZeroValues(vitamins)}/13",
                    nutrients: vitamins.values.toList(),
                    centerTitle: true,
                  ),

                  const SizedBox(height: 20),

                  // Minerals Section
                  _buildNutrientSection(
                    title: "Minerals",
                    count: "${_countNonZeroValues(minerals)}/15",
                    nutrients: minerals.values.toList(),
                    centerTitle: true,
                  ),

                  const SizedBox(height: 20),

                  // Other Nutrients Section
                  _buildNutrientSection(
                    title: "Other",
                    count: "${_countNonZeroValues(other)}/6",
                    nutrients: other.values.toList(),
                    centerTitle: true,
                  ),

                  // Bottom padding
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  int _countNonZeroValues(Map<String, NutrientInfo> nutrientMap) {
    return nutrientMap.values
        .where((nutrient) =>
            nutrient.progress >=
            1.0) // Only count as filled if progress is 100% or higher
        .length;
  }

  // Class to hold nutrient information
  Widget _buildNutrientSection({
    required String title,
    required String count,
    required List<NutrientInfo> nutrients,
    bool centerTitle = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 29),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header section with divider
            Padding(
              padding: const EdgeInsets.only(top: 10, left: 20, right: 20),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Title in exact center
                  Center(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'SF Pro',
                      ),
                    ),
                  ),
                  // Row for info icon, spacer, and count
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Info icon on left
                      GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            barrierColor: Colors.black.withOpacity(0.6),
                            builder: (context) {
                              return Dialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                backgroundColor: Colors.white,
                                insetPadding:
                                    EdgeInsets.symmetric(horizontal: 32),
                                child: Container(
                                  width: 326,
                                  height: 310,
                                  child: Stack(
                                    children: [
                                      // Close icon
                                      Positioned(
                                        top: 21,
                                        right: 21,
                                        child: GestureDetector(
                                          onTap: () =>
                                              Navigator.of(context).pop(),
                                          child: Image.asset(
                                            'assets/images/closeicon.png',
                                            width: 19,
                                            height: 19,
                                          ),
                                        ),
                                      ),
                                      // Content
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(height: 21),
                                          // Info headline horizontally centered and moved up by 6px
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 0),
                                            child: Align(
                                              alignment: Alignment.topCenter,
                                              child: Transform.translate(
                                                offset: Offset(0, -6),
                                                child: Text(
                                                  'Info',
                                                  style: TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.w600,
                                                    fontFamily:
                                                        'SF Pro Display',
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Spacer(),
                                          // Vertically centered, left-aligned subtext/checkmark group
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              SizedBox(width: 32),
                                              Transform.translate(
                                                offset: Offset(0, -10),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      children: [
                                                        CustomPaint(
                                                          size: Size(22, 22),
                                                          painter:
                                                              _CheckmarkPainter(
                                                                  size: 22),
                                                        ),
                                                        SizedBox(width: 16),
                                                        Text(
                                                          'Aim for 100% daily intake',
                                                          style: TextStyle(
                                                            fontSize: 18,
                                                            fontFamily:
                                                                'SF Pro Display',
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    SizedBox(height: 18),
                                                    Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      children: [
                                                        CustomPaint(
                                                          size: Size(22, 22),
                                                          painter:
                                                              _CheckmarkPainter(
                                                                  size: 22),
                                                        ),
                                                        SizedBox(width: 16),
                                                        Text(
                                                          'Individual needs may differ',
                                                          style: TextStyle(
                                                            fontSize: 18,
                                                            fontFamily:
                                                                'SF Pro Display',
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          Spacer(),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 20),
                                            child: Container(
                                              width: 280,
                                              height: 48,
                                              margin:
                                                  EdgeInsets.only(bottom: 24),
                                              decoration: BoxDecoration(
                                                color: Colors.black,
                                                borderRadius:
                                                    BorderRadius.circular(28),
                                              ),
                                              child: TextButton(
                                                onPressed: () =>
                                                    Navigator.of(context).pop(),
                                                style: ButtonStyle(
                                                  overlayColor:
                                                      MaterialStateProperty.all(
                                                          Colors.transparent),
                                                ),
                                                child: const Text(
                                                  'Continue',
                                                  style: TextStyle(
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.w500,
                                                    fontFamily:
                                                        'SF Pro Display',
                                                    color: Colors.white,
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
                              );
                            },
                          );
                        },
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 1),
                          ),
                          child: Center(
                            child: Text(
                              "i",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'SF Pro',
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Counter on right
                      Text(
                        count,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                          fontFamily: 'SF Pro',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Divider line under header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Divider(
                height: 1,
                thickness: 1,
                color: Colors.grey.withOpacity(0.3),
              ),
            ),

            // Nutrients list
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: nutrients.map((nutrient) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nutrient name and values row
                      Row(
                        children: [
                          // Name
                          Expanded(
                            flex: 2,
                            child: Text(
                              nutrient.name,
                              style: const TextStyle(
                                fontSize: 17,
                                color: Colors.black,
                                fontFamily: 'SF Pro',
                              ),
                            ),
                          ),
                          // Value with aligned slash
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: [
                                // Use RichText to align the slash character
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontFamily: 'SF Pro',
                                      color: Colors.black,
                                    ),
                                    children:
                                        _formatValueWithSlash(nutrient.value),
                                  ),
                                ),
                                if (nutrient.hasInfo)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Image.asset(
                                      'assets/images/questionmark.png',
                                      width: 15,
                                      height: 15,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Percentage
                          Text(
                            nutrient.percent,
                            style: const TextStyle(
                              fontSize: 14,
                              fontFamily: 'SF Pro',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: nutrient.progress.clamp(0.0,
                              1.0), // Clamp only for UI display, still show >100% in text
                          minHeight: 8,
                          backgroundColor: Colors.grey.withOpacity(0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(
                              nutrient.progressColor),
                        ),
                      ),

                      const SizedBox(height: 12),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to format the value with aligned slash
  List<TextSpan> _formatValueWithSlash(String value) {
    // If the value contains a slash, split it and align
    if (value.contains('/')) {
      List<String> parts = value.split('/');
      String leftPart = parts[0];
      String rightPart = parts.length > 1 ? parts[1] : '';

      return [
        TextSpan(
          text: leftPart,
          style: const TextStyle(
            fontSize: 13,
            fontFamily: 'SF Pro',
          ),
        ),
        const TextSpan(
          text: '/',
          style: TextStyle(
            fontSize: 14, // Increased by 1
            fontFamily: 'SF Pro',
          ),
        ),
        TextSpan(
          text: rightPart,
          style: const TextStyle(
            fontSize: 13,
            fontFamily: 'SF Pro',
          ),
        ),
      ];
    } else {
      // If no slash, just return the value as is
      return [
        TextSpan(
          text: value,
          style: const TextStyle(
            fontSize: 13,
            fontFamily: 'SF Pro',
          ),
        ),
      ];
    }
  }

  // Save nutrition data - ULTRA RELIABLE with one global key
  Future<void> _saveNutritionData({bool useGlobalKey = true}) async {
    try {
      // Get SharedPreferences instance
      final prefs = await SharedPreferences.getInstance();

      // Create a data object with nutrition data
      Map<String, dynamic> nutritionData = {
        'scanId': _scanId,
        'lastSaved': DateTime.now().millisecondsSinceEpoch,
        'vitamins':
            Map.fromEntries(vitamins.entries.map((e) => MapEntry(e.key, {
                  'name': e.value.name,
                  'value': e.value.value,
                  'percent': e.value.percent,
                  'progress': e.value.progress,
                  'hasInfo': e.value.hasInfo,
                }))),
        'minerals':
            Map.fromEntries(minerals.entries.map((e) => MapEntry(e.key, {
                  'name': e.value.name,
                  'value': e.value.value,
                  'percent': e.value.percent,
                  'progress': e.value.progress,
                  'hasInfo': e.value.hasInfo,
                }))),
        'other': Map.fromEntries(other.entries.map((e) => MapEntry(e.key, {
              'name': e.value.name,
              'value': e.value.value,
              'percent': e.value.percent,
              'progress': e.value.progress,
              'hasInfo': e.value.hasInfo,
            }))),
      };

      // Convert to JSON
      String dataJson = jsonEncode(nutritionData);

      // For food-specific scan IDs, don't save to global key
      if (_scanId.startsWith('food_nutrition_')) {
        // FOOD-SPECIFIC: Save only to food-specific keys
        await prefs.setString('food_nutrition_data_$_scanId', dataJson);
        await prefs.setString('nutrition_data_$_scanId', dataJson);

        // If this is a food-specific scan ID from FoodCardOpen.dart
        try {
          // Format is "food_nutrition_foodname_calories"
          List<String> parts = _scanId.split('_');
          if (parts.length >= 3) {
            // Everything after "food_nutrition_" and before the last part (calories)
            String foodName = parts.sublist(2, parts.length - 1).join('_');

            // Also store by food name for compatibility with FoodCardOpen.dart
            await prefs.setString('food_nutrition_$foodName', dataJson);

            // Update the food_cards list if this food exists there
            await _updateFoodCardWithNutrition(foodName, nutritionData);
          }
        } catch (e) {
          print('Error extracting food name from scan ID: $e');
        }
      } else if (useGlobalKey) {
        // GLOBAL: For non-food specific or when explicitly requested to use global key
        await prefs.setString('PERMANENT_GLOBAL_NUTRITION_DATA', dataJson);
        await prefs.setString('food_nutrition_data_$_scanId', dataJson);
        await prefs.setString('nutrition_data_$_scanId', dataJson);
      }

      // Always store the current scan ID globally
      await prefs.setString('current_nutrition_scan_id', _scanId);

      print(
          'Saved nutrition data for ID: $_scanId (useGlobalKey=$useGlobalKey)');
    } catch (e) {
      print('Error saving nutrition data: $e');
    }
  }

  // Helper method to update a food card's nutrition data if it exists
  Future<void> _updateFoodCardWithNutrition(
      String foodName, Map<String, dynamic> nutritionData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String>? foodCards = prefs.getStringList('food_cards');

      if (foodCards == null || foodCards.isEmpty) return;

      bool updated = false;
      List<String> updatedCards = [];

      // Find the matching food card
      for (String cardJson in foodCards) {
        try {
          Map<String, dynamic> card = jsonDecode(cardJson);
          String cardName = (card['name'] ?? '')
              .toString()
              .toLowerCase()
              .trim()
              .replaceAll(' ', '_');

          if (cardName == foodName ||
              cardName.contains(foodName) ||
              foodName.contains(cardName)) {
            // Found a matching food card, update its nutrition data
            print(
                'Found matching food card for nutrition update: ${card['name']}');

            // Add vitamin/mineral data to the card
            if (nutritionData.containsKey('vitamins')) {
              card['vitamins'] = nutritionData['vitamins'];
            }
            if (nutritionData.containsKey('minerals')) {
              card['minerals'] = nutritionData['minerals'];
            }
            if (nutritionData.containsKey('other')) {
              card['other'] = nutritionData['other'];
            }

            // Add scan_id if it doesn't exist
            if (!card.containsKey('scan_id')) {
              card['scan_id'] = _scanId;
            }

            // Update the card
            updatedCards.add(jsonEncode(card));
            updated = true;
          } else {
            // Keep unchanged cards
            updatedCards.add(cardJson);
          }
        } catch (e) {
          print('Error processing food card: $e');
          // Keep original card if there's an error
          updatedCards.add(cardJson);
        }
      }

      // Save the updated food cards
      if (updated) {
        await prefs.setStringList('food_cards', updatedCards);
        print('Updated food card with nutrition data');
      }
    } catch (e) {
      print('Error updating food card with nutrition: $e');
    }
  }

  // Load saved nutrition data - ULTRA RELIABLE with global key
  Future<bool> _loadSavedNutritionData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // ALWAYS try the global permanent key first
      String? savedData = prefs.getString('PERMANENT_GLOBAL_NUTRITION_DATA');

      // If not found by global key, try scan-specific key
      if (savedData == null || savedData.isEmpty) {
        savedData = prefs.getString('food_nutrition_data_$_scanId');
      }

      // Process the data if found by any key
      if (savedData != null && savedData.isNotEmpty) {
        Map<String, dynamic> loadedData = jsonDecode(savedData);

        // Process vitamins data
        if (loadedData.containsKey('vitamins')) {
          Map<String, dynamic> vitaminData = loadedData['vitamins'];
          vitaminData.forEach((key, value) {
            if (!vitamins.containsKey(key)) return;

            double progress = 0.0;
            if (value is Map) {
              if (value.containsKey('progress')) {
                progress = value['progress'] is double
                    ? value['progress']
                    : double.parse(value['progress'].toString());
              }

              Color progressColor = _getColorBasedOnProgress(progress);
              vitamins[key] = NutrientInfo(
                name: value['name'] ?? key,
                value: value['value'] ?? "0/0 g",
                percent: value['percent'] ?? "0%",
                progress: progress,
                progressColor: progressColor,
                hasInfo: value['hasInfo'] == true,
              );
            }
          });
        }

        // Process minerals data
        if (loadedData.containsKey('minerals')) {
          Map<String, dynamic> mineralData = loadedData['minerals'];
          mineralData.forEach((key, value) {
            if (!minerals.containsKey(key)) return;

            double progress = 0.0;
            if (value is Map) {
              if (value.containsKey('progress')) {
                progress = value['progress'] is double
                    ? value['progress']
                    : double.parse(value['progress'].toString());
              }

              Color progressColor = _getColorBasedOnProgress(progress);
              minerals[key] = NutrientInfo(
                name: value['name'] ?? key,
                value: value['value'] ?? "0/0 g",
                percent: value['percent'] ?? "0%",
                progress: progress,
                progressColor: progressColor,
                hasInfo: value['hasInfo'] == true,
              );
            }
          });
        }

        // Process other nutrients data
        if (loadedData.containsKey('other')) {
          Map<String, dynamic> otherData = loadedData['other'];
          otherData.forEach((key, value) {
            if (!other.containsKey(key)) return;

            double progress = 0.0;
            if (value is Map) {
              if (value.containsKey('progress')) {
                progress = value['progress'] is double
                    ? value['progress']
                    : double.parse(value['progress'].toString());
              }

              Color progressColor = _getColorBasedOnProgress(progress);
              other[key] = NutrientInfo(
                name: value['name'] ?? key,
                value: value['value'] ?? "0/0 g",
                percent: value['percent'] ?? "0%",
                progress: progress,
                progressColor: progressColor,
                hasInfo: value['hasInfo'] == true,
              );
            }
          });
        }

        // Immediately re-save to ensure consistent formats
        await _saveNutritionData();

        return true;
      } else if (widget.nutritionData != null &&
          widget.nutritionData!.isNotEmpty) {
        // If no saved data but widget provided data, use that
        _updateNutrientValuesFromData(widget.nutritionData!);

        // Save this data right away
        await _saveNutritionData();
        return true;
      }

      return false;
    } catch (e) {
      print('Error loading saved nutrition data: $e');
      return false;
    }
  }

  // Helper method to process simplified data format
  void _processSimplifiedData(Map<String, dynamic> simplifiedData,
      Map<String, NutrientInfo> targetMap) {
    simplifiedData.forEach((key, value) {
      if (targetMap.containsKey(key)) {
        List<String> parts = value.toString().split('/');
        double currentValue = double.tryParse(parts[0]) ?? 0;
        double targetValue = 0;
        String unit = "g";

        if (parts.length > 1) {
          String rest = parts[1];
          // Extract the target value and unit
          RegExp regex = RegExp(r'(\d+\.?\d*)\s*(\w+)');
          Match? match = regex.firstMatch(rest);
          if (match != null) {
            targetValue = double.tryParse(match.group(1) ?? "0") ?? 0;
            unit = match.group(2) ?? "g";
          }
        }

        double progress = targetValue > 0
            ? (currentValue / targetValue)
            : 0.0; // Removed clamp
        Color progressColor = _getColorBasedOnProgress(progress);

        targetMap[key] = NutrientInfo(
          name: key,
          value: "$currentValue/$targetValue $unit",
          percent: "${(progress * 100).round()}%",
          progress: progress,
          progressColor: progressColor,
        );
      }
    });
  }

  // Helper method to check if data structure seems valid despite ID mismatch
  bool _isMostLikelyValidNutritionData(Map<String, dynamic> data) {
    // Basic validation: ensure it has expected top-level keys
    bool hasExpectedKeys = data.containsKey('vitamins') ||
        data.containsKey('minerals') ||
        data.containsKey('other');

    if (!hasExpectedKeys && data.containsKey('data')) {
      // Check simplified format
      if (data['data'] is Map) {
        Map dataMap = data['data'] as Map;
        hasExpectedKeys = dataMap.containsKey('vitamins') ||
            dataMap.containsKey('minerals') ||
            dataMap.containsKey('other');
      }
    }

    return hasExpectedKeys;
  }

  // Add a helper method to determine color based on progress
  Color _getColorBasedOnProgress(double progress) {
    if (progress < 0.4) {
      return Colors.red; // Red for 0-40%
    } else if (progress < 0.8) {
      return yellowColor; // Yellow for 40-80%
    } else {
      return greenColor; // Green for 80-100%+ (anything above 0.8 is good)
    }
  }

  // Helper method to load personalized vitamin targets from SharedPreferences
  Future<void> _loadPersonalizedVitaminTargets(
      Map<String, Map<String, dynamic>> vitaminInfo) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Update targets from SharedPreferences where available
      for (var entry in vitaminInfo.entries) {
        String dataKey = entry.key;
        Map<String, dynamic> info = entry.value;
        String uiKey = info['key'] as String;
        String prefsKey = uiKey.toLowerCase().replaceAll(' ', '_');

        // Try to load from SharedPreferences - IMPORTANT: Use vitamin_target_X format to match calculation_screen.dart
        double? target = prefs.getDouble('vitamin_target_$prefsKey');

        // If found, update the target in the vitaminInfo map
        if (target != null) {
          vitaminInfo[dataKey]!['target'] = target;
          print(
              'Loaded personalized vitamin target: $uiKey = $target ${info['unit']}');
        } else {
          print(
              'No personalized target found for $uiKey, using default: ${info['target']} ${info['unit']}');
        }
      }
    } catch (e) {
      print('Error loading personalized vitamin targets: $e');
    }
  }

  Future<void> _refreshDisplaysWithPersonalizedTargets() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if we have personalized targets
      String? calculationDate =
          prefs.getString('nutrient_targets_calculation_date');
      if (calculationDate != null) {
        print(
            'Refreshing all displays with personalized targets calculated on: $calculationDate');

        // UPDATE OTHER NUTRIENTS
        // Fiber
        double fiberTarget = prefs.getDouble('nutrient_target_fiber') ?? 30.0;
        if (other.containsKey('Fiber')) {
          double currentValue = _parseCurrentValue(other['Fiber']!.value);
          _updateNutrientDisplay(
              'Fiber', currentValue, fiberTarget, 'g', other);
        }

        // Cholesterol - FIXED to use the proper SharedPreferences key
        double cholesterolTarget =
            prefs.getDouble('nutrient_target_cholesterol') ?? 300.0;
        if (other.containsKey('Cholesterol')) {
          double currentValue = _parseCurrentValue(other['Cholesterol']!.value);
          _updateNutrientDisplay(
              'Cholesterol', currentValue, cholesterolTarget, 'mg', other);
        }

        // Omega-3
        double omega3Target =
            prefs.getDouble('nutrient_target_omega3') ?? 1500.0;
        if (other.containsKey('Omega-3')) {
          double currentValue = _parseCurrentValue(other['Omega-3']!.value);
          _updateNutrientDisplay(
              'Omega-3', currentValue, omega3Target, 'mg', other);
        }

        // Omega-6
        double omega6Target = prefs.getDouble('nutrient_target_omega6') ?? 14.0;
        if (other.containsKey('Omega-6')) {
          double currentValue = _parseCurrentValue(other['Omega-6']!.value);
          _updateNutrientDisplay(
              'Omega-6', currentValue, omega6Target, 'g', other);
        }

        // Saturated Fats
        double saturatedFatTarget =
            prefs.getDouble('nutrient_target_saturated_fat') ?? 22.0;
        if (other.containsKey('Saturated Fats')) {
          double currentValue =
              _parseCurrentValue(other['Saturated Fats']!.value);
          _updateNutrientDisplay(
              'Saturated Fats', currentValue, saturatedFatTarget, 'g', other);
        }

        // UPDATE VITAMINS
        // Process each vitamin using direct target lookup
        vitamins.forEach((key, info) {
          String prefsKey = key.toLowerCase().replaceAll(' ', '_');
          String basicName = prefsKey.replaceAll('vitamin_', '');

          // Try all possible key formats for vitamins
          double? storedTarget;

          // Try direct format with underscores
          storedTarget = prefs.getDouble('vitamin_target_$prefsKey');

          // Try with spaces as saved by calculation_screen.dart
          if (storedTarget == null) {
            storedTarget =
                prefs.getDouble('vitamin_target_${key.toLowerCase()}');
          }

          // Try with basic name and various prefixes
          if (storedTarget == null) {
            for (String prefix in [
              'vitamin_target_',
              'vitamin_target_vitamin_',
              'vitamin_target_vitamin '
            ]) {
              storedTarget = prefs.getDouble('$prefix$basicName');
              if (storedTarget != null) break;
            }
          }

          if (storedTarget != null) {
            // Use the personalized target
            double currentValue = _parseCurrentValue(info.value);
            String unit = key.contains('A') ||
                    key.contains('D') ||
                    key.contains('B7') ||
                    key.contains('B9') ||
                    key.contains('B12') ||
                    key.contains('K')
                ? 'mcg'
                : 'mg';

            _updateNutrientDisplay(
                key, currentValue, storedTarget, unit, vitamins);
            print('Using personalized target for $key: $storedTarget $unit');
          } else {
            // No personalized target found - should never happen if calculation worked correctly
            print(
                'WARNING: No personalized target found for $key, using existing value');
          }
        });

        // UPDATE MINERALS
        // Process each mineral using direct target lookup
        minerals.forEach((key, info) {
          String prefsKey = key.toLowerCase().replaceAll(' ', '_');

          // Try all possible key formats for minerals
          double? storedTarget;

          // Try various prefix formats
          for (String prefix in ['mineral_target_', 'nutrient_target_']) {
            storedTarget = prefs.getDouble('$prefix$prefsKey');
            if (storedTarget != null) break;
          }

          // Try with raw key format
          if (storedTarget == null) {
            storedTarget =
                prefs.getDouble('mineral_target_${key.toLowerCase()}');
          }

          if (storedTarget != null) {
            // Use the personalized target
            double currentValue = _parseCurrentValue(info.value);
            String unit = key == 'Chromium' ||
                    key == 'Copper' ||
                    key == 'Iodine' ||
                    key == 'Molybdenum' ||
                    key == 'Selenium'
                ? 'mcg'
                : 'mg';

            _updateNutrientDisplay(
                key, currentValue, storedTarget, unit, minerals);
            print('Using personalized target for $key: $storedTarget $unit');
          } else {
            // No personalized target found - should never happen if calculation worked correctly
            print(
                'WARNING: No personalized target found for $key, using existing value');
          }
        });

        print(
            'Successfully refreshed all nutrient displays with personalized targets');
      } else {
        print(
            'No personalized targets calculation date found - targets may not be fully personalized');
      }
    } catch (e) {
      print('Error refreshing displays with personalized targets: $e');
    }
  }

  // Helper method to update nutrient displays consistently
  void _updateNutrientDisplay(String key, double currentValue, double target,
      String unit, Map<String, NutrientInfo> nutrientMap) {
    double progress = (currentValue / target); // No clamping
    int percentage = (progress * 100).round();
    Color progressColor = _getColorBasedOnProgress(progress);

    // Format target value based on unit type
    String formattedTarget;
    if (unit == 'mcg' || unit == 'mg') {
      formattedTarget = target.toStringAsFixed(0);
    } else {
      formattedTarget = target.toStringAsFixed(1);
    }

    nutrientMap[key] = NutrientInfo(
        name: key,
        value: "$currentValue/$formattedTarget $unit",
        percent: "$percentage%",
        progress: progress,
        progressColor: progressColor,
        hasInfo: nutrientMap[key]?.hasInfo ?? false);
  }

  // Save nutrition data to food cards list for permanent storage
  Future<void> _saveToFoodCards(
      Map<String, dynamic> nutritionData, String foodName) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get all existing food cards
      List<String> foodCards = prefs.getStringList('food_cards') ?? [];
      List<String> updatedCards = []; // Initialize the list of updated cards
      bool updated = false;

      // Look for the specific food card that matches this scan ID
      for (int i = 0; i < foodCards.length; i++) {
        String cardJson = foodCards[i]; // Store current card JSON for reference
        try {
          Map<String, dynamic> card = jsonDecode(cardJson);

          // Check if this is the card for our current food (by name or ID)
          if ((card.containsKey('name') &&
                  card['name'].toString().toLowerCase() ==
                      foodName.toLowerCase()) ||
              (card.containsKey('scan_id') && card['scan_id'] == _scanId)) {
            // Update the card with our latest nutrition data
            print(
                'Found matching food card for nutrition update: ${card['name']}');

            // Add vitamin/mineral data to the card
            if (nutritionData.containsKey('vitamins')) {
              card['vitamins'] = nutritionData['vitamins'];
            }
            if (nutritionData.containsKey('minerals')) {
              card['minerals'] = nutritionData['minerals'];
            }
            if (nutritionData.containsKey('other')) {
              card['other'] = nutritionData['other'];
            }

            // Add scan_id if it doesn't exist
            if (!card.containsKey('scan_id')) {
              card['scan_id'] = _scanId;
            }

            // Update the card
            updatedCards.add(jsonEncode(card));
            updated = true;
          } else {
            // Keep unchanged cards
            updatedCards.add(cardJson);
          }
        } catch (e) {
          print('Error processing food card: $e');
          // Keep original card if there's an error
          updatedCards.add(cardJson);
        }
      }

      // Save the updated food cards
      if (updated) {
        await prefs.setStringList('food_cards', updatedCards);
        print('Saved updated food cards list with nutrition data');
      }
    } catch (e) {
      print('Error saving to food cards: $e');
    }
  }

  // Helper method to extract an other nutrient value using multiple possible key variants
  void _extractOtherNutrientByVariants(Map<String, dynamic> data,
      String nutrientKey, List<String> possibleKeys) {
    for (String key in possibleKeys) {
      // Check for the key in both original and lowercase forms
      if (data.containsKey(key) || data.containsKey(key.toLowerCase())) {
        String actualKey = data.containsKey(key) ? key : key.toLowerCase();
        double amount = _extractNumericValue(data[actualKey].toString());
        if (amount > 0) {
          _updateOtherNutrientWithValue(nutrientKey, amount);
          print('Found $nutrientKey: $amount using key: $actualKey');
          return; // Stop after the first match
        }
      }
    }
  }

  // Helper method to parse current value from formatted strings like "10/20 mg"
}

// Simple class to hold nutrient info
class NutrientInfo {
  final String name;
  final String value;
  final String percent;
  final double progress;
  final Color progressColor;
  final bool hasInfo;

  NutrientInfo({
    required this.name,
    required this.value,
    required this.percent,
    required this.progress,
    required this.progressColor,
    this.hasInfo = false,
  });
}

class _CheckmarkPainter extends CustomPainter {
  final double size;
  _CheckmarkPainter({this.size = 22});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint circlePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    final Paint checkPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    // Draw circle
    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2), size.width / 2, circlePaint);
    // Draw checkmark
    final Path path = Path();
    path.moveTo(size.width * 0.32, size.height * 0.55);
    path.lineTo(size.width * 0.48, size.height * 0.7);
    path.lineTo(size.width * 0.72, size.height * 0.36);
    canvas.drawPath(path, checkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
