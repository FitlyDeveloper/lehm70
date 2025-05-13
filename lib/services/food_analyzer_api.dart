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

      // Call our secure API endpoint with improved parameters
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
              'calculate_micronutrients': true,
              'include_nutrients': true,
            }),
          )
          .timeout(const Duration(
              seconds: 60)); // Increased timeout for more detailed analysis

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
        print('Keys in data: ${(responseData['data'] as Map).keys.join(', ')}');

        // Enhanced logging for nutrition data debug
        if ((responseData['data'] as Map).containsKey('nutrition')) {
          print('Nutrition data found in response');
        }
        if ((responseData['data'] as Map).containsKey('ingredients')) {
          print(
              'Ingredients list found in response: ${(responseData['data']['ingredients'] as List?)?.length ?? 0} ingredients');

          // Check if ingredients have nutrition data
          final ingredients = responseData['data']['ingredients'] as List?;
          if (ingredients != null && ingredients.isNotEmpty) {
            final firstIngredient = ingredients.first;
            if (firstIngredient is Map &&
                firstIngredient.containsKey('nutrition')) {
              print('Ingredients include nutrition data');
            }
          }
        }
      }

      // Make sure data is returned as is without any transformation that might lose information
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
