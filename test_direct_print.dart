import 'dart:convert';
import 'dart:io';

void main() async {
  // Mock nutritional data similar to what we'd get from the API
  final mockResponse = {
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
      "vitamin_e": 1.5,
      "vitamin_k": 15,
      "vitamin_b1": 0.6,
      "vitamin_b2": 0.7,
      "vitamin_b3": 5
    },
    "minerals": {
      "calcium": 400,
      "chloride": 1500,
      "iron": 5,
      "magnesium": 50,
      "sodium": 2000,
      "zinc": 4
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

  // Print the raw response
  print("API Response: ${jsonEncode(mockResponse)}");

  // Extract other_nutrients
  Map<String, dynamic> otherNuts = mockResponse['other_nutrients'] != null
      ? Map<String, dynamic>.from(mockResponse['other_nutrients'] as Map)
      : {};

  // Print other nutrients in the desired format
  print("\n===== FORMATTED OTHER NUTRIENTS =====");
  print("  Fiber:         ${otherNuts['fiber'] ?? 0}g");
  print("  Cholesterol:   ${otherNuts['cholesterol'] ?? 0}mg");
  print("  Omega-3:       ${otherNuts['omega_3'] ?? 0}g");
  print("  Omega-6:       ${otherNuts['omega_6'] ?? 0}g");
  print("  Sodium:        ${otherNuts['sodium'] ?? 0}mg");
  print("  Sugar:         ${otherNuts['sugar'] ?? 0}g");
  print("  Saturated Fat: ${otherNuts['saturated_fat'] ?? 0}g");

  // Raw data check
  print("\nRaw other_nutrients data: $otherNuts");

  // Check the keys format
  print("\nKeys in other_nutrients: ${otherNuts.keys.join(', ')}");

  // Check for any transformation issues
  print("\nSanity check:");
  otherNuts.forEach((key, value) {
    print("  $key: $value (${value.runtimeType})");
  });
}
