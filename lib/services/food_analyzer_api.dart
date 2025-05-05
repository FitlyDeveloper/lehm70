import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class FoodAnalyzerApi {
  // Base URL of our Render.com API server
  static const String baseUrl = 'https://snap-food.onrender.com';

  // Endpoint for food analysis
  static const String analyzeEndpoint = '/api/analyze-food';

  // Method to analyze a food image
  static Future<Map<String, dynamic>> analyzeFoodImage(
      Uint8List imageBytes) async {
    try {
      // Convert image bytes to base64
      final String base64Image = base64Encode(imageBytes);
      final String dataUri = 'data:image/jpeg;base64,$base64Image';

      print('Calling API endpoint: $baseUrl$analyzeEndpoint');

      // Call our secure API endpoint
      final response = await http
          .post(
            Uri.parse('$baseUrl$analyzeEndpoint'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'image': dataUri,
              'detail_level': 'high',
              'include_ingredient_macros': true,
              'return_ingredient_nutrition': true,
              'include_additional_nutrition': true,
              'include_vitamins_minerals': true,
            }),
          )
          .timeout(const Duration(seconds: 30));

      // Check for HTTP errors
      if (response.statusCode != 200) {
        print('API error: ${response.statusCode}, ${response.body}');
        throw Exception('Failed to analyze image: ${response.statusCode}');
      }

      // Parse the response
      final Map<String, dynamic> responseData = jsonDecode(response.body);

      // Check for API-level errors
      if (responseData['success'] != true) {
        throw Exception('API error: ${responseData['error']}');
      }

      // If we got here, confirm that we received the expected format
      print(
          'API response format: ${responseData['data'] is Map ? 'Map' : 'Other type'}');
      if (responseData['data'] is Map) {
        print('Keys in data: ${responseData['data'].keys.join(', ')}');

        // Check for vitamins and minerals
        if (responseData['data'].containsKey('vitamins')) {
          print('Vitamins detected in API response');
        }

        if (responseData['data'].containsKey('minerals')) {
          print('Minerals detected in API response');
        }

        // Add direct logging of other_nutrients section
        if (responseData['data'].containsKey('other_nutrients')) {
          print('\n===== OTHER NUTRIENTS SECTION FROM API =====');
          final otherNuts = responseData['data']['other_nutrients'];

          // Format each nutrient with proper capitalization and aligned values
          print('  Fiber:         ${otherNuts['fiber'] ?? 0}g');
          print('  Cholesterol:   ${otherNuts['cholesterol'] ?? 0}mg');
          print('  Omega-3:       ${otherNuts['omega_3'] ?? 0}g');
          print('  Omega-6:       ${otherNuts['omega_6'] ?? 0}g');
          print('  Sodium:        ${otherNuts['sodium'] ?? 0}mg');
          print('  Sugar:         ${otherNuts['sugar'] ?? 0}g');
          print('  Saturated Fat: ${otherNuts['saturated_fat'] ?? 0}g');
          print('=======================================\n');
        } else {
          print('WARNING: No other_nutrients found in API response!');
        }
      }

      // Return the data
      return responseData['data'];
    } catch (e) {
      print('Error analyzing food image: $e');
      rethrow;
    }
  }

  // Check if the API is available
  static Future<bool> checkApiAvailability() async {
    try {
      final response = await http
          .get(Uri.parse(baseUrl))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('API unavailable: $e');
      return false;
    }
  }
}
