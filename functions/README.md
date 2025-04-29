# Firebase Functions for AI Service

This directory contains Firebase Cloud Functions that provide AI capabilities to the Fitly app by connecting to the DeepSeek API and OpenAI Vision API.

## Setup Instructions

### Prerequisites

1. Node.js version 22 or higher
2. Firebase CLI installed (`npm install -g firebase-tools`)
3. A DeepSeek API key from [DeepSeek](https://deepseek.com)
4. An OpenAI API key from [OpenAI Platform](https://platform.openai.com)

### Environment Configuration

1. Set up environment variables for the API keys:

```bash
# Set DeepSeek API key
firebase functions:config:set deepseek.api_key="your_deepseek_api_key_here"

# Set OpenAI API key for Vision API
firebase functions:config:set openai.api_key="your_openai_api_key_here"
```

2. Make the environment variables available locally for testing:

```bash
firebase functions:config:get > .runtimeconfig.json
```

### Installing Dependencies

```bash
cd functions
npm install
```

### Local Testing

```bash
firebase emulators:start --only functions
```

### Deployment

```bash
firebase deploy --only functions
```

## Available Functions

The following Cloud Functions are implemented:

1. `getAIResponse` - Non-streaming API call to DeepSeek
2. `streamAIResponse` - Simulated streaming response for AI chat
3. `analyzeFoodImage` - Analyzes food images using OpenAI Vision API
4. `ping` - A simple function to check if the Firebase Functions are available and working properly

## Usage in Dart

The functions are meant to be called from the Dart code:

### DeepSeek Chat Integration:
```dart
final callable = FirebaseFunctions.instance.httpsCallable('getAIResponse');
final result = await callable.call({'messages': messages});
```

### OpenAI Vision Integration:
```dart
// Convert image to base64
final bytes = await imageFile.readAsBytes();
final base64Image = base64Encode(bytes);

// Call the firebase function
final callable = FirebaseFunctions.instance.httpsCallable('analyzeFoodImage');
final result = await callable.call({'image': base64Image});

// Use the returned analysis
final data = result.data as Map<String, dynamic>;
if (data['success'] == true) {
  final analysis = data['analysis'];
  // Use the nutrition analysis data
}
```

## Demo Mode

For testing purposes, the `analyzeFoodImage` function includes a demo mode that returns sample food analysis data without requiring an actual image. To use this:

```dart
final callable = FirebaseFunctions.instance.httpsCallable('analyzeFoodImage');
final result = await callable.call({}, HttpsCallableOptions(
  timeout: Duration(seconds: 60),
  parameters: {'demo': 'true'}
));
```

## Troubleshooting

- If you encounter CORS issues, ensure your Firebase project has the correct CORS configuration.
- For "Function timeout" errors, check the function logs in the Firebase console and consider increasing the timeout limit.
- If the API returns errors, verify your API key and request format.
- For image analysis issues, ensure images are properly converted to base64 format and aren't too large.

# Food Analysis Firebase Function

This Firebase Cloud Function provides food image analysis using OpenAI's Vision API. The function securely handles API keys and image processing.

## Setup Instructions

### Prerequisites

1. Node.js version 18 or higher
2. Firebase CLI installed (`npm install -g firebase-tools`)
3. An OpenAI API key from [OpenAI Platform](https://platform.openai.com)
4. Firebase project with Blaze (pay-as-you-go) plan enabled (required for external API calls)

### Setting Up the OpenAI API Key

The OpenAI API key is stored securely in Firebase Config, not in the client code. There are two ways to set it up:

#### Option 1: Using the Deploy Script (Recommended)

1. Make the deploy script executable:
   ```bash
   chmod +x deploy.sh
   ```

2. Run the deploy script:
   ```bash
   ./deploy.sh
   ```

   The script will prompt you for your OpenAI API key if it's not already set.

#### Option 2: Manual Setup

1. Set the OpenAI API key in Firebase config:
   ```bash
   firebase functions:config:set openai.api_key="your_openai_api_key_here"
   ```

2. Make the config available for local testing:
   ```bash
   firebase functions:config:get > .runtimeconfig.json
   ```

3. Install dependencies:
   ```bash
   npm install
   ```

4. Deploy the functions:
   ```bash
   firebase deploy --only functions
   ```

### Local Testing

To test locally:

1. Ensure you have the runtime config:
   ```bash
   firebase functions:config:get > .runtimeconfig.json
   ```

2. Start the Firebase emulator:
   ```bash
   firebase emulators:start --only functions
   ```

## Security

- The OpenAI API key is stored securely in Firebase Config, never in client code
- All API calls are made from the server-side function, not from the client
- Error handling is implemented to prevent leaking sensitive information

## Function: analyzeFoodImage

This function takes a base64-encoded image and sends it to OpenAI's Vision API for food analysis.

### Input Parameters

```javascript
{
  "image": "data:image/jpeg;base64,..." // Base64 encoded image with MIME type prefix
}
```

### Response Format

```javascript
{
  "success": true,
  "meal": [
    {
      "dish": "Chicken Salad",
      "calories": 350,
      "macronutrients": {
        "protein": 25,
        "carbohydrates": 15,
        "fat": 20
      },
      "ingredients": ["chicken", "lettuce", "tomato", "avocado"]
    }
  ]
}
```

### Error Handling

If an error occurs, the function will return an error object:

```javascript
{
  "code": "internal", // or "invalid-argument", "unauthenticated", etc.
  "message": "Error message"
}
```

### `ping`

A simple function to check if the Firebase Functions are available and working properly.

**Input:**
- No input required

**Output:**
- String: `"pong"` if the function is working properly

## Testing Food Image Analysis Locally

To test the food image analysis functionality without deploying to Firebase, you can use the provided test script:

1. Place a test food image in the parent directory and name it `test-food-image.jpg` or update the path in the test script.

2. Make sure you have your OpenAI API key:
   - Either set it as an environment variable: `export OPENAI_API_KEY=your_key_here` (Linux/Mac) or `set OPENAI_API_KEY=your_key_here` (Windows)
   - Or edit the test-simple.js file directly to include your key

3. Run the test script:
   ```bash
   node test-simple.js
   ```

4. The script will output:
   - Raw response from OpenAI API
   - Parsed result in JSON format

This local testing helps debug issues with the food analyzer before deploying to Firebase.

# Firebase Functions

This directory contains Firebase Cloud Functions that power the backend of the Fitly App.

## Key Functions

### `analyzeFoodImage`

This function analyzes food images using OpenAI's vision model and returns structured nutrition data.

- **Input**: Base64-encoded image data
- **Output**: JSON object with meal name, ingredients, nutrition values, and health score
- **Features**: 
  - Returns precise integer values for all nutrients
  - Avoids rounding to common numbers for greater accuracy
  - Calculates health score based on ingredient quality

### `streamAIResponse` and `getAIResponse`

These functions handle AI chat interactions.

## Configuration

The functions use environment variables for API keys and configuration.

- Set up `.env` file or Firebase environment configuration
- Required: `OPENAI_API_KEY`

## Development

```bash
# Install dependencies
npm install

# Deploy to Firebase
firebase deploy --only functions
``` 