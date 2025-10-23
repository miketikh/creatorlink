#!/bin/bash

# CreatorLink AI Service Startup Script
# This script starts the FastAPI server with proper environment configuration

echo "======================================"
echo "CreatorLink AI Service"
echo "======================================"
echo ""

# Check if .env file exists
if [ ! -f .env ]; then
    echo "ERROR: .env file not found!"
    echo "Please create a .env file with required environment variables."
    echo "See .env.example for reference."
    exit 1
fi

echo "Loading environment variables from .env..."
export $(cat .env | grep -v '^#' | xargs)

# Check if venv exists
if [ -d "venv" ]; then
    echo "Activating virtual environment..."
    source venv/bin/activate
else
    echo "WARNING: Virtual environment not found at ./venv"
    echo "Run: python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt"
fi

# Get HOST and PORT from environment (with defaults)
HOST=${HOST:-0.0.0.0}
PORT=${PORT:-8000}

echo ""
echo "Starting FastAPI server..."
echo "Host: $HOST"
echo "Port: $PORT"
echo "Mode: Development (auto-reload enabled)"
echo ""
echo "Access the service at:"
echo "  - API: http://localhost:$PORT"
echo "  - Docs: http://localhost:$PORT/docs"
echo "  - Health: http://localhost:$PORT/health"
echo ""
echo "Press Ctrl+C to stop the server"
echo "======================================"
echo ""

# Start uvicorn server
uvicorn app.main:app --host $HOST --port $PORT --reload "$@"
