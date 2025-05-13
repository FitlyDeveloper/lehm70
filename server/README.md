# DeepSeek API Bridge Server

This server acts as a bridge between your Flutter application and the DeepSeek API. It provides endpoints that match what your app expects while forwarding the requests to DeepSeek's API with the appropriate authentication.

## Endpoints

### Root Endpoint
- **GET /** - Health check endpoint that returns status information

### Food Fix Endpoint
- **POST /api/fix-food** - Endpoint that takes food data and instructions to modify it
  - Request body should include `food_data`, `instructions`, and optional `operation_type`
  - Returns detailed nutrition information including cholesterol, omega-3, and omega-6 values

### Nutrition Calculation Endpoint
- **POST /api/nutrition** - Endpoint that calculates nutrition for a food item
  - Request body should include `food_name` and `serving_size`
  - Returns comprehensive nutrition data including macronutrients and micronutrients
  - Now includes enhanced tracking for cholesterol (mg), omega-3 (mg), and omega-6 (g) values

### Food Analysis Endpoint
- **POST /api/analyze-food** - Specialized endpoint for analyzing single food ingredients
  - Request body should include `food_name` and `serving_size`
  - Returns detailed micronutrient breakdown with special focus on cholesterol, omega-3, and omega-6
  - Useful for the "Add Ingredient" feature in the mobile app

## Response Format

All endpoints now return nutrition data with enhanced micronutrient tracking, including:

```json
{
  "calories": 123,
  "protein": 30,
  "fat": 5,
  "carbs": 20,
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
}
```

## Environment Variables

This server requires the following environment variable:

- `DEEPSEEK_API_KEY` - Your DeepSeek API key

## Running Locally

To run this server locally:

```bash
npm install
npm start
```

For development with auto-restart:

```bash
npm run dev
```

## Deployment

This server is designed to be deployed on Render.com. Make sure to set the `DEEPSEEK_API_KEY` environment variable in your Render.com dashboard. 