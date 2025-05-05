import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart'
    as flutter_compress;
// Remove permission_handler temporarily
// import 'package:permission_handler/permission_handler.dart';

// Conditionally import dart:io only on non-web
import 'dart:io' if (dart.library.html) 'package:fitness_app/web_io_stub.dart';

// Import our web handling code
import 'web_impl.dart' if (dart.library.io) 'web_impl_stub.dart';

// Additional imports for mobile platforms
import 'web_image_compress_stub.dart' as img_compress;

// Conditionally import the image compress library
// We need to use a different approach to avoid conflicts
import 'image_compress.dart';

// Add import for our secure API service
import '../services/food_analyzer_api.dart';

// Import FoodCardOpen for navigation after analysis
import 'FoodCardOpen.dart';

class SnapFood extends StatefulWidget {
  const SnapFood({super.key});

  @override
  State<StatefulWidget> createState() => _SnapFoodState();
}

class _SnapFoodState extends State<SnapFood> {
  // Track the active button
  String _activeButton = 'Scan Food'; // Default active button
  bool _permissionsRequested = false;
  bool _isAnalyzing = false; // Track if analysis is in progress

  // Food analysis result
  Map<String, dynamic>? _analysisResult;
  String? _formattedAnalysisResult;

  // Image related variables
  File? _imageFile;
  String? _webImagePath;
  Uint8List? _webImageBytes; // Add storage for web image bytes
  final ImagePicker _picker = ImagePicker();
  XFile? imageFile;
  XFile? _mostRecentImage;
  bool _pendingAnalysis = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      // Simplified permission check - no permission_handler
      _checkPermissionsSimple();
    }
    print("SnapFood screen initialized");
  }

  // Simplified permission check method that doesn't use permission_handler
  Future<void> _checkPermissionsSimple() async {
    if (kIsWeb) return; // Skip permission checks on web

    // For simplicity, we'll just try to use the image picker which will trigger permission prompts
    try {
      await _picker.pickImage(source: ImageSource.camera).then((_) => null);
    } catch (e) {
      print("Camera permission might be needed: $e");
      if (mounted) {
        _showPermissionsDialog();
      }
    }
  }

  void _showPermissionsDialog() {
    _showCustomDialog("Permission Required",
        "Camera permission is needed to take pictures. Please grant permission in your device settings.");
  }

  Future<void> _requestCameraPermission() async {
    // This will trigger the actual iOS system permission dialog for camera
    try {
      // Just check availability, don't actually pick
      await _picker
          .pickImage(source: ImageSource.camera)
          .then((_) => _requestPhotoLibraryPermission());
    } catch (e) {
      print("Camera permission denied or error occurred: $e");
      _requestPhotoLibraryPermission();
    }
  }

  Future<void> _requestPhotoLibraryPermission() async {
    // This will trigger the actual iOS system permission dialog for photo library
    try {
      // Just check availability, don't actually pick
      await _picker.pickImage(source: ImageSource.gallery);
    } catch (e) {
      print("Photo library permission denied or error occurred: $e");
    }
  }

  // Local fallback for image analysis when Firebase isn't working
  Future<Map<String, dynamic>> _analyzeImageLocally(
      Uint8List imageBytes) async {
    // This is a local fallback that doesn't require any Firebase connection
    // It returns mock data similar to what the real function would return

    print("Using local fallback for image analysis");

    // Simulate a processing delay
    await Future.delayed(Duration(seconds: 1));

    // Return mock food analysis data
    return {
      "success": true,
      "meal": [
        {
          "dish": "Local Analysis Result",
          "calories": 450,
          "macronutrients": {"protein": 25, "carbohydrates": 45, "fat": 18},
          "ingredients": [
            "This is a local analysis",
            "Firebase functions deployment had issues",
            "This is a fallback implementation",
            "Image size: ${imageBytes.length} bytes"
          ]
        }
      ]
    };
  }

  // Modify the _analyzeImage method to keep isAnalyzing true until redirection
  Future<void> _analyzeImage(XFile? image) async {
    if (_isAnalyzing || image == null) return;

    setState(() {
      _isAnalyzing = true;
    });

    try {
      print("Processing image ${image.path}");
      Uint8List imageBytes;

      // Get bytes from the image
      if (kIsWeb && _webImageBytes != null) {
        // For web, use the bytes we already have
        imageBytes = _webImageBytes!;
        print("Using web image bytes: ${imageBytes.length} bytes");
      } else {
        // Read as bytes from the file
        imageBytes = await image.readAsBytes();
        print("Read image bytes (${imageBytes.length} bytes)");
      }

      // Process image if needed (e.g., compress large images)
      Uint8List processedBytes = imageBytes;
      // Get image size in MB for logging
      final double originalSizeMB = imageBytes.length / (1024 * 1024);
      print("Original image size: ${originalSizeMB.toStringAsFixed(2)} MB");

      try {
        // Use the exact 0.7MB target approach
        processedBytes = await compressImage(
          imageBytes,
          targetWidth: 1200, // Initial width (will be adjusted)
          quality: 90, // Initial quality (will be adjusted)
        );

        // Calculate compression stats
        final double compressedSizeMB = processedBytes.length / (1024 * 1024);
        final double compressionRatio = originalSizeMB / compressedSizeMB;

        print("Image processing complete:");
        print("  - Original: ${originalSizeMB.toStringAsFixed(2)} MB");
        print("  - Final: ${compressedSizeMB.toStringAsFixed(2)} MB");

        if (originalSizeMB <= 0.7) {
          print("  - Original image preserved (≤0.7MB)");
        } else {
          print("  - Compressed to target size of 0.7MB");
          print(
              "  - Compression ratio: ${compressionRatio.toStringAsFixed(2)}x");
        }
      } catch (e) {
        print("Error during image compression: $e");
        // Fall back to original bytes if compression fails
        processedBytes = imageBytes;
      }

      print("Calling secure API service");

      try {
        // Use our secure API service via Firebase
        final response = await FoodAnalyzerApi.analyzeFoodImage(processedBytes);

        print("API call successful!");
        print('Response: $response');

        if (mounted) {
          // DO NOT set _isAnalyzing to false here to keep animation running
          setState(() {
            _analysisResult = response;
          });

          // Display the formatted results in the terminal
          _displayAnalysisResults(_analysisResult!);

          // _isAnalyzing will be set to false after navigation to FoodCardOpen
        }
      } catch (e) {
        print("API analysis error: $e");

        // Even if API fails, navigate to FoodCardOpen with default values
        if (mounted) {
          // Create a default food card with the image
          final String defaultName = "Unknown Food";
          final String defaultCalories = "0";
          final String defaultProtein = "0";
          final String defaultFat = "0";
          final String defaultCarbs = "0";
          final String healthScore = "5/10";
          final List<Map<String, dynamic>> defaultIngredients = [
            {'name': 'Unknown ingredients', 'amount': '0g', 'calories': 0}
          ];

          // Convert image to base64 for FoodCardOpen
          String? imageBase64;
          try {
            imageBase64 = base64Encode(processedBytes);
          } catch (e) {
            print("Error encoding image: $e");
          }

          print(
              "API failed, but navigating to FoodCardOpen with default values");

          // Navigate to FoodCardOpen with default values
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FoodCardOpen(
                foodName: defaultName,
                healthScore: healthScore,
                calories: defaultCalories,
                protein: defaultProtein,
                fat: defaultFat,
                carbs: defaultCarbs,
                imageBase64: imageBase64,
                ingredients: defaultIngredients,
              ),
            ),
          ).then((_) {
            // Set _isAnalyzing to false only after returning from FoodCardOpen
            if (mounted) {
              setState(() {
                _isAnalyzing = false;
              });
            }
          });
        }
      }
    } catch (e) {
      print("Error analyzing image: $e");
      if (mounted) {
        // Try to use the image even if analysis completely fails
        try {
          Uint8List imageBytes;
          if (kIsWeb && _webImageBytes != null) {
            imageBytes = _webImageBytes!;
          } else if (_imageFile != null && !kIsWeb) {
            imageBytes = await _imageFile!.readAsBytes();
          } else if (image != null) {
            imageBytes = await image.readAsBytes();
          } else {
            throw Exception("No image available");
          }

          // Create a default food card with the image
          final String defaultName = "Unknown Food";
          final String defaultCalories = "0";
          final String defaultProtein = "0";
          final String defaultFat = "0";
          final String defaultCarbs = "0";
          final String healthScore = "5/10";
          final List<Map<String, dynamic>> defaultIngredients = [
            {'name': 'Unknown ingredients', 'amount': '0g', 'calories': 0}
          ];

          // Convert image to base64 for FoodCardOpen
          String? imageBase64 = base64Encode(imageBytes);

          print(
              "Analysis completely failed, but navigating to FoodCardOpen with default values");

          // Navigate to FoodCardOpen with default values
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FoodCardOpen(
                foodName: defaultName,
                healthScore: healthScore,
                calories: defaultCalories,
                protein: defaultProtein,
                fat: defaultFat,
                carbs: defaultCarbs,
                imageBase64: imageBase64,
                ingredients: defaultIngredients,
              ),
            ),
          ).then((_) {
            if (mounted) {
              setState(() {
                _isAnalyzing = false;
              });
            }
          });
        } catch (imageError) {
          // If we can't even get the image, show an error dialog
          print("Failed to process image: $imageError");
          setState(() {
            _isAnalyzing = false;
          });
          _showCustomDialog("Analysis Failed",
              "Failed to analyze the image. Please try again.");
        }
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      print("Opening image picker gallery...");
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        // Disable video selection by using pickImage not pickVideo
        // Note: ImagePicker.pickImage already only selects images
      );

      if (pickedFile != null) {
        print("Image file selected: ${pickedFile.path}");

        if (mounted) {
          if (kIsWeb) {
            // For web platform, read the bytes first
            print("Web platform: reading image bytes first");
            final bytes = await pickedFile.readAsBytes();
            print("Web image bytes read successfully: ${bytes.length} bytes");

            // Check file size - 15MB maximum
            if (bytes.length > 15 * 1024 * 1024) {
              _showCustomDialog("File Too Large",
                  "Image must be less than 15MB. Please select a smaller image.");
              return;
            }

            // Update state with both path and bytes
            setState(() {
              _webImagePath = pickedFile.path;
              _webImageBytes = bytes;
              _imageFile = null;
              _mostRecentImage = pickedFile;
            });

            // Only analyze after we have the bytes
            print("Web image loaded, starting analysis...");
            _analyzeImage(pickedFile);
          } else {
            // For mobile platforms
            final bytes = await pickedFile.readAsBytes();

            // Check file size - 15MB maximum
            if (bytes.length > 15 * 1024 * 1024) {
              _showCustomDialog("File Too Large",
                  "Image must be less than 15MB. Please select a smaller image.");
              return;
            }

            setState(() {
              _imageFile = File(pickedFile.path);
              _webImagePath = null;
              _webImageBytes = null;
              _mostRecentImage = pickedFile;
            });

            _analyzeImage(pickedFile);
          }

          print(
              "Image set to state: ${kIsWeb ? _webImagePath : _imageFile?.path}");
        } else {
          print("Widget not mounted, can't update state");
        }
      } else {
        print("No image selected from gallery");
      }
    } catch (e) {
      print("Error picking image: $e");

      if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
        // For desktop or web
        _showUnsupportedPlatformDialog();
      }
    }
  }

  Future<void> _takePicture() async {
    try {
      print("Opening camera...");

      // Check if camera is available using _cameraOnly method
      bool isCameraAvailable = await _cameraOnly();

      if (!isCameraAvailable) {
        print("Camera not available or permission denied");
        setState(() {
          _isAnalyzing = false;
        });
        return;
      }

      // Show loading state
      setState(() {
        _isAnalyzing = true;
      });

      // Try to access camera directly, with no gallery fallback
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        // Disable video by using pickImage not pickVideo
        // Additional parameters could be set here for image quality
      );

      if (pickedFile != null) {
        print("Photo taken: ${pickedFile.path}");

        if (mounted) {
          if (kIsWeb) {
            // For web platform, read the bytes first
            print("Web platform: reading image bytes first");
            final bytes = await pickedFile.readAsBytes();
            print(
                "Web camera image bytes read successfully: ${bytes.length} bytes");

            // Check file size - 15MB maximum
            if (bytes.length > 15 * 1024 * 1024) {
              _showCustomDialog("File Too Large",
                  "Image must be less than 15MB. Please take a smaller image or adjust your camera settings.");
              setState(() {
                _isAnalyzing = false;
              });
              return;
            }

            // Update state with both path and bytes
            setState(() {
              _webImagePath = pickedFile.path;
              _webImageBytes = bytes;
              _imageFile = null;
              _mostRecentImage = pickedFile;
            });

            // Analyze the image
            _analyzeImage(pickedFile);
          } else {
            // For mobile platforms
            final bytes = await pickedFile.readAsBytes();

            // Check file size - 15MB maximum
            if (bytes.length > 15 * 1024 * 1024) {
              _showCustomDialog("File Too Large",
                  "Image must be less than 15MB. Please take a smaller image or adjust your camera settings.");
              setState(() {
                _isAnalyzing = false;
              });
              return;
            }

            setState(() {
              _imageFile = File(pickedFile.path);
              _webImagePath = null;
              _webImageBytes = null;
              _mostRecentImage = pickedFile;
            });

            // Analyze the image
            _analyzeImage(pickedFile);
          }

          print(
              "Photo set to state: ${kIsWeb ? _webImagePath : _imageFile?.path}");
        } else {
          print("Widget not mounted, can't update state");
        }
      } else {
        print("No photo taken");
        setState(() {
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      print("Error taking picture: $e");
      setState(() {
        _isAnalyzing = false;
      });

      if (mounted) {
        _showCameraErrorDialog();
      }
    }
  }

  Future<bool> _cameraOnly() async {
    try {
      await _checkPermissionsSimple();

      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxHeight: 1000,
        maxWidth: 1000,
        imageQuality: 85, // Improved compression to ensure smaller file sizes
      );

      if (photo != null) {
        setState(() {
          _mostRecentImage = photo;
        });

        // Analyze the image directly here
        _analyzeImage(photo);
        return true;
      }
      return false;
    } catch (e) {
      print("Error picking image: $e");
      // Show error dialog instead of snackbar
      if (mounted) {
        _showCustomDialog("Error", "Failed to access camera: ${e.toString()}");
      }
      return false;
    }
  }

  // Simplified version that doesn't use missing libraries
  Future<String?> _getBase64FromPath(String path) async {
    try {
      // For web platform
      if (kIsWeb) {
        if (_webImageBytes != null) {
          return base64Encode(_webImageBytes!);
        } else {
          // Try to load from path for web
          final response = await http.get(Uri.parse(path));
          if (response.statusCode == 200) {
            return base64Encode(response.bodyBytes);
          } else {
            throw Exception('Failed to load image from URL');
          }
        }
      }
      // For mobile platforms
      else {
        final file = File(path);
        final bytes = await file.readAsBytes();

        // Simple size check
        if (bytes.length > 700000) {
          // Use our image compression helper
          final Uint8List result = await _compressBytesConsistently(
            bytes,
            quality: 80,
            targetWidth: 800,
          );
          return base64Encode(result);
        }

        return base64Encode(bytes);
      }
    } catch (e) {
      print("Error converting image to base64: $e");
      return null;
    }
  }

  Future<Uint8List> _compressImage(Uint8List imageBytes) async {
    try {
      print('Starting image compression process...');
      final double imageSizeMB = imageBytes.length / (1024 * 1024);
      print('Original image size: ${imageSizeMB.toStringAsFixed(2)} MB');

      // Target size of 0.7MB
      final int targetSizeBytes = 716800; // 0.7MB in bytes

      // If already smaller than 0.7MB, keep original
      if (imageBytes.length <= targetSizeBytes) {
        print('Image already under 0.7MB, preserving original quality');
        return imageBytes;
      }

      // Compress to exactly 0.7MB
      final Uint8List compressedImage = await compressImage(
        imageBytes,
        targetWidth: 1200, // Initial width
        quality: 90, // Initial quality
      );

      // Log results
      final double compressedSizeMB = compressedImage.length / (1024 * 1024);
      final double compressionRatio = imageSizeMB / compressedSizeMB;

      print('Image compression complete:');
      print('  - Original: ${imageSizeMB.toStringAsFixed(2)} MB');
      print('  - Compressed: ${compressedSizeMB.toStringAsFixed(2)} MB');
      print('  - Target: 0.7MB');
      print('  - Compression ratio: ${compressionRatio.toStringAsFixed(2)}x');

      return compressedImage;
    } catch (e) {
      print('Error during image compression: $e');
      return imageBytes; // Return original if compression fails
    }
  }

  void _displayAnalysisResults(Map<String, dynamic> analysisData) {
    try {
      print("\n----- FOOD ANALYSIS RESULTS -----");

      // NEW FORMAT: First check for the meal_name format which is our desired format
      if (analysisData.containsKey('meal_name')) {
        String mealName = analysisData['meal_name'];
        List<dynamic> ingredients = analysisData['ingredients'] ?? [];
        double calories =
            _extractDecimalValue(analysisData['calories']?.toString() ?? "0");
        double protein =
            _extractDecimalValue(analysisData['protein']?.toString() ?? "0");
        double fat =
            _extractDecimalValue(analysisData['fat']?.toString() ?? "0");
        double carbs =
            _extractDecimalValue(analysisData['carbs']?.toString() ?? "0");
        double vitaminC =
            _extractDecimalValue(analysisData['vitamin_c']?.toString() ?? "0");
        String healthScore = analysisData['health_score']?.toString() ?? "5/10";

        // Display in the format the user wants - with the exact format requested, adding "Name:" only in terminal output
        print("\n----- FOOD ANALYSIS RESULTS -----");
        print("Name: $mealName"); // Add "Name:" prefix only for terminal output
        String ingredientsText = ingredients.isNotEmpty
            ? ingredients.join(", ")
            : "Mixed ingredients";
        print("Ingredients: $ingredientsText");
        print(
            "Calories: ${calories.toInt()}kcal"); // Format as integer for terminal
        print("Protein: ${protein.toInt()}g");
        print("Fat: ${fat.toInt()}g");
        print("Carbs: ${carbs.toInt()}g");
        print("Vitamin C: ${vitaminC.toInt()}mg");

        // Extract and display additional nutritional information
        print("\n----- ADDITIONAL NUTRITIONAL INFORMATION -----");

        // Vitamins
        Map<String, dynamic> vitamins = analysisData['vitamins'] ?? {};
        if (vitamins.isNotEmpty) {
          print("VITAMINS:");
          vitamins.forEach((key, value) {
            String vitaminName = key;
            // Format vitamin A, B, C, D, E, K specially
            if (vitaminName.length == 1 ||
                (vitaminName.length == 2 && vitaminName.startsWith("B"))) {
              vitaminName = "Vitamin $vitaminName";
            }
            print(
                "  $vitaminName: ${_extractDecimalValue(value.toString())}${_getUnitForVitamin(key)}");
          });
        }

        // Minerals
        Map<String, dynamic> minerals = analysisData['minerals'] ?? {};
        if (minerals.isNotEmpty) {
          print("\nMINERALS:");
          minerals.forEach((key, value) {
            print(
                "  $key: ${_extractDecimalValue(value.toString())}${_getUnitForMineral(key)}");
          });
        }

        // Other nutrients - extract directly from response and always display
        print("\nOTHER NUTRIENTS:");
        Map<String, dynamic> otherNutrients = analysisData['other_nutrients'] ?? {};
        
        // Debug the raw data
        print("DEBUG - RAW OTHER NUTRIENTS DATA: $otherNutrients");
        
        // Always show these nutrients even if other_nutrients is empty
        final mandatoryNutrients = [
          {'key': 'fiber', 'label': 'Fiber', 'unit': 'g'},
          {'key': 'cholesterol', 'label': 'Cholesterol', 'unit': 'mg'},
          {'key': 'omega_3', 'label': 'Omega-3', 'unit': 'g'},
          {'key': 'omega_6', 'label': 'Omega-6', 'unit': 'g'},
          {'key': 'sodium', 'label': 'Sodium', 'unit': 'mg'},
          {'key': 'sugar', 'label': 'Sugar', 'unit': 'g'},
          {'key': 'saturated_fat', 'label': 'Saturated Fat', 'unit': 'g'}
        ];
        
        // First try to get values from other_nutrients map
        if (otherNutrients.isNotEmpty) {
          otherNutrients.forEach((key, value) {
            // Format key for display - convert snake_case to proper case
            String displayKey = key.split('_').map((word) => 
              word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1)
            ).join(' ');
            
            String unit = _getUnitForOtherNutrient(key);
            print("  $displayKey: ${_extractDecimalValue(value.toString())}$unit");
          });
        } 
        
        // If other_nutrients doesn't contain all expected values, check if they're in the root object
        bool foundMissingNutrients = false;
        for (var item in mandatoryNutrients) {
          final String key = item['key'] as String;
          final String label = item['label'] as String;
          final String unit = item['unit'] as String;
          
          // Skip if we already displayed this from other_nutrients
          if (otherNutrients.containsKey(key)) continue;
          
          // If it's in the root object, display it
          if (analysisData.containsKey(key)) {
            foundMissingNutrients = true;
            print("  $label: ${_extractDecimalValue(analysisData[key].toString())}$unit");
          } else {
            // If it's missing completely, show as 0
            print("  $label: 0$unit");
          }
        }

        print("Health Score: $healthScore");
        print(
            "TOTAL CALORIES: ${calories.toInt()}kcal"); // Format as integer for terminal
        print("---------------------------------\n");

        // Save the food card
        _saveFoodCardData(
            mealName,
            ingredientsText,
            calories.toString(),
            protein.toString(),
            fat.toString(),
            carbs.toString(),
            _processIngredients(ingredients, analysisData['ingredient_macros']),
            healthScore,
            analysisData['vitamins'], // Pass vitamins data
            analysisData['minerals'], // Pass minerals data
            analysisData['other_nutrients']); // Pass other nutrients data
            
        return; // Exit early as we've handled the new format
      }
    } catch (e) {
      print("Error displaying analysis results: $e");
    }
  }

  // Helper method to process ingredients list
  List<Map<String, dynamic>> _processIngredients(List<dynamic> ingredients, List<dynamic>? ingredientMacros) {
    List<Map<String, dynamic>> ingredientsList = [];
    
        for (int i = 0; i < ingredients.length; i++) {
      String ingredient = ingredients[i].toString();

          // Extract weight and calories if available
          final regex = RegExp(r'(.*?)\s*\((.*?)\)\s*(\d+)kcal');
      final match = regex.firstMatch(ingredient);

          Map<String, dynamic> ingredientData = {};

          if (match != null) {
        String ingredientName = match.group(1)?.trim() ?? ingredient;
            String weight = match.group(2) ?? "30g";
            int kcal = int.tryParse(match.group(3) ?? "75") ?? 75;

            ingredientData = {
              'name': ingredientName,
              'amount': weight,
              'calories': kcal,
            };
          } else {
            // Default values if no match
            ingredientData = {
          'name': ingredient,
              'amount': "30g",
              'calories': 75,
            };
          }

          // Add macronutrient data if available
      if (ingredientMacros != null && i < ingredientMacros.length && ingredientMacros[i] is Map) {
        Map<String, dynamic> macros = Map<String, dynamic>.from(ingredientMacros[i]);

        // Add protein, fat, and carbs
            if (macros.containsKey('protein')) {
              var proteinValue = macros['protein'];
          ingredientData['protein'] = (proteinValue is num) 
              ? proteinValue.toDouble() 
              : double.tryParse(proteinValue.toString()) ?? 0.0;
            } else {
              ingredientData['protein'] = 0.0;
            }

            if (macros.containsKey('fat')) {
              var fatValue = macros['fat'];
          ingredientData['fat'] = (fatValue is num) 
              ? fatValue.toDouble() 
              : double.tryParse(fatValue.toString()) ?? 0.0;
            } else {
              ingredientData['fat'] = 0.0;
            }

        if (macros.containsKey('carbs') || macros.containsKey('carbohydrates')) {
              var carbsValue = macros['carbs'] ?? macros['carbohydrates'];
          ingredientData['carbs'] = (carbsValue is num) 
              ? carbsValue.toDouble() 
              : double.tryParse(carbsValue.toString()) ?? 0.0;
              } else {
                ingredientData['carbs'] = 0.0;
              }
            } else {
        // If no specific macros data, set defaults
        ingredientData['protein'] = 3.0;
        ingredientData['fat'] = 2.0;
        ingredientData['carbs'] = 10.0;
          }

          ingredientsList.add(ingredientData);
        }

    return ingredientsList;
  }

  // Helper method to get the appropriate unit for other nutrients
  String _getUnitForOtherNutrient(String nutrient) {
    switch (nutrient.toLowerCase()) {
      case 'fiber':
      case 'sugar':
      case 'omega_3':
      case 'omega_6':
      case 'saturated_fat':
        return 'g';
      case 'cholesterol':
      case 'sodium':
        return 'mg';
      default:
        return '';
    }
  }

  // Save food card data to SharedPreferences
  Future<void> _saveFoodCardData(
      String foodName,
      String ingredients,
      String calories,
      String protein,
      String fat,
      String carbs,
      List<Map<String, dynamic>> ingredientsList,
      [String healthScore = "5/10",
      Map<String, dynamic>? vitamins,
      Map<String, dynamic>? minerals,
      Map<String, dynamic>? otherNutrients]) async {

      // Create food card data - store raw values with decimal precision
      final Map<String, dynamic> foodCard = {
        'name': foodName.isNotEmpty ? foodName : 'Analyzed Meal',
        'calories':
            calories, // Store original calories string with decimal places
        'protein': protein, // Use original protein value
        'fat': fat, // Use original fat value
        'carbs': carbs, // Use original carbs value
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'image': base64Image,
        'ingredients':
            ingredientsList, // Store full ingredient objects, not just names
        'health_score': healthScore, // Store health score in the food card
        'vitamins': vitamins ?? {}, // Store vitamins data
        'minerals': minerals ?? {}, // Store minerals data
        'other_nutrients': otherNutrients ?? {}, // Store other nutrients data
      };

      // Try to persist the data to SharedPreferences
      try {
      final prefs = await SharedPreferences.getInstance();
        List<String> foodCards = prefs.getStringList('food_cards') ?? [];
        
        // Add new food card to the list
        foodCards.add(jsonEncode(foodCard));
        
        // Save updated list back to SharedPreferences
        await prefs.setStringList('food_cards', foodCards);
        print('Food card saved successfully!');
          } catch (e) {
        print('Error saving food card: $e');
      }

      // Always navigate to FoodCardOpen regardless of save success
      // This ensures we move to the next screen even if storage is full
      if (mounted) {
        // Create a new route to FoodCardOpen
        final route = MaterialPageRoute(
            builder: (context) => FoodCardOpen(
              foodName: foodName,
              healthScore: healthScore,
              calories: calories.toString(),
              protein: protein.toString(),
              fat: fat.toString(),
              carbs: carbs.toString(),
              imageBase64: highQualityImageBase64 ?? base64Image,
              ingredients: ingredientsList, // Pass ingredients list
            vitamins: vitamins, // Pass vitamins data
            minerals: minerals, // Pass minerals data
            otherNutrients: otherNutrients, // Pass other nutrients data
          ),
        );
        
        // Push the route and set _isAnalyzing to false when returning
        Navigator.of(context).push(route).then((_) {
          if (mounted) {
            setState(() {
              _isAnalyzing = false;
            });
          }
        });
      }
    }

  // Helper method to get the appropriate unit for other nutrients
  String _getUnitForOtherNutrient(String nutrient) {
    switch (nutrient.toLowerCase()) {
      case 'fiber':
      case 'sugar':
      case 'omega_3':
      case 'omega_6':
      case 'saturated_fat':
        return 'g';
      case 'cholesterol':
      case 'sodium':
      return 'mg';
      default:
        return '';
    }
  }
