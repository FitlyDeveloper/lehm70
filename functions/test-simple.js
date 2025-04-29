const fs = require('fs');
const path = require('path');
const { analyzeFoodImageImpl, parseResult } = require('./simple');

// Replace with your actual OpenAI API key or use environment variable
const API_KEY = process.env.OPENAI_API_KEY || 'YOUR_API_KEY_HERE';

// Path to a food image for testing (update this path to your test image)
const TEST_IMAGE_PATH = path.join(__dirname, '../test-food-image.jpg');

async function runTest() {
  try {
    // Check if the test image exists
    if (!fs.existsSync(TEST_IMAGE_PATH)) {
      console.error(`Test image not found at: ${TEST_IMAGE_PATH}`);
      console.log('Please place a food image at this location or update the TEST_IMAGE_PATH');
      return;
    }

    console.log(`Reading test image from: ${TEST_IMAGE_PATH}`);
    
    // Read the image file and convert to base64
    const imageBuffer = fs.readFileSync(TEST_IMAGE_PATH);
    const base64Image = `data:image/jpeg;base64,${imageBuffer.toString('base64')}`;
    
    console.log('Analyzing food image...');
    const result = await analyzeFoodImageImpl(base64Image, API_KEY);
    
    console.log('Raw OpenAI response:');
    console.log(result);
    
    console.log('\nParsed result:');
    const parsedResult = parseResult(result);
    console.log(JSON.stringify(parsedResult, null, 2));
    
  } catch (error) {
    console.error('Test failed with error:', error);
  }
}

// Run the test
runTest(); 