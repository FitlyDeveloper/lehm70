// Import required packages
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const fetch = require('node-fetch');

// Create Express app
const app = express();
const PORT = process.env.PORT || 3000;

// Debug startup
console.log('Starting server...');
console.log('Node environment:', process.env.NODE_ENV);
console.log('Current directory:', process.cwd());
console.log('OpenAI API Key present:', process.env.OPENAI_API_KEY ? 'Yes' : 'No');

// Set trust proxy to fix the X-Forwarded-For warning
app.set('trust proxy', 1);

// Configure rate limiting
const limiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: process.env.RATE_LIMIT || 30, // Limit each IP to 30 requests per minute
  standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
  legacyHeaders: false, // Disable the `X-RateLimit-*` headers
  message: {
    status: 429,
    message: 'Too many requests, please try again later.'
  }
});

// Get allowed origins from environment or use default
const allowedOrigins = process.env.ALLOWED_ORIGINS 
  ? process.env.ALLOWED_ORIGINS.split(',') 
  : [
      'http://localhost:3000',
      'https://snap-food.onrender.com',
      'https://deepseek-uhrc.onrender.com',
      'http://snap-food.onrender.com',
      'http://deepseek-uhrc.onrender.com'
    ];

console.log('Allowed origins:', allowedOrigins);

// Configure CORS
app.use(cors({
  origin: function(origin, callback) {
    // Allow requests with no origin (like mobile apps or curl requests)
    if (!origin) return callback(null, true);
    
    // Allow all origins
    return callback(null, true);
  },
  methods: ['GET', 'POST', 'OPTIONS'],
  credentials: true,
  allowedHeaders: ['Content-Type', 'Authorization']
}));

// Body parser middleware
app.use(express.json({ limit: '10mb' }));

// Middleware to check for OpenAI API key
const checkApiKey = (req, res, next) => {
  if (!process.env.OPENAI_API_KEY) {
    console.error('OpenAI API key not configured');
    return res.status(500).json({
      success: false,
      error: 'Server configuration error: OpenAI API key not set'
    });
  }
  console.log('OpenAI API key verified');
  next();
};

// Define routes
app.get('/', (req, res) => {
  console.log('Health check endpoint called');
  res.json({
    message: 'Food Analyzer API Server',
    status: 'operational'
  });
});

// OpenAI proxy endpoint for food analysis
app.post('/api/analyze-food', limiter, checkApiKey, async (req, res) => {
  try {
    console.log('Analyze food endpoint called');
    const { image } = req.body;

    if (!image) {
      console.error('No image provided in request');
      return res.status(400).json({
        success: false,
        error: 'Image data is required'
      });
    }

    // Debug logging
    console.log('Received image data, length:', image.length);
    console.log('Image data starts with:', image.substring(0, 50));

    // Call OpenAI API
    console.log('Calling OpenAI API...');
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`
      },
      body: JSON.stringify({
        model: 'gpt-4o',
        temperature: 0.1,
        messages: [
          {
            role: 'system',
            content: '[NUTRIENTS EXTRACTION PRIORITY] You are a nutrition expert analyzing food images. YOUR RESPONSE MUST INCLUDE ALL NUTRIENTS LISTED BELOW FOR EACH INGREDIENT OR YOU WILL FAIL. OUTPUT MUST BE VALID JSON AND NOTHING ELSE.\n\nFORMAT RULES:\n1. Return a single meal name for the entire image (e.g., "Pasta Meal", "Breakfast Plate")\n2. List ingredients with weights and calories (e.g., "Pasta (100g) 200kcal")\n3. Return total values for all nutrients\n4. Add a health score (1-10)\n5. CRITICAL: provide EXACT macronutrient AND micronutrient breakdown for EACH ingredient\n6. CRITICAL: EVERY ingredient must include ALL of these nutrients (no exceptions):\n   - protein: string with g unit (e.g., "12.5g")\n   - fat: string with g unit (e.g., "5.2g")\n   - carbs: string with g unit (e.g., "45.7g")\n   \n   VITAMINS:\n   - vitamin_a: string with mcg unit (e.g., "300mcg")\n   - vitamin_c: string with mg unit (e.g., "15mg")\n   - vitamin_d: string with mcg unit (e.g., "0.5mcg")\n   - vitamin_e: string with mg unit (e.g., "1.2mg")\n   - vitamin_k: string with mcg unit (e.g., "120mcg")\n   - vitamin_b1: string with mg unit (e.g., "0.4mg")\n   - vitamin_b2: string with mg unit (e.g., "0.5mg")\n   - vitamin_b3: string with mg unit (e.g., "6.2mg")\n   - vitamin_b5: string with mg unit (e.g., "1.8mg")\n   - vitamin_b6: string with mg unit (e.g., "0.6mg")\n   - vitamin_b7: string with mcg unit (e.g., "12mcg")\n   - vitamin_b9: string with mcg unit (e.g., "80mcg")\n   - vitamin_b12: string with mcg unit (e.g., "1.2mcg")\n   \n   MINERALS:\n   - calcium: string with mg unit (e.g., "25mg")\n   - chloride: string with mg unit (e.g., "150mg")\n   - chromium: string with mcg unit (e.g., "12mcg")\n   - copper: string with mcg unit (e.g., "220mcg")\n   - fluoride: string with mg unit (e.g., "0.8mg")\n   - iodine: string with mcg unit (e.g., "35mcg")\n   - iron: string with mg unit (e.g., "1.8mg")\n   - magnesium: string with mg unit (e.g., "56mg")\n   - manganese: string with mg unit (e.g., "0.8mg")\n   - molybdenum: string with mcg unit (e.g., "15mcg")\n   - phosphorus: string with mg unit (e.g., "120mg")\n   - potassium: string with mg unit (e.g., "350mg")\n   - selenium: string with mcg unit (e.g., "18mcg")\n   - sodium: string with mg unit (e.g., "15mg")\n   - zinc: string with mg unit (e.g., "2.5mg")\n   \n   OTHER NUTRIENTS:\n   - fiber: string with g unit (e.g., "3.5g")\n   - cholesterol: string with mg unit (e.g., "25mg")\n   - sugar: string with g unit (e.g., "6.2g")\n   - saturated_fats: string with g unit (e.g., "2.1g")\n   - omega_3: string with mg unit (e.g., "120mg")\n   - omega_6: string with g unit (e.g., "1.2g")\n   \n7. Use decimal places for precise values\n8. NEVER separate numbers from their units with spaces\n9. DO NOT respond with markdown code blocks or text explanations\n10. DO NOT prefix your response with "json" or ```\n11. ONLY RETURN A RAW JSON OBJECT\n12. VERIFY your response includes ALL required nutrients for EACH ingredient before submitting\n13. CRITICALLY IMPORTANT: Always identify REAL food ingredients (e.g., "Rice", "Chicken", "Broccoli", "Pasta", "Cheese") - never use generic placeholders like "Mixed ingredients"\n14. If you cannot identify specific ingredients but see a food item, name actual foods that would reasonably be in the dish (e.g., for a stew: "Beef", "Potatoes", "Carrots", "Onions")\n\nEXACT FORMAT REQUIRED:\n{\n  "meal_name": "Meal Name",\n  "ingredients": ["Item1 (weight) calories", "Item2 (weight) calories"],\n  "ingredient_macros": [\n    {\n      "protein": "12.5g",\n      "fat": "5.2g",\n      "carbs": "45.7g",\n      "vitamin_a": "300mcg",\n      "vitamin_c": "15mg",\n      "vitamin_d": "0.5mcg",\n      "vitamin_e": "1.2mg",\n      "vitamin_k": "120mcg",\n      "vitamin_b1": "0.4mg",\n      "vitamin_b2": "0.5mg",\n      "vitamin_b3": "6.2mg",\n      "vitamin_b5": "1.8mg",\n      "vitamin_b6": "0.6mg",\n      "vitamin_b7": "12mcg",\n      "vitamin_b9": "80mcg",\n      "vitamin_b12": "1.2mcg",\n      "calcium": "25mg",\n      "chloride": "150mg",\n      "chromium": "12mcg",\n      "copper": "220mcg",\n      "fluoride": "0.8mg",\n      "iodine": "35mcg",\n      "iron": "1.8mg",\n      "magnesium": "56mg",\n      "manganese": "0.8mg",\n      "molybdenum": "15mcg",\n      "phosphorus": "120mg",\n      "potassium": "350mg",\n      "selenium": "18mcg",\n      "sodium": "15mg",\n      "zinc": "2.5mg",\n      "fiber": "3.5g",\n      "cholesterol": "25mg",\n      "sugar": "6.2g",\n      "saturated_fats": "2.1g",\n      "omega_3": "120mg",\n      "omega_6": "1.2g"\n    },\n    {\n      "protein": "8.3g",\n      "fat": "3.1g",\n      "carbs": "28.3g",\n      "vitamin_a": "150mcg",\n      "vitamin_c": "8mg",\n      "vitamin_d": "0.2mcg",\n      "vitamin_e": "0.8mg",\n      "vitamin_k": "85mcg",\n      "vitamin_b1": "0.3mg",\n      "vitamin_b2": "0.4mg",\n      "vitamin_b3": "4.8mg",\n      "vitamin_b5": "1.2mg",\n      "vitamin_b6": "0.4mg",\n      "vitamin_b7": "8mcg",\n      "vitamin_b9": "60mcg",\n      "vitamin_b12": "0.8mcg",\n      "calcium": "15mg",\n      "chloride": "120mg",\n      "chromium": "8mcg",\n      "copper": "180mcg",\n      "fluoride": "0.5mg",\n      "iodine": "25mcg",\n      "iron": "1.2mg",\n      "magnesium": "42mg",\n      "manganese": "0.6mg",\n      "molybdenum": "12mcg",\n      "phosphorus": "90mg",\n      "potassium": "220mg",\n      "selenium": "14mcg",\n      "sodium": "10mg",\n      "zinc": "1.8mg",\n      "fiber": "2.1g",\n      "cholesterol": "18mg",\n      "sugar": "4.5g",\n      "saturated_fats": "1.5g",\n      "omega_3": "80mg",\n      "omega_6": "0.8g"\n    }\n  ],\n  "calories": "500kcal",\n  "protein": "20.8g",\n  "fat": "8.3g",\n  "carbs": "74.0g",\n  "vitamin_a": "450mcg",\n  "vitamin_c": "23mg",\n  "vitamin_d": "0.7mcg",\n  "vitamin_e": "2.0mg",\n  "vitamin_k": "205mcg",\n  "vitamin_b1": "0.7mg",\n  "vitamin_b2": "0.9mg",\n  "vitamin_b3": "11.0mg",\n  "vitamin_b5": "3.0mg",\n  "vitamin_b6": "1.0mg",\n  "vitamin_b7": "20mcg",\n  "vitamin_b9": "140mcg",\n  "vitamin_b12": "2.0mcg",\n  "calcium": "40mg",\n  "chloride": "270mg",\n  "chromium": "20mcg",\n  "copper": "400mcg",\n  "fluoride": "1.3mg",\n  "iodine": "60mcg",\n  "iron": "3.0mg",\n  "magnesium": "98mg",\n  "manganese": "1.4mg",\n  "molybdenum": "27mcg",\n  "phosphorus": "210mg",\n  "potassium": "570mg",\n  "selenium": "32mcg",\n  "sodium": "25mg",\n  "zinc": "4.3mg",\n  "fiber": "5.6g",\n  "cholesterol": "43mg",\n  "sugar": "10.7g",\n  "saturated_fats": "3.6g",\n  "omega_3": "200mg",\n  "omega_6": "2.0g",\n  "health_score": "7/10"\n}'
          },
          {
            role: 'user',
            content: [
              {
                type: 'text',
                text: "RETURN ONLY RAW JSON - NO TEXT, NO CODE BLOCKS, NO EXPLANATIONS. Analyze this food image and return ALL required nutrients in the EXACT format - ALL fields are required for EACH ingredient. MUST include all nutrients for EACH ingredient AND all totals.\n\nThe response MUST match this format:\n{\n  \"meal_name\": string,\n  \"ingredients\": array of strings,\n  \"ingredient_macros\": array containing objects with ALL these nutrients for EACH ingredient:\n    - protein: string with g unit\n    - fat: string with g unit\n    - carbs: string with g unit\n    - vitamin_a: string with mcg unit\n    - vitamin_c: string with mg unit\n    - vitamin_d: string with mcg unit\n    - vitamin_e: string with mg unit\n    - vitamin_k: string with mcg unit\n    - vitamin_b1: string with mg unit\n    - vitamin_b2: string with mg unit\n    - vitamin_b3: string with mg unit\n    - vitamin_b5: string with mg unit\n    - vitamin_b6: string with mg unit\n    - vitamin_b7: string with mcg unit\n    - vitamin_b9: string with mcg unit\n    - vitamin_b12: string with mcg unit\n    - calcium: string with mg unit\n    - chloride: string with mg unit\n    - chromium: string with mcg unit\n    - copper: string with mcg unit\n    - fluoride: string with mg unit\n    - iodine: string with mcg unit\n    - iron: string with mg unit\n    - magnesium: string with mg unit\n    - manganese: string with mg unit\n    - molybdenum: string with mcg unit\n    - phosphorus: string with mg unit\n    - potassium: string with mg unit\n    - selenium: string with mcg unit\n    - sodium: string with mg unit\n    - zinc: string with mg unit\n    - fiber: string with g unit\n    - cholesterol: string with mg unit\n    - sugar: string with g unit\n    - saturated_fats: string with g unit\n    - omega_3: string with mg unit\n    - omega_6: string with g unit\n  \"calories\": string with kcal unit,\n  \"protein\": string with g unit,\n  \"fat\": string with g unit,\n  \"carbs\": string with g unit,\n  \"vitamin_a\": string with mcg unit,\n  \"vitamin_c\": string with mg unit,\n  \"vitamin_d\": string with mcg unit,\n  \"vitamin_e\": string with mg unit,\n  \"vitamin_k\": string with mcg unit,\n  \"vitamin_b1\": string with mg unit,\n  \"vitamin_b2\": string with mg unit,\n  \"vitamin_b3\": string with mg unit,\n  \"vitamin_b5\": string with mg unit,\n  \"vitamin_b6\": string with mg unit,\n  \"vitamin_b7\": string with mcg unit,\n  \"vitamin_b9\": string with mcg unit,\n  \"vitamin_b12\": string with mcg unit,\n  \"calcium\": string with mg unit,\n  \"chloride\": string with mg unit,\n  \"chromium\": string with mcg unit,\n  \"copper\": string with mcg unit,\n  \"fluoride\": string with mg unit,\n  \"iodine\": string with mcg unit,\n  \"iron\": string with mg unit,\n  \"magnesium\": string with mg unit,\n  \"manganese\": string with mg unit,\n  \"molybdenum\": string with mcg unit,\n  \"phosphorus\": string with mg unit,\n  \"potassium\": string with mg unit,\n  \"selenium\": string with mcg unit,\n  \"sodium\": string with mg unit,\n  \"zinc\": string with mg unit,\n  \"fiber\": string with g unit,\n  \"cholesterol\": string with mg unit,\n  \"sugar\": string with g unit,\n  \"saturated_fats\": string with g unit,\n  \"omega_3\": string with mg unit,\n  \"omega_6\": string with g unit,\n  \"health_score\": string\n}"
              },
              {
                type: 'image_url',
                image_url: { url: image }
              }
            ]
          }
        ],
        max_tokens: 1500,
        response_format: { type: 'json_object' }
      })
    });

    if (!response.ok) {
      const errorData = await response.text();
      console.error('OpenAI API error:', response.status, errorData);
      return res.status(response.status).json({
        success: false,
        error: `OpenAI API error: ${response.status}`
      });
    }

    console.log('OpenAI API response received');
    const data = await response.json();
    
    if (!data.choices || 
        !data.choices[0] || 
        !data.choices[0].message || 
        !data.choices[0].message.content) {
      console.error('Invalid response format from OpenAI:', JSON.stringify(data));
      return res.status(500).json({
        success: false,
        error: 'Invalid response from OpenAI'
      });
    }

    const content = data.choices[0].message.content;
    console.log('OpenAI API response content:', content.substring(0, 100) + '...');
    
    // Process and parse the response
    try {
      // First try direct parsing
      const parsedData = JSON.parse(content);
      console.log('Successfully parsed JSON response');
      console.log('RAW OPENAI DATA:', content.substring(0, 1000) + (content.length > 1000 ? '...' : ''));
      
      // Check if we have the expected meal_name format
      if (parsedData.meal_name) {
        // Process the data to add micronutrients
        const processedData = addMicronutrientsToTopLevel(parsedData);
        return res.json({
          success: true,
          data: processedData
        });
      } else {
        // Transform the response to match our expected format
        const transformedData = transformToRequiredFormat(parsedData);
        console.log('Transformed data to required format');
        return res.json({
          success: true,
          data: transformedData
        });
      }
    } catch (error) {
      console.log('Direct JSON parsing failed, attempting to extract JSON from text');
      // Try to extract JSON from the text
      const jsonMatch = content.match(/```json\n([\s\S]*?)\n```/) || 
                      content.match(/\{[\s\S]*\}/);
      
      if (jsonMatch) {
        const jsonContent = jsonMatch[0].replace(/```json\n|```/g, '').trim();
        try {
          const parsedData = JSON.parse(jsonContent);
          console.log('Successfully extracted and parsed JSON from text');
          console.log('RAW EXTRACTED JSON:', jsonContent.substring(0, 1000) + (jsonContent.length > 1000 ? '...' : ''));
          
          // Check if we have the expected meal_name format
          if (parsedData.meal_name) {
            // Process the data to add micronutrients
            const processedData = addMicronutrientsToTopLevel(parsedData);
            return res.json({
              success: true,
              data: processedData
            });
          } else {
            // Transform the response to match our expected format
            const transformedData = transformToRequiredFormat(parsedData);
            console.log('Transformed extracted JSON to required format');
            return res.json({
              success: true,
              data: transformedData
            });
          }
        } catch (err) {
          console.error('JSON extraction failed:', err);
          // Transform the raw text
          const transformedData = transformTextToRequiredFormat(content);
          return res.json({
            success: true,
            data: transformedData
          });
        }
      } else {
        console.warn('No JSON pattern found in response');
        // Transform the raw text
        const transformedData = transformTextToRequiredFormat(content);
        return res.json({
          success: true,
          data: transformedData
        });
      }
    }
  } catch (error) {
    console.error('Server error:', error);
    return res.status(500).json({
      success: false,
      error: 'Server error processing request'
    });
  }
});

// Helper function to transform data to our required format
function transformToRequiredFormat(data) {
  // If it's the old meal array format
  if (data.meal && Array.isArray(data.meal) && data.meal.length > 0) {
    const mealItem = data.meal[0];
    
    // Ingredient macros array to match the number of ingredients
    const ingredientsList = mealItem.ingredients || [];
    const ingredientMacros = [];

    // Extract top-level micronutrients if available
    const topLevelVitamins = {};
    const topLevelMinerals = {};
    const topLevelOtherNutrients = {};

    // Helper function to copy nutrients to each ingredient
    const copyNutrients = (source, target) => {
      if (source && typeof source === 'object') {
        Object.keys(source).forEach(key => {
          if (typeof source[key] === 'number' || 
              typeof source[key] === 'string' ||
              (typeof source[key] === 'object' && source[key] !== null)) {
            target[key] = source[key];
          }
        });
      }
    };

    // Extract top-level micronutrients if available for later distribution
    if (mealItem.vitamins && typeof mealItem.vitamins === 'object') {
      copyNutrients(mealItem.vitamins, topLevelVitamins);
    }

    if (mealItem.minerals && typeof mealItem.minerals === 'object') {
      copyNutrients(mealItem.minerals, topLevelMinerals);
    }

    if (mealItem.other_nutrients && typeof mealItem.other_nutrients === 'object') {
      copyNutrients(mealItem.other_nutrients, topLevelOtherNutrients);
    }
    
    // Create ingredient macros array
    const transformedIngredients = ingredientsList.map((ingredient, index) => {
      let ingredientName = typeof ingredient === 'string' ? ingredient : '';
      let ingredientWeight = '30g';
      let ingredientCalories = 75;
      
      // Estimate ingredient macros based on name
      let protein = 0;
      let fat = 0;
      let carbs = 0;
      
      // Extract values if ingredient is in format "Name (Weight) Calories"
      if (typeof ingredient === 'string') {
        const weightMatch = ingredient.match(/\(([^)]+)\)/);
        const caloriesMatch = ingredient.match(/(\d+)\s*kcal/i);

        if (weightMatch) {
          ingredientWeight = weightMatch[1];
          ingredientName = ingredient.split('(')[0].trim();
        }

        if (caloriesMatch) {
          ingredientCalories = parseInt(caloriesMatch[1]);
        }

        // Simple estimation based on common ingredients
        const lowerName = ingredientName.toLowerCase();
        
        if (lowerName.includes('chicken') || lowerName.includes('beef') || lowerName.includes('fish') || lowerName.includes('meat')) {
          protein = ingredientCalories * 0.6 / 4; // 60% of calories from protein
          fat = ingredientCalories * 0.4 / 9; // 40% of calories from fat
        } else if (lowerName.includes('cheese') || lowerName.includes('avocado') || lowerName.includes('nut') || lowerName.includes('oil')) {
          protein = ingredientCalories * 0.1 / 4; // 10% of calories from protein
          fat = ingredientCalories * 0.8 / 9; // 80% of calories from fat
          carbs = ingredientCalories * 0.1 / 4; // 10% of calories from carbs
        } else if (lowerName.includes('rice') || lowerName.includes('pasta') || lowerName.includes('bread') || lowerName.includes('potato')) {
          protein = ingredientCalories * 0.1 / 4; // 10% of calories from protein
          fat = ingredientCalories * 0.05 / 9; // 5% of calories from fat
          carbs = ingredientCalories * 0.85 / 4; // 85% of calories from carbs
        } else if (lowerName.includes('vegetable') || lowerName.includes('broccoli') || lowerName.includes('spinach')) {
          protein = ingredientCalories * 0.3 / 4; // 30% of calories from protein
          carbs = ingredientCalories * 0.7 / 4; // 70% of calories from carbs
        } else if (lowerName.includes('fruit') || lowerName.includes('apple') || lowerName.includes('banana')) {
          carbs = ingredientCalories * 0.9 / 4; // 90% of calories from carbs
          protein = ingredientCalories * 0.05 / 4; // 5% of calories from protein
          fat = ingredientCalories * 0.05 / 9; // 5% of calories from fat
        } else {
          // Default balanced macros for unknown ingredients
          protein = ingredientCalories * 0.2 / 4; // 20% of calories from protein
          fat = ingredientCalories * 0.3 / 9; // 30% of calories from fat
          carbs = ingredientCalories * 0.5 / 4; // 50% of calories from carbs
        }
      }

      // Create ingredient macro object
      const macroObj = {
        name: ingredientName,
        amount: ingredientWeight,
        calories: ingredientCalories,
        protein: Math.round(protein * 10) / 10,
        fat: Math.round(fat * 10) / 10,
        carbs: Math.round(carbs * 10) / 10,
        // Add directly accessible micronutrient data to each ingredient
        vitamins: {},
        minerals: {},
        other: {}
      };

      // Copy top-level micronutrients to each ingredient
      if (Object.keys(topLevelVitamins).length > 0) {
        copyNutrients(topLevelVitamins, macroObj.vitamins);
      }
      
      if (Object.keys(topLevelMinerals).length > 0) {
        copyNutrients(topLevelMinerals, macroObj.minerals);
      }
      
      if (Object.keys(topLevelOtherNutrients).length > 0) {
        copyNutrients(topLevelOtherNutrients, macroObj.other);
      }
     
      return macroObj;
    });

    // Prepare our transformed data response
    const transformedData = {
      meal_name: mealItem.dish || 'Analyzed Meal',
      ingredients: ingredientsList.map(ingredient => {
        if (typeof ingredient === 'string') {
          return ingredient;
        } else if (typeof ingredient === 'object' && ingredient !== null) {
          return ingredient.name || 'Unknown Ingredient';
        }
        return 'Unknown Ingredient';
      }),
      ingredient_macros: transformedIngredients,
      calories: mealItem.calories || transformedIngredients.reduce((sum, item) => sum + item.calories, 0),
      protein: mealItem.protein || Math.round(transformedIngredients.reduce((sum, item) => sum + item.protein, 0)),
      fat: mealItem.fat || Math.round(transformedIngredients.reduce((sum, item) => sum + item.fat, 0)),
      carbs: mealItem.carbs || Math.round(transformedIngredients.reduce((sum, item) => sum + item.carbs, 0)),
      health_score: mealItem.health_score || '7/10',
      vitamins: topLevelVitamins,
      minerals: topLevelMinerals,
      other_nutrients: topLevelOtherNutrients
    };
    
    return transformedData;
  }
  
  // If we have top-level vitamins or minerals in the input data, use them
  const topLevelVitamins = data.vitamins || {};
  const topLevelMinerals = data.minerals || {};
  
  // Return a default format if nothing else works
  return {
    meal_name: "Mixed Meal",
    ingredients: [
      "Rice (50g) 100kcal",
      "Chicken (50g) 100kcal"
    ],
    ingredient_macros: [
      {
        protein: "2.0g",
        fat: "0.3g",
        carbs: "22.5g",
        vitamins: Object.keys(topLevelVitamins).length > 0 ? 
          { ...topLevelVitamins } : 
          {
            'c': "1.0mg",
            'a': "0mcg",
            'b1': "0.1mg",
            'b2': "0.01mg"
          },
        minerals: Object.keys(topLevelMinerals).length > 0 ? 
          { ...topLevelMinerals } : 
          {
            'calcium': "15mg",
            'iron': "0.4mg",
            'potassium': "35mg",
            'magnesium': "12mg"
          }
      },
      {
        protein: "18.0g",
        fat: "3.0g",
        carbs: "0.0g",
        vitamins: Object.keys(topLevelVitamins).length > 0 ? 
          { ...topLevelVitamins } : 
          {
            'c': "0.0mg",
            'a': "15mcg",
            'b1': "0.05mg",
            'b2': "0.12mg"
          },
        minerals: Object.keys(topLevelMinerals).length > 0 ? 
          { ...topLevelMinerals } : 
          {
            'calcium': "5mg",
            'iron': "0.6mg",
            'potassium': "200mg",
            'magnesium': "20mg"
          }
      }
    ],
    calories: 500,
    protein: 20,
    fat: 15,
    carbs: 60,
    vitamin_c: 2,
    health_score: "6/10",
    vitamins: topLevelVitamins,
    minerals: topLevelMinerals
  };
}

// Helper function to transform raw text to our required format
function transformTextToRequiredFormat(text) {
  // Extract any top-level micronutrients from the text
  const topLevelVitamins = {};
  const topLevelMinerals = {};
  
  // Look for vitamin and mineral mentions in the text
  const vitaminMatches = text.match(/vitamin [a-z]\s*:\s*[\d\.]+/gi) || [];
  const mineralMatches = text.match(/(iron|calcium|zinc|magnesium|potassium|sodium)\s*:\s*[\d\.]+/gi) || [];
  
  // Extract values from matches
  vitaminMatches.forEach(match => {
    const parts = match.split(':');
    if (parts.length === 2) {
      const name = parts[0].trim().toLowerCase().replace('vitamin ', '');
      const value = parseFloat(parts[1].trim());
      if (!isNaN(value)) {
        topLevelVitamins[name] = value;
      }
    }
  });
  
  mineralMatches.forEach(match => {
    const parts = match.split(':');
    if (parts.length === 2) {
      const name = parts[0].trim().toLowerCase();
      const value = parseFloat(parts[1].trim());
      if (!isNaN(value)) {
        topLevelMinerals[name] = value;
      }
    }
  });
  
  // Try to parse "Food item" format
  if (text.includes('Food item') || text.includes('FOOD ANALYSIS RESULTS')) {
    const lines = text.split('\n');
    const ingredients = [];
    const ingredientMacros = [];
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
          let ingredientWeight = '30g';
          let ingredientCalories = 75;
          let ingredientProtein = 3.0;
          let ingredientFat = 2.0;
          let ingredientCarbs = 10.0;
          
          // Vitamins and minerals for this ingredient
          let vitamins = {};
          let minerals = {};
          
          // Customize based on ingredient type - using same logic as above for consistency
          if (ingredient.toLowerCase().includes('pasta') || 
              ingredient.toLowerCase().includes('noodle')) {
            ingredientWeight = '100g';
            ingredientCalories = 200;
            ingredientProtein = 7.5;
            ingredientFat = 1.1;
            ingredientCarbs = 43.2;
            // Add micronutrients
            vitamins = {
              'b1': 0.2,
              'b2': 0.1,
              'b3': 1.7,
              'b6': 0.1,
              'folate': 18
            };
            minerals = {
              'iron': 1.8,
              'magnesium': 53,
              'phosphorus': 189,
              'zinc': 1.3,
              'selenium': 63.2,
              'potassium': 223
            };
          } else if (ingredient.toLowerCase().includes('rice')) {
            ingredientWeight = '100g';
            ingredientCalories = 130;
            ingredientProtein = 2.7;
            ingredientFat = 0.3;
            ingredientCarbs = 28.2;
            // Add micronutrients
            vitamins = {
              'b1': 0.1,
              'b3': 1.6,
              'b6': 0.15,
              'folate': 8
            };
            minerals = {
              'iron': 0.4,
              'magnesium': 25,
              'phosphorus': 115,
              'zinc': 1.2,
              'selenium': 15.1,
              'potassium': 115
            };
          } else if (ingredient.toLowerCase().includes('watermelon')) {
            ingredientWeight = '100g';
            ingredientCalories = 30;
            ingredientProtein = 0.6;
            ingredientFat = 0.2;
            ingredientCarbs = 7.6;
            // Add micronutrients for watermelon
            vitamins = {
              'a': 569,
              'c': 8.1,
              'b6': 0.045,
              'b1': 0.033
            };
            minerals = {
              'potassium': 112,
              'magnesium': 10,
              'phosphorus': 11,
              'zinc': 0.1
            };
          } else if (ingredient.toLowerCase().includes('pineapple')) {
            ingredientWeight = '100g';
            ingredientCalories = 50;
            ingredientProtein = 0.5;
            ingredientFat = 0.1;
            ingredientCarbs = 13.1;
            // Add micronutrients for pineapple
            vitamins = {
              'c': 47.8,
              'b1': 0.079,
              'b6': 0.112,
              'folate': 18
            };
            minerals = {
              'manganese': 0.927,
              'copper': 0.110,
              'potassium': 109,
              'magnesium': 12
            };
          }

          if (ingredient.includes('(') && ingredient.includes(')')) {
            ingredients.push(ingredient);
          } else {
            // Add estimated weight and calories if not provided
            ingredients.push(`${ingredient} (${ingredientWeight}) ${ingredientCalories}kcal`);
          }
          
          // Ensure each ingredient has vitamins/minerals by using top-level data if available
          if (Object.keys(vitamins).length === 0 && Object.keys(topLevelVitamins).length > 0) {
            vitamins = { ...topLevelVitamins };
          }
          
          if (Object.keys(minerals).length === 0 && Object.keys(topLevelMinerals).length > 0) {
            minerals = { ...topLevelMinerals };
          }

          // Add macros for this ingredient with 1 decimal precision
          ingredientMacros.push({
            protein: parseFloat(ingredientProtein.toFixed(1)),
            fat: parseFloat(ingredientFat.toFixed(1)),
            carbs: parseFloat(ingredientCarbs.toFixed(1)),
            vitamins: vitamins,
            minerals: minerals
          });
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
      ingredients.push("Mixed_ingredients (100g) 200kcal");  // Use underscore instead of space
      ingredientMacros.push({
        protein: "10.0g",  // Use string format with units
        fat: "7.0g",
        carbs: "30.0g",
        vitamins: Object.keys(topLevelVitamins).length > 0 ? { ...topLevelVitamins } : {
          'c': 2.0,
          'a': 100,
          'b1': 0.1,
          'b2': 0.2
        },
        minerals: Object.keys(topLevelMinerals).length > 0 ? { ...topLevelMinerals } : {
          'calcium': 30,
          'iron': 1.2,
          'potassium': 150,
          'magnesium': 20
        }
      });
    }
    
    // Calculate a health score (simple algorithm based on macros)
    const healthScore = Math.max(1, Math.min(10, Math.round((protein * 0.5 + vitaminC * 0.3) / (fat * 0.3 + calories / 100))));
    
    // Return the properly formatted JSON
    return {
      meal_name: mealName,
      ingredients: ingredients,
      ingredient_macros: ingredientMacros,
      calories: calories || 500,
      protein: protein || 15,
      fat: fat || 10,
      carbs: carbs || 20,
      vitamin_c: vitaminC || 2,
      health_score: `${healthScore}/10`,
      vitamins: topLevelVitamins,
      minerals: topLevelMinerals
    };
  }
  
  // Default response if we can't parse anything meaningful
  return {
    meal_name: "Mixed Meal",
    ingredients: [
      "Mixed_ingredients (100g) 200kcal"  // Use underscore instead of space
    ],
    ingredient_macros: [
      {
        protein: "10g",  // Use string format with units
        fat: "7g",
        carbs: "30g",
        vitamins: Object.keys(topLevelVitamins).length > 0 ? { ...topLevelVitamins } : {
          'c': 2.0,
          'a': 100,
          'b1': 0.1,
          'b2': 0.2
        },
        minerals: Object.keys(topLevelMinerals).length > 0 ? { ...topLevelMinerals } : {
          'calcium': 30,
          'iron': 1.2,
          'potassium': 150,
          'magnesium': 20
        }
      }
    ],
    calories: "500kcal",  // Use string format with units
    protein: "20g",
    fat: "15g",
    carbs: "60g",
    vitamin_c: "2mg",  // Use string format with units
    health_score: "6/10",
    vitamins: topLevelVitamins,
    minerals: topLevelMinerals
  };
}

// Error handling for unhandled promises
process.on('unhandledRejection', (error) => {
  console.error('Unhandled Promise Rejection:', error);
});

// Utility function to process ingredient nutrients
// This ensures compatibility with both string and numeric values
function addMicronutrientsToTopLevel(data) {
  if (!data || !data.ingredient_macros || !Array.isArray(data.ingredient_macros)) {
    console.log('No ingredient macros to process');
    return data;
  }
  
  try {
    console.log('Processing ALL nutrients from OpenAI response...');
    
    // Extract and consolidate nutrients from all ingredients
    const allNutrients = {};
    // Include ALL nutrients that can be present in the API response
    const nutrientsToExtract = [
      'vitamin_a', 'vitamin_c', 'vitamin_d', 'vitamin_e', 'vitamin_k',
      'vitamin_b1', 'vitamin_b2', 'vitamin_b3', 'vitamin_b5', 'vitamin_b6',
      'vitamin_b7', 'vitamin_b9', 'vitamin_b12',
      'calcium', 'chloride', 'chromium', 'copper', 'fluoride', 'iodine',
      'iron', 'magnesium', 'manganese', 'molybdenum', 'phosphorus',
      'potassium', 'selenium', 'sodium', 'zinc',
      'fiber', 'cholesterol', 'sugar', 'saturated_fats', 'omega_3', 'omega_6'
    ];
    
    // Process each ingredient
    data.ingredient_macros.forEach(ingredient => {
      nutrientsToExtract.forEach(nutrient => {
        if (nutrient in ingredient) {
          // Convert to proper format handling both string and numeric values
          const value = ingredient[nutrient];
          if (typeof value === 'string') {
            // String value (e.g. "12.5g") - just use as is
            allNutrients[nutrient] = value;
          } else if (typeof value === 'number') {
            // Numeric value - convert to string with appropriate unit
            let unit = '';
            if (nutrient === 'protein' || nutrient === 'fat' || nutrient === 'carbs' || 
                nutrient === 'fiber' || nutrient === 'sugar' || nutrient === 'saturated_fats' ||
                nutrient === 'omega_6') {
              unit = 'g';
            } else if (nutrient === 'vitamin_a' || nutrient === 'vitamin_d' || 
                       nutrient === 'vitamin_b7' || nutrient === 'vitamin_b9' || 
                       nutrient === 'vitamin_b12' || nutrient === 'vitamin_k' || 
                       nutrient === 'chromium' || nutrient === 'copper' || 
                       nutrient === 'iodine' || nutrient === 'molybdenum' || 
                       nutrient === 'selenium') {
              unit = 'mcg';
            } else if (nutrient === 'cholesterol' || nutrient === 'omega_3' ||
                       nutrient === 'vitamin_c' || nutrient === 'vitamin_e' || 
                       nutrient === 'vitamin_b1' || nutrient === 'vitamin_b2' || 
                       nutrient === 'vitamin_b3' || nutrient === 'vitamin_b5' || 
                       nutrient === 'vitamin_b6' || nutrient === 'calcium' || 
                       nutrient === 'chloride' || nutrient === 'fluoride' || 
                       nutrient === 'iron' || nutrient === 'magnesium' || 
                       nutrient === 'manganese' || nutrient === 'phosphorus' || 
                       nutrient === 'potassium' || nutrient === 'sodium' || 
                       nutrient === 'zinc') {
              unit = 'mg';
            }
            allNutrients[nutrient] = value + unit;
          }
        }
      });
    });
    
    // Add all extracted nutrients to the top level
    Object.keys(allNutrients).forEach(nutrient => {
      if (!data[nutrient]) {
        data[nutrient] = allNutrients[nutrient];
      }
    });
    
    // Log each nutrient that was processed for verification
    console.log('Nutrients processed and added to response:');
    Object.entries(allNutrients).forEach(([key, value]) => {
      console.log(`  ${key}: ${value}`);
    });
    
    console.log('All nutrients processed for Nutrition.dart display');
    
    return data;
  } catch (error) {
    console.error('JSON extraction failed:', error);
    return data;
  }
}

// Start the server
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`API Key configured: ${process.env.OPENAI_API_KEY ? 'Yes' : 'No'}`);
  console.log(`Allowed origins: ${allowedOrigins.join(', ')}`);
}); 