const fetch = require('node-fetch');

// Mock test for other nutrients formatting

// Simulate the API response we saw in the logs
const mockData = {
  success: true,
  data: {
    meal_name: "Pepperoni and Ham Pizza",
    ingredients: ["Pizza Dough (200g) 530kcal", "Tomato Sauce (50g) 30kcal", "Mozzarella Cheese (100g) 280kcal"],
    calories: 1160,
    protein: 51,
    fat: 49,
    carbs: 115,
    health_score: "6/10",
    vitamins: {
      vitamin_a: 500,
      vitamin_c: 10,
      vitamin_d: 0.5,
      vitamin_e: 1.5,
      vitamin_k: 15
    },
    minerals: {
      calcium: 400,
      chloride: 1500,
      iron: 5,
      magnesium: 50,
      sodium: 2000,
      zinc: 4
    },
    other_nutrients: {
      fiber: 5,
      cholesterol: 100,
      omega_3: 0.2,
      omega_6: 2,
      sodium: 2000,
      sugar: 5,
      saturated_fat: 20
    }
  }
};

// Simulate the food analysis response processing
function testOtherNutrients() {
  try {
    console.log('Testing simulated food analysis response...');
    
    const data = mockData;
    
    // Check if the response was successful
    if (data.success) {
      console.log('\n----- FOOD ANALYSIS RESULTS -----');
      console.log('Name:', data.data.meal_name);
      console.log('Calories:', data.data.calories);
      console.log('Protein:', data.data.protein + 'g');
      console.log('Fat:', data.data.fat + 'g');
      console.log('Carbs:', data.data.carbs + 'g');
      
      console.log('\n----- ADDITIONAL NUTRITIONAL INFORMATION -----');
      
      // Print vitamins section
      console.log('\nVITAMINS:');
      for (const [key, value] of Object.entries(data.data.vitamins)) {
        console.log(`  ${key}: ${value}mg`);
      }
      
      // Print minerals section
      console.log('\nMINERALS:');
      for (const [key, value] of Object.entries(data.data.minerals)) {
        console.log(`  ${key}: ${value}mg`);
      }
      
      // Print other nutrients section with super obvious markers
      console.log('\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
      console.log('!!!! OTHER NUTRIENTS SECTION !!!!!!!!');
      console.log('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n');
      
      console.log('OTHER NUTRIENTS:');
      if (data.data.other_nutrients) {
        const otherNuts = data.data.other_nutrients;
        console.log('  Fiber:         ' + (otherNuts.fiber || 0) + 'g');
        console.log('  Cholesterol:   ' + (otherNuts.cholesterol || 0) + 'mg');
        console.log('  Omega-3:       ' + (otherNuts.omega_3 || 0) + 'g');
        console.log('  Omega-6:       ' + (otherNuts.omega_6 || 0) + 'g');
        console.log('  Sodium:        ' + (otherNuts.sodium || 0) + 'mg');
        console.log('  Sugar:         ' + (otherNuts.sugar || 0) + 'g');
        console.log('  Saturated Fat: ' + (otherNuts.saturated_fat || 0) + 'g');
        
        // Print raw data for comparison
        console.log('\nRaw other_nutrients data:');
        console.log(otherNuts);
        
        // Show key-value pairs for debugging
        console.log('\nDEBUG EACH KEY-VALUE:');
        for (const [key, value] of Object.entries(otherNuts)) {
          console.log(`  Key: "${key}" = Value: "${value}" (${typeof value})`);
        }
      }
      
      console.log('\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
      console.log('!!!! END OTHER NUTRIENTS SECTION !!!!');
      console.log('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n');
      
      console.log('Health Score:', data.data.health_score);
    } else {
      console.error('API request would fail:', data.error || 'Unknown error');
    }
  } catch (error) {
    console.error('Error in test:', error);
  }
}

// Run the test
testOtherNutrients(); 