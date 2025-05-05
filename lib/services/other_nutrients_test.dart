import 'dart:convert';

void main() {
  // Create a mock response similar to what we'd get from the API
  final Map<String, dynamic> mockResponse = {
    "meal_name": "Test Pizza",
    "calories": 1160,
    "protein": 51,
    "fat": 49,
    "carbs": 115,
    "health_score": "6/10",
    "vitamins": {
      "vitamin_a": 500,
      "vitamin_c": 10,
      "vitamin_d": 0.5,
    },
    "minerals": {
      "calcium": 400,
      "iron": 5,
      "sodium": 2000,
    },
    "other_nutrients": {
      "fiber": 5,
      "cholesterol": 100,
      "omega_3": 0.2,
      "omega_6": 2,
      "sodium": 2000,
      "sugar": 5,
      "saturated_fat": 20
    }
  };

  print('Starting OTHER NUTRIENTS test...');

  // Extract and print other_nutrients
  try {
    print("\n===== APPROACH 1: Direct Map Access =====");
    Map<String, dynamic> otherNutrients = {};

    if (mockResponse.containsKey('other_nutrients')) {
      otherNutrients =
          Map<String, dynamic>.from(mockResponse['other_nutrients']);

      print("OTHER NUTRIENTS:");
      print("  Fiber:         ${otherNutrients['fiber'] ?? 0}g");
      print("  Cholesterol:   ${otherNutrients['cholesterol'] ?? 0}mg");
      print("  Omega-3:       ${otherNutrients['omega_3'] ?? 0}g");
      print("  Omega-6:       ${otherNutrients['omega_6'] ?? 0}g");
      print("  Sodium:        ${otherNutrients['sodium'] ?? 0}mg");
      print("  Sugar:         ${otherNutrients['sugar'] ?? 0}g");
      print("  Saturated Fat: ${otherNutrients['saturated_fat'] ?? 0}g");

      print("\nRaw data: $otherNutrients");
    } else {
      print("No other_nutrients found in the response");
    }

    print("\n===== APPROACH 2: String Parsing =====");
    final responseStr = jsonEncode(mockResponse);

    // Extract the other_nutrients section using regex
    final regex = RegExp(r'"other_nutrients"\s*:\s*{([^}]*)}');
    final match = regex.firstMatch(responseStr);

    if (match != null && match.groupCount >= 1) {
      String otherNutrientsStr = match.group(1) ?? '';
      print("Raw other_nutrients string: $otherNutrientsStr");

      // Extract key-value pairs
      final pairsRegex = RegExp(r'"(\w+)"\s*:\s*([^,}]+)');
      final pairs = pairsRegex.allMatches(otherNutrientsStr);

      print("\nOTHER NUTRIENTS (from regex):");

      // Process each pair
      for (var pair in pairs) {
        if (pair.groupCount >= 2) {
          String key = pair.group(1) ?? '';
          String valueStr = pair.group(2)?.trim() ?? '';

          // Format output based on key
          String unit = '';
          if (key == 'fiber' ||
              key == 'sugar' ||
              key == 'omega_3' ||
              key == 'omega_6' ||
              key == 'saturated_fat') {
            unit = 'g';
          } else if (key == 'cholesterol' || key == 'sodium') {
            unit = 'mg';
          }

          // Format output with proper spacing
          if (key == 'fiber') {
            print("  Fiber:         $valueStr$unit");
          } else if (key == 'cholesterol') {
            print("  Cholesterol:   $valueStr$unit");
          } else if (key == 'omega_3') {
            print("  Omega-3:       $valueStr$unit");
          } else if (key == 'omega_6') {
            print("  Omega-6:       $valueStr$unit");
          } else if (key == 'sodium') {
            print("  Sodium:        $valueStr$unit");
          } else if (key == 'sugar') {
            print("  Sugar:         $valueStr$unit");
          } else if (key == 'saturated_fat') {
            print("  Saturated Fat: $valueStr$unit");
          } else {
            print("  $key: $valueStr$unit");
          }
        }
      }
    } else {
      print("Could not extract other_nutrients from string");
    }

    print("\n===== APPROACH 3: Super Basic =====");
    print("OTHER NUTRIENTS (hardcoded):");
    print("  Fiber:         5g");
    print("  Cholesterol:   100mg");
    print("  Omega-3:       0.2g");
    print("  Omega-6:       2g");
    print("  Sodium:        2000mg");
    print("  Sugar:         5g");
    print("  Saturated Fat: 20g");
  } catch (e) {
    print("Error testing other_nutrients: $e");
  }
}
