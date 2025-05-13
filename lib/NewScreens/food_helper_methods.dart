// A collection of helper methods for food-related functionality
// These methods are used in FoodCardOpen.dart and other food-related screens

import 'dart:math';

// Helper method to extract numeric values from different possible field names
double extractNumericValue(
    Map<String, dynamic> data, List<String> possibleKeys) {
  for (var key in possibleKeys) {
    if (data.containsKey(key)) {
      var value = data[key];
      if (value is num) {
        return value.toDouble();
      } else if (value is String) {
        // Try to extract numeric portion from strings like "150 kcal"
        final numericMatch = RegExp(r'(\d+\.?\d*)').firstMatch(value);
        if (numericMatch != null) {
          return double.tryParse(numericMatch.group(1) ?? '0') ?? 0.0;
        }
      } else if (value is Map && value.containsKey('amount')) {
        var amount = value['amount'];
        if (amount is num) return amount.toDouble();
        if (amount is String) return double.tryParse(amount) ?? 0.0;
      }
    }
  }
  return 0.0;
}

// Helper method to parse nutrition value from various formats
double parseNutritionValue(dynamic value) {
  if (value == null) return 0;

  if (value is int) {
    return value.toDouble();
  } else if (value is double) {
    return value;
  } else if (value is String) {
    return double.tryParse(value) ?? 0;
  }

  return 0;
}

// Helper method to format ingredient calories
String formatIngredientCalories(dynamic calories) {
  if (calories == null) return "0 kcal";

  // If it's already a string, ensure it has "kcal" suffix
  if (calories is String) {
    // Try to parse the string to a number to remove decimal points
    try {
      double calValue = double.parse(calories.replaceAll("kcal", "").trim());
      // Round to a whole number
      int roundedCal = calValue.round();
      return "$roundedCal kcal";
    } catch (e) {
      // If parsing fails, just ensure it has kcal suffix
      return calories.contains("kcal") ? calories : "$calories kcal";
    }
  }

  // If it's a number, convert to whole number string with "kcal" suffix
  if (calories is num) {
    return "${calories.round()} kcal";
  }

  // Fallback for any other type
  return "$calories kcal";
}

// Helper method to format numeric values without decimal places
String formatNumericValue(dynamic input) {
  if (input is int) {
    // Return integer value as is
    return input.toString();
  } else if (input is double) {
    // Convert to integer to remove decimal places
    return input.toInt().toString();
  } else if (input is String) {
    // Try to extract digits from the string, including decimal values
    final match = RegExp(r'(\d+\.?\d*)').firstMatch(input);
    if (match != null && match.group(1) != null) {
      // Convert to double then integer to remove decimals
      double value = double.tryParse(match.group(1)!) ?? 0.0;
      return value.toInt().toString();
    }
  }
  return "0"; // Return string "0" as fallback (without decimal)
}

// Helper method to format decimal values with one decimal place
String formatDecimalValue(dynamic input) {
  if (input == null) return "0";

  double value = 0.0;

  if (input is num) {
    value = input.toDouble();
  } else if (input is String) {
    value = double.tryParse(input) ?? 0.0;
  }

  // Format with one decimal place
  return value.toStringAsFixed(1);
}

// Helper function to estimate calories based on food name and serving size
double estimateCaloriesForFood(String foodName, String servingSize) {
  // Default calories if we can't make a better estimate
  double baseCalories = 250.0;

  // Extract serving size in grams if available
  double grams = 100.0; // Default to 100g if not specified
  final gramsMatch = RegExp(r'(\d+)g').firstMatch(servingSize);
  if (gramsMatch != null && gramsMatch.group(1) != null) {
    grams = double.tryParse(gramsMatch.group(1)!) ?? 100.0;
  }

  // Scale factor based on serving size
  double sizeFactor = grams / 100.0;

  // Food type detection
  String lowercaseName = foodName.toLowerCase();

  // Estimate based on food type
  if (lowercaseName.contains('salad')) {
    baseCalories = 50.0;
  } else if (lowercaseName.contains('soup')) {
    baseCalories = 120.0;
  } else if (lowercaseName.contains('chicken') ||
      lowercaseName.contains('beef') ||
      lowercaseName.contains('meat')) {
    baseCalories = 200.0;
  } else if (lowercaseName.contains('pasta') ||
      lowercaseName.contains('rice')) {
    baseCalories = 300.0;
  } else if (lowercaseName.contains('cake') ||
      lowercaseName.contains('dessert') ||
      lowercaseName.contains('chocolate')) {
    baseCalories = 350.0;
  } else if (lowercaseName.contains('fruit')) {
    baseCalories = 80.0;
  } else if (lowercaseName.contains('vegetable')) {
    baseCalories = 40.0;
  }

  // Apply serving size factor
  return baseCalories * sizeFactor;
}

// Helper to extract vitamins from nutrition data
void extractVitaminsFromData(
    Map<String, dynamic> nutritionData, Map<String, dynamic> result) {
  // Define mapping of possible API keys to vitamin names
  final vitaminMappings = {
    'vitamin_a': 'vitamin_a',
    'vitamin_c': 'vitamin_c',
    'vitamin_d': 'vitamin_d',
    'vitamin_e': 'vitamin_e',
    'vitamin_k': 'vitamin_k',
    'vitamin_b1': 'vitamin_b1',
    'thiamin': 'vitamin_b1',
    'vitamin_b2': 'vitamin_b2',
    'riboflavin': 'vitamin_b2',
    'vitamin_b3': 'vitamin_b3',
    'niacin': 'vitamin_b3',
    'vitamin_b5': 'vitamin_b5',
    'pantothenic_acid': 'vitamin_b5',
    'vitamin_b6': 'vitamin_b6',
    'pyridoxine': 'vitamin_b6',
    'vitamin_b7': 'vitamin_b7',
    'biotin': 'vitamin_b7',
    'vitamin_b9': 'vitamin_b9',
    'folate': 'vitamin_b9',
    'folic_acid': 'vitamin_b9',
    'vitamin_b12': 'vitamin_b12',
    'cobalamin': 'vitamin_b12',
  };

  // Loop through nutrition data keys and extract vitamins
  nutritionData.forEach((key, value) {
    // Convert key to lowercase for case-insensitive matching
    String keyLower = key.toLowerCase();

    // Check if this key is a vitamin we're interested in
    if (vitaminMappings.containsKey(keyLower)) {
      String standardizedName = vitaminMappings[keyLower]!;

      // Add to result with the standardized name
      result[standardizedName] = value;
    } else {
      // Check if the key contains any of our vitamin names
      for (var vitKey in vitaminMappings.keys) {
        if (keyLower.contains(vitKey)) {
          String standardizedName = vitaminMappings[vitKey]!;
          result[standardizedName] = value;
          break;
        }
      }
    }
  });
}
