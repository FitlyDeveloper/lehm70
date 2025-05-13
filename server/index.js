const express = require('express');
const axios = require('axios');
const cors = require('cors');
const app = express();
const port = process.env.PORT || 3000;

app.use(express.json());
app.use(cors());

// Root route for simple health check
app.get('/', (req, res) => {
  res.json({
    "message": "Food Analyzer API Server",
    "status": "operational"
  });
});

// API endpoint for food fixing
app.post('/api/fix-food', async (req, res) => {
  try {
    const { query, instructions, operation_type, food_data } = req.body;
    
    console.log('Received fix-food request:', JSON.stringify(req.body, null, 2));
    
    // Create a comprehensive prompt for DeepSeek
    let prompt = "Analyze and modify the following food based on instructions:\n\n";
    
    if (food_data) {
      prompt += `Food: ${food_data.name || 'Unknown'}\n`;
      prompt += `Total calories: ${food_data.calories || '0'}\n`;
      prompt += `Total protein: ${food_data.protein || '0'}\n`;
      prompt += `Total fat: ${food_data.fat || '0'}\n`;
      prompt += `Total carbs: ${food_data.carbs || '0'}\n`;
      prompt += `Total cholesterol: ${food_data.cholesterol || '0 mg'}\n`;
      prompt += `Total omega-3: ${food_data.omega_3 || '0 mg'}\n`;
      prompt += `Total omega-6: ${food_data.omega_6 || '0 g'}\n`;
      
      if (food_data.ingredients && Array.isArray(food_data.ingredients)) {
        prompt += "Ingredients:\n";
        food_data.ingredients.forEach(ingredient => {
          let ingredientInfo = `- ${ingredient.name} (${ingredient.amount}): ${ingredient.calories} calories, ${ingredient.protein}g protein, ${ingredient.fat}g fat, ${ingredient.carbs}g carbs`;
          if (ingredient.cholesterol) ingredientInfo += `, ${ingredient.cholesterol}mg cholesterol`;
          if (ingredient.omega_3) ingredientInfo += `, ${ingredient.omega_3}mg omega-3`;
          if (ingredient.omega_6) ingredientInfo += `, ${ingredient.omega_6}g omega-6`;
          prompt += ingredientInfo + '\n';
        });
      }
    }
    
    prompt += `\nInstruction: ${instructions || query || 'Analyze and improve this food'}\n`;
    if (operation_type) {
      prompt += `Operation type: ${operation_type}\n`;
    }
    
    prompt += "\nPlease respond with a valid JSON object using this structure:";
    prompt += `
{
  "name": "Updated Food Name",
  "calories": 123,
  "protein": 30,
  "fat": 5,
  "carbs": 20,
  "cholesterol": 10,
  "omega_3": 150,
  "omega_6": 2.5,
  "ingredients": [
    {
      "name": "Ingredient 1",
      "amount": "100g",
      "calories": 100,
      "protein": 10,
      "fat": 2,
      "carbs": 5,
      "cholesterol": 5,
      "omega_3": 50,
      "omega_6": 1.0
    },
    {
      "name": "Ingredient 2",
      "amount": "50g",
      "calories": 50,
      "protein": 5,
      "fat": 1,
      "carbs": 3,
      "cholesterol": 5,
      "omega_3": 100,
      "omega_6": 1.5
    }
  ],
  "other_nutrients": {
    "cholesterol": {
      "amount": 10,
      "unit": "mg"
    },
    "omega_3": {
      "amount": 150,
      "unit": "mg"
    },
    "omega_6": {
      "amount": 2.5,
      "unit": "g"
    }
  }
}`;
    
    console.log('Sending prompt to DeepSeek API:', prompt);
    
    // Call DeepSeek API
    const response = await axios.post(
      'https://api.deepseek.com/v1/chat/completions',
      {
        model: "deepseek-chat",
        messages: [
          {
            role: "system", 
            content: "You are a nutrition expert specialized in analyzing and improving food recipes. Always respond with valid JSON. Always include values for cholesterol (in mg), omega-3 fatty acids (in mg), and omega-6 fatty acids (in g) in both the root level and in a nested 'other_nutrients' object with proper units. For eggs and animal products, be particularly accurate with cholesterol values. For fatty fish, nuts, and plant oils, be accurate with omega-3 and omega-6 values."
          },
          {
            role: "user", 
            content: prompt
          }
        ],
        temperature: 0.3,
        response_format: { type: "json_object" }
      },
      {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${process.env.DEEPSEEK_API_KEY}`
        }
      }
    );
    
    // Return the content from DeepSeek API
    const resultContent = response.data.choices[0].message.content;
    console.log('Received response from DeepSeek:', resultContent.substring(0, 200) + '...');
    
    try {
      const parsedContent = JSON.parse(resultContent);
      console.log('Successfully parsed JSON response');
      res.json({
        success: true,
        data: parsedContent
      });
    } catch (parseError) {
      console.error('Error parsing JSON from DeepSeek:', parseError);
      // Try to extract JSON from the text if possible
      const jsonMatch = resultContent.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        try {
          const extractedJson = JSON.parse(jsonMatch[0]);
          console.log('Extracted JSON from response text');
          res.json({
            success: true,
            data: extractedJson
          });
        } catch (e) {
          res.status(500).json({
            success: false,
            error: `Error parsing JSON from response: ${parseError.message}`,
            rawContent: resultContent
          });
        }
      } else {
        res.status(500).json({
          success: false,
          error: `Error parsing JSON from response: ${parseError.message}`,
          rawContent: resultContent
        });
      }
    }
  } catch (error) {
    console.error('Error:', error.message);
    if (error.response) {
      console.error('Response data:', error.response.data);
      console.error('Response status:', error.response.status);
    }
    res.status(500).json({
      success: false,
      error: `Error processing request: ${error.message}`,
      details: error.response ? error.response.data : null
    });
  }
});

// API endpoint for nutrition calculation
app.post('/api/nutrition', async (req, res) => {
  try {
    const { food_name, serving_size, query, request_type, current_data, operation_type, instructions } = req.body;
    
    console.log('Received nutrition request:', JSON.stringify(req.body, null, 2));
    
    // Create a prompt for the nutrition calculation
    let prompt = "Calculate accurate nutrition values for the following food:";
    if (food_name) {
      prompt += `\nFood: ${food_name}`;
    }
    if (serving_size) {
      prompt += `\nServing size: ${serving_size}`;
    }
    
    // Handle complex food modification requests (compatibility with Flutter app)
    if (current_data) {
      prompt = "Analyze and modify the following food based on instructions:\n\n";
      
      prompt += `Food: ${food_name || 'Unknown'}\n`;
      
      if (current_data.calories) prompt += `Total calories: ${current_data.calories}\n`;
      if (current_data.protein) prompt += `Total protein: ${current_data.protein}\n`;
      if (current_data.fat) prompt += `Total fat: ${current_data.fat}\n`;
      if (current_data.carbs) prompt += `Total carbs: ${current_data.carbs}\n`;
      if (current_data.cholesterol) prompt += `Total cholesterol: ${current_data.cholesterol}\n`;
      if (current_data.omega_3) prompt += `Total omega-3: ${current_data.omega_3}\n`;
      if (current_data.omega_6) prompt += `Total omega-6: ${current_data.omega_6}\n`;
      
      if (current_data.ingredients && Array.isArray(current_data.ingredients)) {
        prompt += "Ingredients:\n";
        current_data.ingredients.forEach(ingredient => {
          let ingredientInfo = `- ${ingredient.name} (${ingredient.amount}): ${ingredient.calories} calories, ${ingredient.protein}g protein, ${ingredient.fat}g fat, ${ingredient.carbs}g carbs`;
          if (ingredient.cholesterol) ingredientInfo += `, ${ingredient.cholesterol}mg cholesterol`;
          if (ingredient.omega_3) ingredientInfo += `, ${ingredient.omega_3}mg omega-3`;
          if (ingredient.omega_6) ingredientInfo += `, ${ingredient.omega_6}g omega-6`;
          prompt += ingredientInfo + '\n';
        });
      }
      
      prompt += `\nInstruction: ${instructions || 'Analyze and improve this food'}\n`;
      if (operation_type) {
        prompt += `Operation type: ${operation_type}\n`;
      }
      
      prompt += "\nPlease respond with a valid JSON object using this structure:";
      prompt += `
{
  "name": "Updated Food Name",
  "calories": 123,
  "protein": 30,
  "fat": 5,
  "carbs": 20,
  "cholesterol": 10,
  "omega_3": 150,
  "omega_6": 2.5,
  "ingredients": [
    {
      "name": "Ingredient 1",
      "amount": "100g",
      "calories": 100,
      "protein": 10,
      "fat": 2,
      "carbs": 5,
      "cholesterol": 5,
      "omega_3": 50,
      "omega_6": 1.0
    },
    {
      "name": "Ingredient 2",
      "amount": "50g",
      "calories": 50,
      "protein": 5,
      "fat": 1,
      "carbs": 3,
      "cholesterol": 5,
      "omega_3": 100,
      "omega_6": 1.5
    }
  ],
  "other_nutrients": {
    "cholesterol": {
      "amount": 10,
      "unit": "mg"
    },
    "omega_3": {
      "amount": 150,
      "unit": "mg"
    },
    "omega_6": {
      "amount": 2.5,
      "unit": "g"
    }
  }
}`;
    }
    else if (query) {
      prompt += `\nQuery: ${query}`;
      
      prompt += "\n\nPlease provide a valid JSON response with the following structure:";
      prompt += `
{
  "calories": 250,
  "protein": 20,
  "fat": 10, 
  "carbs": 15,
  "cholesterol": 10,
  "omega_3": 150,
  "omega_6": 2.5,
  "other_nutrients": {
    "cholesterol": {
      "amount": 10,
      "unit": "mg"
    },
    "omega_3": {
      "amount": 150,
      "unit": "mg"
    },
    "omega_6": {
      "amount": 2.5,
      "unit": "g"
    }
  }
}`;
    }
    else {
      // Standard nutrition calculation for a food name and serving size
      prompt += "\n\nPlease always include detailed micronutrient information in your response, including: cholesterol (in mg), omega-3 fatty acids (in mg), and omega-6 fatty acids (in g).";
      
      prompt += "\n\nPlease provide a valid JSON response with the following structure:";
      prompt += `
{
  "calories": 250,
  "protein": 20,
  "fat": 10, 
  "carbs": 15,
  "cholesterol": 10,
  "omega_3": 150,
  "omega_6": 2.5,
  "other_nutrients": {
    "cholesterol": {
      "amount": 10,
      "unit": "mg"
    },
    "omega_3": {
      "amount": 150,
      "unit": "mg"
    },
    "omega_6": {
      "amount": 2.5,
      "unit": "g"
    }
  }
}`;
    }
    
    console.log('Sending prompt to DeepSeek API:', prompt);
    
    // Call DeepSeek API
    const response = await axios.post(
      'https://api.deepseek.com/v1/chat/completions',
      {
        model: "deepseek-chat",
        messages: [
          {
            role: "system", 
            content: "You are a specialized nutrition calculator. Analyze food ingredients and provide accurate nutrition information in valid JSON format. Always include values for cholesterol (in mg), omega-3 fatty acids (in mg), and omega-6 fatty acids (in g) in both the root level and in a nested 'other_nutrients' object with proper units. For eggs and animal products, be particularly accurate with cholesterol values. For fatty fish, nuts, and plant oils, be accurate with omega-3 and omega-6 values."
          },
          {
            role: "user", 
            content: prompt
          }
        ],
        temperature: 0.2,
        response_format: { type: "json_object" }
      },
      {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${process.env.DEEPSEEK_API_KEY}`
        }
      }
    );
    
    // Return the content from DeepSeek API
    const resultContent = response.data.choices[0].message.content;
    console.log('Received response from DeepSeek:', resultContent.substring(0, 200) + '...');
    
    try {
      const parsedContent = JSON.parse(resultContent);
      console.log('Successfully parsed JSON response');
      res.json({
        success: true,
        data: parsedContent
      });
    } catch (parseError) {
      console.error('Error parsing JSON from DeepSeek:', parseError);
      // Try to extract JSON from the text if possible
      const jsonMatch = resultContent.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        try {
          const extractedJson = JSON.parse(jsonMatch[0]);
          console.log('Extracted JSON from response text');
          res.json({
            success: true,
            data: extractedJson
          });
        } catch (e) {
          res.status(500).json({
            success: false,
            error: `Error parsing JSON from response: ${parseError.message}`,
            rawContent: resultContent
          });
        }
      } else {
        res.status(500).json({
          success: false,
          error: `Error parsing JSON from response: ${parseError.message}`,
          rawContent: resultContent
        });
      }
    }
  } catch (error) {
    console.error('Error:', error.message);
    if (error.response) {
      console.error('Response data:', error.response.data);
      console.error('Response status:', error.response.status);
    }
    res.status(500).json({
      success: false,
      error: `Error processing request: ${error.message}`,
      details: error.response ? error.response.data : null
    });
  }
});

// API endpoint for analyzing food ingredients
app.post('/api/analyze-food', async (req, res) => {
  try {
    const { food_name, serving_size, messages, operation_type } = req.body;
    
    console.log('Received analyze-food request:', JSON.stringify(req.body, null, 2));
    
    // Create a prompt for detailed food analysis with emphasis on micronutrients
    let prompt = "Analyze the following food ingredient in detail:";
    if (food_name) {
      prompt += `\nFood: ${food_name}`;
    }
    if (serving_size) {
      prompt += `\nServing size: ${serving_size}`;
    }
    
    // Add operation type if provided (e.g., NUTRITION_CALCULATION)
    if (operation_type) {
      prompt += `\nOperation: ${operation_type}`;
    }
    
    // Add special instructions for micronutrient analysis
    prompt += `\n\nPlease analyze this food and provide detailed nutrition information, with special focus on cholesterol, omega-3, and omega-6 content. If this is an animal product like egg, meat, or dairy, be particularly accurate with cholesterol values. If this is a fatty fish, nut, seed, or plant oil, be accurate with omega-3 and omega-6 values.`;
    
    // Define the expected JSON response format
    prompt += `\n\nPlease respond with a valid JSON object using this structure:
{
  "name": "${food_name || 'Food Name'}",
  "serving_size": "${serving_size || 'Serving Size'}",
  "calories": 123,
  "protein": 10,
  "fat": 5,
  "carbs": 15,
  "cholesterol": 10,
  "omega_3": 150,
  "omega_6": 2.5,
  "vitamins": {
    "vitamin_a": {
      "amount": 100,
      "unit": "mcg"
    },
    "vitamin_c": {
      "amount": 10,
      "unit": "mg"
    },
    // other vitamins...
  },
  "minerals": {
    "calcium": {
      "amount": 100,
      "unit": "mg"
    },
    "iron": {
      "amount": 2,
      "unit": "mg"
    },
    // other minerals...
  },
  "other_nutrients": {
    "cholesterol": {
      "amount": 10,
      "unit": "mg"
    },
    "omega_3": {
      "amount": 150,
      "unit": "mg"
    },
    "omega_6": {
      "amount": 2.5,
      "unit": "g"
    },
    "fiber": {
      "amount": 3,
      "unit": "g"
    }
  }
}`;
    
    console.log('Sending prompt to DeepSeek API for food analysis:', prompt);
    
    // Determine what prompting approach to use based on request
    let systemPrompt = "You are a specialized nutrition analyzer that provides accurate, detailed nutrition information for food ingredients. Always use scientific data sources and provide accurate values in the right units. Always include values for cholesterol (in mg), omega-3 fatty acids (in mg), and omega-6 fatty acids (in g) in both the root level and in the nested 'other_nutrients' object.";
    let userPrompts = [];
    
    // If messages array is provided (for back compatibility), use that instead
    if (messages && Array.isArray(messages) && messages.length > 0) {
      const customMessages = messages.map(msg => {
        return {
          role: msg.role || "user",
          content: msg.content || ""
        };
      });
      
      // Add micronutrient requirement to the system message
      if (customMessages[0].role === "system") {
        customMessages[0].content += " Always include cholesterol, omega-3, and omega-6 values.";
      } else {
        customMessages.unshift({
          role: "system",
          content: systemPrompt
        });
      }
      
      // Call DeepSeek with custom messages
      const response = await axios.post(
        'https://api.deepseek.com/v1/chat/completions',
        {
          model: "deepseek-chat",
          messages: customMessages,
          temperature: 0.2,
          response_format: { type: "json_object" }
        },
        {
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${process.env.DEEPSEEK_API_KEY}`
          }
        }
      );
      
      // Process response as usual
      const resultContent = response.data.choices[0].message.content;
      console.log('Received response from DeepSeek:', resultContent.substring(0, 200) + '...');
      
      try {
        const parsedContent = JSON.parse(resultContent);
        console.log('Successfully parsed JSON response');
        res.json({
          success: true,
          data: parsedContent
        });
      } catch (parseError) {
        // Try to extract JSON from text if needed
        const jsonMatch = resultContent.match(/\{[\s\S]*\}/);
        if (jsonMatch) {
          try {
            const extractedJson = JSON.parse(jsonMatch[0]);
            console.log('Extracted JSON from response text');
            res.json({
              success: true,
              data: extractedJson
            });
          } catch (e) {
            res.status(500).json({
              success: false,
              error: `Error parsing JSON from response: ${parseError.message}`,
              rawContent: resultContent
            });
          }
        } else {
          res.status(500).json({
            success: false,
            error: `Error parsing JSON from response: ${parseError.message}`,
            rawContent: resultContent
          });
        }
      }
    } else {
      // Use the standard prompt approach
      const response = await axios.post(
        'https://api.deepseek.com/v1/chat/completions',
        {
          model: "deepseek-chat",
          messages: [
            {
              role: "system",
              content: systemPrompt
            },
            {
              role: "user",
              content: prompt
            }
          ],
          temperature: 0.2,
          response_format: { type: "json_object" }
        },
        {
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${process.env.DEEPSEEK_API_KEY}`
          }
        }
      );
      
      // Process response
      const resultContent = response.data.choices[0].message.content;
      console.log('Received response from DeepSeek:', resultContent.substring(0, 200) + '...');
      
      try {
        const parsedContent = JSON.parse(resultContent);
        console.log('Successfully parsed JSON response');
        res.json({
          success: true,
          data: parsedContent
        });
      } catch (parseError) {
        // Try to extract JSON from text if needed
        const jsonMatch = resultContent.match(/\{[\s\S]*\}/);
        if (jsonMatch) {
          try {
            const extractedJson = JSON.parse(jsonMatch[0]);
            console.log('Extracted JSON from response text');
            res.json({
              success: true,
              data: extractedJson
            });
          } catch (e) {
            res.status(500).json({
              success: false,
              error: `Error parsing JSON from response: ${parseError.message}`,
              rawContent: resultContent
            });
          }
        } else {
          res.status(500).json({
            success: false,
            error: `Error parsing JSON from response: ${parseError.message}`,
            rawContent: resultContent
          });
        }
      }
    }
  } catch (error) {
    console.error('Error in analyze-food endpoint:', error.message);
    if (error.response) {
      console.error('Response data:', error.response.data);
      console.error('Response status:', error.response.status);
    }
    res.status(500).json({
      success: false,
      error: `Error processing food analysis request: ${error.message}`,
      details: error.response ? error.response.data : null
    });
  }
});

// Start the server
app.listen(port, () => {
  console.log(`Food Analyzer API Server listening on port ${port}`);
  console.log(`API key present: ${process.env.DEEPSEEK_API_KEY ? 'Yes' : 'No'}`);
}); 