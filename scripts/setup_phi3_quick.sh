#!/bin/bash
# Quick setup with Phi-3 Mini for immediate testing

echo "Setting up Phi-3 Mini (lightweight, 2.3GB)..."

cd ~/cladari_ai || mkdir -p ~/cladari_ai && cd ~/cladari_ai

# Setup venv if needed
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi
source venv/bin/activate

# Install vLLM
pip install vllm transformers torch

# Download Phi-3 Mini (only 2.3GB!)
echo "Downloading Phi-3 Mini..."
huggingface-cli download microsoft/Phi-3-mini-4k-instruct \
    --local-dir ./models/phi-3-mini \
    --local-dir-use-symlinks False

# Start Phi-3
echo "Starting Phi-3 Mini..."
python -m vllm.entrypoints.openai.api_server \
    --model ./models/phi-3-mini \
    --port 8090 \
    --host 0.0.0.0 \
    --gpu-memory-utilization 0.3 \
    --dtype auto \
    > ~/cladari_ai/phi3.log 2>&1 &

echo "Phi-3 Mini started on port 8090 (PID: $!)"
echo "This uses minimal GPU memory and is perfect for testing!"
