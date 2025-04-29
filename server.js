// Import required packages
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const fetch = require('node-fetch');
const fs = require('fs'); // For logging to file

// Create Express app
const app = express();
const PORT = process.env.PORT || 3000;

// Debug startup
console.log('Starting server...');
console.log('Node environment:', process.env.NODE_ENV);
console.log('Current directory:', process.cwd());
console.log('OpenAI API Key present:', process.env.OPENAI_API_KEY ? 'Yes' : 'No');

// Configure logging
const logToFile = (message) => {
  const timestamp = new Date().toISOString();
  const logMessage = `${timestamp}: ${message}\n`;
  fs.appendFileSync('api-server.log', logMessage);
  console.log(message);
};

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

// Configure CORS
app.use(cors());

// Body parser middleware
app.use(express.json({ limit: '10mb' }));

// Define routes
app.get('/', (req, res) => {
  res.json({
    message: 'Food Analyzer API Server',
    status: 'operational'
  });
});

// OpenAI proxy endpoint for food analysis
app.post('/api/analyze-food', limiter, async (req, res) => {
  try {
    logToFile('Analyze food endpoint called');
    const { image } = req.body;

    if (!image) {
      logToFile('No image provided in request');
      return res.status(400).json({
        success: false,
        error: 'Image data is required'
      });
    }

    // Debug logging
    logToFile(`Received image data, length: ${image.length}`);
    logToFile(`Image data starts with: ${image.substring(0, 50)}`);

    // Check for API key
    if (!process.env.OPENAI_API_KEY) {
      logToFile('OpenAI API key not configured');
      return res.status(500).json({
        success: false,
        error: 'Server configuration error: OpenAI API key not set'
      });
    }

    // Call OpenAI API
    logToFile('Calling OpenAI API...');
    
    // Force JSON response format
    const requestBody = {
      model: 'gpt-4o',
      temperature: 0.2,
      messages: [
        {
          role: 'system',
          content: '[STRICTLY JSON ONLY] You are a nutrition expert analyzing food images. OUTPUT MUST BE VALID JSON AND NOTHING ELSE.\n\nFORMAT RULES:\n1. Return a single meal name for the entire image (e.g., "Pasta Meal", "Breakfast Plate") WITHOUT "Name:" prefix\n2. List ingredients with weights and calories (e.g., "Pasta (100g) 200kcal")\n3. Return WHOLE NUMBER values for calories, protein, fat, carbs, vitamin C - NEVER include decimal points\n4. Calculate a health score (1-10) based ONLY on ingredient quality and nutritional value:\n\n   HEALTH SCORE CRITERIA:\n   • Positive indicators (+): Whole/unprocessed foods (vegetables, legumes, whole grains, lean meats), healthy fats (olive oil, avocado), high fiber or micronutrient-dense foods (spinach, lentils, salmon)\n   • Negative indicators (-): Highly processed or fried ingredients, high added sugars (syrups, sweetened sauces), high saturated fats (butter, cream, fatty meats), excess sodium (salty sauces, processed meats)\n   • Score meaning: 9-10 (Very healthy), 7-8 (Healthy), 5-6 (Moderate), 3-4 (Unhealthy), 1-2 (Very unhealthy)\n\n5. Use REALISTIC and PRECISE estimates - DO NOT round macronutrient values\n6. DO NOT respond with markdown code blocks or text explanations\n7. DO NOT prefix your response with "json" or ```\n8. ONLY RETURN A RAW JSON OBJECT\n9. FAILURE TO FOLLOW THESE INSTRUCTIONS WILL RESULT IN REJECTION\n\nEXACT FORMAT REQUIRED:\n{\n  "meal_name": "Meal Name",\n  "ingredients": ["Item1 (weight) calories", "Item2 (weight) calories"],\n  "calories": integer,\n  "protein": integer,\n  "fat": integer,\n  "carbs": integer,\n  "vitamin_c": integer,\n  "health_score": "score/10"\n}'
        },
        {
          role: 'user',
          content: [
            {
              type: 'text',
              text: "RETURN ONLY RAW JSON - NO TEXT, NO CODE BLOCKS, NO EXPLANATIONS. Analyze this food image and return nutrition data in this EXACT format with no deviations:\n\n{\n  \"meal_name\": string (single name for entire meal, NO \"Name:\" prefix),\n  \"ingredients\": array of strings with weights and calories,\n  \"calories\": number,\n  \"protein\": number,\n  \"fat\": number,\n  \"carbs\": number,\n  \"vitamin_c\": number,\n  \"health_score\": string\n}"
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
    };
    
    logToFile('OpenAI request payload structure:');
    logToFile(JSON.stringify({
      model: requestBody.model,
      temperature: requestBody.temperature,
      max_tokens: requestBody.max_tokens,
      response_format: requestBody.response_format,
      message_count: requestBody.messages.length
    }));
    
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`
      },
      body: JSON.stringify(requestBody)
    });

    if (!response.ok) {
      const errorData = await response.text();
      logToFile(`OpenAI API error: ${response.status} ${errorData}`);
      return res.status(response.status).json({
        success: false,
        error: `OpenAI API error: ${response.status}`,
        details: errorData
      });
    }

    logToFile('OpenAI API response received');
    const data = await response.json();
    
    // Log the full response structure but not content
    logToFile(`OpenAI response structure: ${JSON.stringify({
      id: data.id,
      object: data.object,
      created: data.created,
      model: data.model,
      choices_count: data.choices ? data.choices.length : 0,
      usage: data.usage
    })}`);
    
    if (!data.choices || 
        !data.choices[0] || 
        !data.choices[0].message || 
        !data.choices[0].message.content) {
      logToFile(`Invalid response format from OpenAI: ${JSON.stringify(data)}`);
      return res.status(500).json({
        success: false,
        error: 'Invalid response from OpenAI',
        raw_response: data
      });
    }

    const content = data.choices[0].message.content;
    logToFile(`OpenAI API response content (first 200 chars): ${content.substring(0, 200)}...`);
    
    // Process and parse the response
    try {
      // First try direct parsing
      const parsedData = JSON.parse(content);
      logToFile('Successfully parsed JSON response');
      logToFile(`Parsed data structure: ${Object.keys(parsedData).join(', ')}`);
      
      return res.json({
        success: true,
        data: parsedData
      });
    } catch (error) {
      logToFile(`Direct JSON parsing failed: ${error.message}`);
      logToFile('Attempting to extract JSON from text');
      
      // Try to extract JSON from the text
      const jsonMatch = content.match(/```json\n([\s\S]*?)\n```/) || 
                      content.match(/\{[\s\S]*\}/);
      
      if (jsonMatch) {
        const jsonContent = jsonMatch[0].replace(/```json\n|```/g, '').trim();
        logToFile(`Found JSON-like content: ${jsonContent.substring(0, 100)}...`);
        
        try {
          const parsedData = JSON.parse(jsonContent);
          logToFile('Successfully extracted and parsed JSON from text');
          return res.json({
            success: true,
            data: parsedData,
            note: 'JSON was extracted from text response'
          });
        } catch (err) {
          logToFile(`JSON extraction failed: ${err.message}`);
          // Return the raw text if JSON parsing fails
          return res.json({
            success: false,
            error: 'Failed to parse JSON',
            data: { text: content }
          });
        }
      } else {
        logToFile('No JSON pattern found in response');
        // Return the raw text if no JSON found
        return res.json({
          success: false,
          error: 'No JSON found in response',
          data: { text: content }
        });
      }
    }
  } catch (error) {
    logToFile(`Server error: ${error.message}`);
    logToFile(error.stack);
    return res.status(500).json({
      success: false,
      error: 'Server error processing request',
      message: error.message
    });
  }
});

// Start the server
app.listen(PORT, () => {
  logToFile(`Server running on port ${PORT}`);
  logToFile(`API Key configured: ${process.env.OPENAI_API_KEY ? 'Yes' : 'No'}`);
}); 