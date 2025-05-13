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
  : ['http://localhost:3000'];

// Configure CORS
app.use(cors({
  origin: function(origin, callback) {
    // Allow requests with no origin (like mobile apps or curl requests)
    if (!origin) return callback(null, true);
    
    // Check if the origin is allowed
    if (allowedOrigins.indexOf(origin) === -1) {
      const msg = 'The CORS policy for this site does not allow access from the specified Origin.';
      return callback(new Error(msg), false);
    }
    return callback(null, true);
  },
  methods: ['POST'],
  credentials: true
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
        temperature: 0.2,
        messages: [
          {
            role: 'system',
            content: '[STRICTLY JSON ONLY] You are a nutrition expert analyzing food images. OUTPUT MUST BE VALID JSON AND NOTHING ELSE.\n\nFORMAT RULES:\n1. Return a single meal name for the entire image (e.g., "Pasta Meal", "Breakfast Plate")\n2. List ingredients with weights and calories (e.g., "Pasta (100g) 200kcal")\n3. Return total values for calories, protein, fat, carbs, vitamin C\n4. Add a health score (1-10)\n5. CRITICAL: provide EXACT macronutrient breakdown for EACH ingredient (protein, fat, carbs) - THIS IS THE MOST IMPORTANT PART\n6. Use decimal places and realistic estimates\n7. DO NOT respond with markdown code blocks or text explanations\n8. DO NOT prefix your response with "json" or ```\n9. ONLY RETURN A RAW JSON OBJECT\n10. FAILURE TO FOLLOW THESE INSTRUCTIONS WILL RESULT IN REJECTION\n\nEXACT FORMAT REQUIRED:\n{\n  "meal_name": "Meal Name",\n  "ingredients": ["Item1 (weight) calories", "Item2 (weight) calories"],\n  "ingredient_macros": [\n    {"protein": 12.5, "fat": 5.2, "carbs": 45.7},\n    {"protein": 8.3, "fat": 3.1, "carbs": 28.3}\n  ],\n  "calories": number,\n  "protein": number,\n  "fat": number,\n  "carbs": number,\n  "vitamin_c": number,\n  "health_score": "score/10"\n}'
          },
          {
            role: 'user',
            content: [
              {
                type: 'text',
                text: "RETURN ONLY RAW JSON - NO TEXT, NO CODE BLOCKS, NO EXPLANATIONS. Analyze this food image and return nutrition data in this EXACT format with no deviations. YOU MUST PROVIDE ACCURATE PROTEIN, FAT, AND CARB VALUES FOR EACH INGREDIENT:\n\n{\n  \"meal_name\": string (single name for entire meal),\n  \"ingredients\": array of strings with weights and calories,\n  \"ingredient_macros\": array of objects with protein, fat, carbs for each ingredient,\n  \"calories\": number,\n  \"protein\": number,\n  \"fat\": number,\n  \"carbs\": number,\n  \"vitamin_c\": number,\n  \"health_score\": string\n}"
              },
              {
                type: 'image_url',
                image_url: { url: image }
              }
            ]
          }
        ],
        max_tokens: 1000,
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
      
      // Check if we have the expected meal_name format
      if (parsedData.meal_name) {
        return res.json({
          success: true,
          data: parsedData
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
          
          // Check if we have the expected meal_name format
          if (parsedData.meal_name) {
            return res.json({
              success: true,
              data: parsedData
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

    // Check for vitamins in the response
    if (data.vitamins || mealItem.vitamins) {
      const vitaminsData = data.vitamins || mealItem.vitamins || {};
      
      // Format each vitamin with proper unit
      Object.keys(vitaminsData).forEach(key => {
        const normalizedKey = normalizeNutrientKey(key);
        const value = vitaminsData[key];
        
        topLevelVitamins[normalizedKey] = {
          amount: typeof value === 'number' ? value : parseFloat(value) || 0,
          unit: getUnitForVitamin(normalizedKey)
        };
      });
    }

    // Check for minerals in the response
    if (data.minerals || mealItem.minerals) {
      const mineralsData = data.minerals || mealItem.minerals || {};
      
      // Format each mineral with proper unit
      Object.keys(mineralsData).forEach(key => {
        const normalizedKey = normalizeNutrientKey(key);
        const value = mineralsData[key];
        
        topLevelMinerals[normalizedKey] = {
          amount: typeof value === 'number' ? value : parseFloat(value) || 0,
          unit: getUnitForMineral(normalizedKey)
        };
      });
    }

    // Check for other nutrients
    if (data.other_nutrients || mealItem.other_nutrients || data.other || mealItem.other) {
      const otherData = data.other_nutrients || mealItem.other_nutrients || data.other || mealItem.other || {};
      
      // Format each nutrient with proper unit
      Object.keys(otherData).forEach(key => {
        const normalizedKey = normalizeNutrientKey(key);
        const value = otherData[key];
        
        topLevelOtherNutrients[normalizedKey] = {
          amount: typeof value === 'number' ? value : parseFloat(value) || 0,
          unit: getUnitForNutrient(normalizedKey)
        };
      });
    }

    // Process common micronutrients that might be at the root level
    const commonMicronutrients = [
      'fiber', 'cholesterol', 'sodium', 'potassium', 'calcium', 'iron',
      'vitamin_a', 'vitamin_c', 'vitamin_d', 'vitamin_e', 'vitamin_k',
      'thiamin', 'riboflavin', 'niacin', 'folate', 'vitamin_b12',
      'magnesium', 'zinc', 'phosphorus', 'copper', 'manganese', 'selenium'
    ];

    // Check both top-level data and mealItem for micronutrients
    for (const nutrient of commonMicronutrients) {
      if (data[nutrient] !== undefined || mealItem[nutrient] !== undefined) {
        const value = data[nutrient] !== undefined ? data[nutrient] : mealItem[nutrient];
        const normalizedKey = normalizeNutrientKey(nutrient);
        
        // Determine if it's a vitamin, mineral, or other nutrient
        if (normalizedKey.startsWith('vitamin_') || 
            normalizedKey === 'thiamin' || 
            normalizedKey === 'riboflavin' || 
            normalizedKey === 'niacin' || 
            normalizedKey === 'folate') {
          topLevelVitamins[normalizedKey] = {
            amount: typeof value === 'number' ? value : parseFloat(value) || 0,
            unit: getUnitForVitamin(normalizedKey)
          };
        } else if (['calcium', 'iron', 'magnesium', 'phosphorus', 'potassium', 
                    'sodium', 'zinc', 'copper', 'manganese', 'selenium'].includes(normalizedKey)) {
          topLevelMinerals[normalizedKey] = {
            amount: typeof value === 'number' ? value : parseFloat(value) || 0,
            unit: getUnitForMineral(normalizedKey)
          };
        } else {
          topLevelOtherNutrients[normalizedKey] = {
            amount: typeof value === 'number' ? value : parseFloat(value) || 0,
            unit: getUnitForNutrient(normalizedKey)
          };
        }
      }
    }

    // For each ingredient, create a basic macro structure
    if (Array.isArray(mealItem.ingredient_macros) && mealItem.ingredient_macros.length > 0) {
      // Use provided macros
      mealItem.ingredient_macros.forEach((macro, index) => {
        // Create macros object with all required fields
        const macrosObj = {
          protein: macro.protein || 0,
          fat: macro.fat || 0,
          carbs: macro.carbs || 0,
          
          // Add micronutrients to each ingredient
          vitamins: { ...topLevelVitamins },
          minerals: { ...topLevelMinerals },
          other_nutrients: { ...topLevelOtherNutrients }
        };
        
        ingredientMacros.push(macrosObj);
      });
    } else {
      // No macros provided, create default entries for each ingredient
      ingredientsList.forEach(() => {
        const macrosObj = {
          protein: 0,
          fat: 0,
          carbs: 0,
          
          // Add micronutrients to each ingredient
          vitamins: { ...topLevelVitamins },
          minerals: { ...topLevelMinerals },
          other_nutrients: { ...topLevelOtherNutrients }
        };
        
        ingredientMacros.push(macrosObj);
      });
    }

    // Create a transformed object in our expected format
    return {
      meal_name: mealItem.meal_name || data.meal_name || "Unknown Meal",
      ingredients: ingredientsList,
      ingredient_macros: ingredientMacros,
      calories: mealItem.calories || data.calories || 0,
      protein: mealItem.protein || data.protein || 0,
      fat: mealItem.fat || data.fat || 0,
      carbs: mealItem.carbs || data.carbs || 0,
      
      // Include micronutrients at top level too for compatibility
      vitamins: topLevelVitamins,
      minerals: topLevelMinerals,
      other_nutrients: topLevelOtherNutrients,
      
      health_score: mealItem.health_score || data.health_score || "5/10"
    };
  }
  
  // If it's already in our format, just ensure we have ingredient_macros
  const formattedData = { ...data };
  
  // Extract top-level micronutrients if available
  const topLevelVitamins = formattedData.vitamins || {};
  const topLevelMinerals = formattedData.minerals || {};
  const topLevelOtherNutrients = formattedData.other_nutrients || {};

  // Format vitamins with proper units if not already structured
  if (topLevelVitamins) {
    Object.keys(topLevelVitamins).forEach(key => {
      const value = topLevelVitamins[key];
      const normalizedKey = normalizeNutrientKey(key);
      
      if (typeof value !== 'object' || !value.hasOwnProperty('amount')) {
        topLevelVitamins[normalizedKey] = {
          amount: typeof value === 'number' ? value : parseFloat(value) || 0,
          unit: getUnitForVitamin(normalizedKey)
        };
      }
    });
    formattedData.vitamins = topLevelVitamins;
  }

  // Format minerals with proper units if not already structured
  if (topLevelMinerals) {
    Object.keys(topLevelMinerals).forEach(key => {
      const value = topLevelMinerals[key];
      const normalizedKey = normalizeNutrientKey(key);
      
      if (typeof value !== 'object' || !value.hasOwnProperty('amount')) {
        topLevelMinerals[normalizedKey] = {
          amount: typeof value === 'number' ? value : parseFloat(value) || 0,
          unit: getUnitForMineral(normalizedKey)
        };
      }
    });
    formattedData.minerals = topLevelMinerals;
  }

  // Format other nutrients with proper units if not already structured
  if (topLevelOtherNutrients) {
    Object.keys(topLevelOtherNutrients).forEach(key => {
      const value = topLevelOtherNutrients[key];
      const normalizedKey = normalizeNutrientKey(key);
      
      if (typeof value !== 'object' || !value.hasOwnProperty('amount')) {
        topLevelOtherNutrients[normalizedKey] = {
          amount: typeof value === 'number' ? value : parseFloat(value) || 0,
          unit: getUnitForNutrient(normalizedKey)
        };
      }
    });
    formattedData.other_nutrients = topLevelOtherNutrients;
  }

  // Ensure ingredient_macros exists and has same length as ingredients
  if (!formattedData.ingredient_macros || 
      !Array.isArray(formattedData.ingredient_macros) || 
      (formattedData.ingredients && 
       formattedData.ingredients.length !== formattedData.ingredient_macros.length)) {
    
    formattedData.ingredient_macros = [];
    
    // Create macro objects for each ingredient
    const ingredientCount = formattedData.ingredients ? formattedData.ingredients.length : 0;
    for (let i = 0; i < ingredientCount; i++) {
      formattedData.ingredient_macros.push({
        protein: 0,
        fat: 0,
        carbs: 0,
        
        // Add micronutrients to each ingredient
        vitamins: { ...topLevelVitamins },
        minerals: { ...topLevelMinerals },
        other_nutrients: { ...topLevelOtherNutrients }
      });
    }
  } else {
    // Add micronutrients to existing ingredient_macros objects
    formattedData.ingredient_macros.forEach(macro => {
      if (!macro.vitamins) macro.vitamins = { ...topLevelVitamins };
      if (!macro.minerals) macro.minerals = { ...topLevelMinerals };
      if (!macro.other_nutrients) macro.other_nutrients = { ...topLevelOtherNutrients };
    });
  }
  
  return formattedData;
}

// Helper function to normalize nutrient keys
function normalizeNutrientKey(key) {
  if (!key) return '';
  
  // Convert to lowercase
  let normalizedKey = key.toLowerCase();
  
  // Replace spaces with underscores
  normalizedKey = normalizedKey.replace(/\s+/g, '_');
  
  // Handle vitamin prefix formatting
  if (/^vitamin\s*[a-z\d]+$/i.test(normalizedKey)) {
    normalizedKey = normalizedKey.replace(/^vitamin\s*([a-z\d]+)$/i, 'vitamin_$1');
  }
  
  return normalizedKey;
}

// Helper function to get unit for vitamins
function getUnitForVitamin(vitaminName) {
  vitaminName = vitaminName.toLowerCase();
  
  // Common vitamin units
  if (vitaminName.includes('vitamin_d')) return 'IU';
  if (vitaminName.includes('vitamin_a')) return 'IU';
  if (vitaminName.includes('vitamin_e')) return 'mg';
  if (vitaminName.includes('vitamin_k')) return 'μg';
  if (vitaminName.includes('vitamin_c')) return 'mg';
  if (vitaminName.includes('vitamin_b12')) return 'μg';
  if (vitaminName.includes('folate') || 
      vitaminName.includes('folic') || 
      vitaminName.includes('vitamin_b9')) return 'μg';
  if (vitaminName.includes('niacin') || 
      vitaminName.includes('vitamin_b3')) return 'mg';
  if (vitaminName.includes('riboflavin') || 
      vitaminName.includes('vitamin_b2')) return 'mg';
  if (vitaminName.includes('thiamin') || 
      vitaminName.includes('vitamin_b1')) return 'mg';
      
  // Default unit for vitamins
  return 'mg';
}

// Helper function to get unit for minerals
function getUnitForMineral(mineralName) {
  mineralName = mineralName.toLowerCase();
  
  // Common mineral units
  if (mineralName.includes('sodium') || 
      mineralName.includes('potassium') || 
      mineralName.includes('calcium') ||
      mineralName.includes('phosphorus') ||
      mineralName.includes('magnesium')) return 'mg';
  if (mineralName.includes('iron') || 
      mineralName.includes('zinc') ||
      mineralName.includes('manganese') ||
      mineralName.includes('copper')) return 'mg';
  if (mineralName.includes('selenium') ||
      mineralName.includes('chromium') ||
      mineralName.includes('molybdenum') ||
      mineralName.includes('iodine')) return 'μg';
      
  // Default unit for minerals
  return 'mg';
}

// Helper function to get unit for other nutrients
function getUnitForNutrient(nutrientName) {
  nutrientName = nutrientName.toLowerCase();
  
  // Common nutrient units
  if (nutrientName.includes('fiber') || 
      nutrientName.includes('sugar') || 
      nutrientName.includes('starch')) return 'g';
  if (nutrientName.includes('cholesterol')) return 'mg';
  if (nutrientName.includes('caffeine')) return 'mg';
  if (nutrientName.includes('alcohol')) return 'g';
  
  // Default unit
  return 'g';
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
      ingredients.push("Mixed ingredients (100g) 200kcal");
      ingredientMacros.push({
        protein: 10.0,
        fat: 7.0,
        carbs: 30.0,
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
      "Mixed ingredients (100g) 200kcal"
    ],
    ingredient_macros: [
      {
        protein: 10,
        fat: 7,
        carbs: 30,
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

// Start the server
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`API Key configured: ${process.env.OPENAI_API_KEY ? 'Yes' : 'No'}`);
  console.log(`Allowed origins: ${allowedOrigins.join(', ')}`);
});

// Error handling for unhandled promises
process.on('unhandledRejection', (error) => {
  console.error('Unhandled Promise Rejection:', error);
}); 