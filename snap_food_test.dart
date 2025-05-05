import 'dart:convert';

void main() {
  // This is a direct copy of the response seen in the terminal log
  final apiResponse = 
    '{meal_name: Pepperoni and Ham Pizza, ingredients: [Pizza Dough (200g) 530kcal, Tomato Sauce (50g) 30kcal, Mozzarella Cheese (100g) 280kcal, Pepperoni(50g) 250kcal, Ham (50g) 70kcal], ingredient_macros: [{protein: 12, fat: 2, carbs: 104}, {protein: 1, fat: 0, carbs: 7}, {protein: 18, fat: 22, carbs: 2}, {protein: 10, fat: 22, carbs: 1}, {protein: 10, fat: 3, carbs: 1}], calories: 1160, protein: 51, fat: 49, carbs: 115, health_score: 6/10, vitamins: {vitamin_a:500, vitamin_c: 10, vitamin_d: 0.5, vitamin_e: 1.5, vitamin_k: 15, vitamin_b1: 0.6, vitamin_b2: 0.7, vitamin_b3: 5, vitamin_b5: 1.5, vitamin_b6: 0.6, vitamin_b7: 10, vitamin_b9: 50, vitamin_b12: 1.5}, minerals: {calcium: 400, chloride: 1500, chromium: 0, copper: 0.2, fluoride: 0, iodine: 30, iron: 5, magnesium: 50, manganese: 0.5, molybdenum: 0, phosphorus: 400, potassium: 500, selenium: 30, sodium: 2000, zinc: 4}, other_nutrients: {fiber: 5, cholesterol: 100, omega_3: 0.2, omega_6: 2, sodium: 2000, sugar: 5, saturated_fat: 20}}';

  // First, directly extract other nutrients using regex for reliability
  print("STARTING DIRECT OTHER NUTRIENTS EXTRACTION...\n");
  extractOtherNutrients(apiResponse);
}

void extractOtherNutrients(String apiResponse) {
  // Extract the other_nutrients section using regex
  final regex = RegExp(r'other_nutrients:\s*{([^}]*)}');
  final match = regex.firstMatch(apiResponse);
  
  if (match != null && match.groupCount >= 1) {
    String otherNutrientsStr = match.group(1) ?? '';
    print("Raw other_nutrients string: $otherNutrientsStr");
    
    // Extract key-value pairs
    final pairsRegex = RegExp(r'(\w+):\s*([^,}]+)');
    final pairs = pairsRegex.allMatches(otherNutrientsStr);
    
    print("\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
    print("!!!! MANUALLY EXTRACTED OTHER NUTRIENTS !!!!");
    print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n");
    
    print("OTHER NUTRIENTS:");
    
    // Process each pair
    for (var pair in pairs) {
      if (pair.groupCount >= 2) {
        String key = pair.group(1) ?? '';
        String valueStr = pair.group(2)?.trim() ?? '';
        
        // Format output based on key
        String unit = '';
        if (key == 'fiber' || key == 'sugar' || key == 'omega_3' || 
            key == 'omega_6' || key == 'saturated_fat') {
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
          String formattedKey = key.replaceAll('_', ' ');
          formattedKey = formattedKey.substring(0, 1).toUpperCase() + formattedKey.substring(1);
          print("  $formattedKey: $valueStr$unit");
        }
      }
    }
    
    print("\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
    print("!!!! END MANUALLY EXTRACTED OTHER NUTRIENTS !!!!");
    print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n");
  } else {
    print("Could not extract other_nutrients from response");
  }
} 