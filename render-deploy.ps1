# Script to deploy to Render.com
Write-Host "Starting deployment to Render.com..."

# 1. Copy the fixed server.js that handles missing dotenv gracefully
Write-Host "Copying fix-server.js to server.js..."
Copy-Item -Path "fix-server.js" -Destination "server.js" -Force

# 2. Ensure package.json includes dotenv
Write-Host "Checking package.json..."
$packageJson = @"
{
  "name": "food-analyzer-api",
  "version": "1.0.0",
  "description": "Secure API for food image analysis",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "engines": {
    "node": ">=14.0.0"
  },
  "dependencies": {
    "cors": "^2.8.5",
    "dotenv": "^16.4.1",
    "express": "^4.18.2",
    "express-rate-limit": "^7.1.5",
    "node-fetch": "^2.7.0"
  }
}
"@
Set-Content -Path "package.json" -Value $packageJson

# 3. Create a minimal render.yaml file
Write-Host "Creating render.yaml..."
$renderYaml = @"
services:
  - type: web
    name: snap-food
    env: node
    buildCommand: npm install
    startCommand: node server.js
    envVars:
      - key: PORT
        value: 3000
      - key: OPENAI_API_KEY
        sync: false
      - key: NODE_ENV
        value: production
    domains:
      - snap-food.onrender.com
"@
Set-Content -Path "render.yaml" -Value $renderYaml

Write-Host "Deployment files prepared successfully!"
Write-Host "Run 'git add server.js package.json render.yaml'"
Write-Host "Then commit and push to GitHub to trigger a Render.com deployment." 