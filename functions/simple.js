const functions = require('firebase-functions');
const fetch = require('node-fetch');

// Helper for analyzing an food image using OpenAI API
exports.analyzeFoodImageImpl = async (imageData, apiKey) => {
  try {
    console.log('Analyzing food image...');
    
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`
      },
      body: JSON.stringify({
        'model': 'gpt-4o',
        'messages': [
          {
            'role': 'system',
            'content': '[STRICTLY JSON ONLY] You are a nutrition expert analyzing food images. OUTPUT MUST BE VALID JSON AND NOTHING ELSE.\n\n[CRITICAL NUMBER FORMATTING RULES]\nYou MUST generate integer nutritional values where the LAST DIGIT (ones place) follows these strict requirements:\n- The last digits MUST be distributed across all digits 0-9\n- For each set of 10 analyses, each digit 0-9 should appear roughly equal number of times\n- NEVER favor any specific digit (like 0 or 5) in the last position\n- DO NOT generate multiple values ending with the same digit within a single response\n- Example correct distribution: 127, 348, 456, 219, 583, 670, 361, 792, 904, 615\n- Example incorrect distribution: 130, 150, 230, 300, 450, 500, 600 (too many 0s)\n\nFORMAT RULES:\n1. Return a single meal name for the entire image (e.g., "Pasta Meal")\n2. List ingredients with weights and calories (e.g., "Pasta (100g) 200kcal")\n3. Return PRECISE WHOLE NUMBER values with DIVERSE ending digits as described above\n4. Calculate a health score (1-10) based on ingredient quality and nutritional value\n\nHEALTH SCORE CRITERIA:\n• Positive indicators (+): Whole/unprocessed foods, healthy fats, high fiber foods\n• Negative indicators (-): Highly processed/fried ingredients, added sugars, high saturated fats\n• Score meaning: 9-10 (Very healthy), 7-8 (Healthy), 5-6 (Moderate), 3-4 (Unhealthy), 1-2 (Very unhealthy)\n\nYOU WILL BE PENALIZED SEVERELY IF YOU GENERATE VALUES WITH UNNATURAL DISTRIBUTIONS OF ENDING DIGITS.\n\nEXACT FORMAT REQUIRED:\n{\n  "meal_name": "Meal Name",\n  "ingredients": ["Item1 (weight) calories", "Item2 (weight) calories"],\n  "calories": integer with random last digit,\n  "protein": integer with random last digit (different from calories),\n  "fat": integer with random last digit (different from protein and calories),\n  "carbs": integer with random last digit (different from other values),\n  "vitamin_c": integer with random last digit (different from other values),\n  "health_score": "score/10"\n}'
          },
          {
            'role': 'user',
            'content': [
              { 'type': 'text', 'text': "RETURN ONLY RAW JSON. Analyze this food image with the MOST PRECISE values possible. Each nutritional value MUST have a different last digit (ones place). Do not use the same last digit twice. Make sure to include all digits 0-9 across different analyses.\n\n{\n  \"meal_name\": string (single name for entire meal),\n  \"ingredients\": array of strings with weights and calories,\n  \"calories\": integer with random last digit (NOT ending in 0 or 5),\n  \"protein\": integer with random last digit (must differ from calories),\n  \"fat\": integer with random last digit (must differ from protein and calories),\n  \"carbs\": integer with random last digit (must differ from other values),\n  \"vitamin_c\": integer with random last digit (must differ from other values),\n  \"health_score\": string\n}" },
              { 'type': 'image_url', 'image_url': { 'url': imageData } }
            ]
          }
        ],
        'max_tokens': 1000,
        'temperature': 0.9,
        'response_format': { 'type': 'json_object' }
      })
    });
    
    if (!response.ok) {
      throw new Error(`API error: ${response.status}`);
    }
    
    const result = await response.json();
    return result.choices[0].message.content;
  } catch (error) {
    console.error('Error analyzing food image:', error);
    throw error;
  }
}

// Simple ping function for status checking
async function pingFunction() {
  return 'pong';
}

// Parse the JSON from OpenAI response
function parseResult(content) {
  try {
    // First try direct parsing
    const jsonData = JSON.parse(content);
    
    // Check if we have a properly formatted JSON with meal_name
    if (jsonData.meal_name) {
      return jsonData;
    } else {
      // The JSON is not in the right format, try to fix it
      return transformToRequiredFormat(jsonData);
    }
  } catch (error1) {
    // Look for JSON in markdown blocks
    const match = content.match(/```(?:json)?\s*([\s\S]*?)\s*```/) || content.match(/\{[\s\S]*\}/);
    if (match) {
      try {
      const jsonText = match[0].replace(/```json\n|```/g, '').trim();
        const jsonData = JSON.parse(jsonText);
        
        // Check if we have a properly formatted JSON with meal_name
        if (jsonData.meal_name) {
          return jsonData;
        } else {
          // The JSON is not in the right format, try to fix it
          return transformToRequiredFormat(jsonData);
        }
      } catch (error2) {
        // JSON parsing failed, apply text transformation
        return transformToRequiredFormat({ text: content });
      }
    }
    // Fall back to returning transformed text
    return transformToRequiredFormat({ text: content });
  }
}

// Transform any response into our required format
function transformToRequiredFormat(data) {
  // If the data is in the old format (with Food item 1, Food item 2, etc.)
  if (data.text && data.text.includes('FOOD ANALYSIS RESULTS')) {
    const lines = data.text.split('\n');
    const ingredients = [];
    let calories = 0;
    let protein = 0;
    let fat = 0;
    let carbs = 0;
    let vitaminC = 0;
    let mealName = "Mixed Meal";
    
    // Extract meal name from the first food item if available
    for (let i = 0; i < lines.length; i++) {
      if (lines[i].includes('Food item 1:')) {
        mealName = lines[i].replace('Food item 1:', '').trim();
        break;
      }
    }
    
    // Process each line for ingredients and nutrition values
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim();
      
      if (line.startsWith('Ingredients:')) {
        const ingredientsText = line.replace('Ingredients:', '').trim();
        const ingredientParts = ingredientsText.split(',');
        
        for (const part of ingredientParts) {
          let ingredient = part.trim();
          if (ingredient.includes('(') && ingredient.includes(')')) {
            ingredients.push(ingredient);
          } else {
            // Estimate weight and calories if not provided
            ingredients.push(`${ingredient} (15g) 30kcal`);
          }
        }
      }
      
      if (line.startsWith('Calories:')) {
        const calValue = parseFloat(line.replace('Calories:', '').replace('kcal', '').trim());
        if (!isNaN(calValue)) calories += calValue;
      }
      
      if (line.startsWith('Protein:')) {
        const protValue = parseFloat(line.replace('Protein:', '').replace('g', '').trim());
        if (!isNaN(protValue)) protein += protValue;
      }
      
      if (line.startsWith('Fat:')) {
        const fatValue = parseFloat(line.replace('Fat:', '').replace('g', '').trim());
        if (!isNaN(fatValue)) fat += fatValue;
      }
      
      if (line.startsWith('Carbs:')) {
        const carbValue = parseFloat(line.replace('Carbs:', '').replace('g', '').trim());
        if (!isNaN(carbValue)) carbs += carbValue;
      }
      
      if (line.startsWith('Vitamin C:')) {
        const vitCValue = parseFloat(line.replace('Vitamin C:', '').replace('mg', '').trim());
        if (!isNaN(vitCValue)) vitaminC += vitCValue;
      }
    }
    
    // If we don't have any ingredients, add placeholders
    if (ingredients.length === 0) {
      ingredients.push("Mixed ingredients (100g) 200kcal");
    }
    
    // Look for existing health score in the text
    let healthScore = null;
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim();
      if (line.startsWith('Health Score:')) {
        const scoreText = line.replace('Health Score:', '').trim();
        const scoreMatch = scoreText.match(/(\d+)\/10/);
        if (scoreMatch && scoreMatch[1]) {
          healthScore = parseInt(scoreMatch[1]);
          break;
        }
      }
    }
    
    // If no health score was found, estimate one based on ingredients
    if (healthScore === null) {
      // Count positive and negative nutritional factors
      const ingredientText = ingredients.join(' ').toLowerCase();
      
      // Start with a moderate score
      let score = 5;
      
      // Positive factors - add points for healthy ingredients
      if (ingredientText.includes('vegetable') || ingredientText.includes('veg') || 
          ingredientText.includes('broccoli') || ingredientText.includes('spinach') || 
          ingredientText.includes('kale')) score += 1;
      
      if (ingredientText.includes('whole grain') || ingredientText.includes('brown rice') || 
          ingredientText.includes('quinoa') || ingredientText.includes('oat')) score += 1;
      
      if (ingredientText.includes('lean') || ingredientText.includes('fish') || 
          ingredientText.includes('salmon') || ingredientText.includes('chicken breast')) score += 1;
      
      if (ingredientText.includes('olive oil') || ingredientText.includes('avocado') || 
          ingredientText.includes('nuts') || ingredientText.includes('seed')) score += 1;
      
      // Negative factors - subtract points for unhealthy ingredients
      if (ingredientText.includes('fried') || ingredientText.includes('deep fried') || 
          ingredientText.includes('crispy')) score -= 1;
      
      if (ingredientText.includes('sugar') || ingredientText.includes('syrup') || 
          ingredientText.includes('sweetened') || ingredientText.includes('candy')) score -= 1;
      
      if (ingredientText.includes('cream') || ingredientText.includes('butter') || 
          ingredientText.includes('cheese') || ingredientText.includes('mayo')) score -= 1;
      
      if (ingredientText.includes('processed') || ingredientText.includes('sausage') || 
          ingredientText.includes('bacon') || ingredientText.includes('ham')) score -= 1;
      
      // Constrain to range 1-10
      healthScore = Math.max(1, Math.min(10, score));
    }
    
    // Return the properly formatted JSON
    return {
      meal_name: mealName,
      ingredients: ingredients,
      calories: calories || 500, // Default if missing
      protein: protein || 15,
      fat: fat || 10,
      carbs: carbs || 20,
      vitamin_c: vitaminC || 2,
      health_score: `${healthScore}/10`
    };
  }
  
  // If we got here and data has properties like "calories" but no meal_name
  if (data.calories && !data.meal_name) {
    // If health_score is available in the data, use it
    const healthScore = data.health_score ? 
      data.health_score.replace('/10', '') : 
      estimateHealthScoreFromIngredients(data.ingredients || []);
    
    return {
      meal_name: data.name || "Mixed Meal",
      ingredients: data.ingredients || ["Mixed ingredients (100g) 200kcal"],
      calories: data.calories,
      protein: data.protein || 15,
      fat: data.fat || 10,
      carbs: data.carbs || 20,
      vitamin_c: data.vitamin_c || 2,
      health_score: `${healthScore}/10`
    };
  }
  
  // Default response format if we can't extract meaningful data
  return {
    meal_name: "Mixed Meal",
    ingredients: ["Mixed ingredients (100g) 200kcal"],
    calories: 500,
    protein: 15,
    fat: 10,
    carbs: 20,
    vitamin_c: 2,
    health_score: "5/10" // Moderate health score as default
  };
}

// Helper function to estimate health score from ingredients
function estimateHealthScoreFromIngredients(ingredients) {
  if (!ingredients || ingredients.length === 0) return 5;
  
  const ingredientText = ingredients.join(' ').toLowerCase();
  
  // Start with a moderate score
  let score = 5;
  
  // Positive factors - add points for healthy ingredients
  if (ingredientText.includes('vegetable') || ingredientText.includes('veg') || 
      ingredientText.includes('broccoli') || ingredientText.includes('spinach') || 
      ingredientText.includes('kale')) score += 1;
  
  if (ingredientText.includes('whole grain') || ingredientText.includes('brown rice') || 
      ingredientText.includes('quinoa') || ingredientText.includes('oat')) score += 1;
  
  if (ingredientText.includes('lean') || ingredientText.includes('fish') || 
      ingredientText.includes('salmon') || ingredientText.includes('chicken breast')) score += 1;
  
  if (ingredientText.includes('olive oil') || ingredientText.includes('avocado') || 
      ingredientText.includes('nuts') || ingredientText.includes('seed')) score += 1;
  
  // Negative factors - subtract points for unhealthy ingredients
  if (ingredientText.includes('fried') || ingredientText.includes('deep fried') || 
      ingredientText.includes('crispy')) score -= 1;
  
  if (ingredientText.includes('sugar') || ingredientText.includes('syrup') || 
      ingredientText.includes('sweetened') || ingredientText.includes('candy')) score -= 1;
  
  if (ingredientText.includes('cream') || ingredientText.includes('butter') || 
      ingredientText.includes('cheese') || ingredientText.includes('mayo')) score -= 1;
  
  if (ingredientText.includes('processed') || ingredientText.includes('sausage') || 
      ingredientText.includes('bacon') || ingredientText.includes('ham')) score -= 1;
  
  // Constrain to range 1-10
  return Math.max(1, Math.min(10, score));
}

// Add a more sophisticated health score calculation function that varies results
function calculateHealthScore(protein, vitaminC, fat, calories, carbs) {
  // This function is kept for compatibility with existing code
  // but we now prefer to use the ingredient-based scoring from OpenAI
  return estimateHealthScoreFromIngredients([]);
}

module.exports = { analyzeFoodImageImpl, parseResult, pingFunction }; 