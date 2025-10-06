#!/bin/bash
# Quick start script for MACM API Server

echo "🚀 Starting MACM Agent Tools API Server..."

# Check if requirements are installed
python -c "import fastapi, uvicorn" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "📦 Installing dependencies..."
    pip install -r requirements.txt
fi

echo "🌐 Starting server on http://localhost:8080"
echo "📖 API docs will be available at http://localhost:8080/docs"
echo ""

# Navigate to src directory and start the server
cd src
python main.py