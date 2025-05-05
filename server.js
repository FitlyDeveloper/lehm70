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
    
    // Create ingredient macros array
    const transformedIngredients = ingredientsList.map((ingredient, index) => {
      let ingredientName = typeof ingredient === 'string' ? ingredient : '';
      let ingredientWeight = '30g';
      let ingredientCalories = 75;
      
      // Estimate ingredient macros based on name
      let protein = 0;
      let fat = 0;
      let carbs = 0;
      
      // Try to estimate weights, calories and macros for common ingredients
      if (ingredientName.toLowerCase().includes('pasta') || 
          ingredientName.toLowerCase().includes('noodle')) {
        ingredientWeight = '100g';
        ingredientCalories = 200;
        protein = 7.5;
        fat = 1.1;
        carbs = 43.2;
      } else if (ingredientName.toLowerCase().includes('rice')) {
        ingredientWeight = '100g';
        ingredientCalories = 130;
        protein = 2.7;
        fat = 0.3;
        carbs = 28.2;
      } else if (ingredientName.toLowerCase().includes('bread') || 
                ingredientName.toLowerCase().includes('toast')) {
        ingredientWeight = '60g';
        ingredientCalories = 150;
        protein = 5.4;
        fat = 1.8;
        carbs = 28.2;
      } else if (ingredientName.toLowerCase().includes('potato')) {
        ingredientWeight = '100g';
        ingredientCalories = 80;
        protein = 2.0;
        fat = 0.1;
        carbs = 17.0;
      } else if (ingredientName.toLowerCase().includes('salad') || 
                ingredientName.toLowerCase().includes('lettuce')) {
        ingredientWeight = '50g';
        ingredientCalories = 25;
        protein = 1.2;
        fat = 0.2;
        carbs = 3.0;
      } else if (ingredientName.toLowerCase().includes('tomato')) {
        ingredientWeight = '100g';
        ingredientCalories = 18;
        protein = 0.9;
        fat = 0.2;
        carbs = 3.9;
      } else if (ingredientName.toLowerCase().includes('cheese')) {
        ingredientWeight = '30g';
        ingredientCalories = 120;
        protein = 7.8;
        fat = 9.9;
        carbs = 0.4;
      } else if (ingredientName.toLowerCase().includes('milk')) {
        ingredientWeight = '100ml';
        ingredientCalories = 42;
        protein = 3.4;
        fat = 1.0;
        carbs = 5.0;
      } else if (ingredientName.toLowerCase().includes('egg')) {
        ingredientWeight = '50g';
        ingredientCalories = 78;
        protein = 6.3;
        fat = 5.3;
        carbs = 0.6;
      } else if (ingredientName.toLowerCase().includes('chicken') || 
                ingredientName.toLowerCase().includes('poultry')) {
        ingredientWeight = '100g';
        ingredientCalories = 165;
        protein = 31.0;
        fat = 3.6;
        carbs = 0.0;
      } else if (ingredientName.toLowerCase().includes('beef') || 
                ingredientName.toLowerCase().includes('steak')) {
        ingredientWeight = '100g';
        ingredientCalories = 250;
        protein = 26.0;
        fat = 17.0;
        carbs = 0.0;
      } else if (ingredientName.toLowerCase().includes('pork')) {
        ingredientWeight = '100g';
        ingredientCalories = 242;
        protein = 29.0;
        fat = 14.0;
        carbs = 0.0;
      } else if (ingredientName.toLowerCase().includes('fish') || 
                ingredientName.toLowerCase().includes('salmon')) {
        ingredientWeight = '100g';
        ingredientCalories = 206;
        protein = 22.0;
        fat = 13.0;
        carbs = 0.0;
      } else if (ingredientName.toLowerCase().includes('meat') || 
                ingredientName.toLowerCase().includes('salami')) {
        ingredientWeight = '85g';
        ingredientCalories = 250;
        protein = 25.0;
        fat = 15.0;
        carbs = 0.0;
      } else if (ingredientName.toLowerCase().includes('oil') || 
                ingredientName.toLowerCase().includes('butter')) {
        ingredientWeight = '15g';
        ingredientCalories = 135;
        protein = 0.0;
        fat = 15.0;
        carbs = 0.0;
      } else if (ingredientName.toLowerCase().includes('sugar') || 
                ingredientName.toLowerCase().includes('sweetener')) {
        ingredientWeight = '10g';
        ingredientCalories = 40;
        protein = 0.0;
        fat = 0.0;
        carbs = 10.0;
      } else if (ingredientName.toLowerCase().includes('fruit') || 
                ingredientName.toLowerCase().includes('apple') || 
                ingredientName.toLowerCase().includes('banana')) {
        ingredientWeight = '100g';
        ingredientCalories = 60;
        protein = 0.7;
        fat = 0.3;
        carbs = 14.0;
      } else if (ingredientName.toLowerCase().includes('chocolate') || 
                ingredientName.toLowerCase().includes('candy')) {
        ingredientWeight = '25g';
        ingredientCalories = 130;
        protein = 1.5;
        fat = 8.0;
        carbs = 14.0;
      } else if (ingredientName.toLowerCase().includes('nut') || 
                ingredientName.toLowerCase().includes('peanut') || 
                ingredientName.toLowerCase().includes('almond')) {
        ingredientWeight = '30g';
        ingredientCalories = 180;
        protein = 6.0;
        fat = 16.0;
        carbs = 5.0;
      } else {
        // Default values
        protein = ingredientCalories * 0.15 / 4; // Estimate 15% of calories from protein
        fat = ingredientCalories * 0.30 / 9;     // Estimate 30% of calories from fat
        carbs = ingredientCalories * 0.55 / 4;   // Estimate 55% of calories from carbs
      }
      
      // Save macros for this ingredient with 1 decimal precision
      ingredientMacros.push({
        protein: parseFloat(protein.toFixed(1)),
        fat: parseFloat(fat.toFixed(1)),
        carbs: parseFloat(carbs.toFixed(1))
      });
      
      // Return formatted ingredient text
      if (typeof ingredient === 'string') {
        return `${ingredient} (${ingredientWeight}) ${ingredientCalories}kcal`;
      }
      return ingredient;
    });
    
    return {
      meal_name: mealItem.dish || "Mixed Meal",
      ingredients: transformedIngredients,
      ingredient_macros: ingredientMacros,
      calories: mealItem.calories || 0,
      protein: mealItem.macronutrients?.protein || 0,
      fat: mealItem.macronutrients?.fat || 0,
      carbs: mealItem.macronutrients?.carbohydrates || 0,
      vitamin_c: 1.5, // Default value
      health_score: "7/10" // Default value
    };
  }
  
  // Return a default format if nothing else works
  return {
    meal_name: "Mixed Meal",
    ingredients: [
      "Mixed ingredients (100g) 200kcal"
    ],
    ingredient_macros: [
      {
        protein: 10.5,
        fat: 7.3,
        carbs: 30.2
      }
    ],
    calories: 500,
    protein: 20,
    fat: 15,
    carbs: 60,
    vitamin_c: 2,
    health_score: "6/10"
  };
}

// Helper function to transform raw text to our required format
function transformTextToRequiredFormat(text) {
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
          
          // Customize based on ingredient type - using same logic as above for consistency
          if (ingredient.toLowerCase().includes('pasta') || 
              ingredient.toLowerCase().includes('noodle')) {
            ingredientWeight = '100g';
            ingredientCalories = 200;
            ingredientProtein = 7.5;
            ingredientFat = 1.1;
            ingredientCarbs = 43.2;
          } else if (ingredient.toLowerCase().includes('rice')) {
            ingredientWeight = '100g';
            ingredientCalories = 130;
            ingredientProtein = 2.7;
            ingredientFat = 0.3;
            ingredientCarbs = 28.2;
          } else if (ingredient.toLowerCase().includes('bread') || 
                    ingredient.toLowerCase().includes('toast')) {
            ingredientWeight = '60g';
            ingredientCalories = 150;
            ingredientProtein = 5.4;
            ingredientFat = 1.8;
            ingredientCarbs = 28.2;
          } else if (ingredient.toLowerCase().includes('potato')) {
            ingredientWeight = '100g';
            ingredientCalories = 80;
            ingredientProtein = 2.0;
            ingredientFat = 0.1;
            ingredientCarbs = 17.0;
          } else if (ingredient.toLowerCase().includes('salad') || 
                    ingredient.toLowerCase().includes('lettuce')) {
            ingredientWeight = '50g';
            ingredientCalories = 25;
            ingredientProtein = 1.2;
            ingredientFat = 0.2;
            ingredientCarbs = 3.0;
          } else if (ingredient.toLowerCase().includes('tomato')) {
            ingredientWeight = '100g';
            ingredientCalories = 18;
            ingredientProtein = 0.9;
            ingredientFat = 0.2;
            ingredientCarbs = 3.9;
          } else if (ingredient.toLowerCase().includes('cheese')) {
            ingredientWeight = '30g';
            ingredientCalories = 120;
            ingredientProtein = 7.8;
            ingredientFat = 9.9;
            ingredientCarbs = 0.4;
          } else if (ingredient.toLowerCase().includes('milk')) {
            ingredientWeight = '100ml';
            ingredientCalories = 42;
            ingredientProtein = 3.4;
            ingredientFat = 1.0;
            ingredientCarbs = 5.0;
          } else if (ingredient.toLowerCase().includes('egg')) {
            ingredientWeight = '50g';
            ingredientCalories = 78;
            ingredientProtein = 6.3;
            ingredientFat = 5.3;
            ingredientCarbs = 0.6;
          } else if (ingredient.toLowerCase().includes('chicken') || 
                    ingredient.toLowerCase().includes('poultry')) {
            ingredientWeight = '100g';
            ingredientCalories = 165;
            ingredientProtein = 31.0;
            ingredientFat = 3.6;
            ingredientCarbs = 0.0;
          } else if (ingredient.toLowerCase().includes('beef') || 
                    ingredient.toLowerCase().includes('steak')) {
            ingredientWeight = '100g';
            ingredientCalories = 250;
            ingredientProtein = 26.0;
            ingredientFat = 17.0;
            ingredientCarbs = 0.0;
          } else if (ingredient.toLowerCase().includes('pork')) {
            ingredientWeight = '100g';
            ingredientCalories = 242;
            ingredientProtein = 29.0;
            ingredientFat = 14.0;
            ingredientCarbs = 0.0;
          } else if (ingredient.toLowerCase().includes('fish') || 
                    ingredient.toLowerCase().includes('salmon')) {
            ingredientWeight = '100g';
            ingredientCalories = 206;
            ingredientProtein = 22.0;
            ingredientFat = 13.0;
            ingredientCarbs = 0.0;
          } else if (ingredient.toLowerCase().includes('meat') || 
                    ingredient.toLowerCase().includes('salami')) {
            ingredientWeight = '85g';
            ingredientCalories = 250;
            ingredientProtein = 25.0;
            ingredientFat = 15.0;
            ingredientCarbs = 0.0;
          } else if (ingredient.toLowerCase().includes('oil') || 
                    ingredient.toLowerCase().includes('butter')) {
            ingredientWeight = '15g';
            ingredientCalories = 135;
            ingredientProtein = 0.0;
            ingredientFat = 15.0;
            ingredientCarbs = 0.0;
          } else if (ingredient.toLowerCase().includes('sugar') || 
                    ingredient.toLowerCase().includes('sweetener')) {
            ingredientWeight = '10g';
            ingredientCalories = 40;
            ingredientProtein = 0.0;
            ingredientFat = 0.0;
            ingredientCarbs = 10.0;
          } else if (ingredient.toLowerCase().includes('fruit') || 
                    ingredient.toLowerCase().includes('apple') || 
                    ingredient.toLowerCase().includes('banana')) {
            ingredientWeight = '100g';
            ingredientCalories = 60;
            ingredientProtein = 0.7;
            ingredientFat = 0.3;
            ingredientCarbs = 14.0;
          } else if (ingredient.toLowerCase().includes('chocolate') || 
                    ingredient.toLowerCase().includes('candy')) {
            ingredientWeight = '25g';
            ingredientCalories = 130;
            ingredientProtein = 1.5;
            ingredientFat = 8.0;
            ingredientCarbs = 14.0;
          } else if (ingredient.toLowerCase().includes('nut') || 
                    ingredient.toLowerCase().includes('peanut') || 
                    ingredient.toLowerCase().includes('almond')) {
            ingredientWeight = '30g';
            ingredientCalories = 180;
            ingredientProtein = 6.0;
            ingredientFat = 16.0;
            ingredientCarbs = 5.0;
          } else {
            // Default value calculation
            ingredientProtein = ingredientCalories * 0.15 / 4;
            ingredientFat = ingredientCalories * 0.30 / 9;
            ingredientCarbs = ingredientCalories * 0.55 / 4;
          }
          
          if (ingredient.includes('(') && ingredient.includes(')')) {
            ingredients.push(ingredient);
          } else {
            // Add estimated weight and calories if not provided
            ingredients.push(`${ingredient} (${ingredientWeight}) ${ingredientCalories}kcal`);
          }
          
          // Add macros for this ingredient with 1 decimal precision
          ingredientMacros.push({
            protein: parseFloat(ingredientProtein.toFixed(1)),
            fat: parseFloat(ingredientFat.toFixed(1)),
            carbs: parseFloat(ingredientCarbs.toFixed(1))
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
      health_score: `${healthScore}/10`
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
        carbs: 30
      }
    ],
    calories: 500,
    protein: 20,
    fat: 15,
    carbs: 60,
    vitamin_c: 2,
    health_score: "6/10"
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