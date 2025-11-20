#!/bin/bash
# Run this on F2 to set up the models

echo "Setting up Cladari AI models on F2..."

# Check CUDA
nvidia-smi > /dev/null 2>&1 || { echo "CUDA not available!"; exit 1; }

# Create directories
mkdir -p ~/cladari_ai/{models,logs}
cd ~/cladari_ai

# Setup Python environment
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

source venv/bin/activate

# Install requirements
echo "Installing vLLM and dependencies..."
pip install --upgrade pip
pip install vllm transformers torch accelerate

# Download Mistral-Nemo-12B
echo "Downloading Mistral-Nemo-12B (this may take a while)..."
huggingface-cli download mistralai/Mistral-Nemo-Instruct-2407 \
    --local-dir ./models/mistral-nemo-12b \
    --local-dir-use-symlinks False

# Download PLLaMa-7B (plant specialist)
echo "Downloading PLLaMa-7B botanical model..."
huggingface-cli download zhangtaolab/PLLaMa-7b-base \
    --local-dir ./models/pllama-7b \
    --local-dir-use-symlinks False \
    2>/dev/null || echo "Note: PLLaMa may require access request"

echo "✅ Models downloaded"

# Create service scripts
cat > start_mistral.sh << 'EOF'
#!/bin/bash
source ~/cladari_ai/venv/bin/activate
python -m vllm.entrypoints.openai.api_server \
    --model ~/cladari_ai/models/mistral-nemo-12b \
    --port 8088 \
    --host 0.0.0.0 \
    --gpu-memory-utilization 0.8 \
    --max-model-len 8192 \
    --dtype auto \
    > ~/cladari_ai/logs/mistral.log 2>&1 &
echo "Mistral-Nemo started on port 8088, PID: $!"
EOF

cat > start_pllama.sh << 'EOF'
#!/bin/bash
source ~/cladari_ai/venv/bin/activate
python -m vllm.entrypoints.openai.api_server \
    --model ~/cladari_ai/models/pllama-7b \
    --port 8089 \
    --host 0.0.0.0 \
    --gpu-memory-utilization 0.4 \
    --max-model-len 4096 \
    --dtype auto \
    > ~/cladari_ai/logs/pllama.log 2>&1 &
echo "PLLaMa started on port 8089, PID: $!"
EOF

chmod +x start_*.sh

echo ""
echo "✅ F2 setup complete!"
echo ""
echo "To start the models:"
echo "  ./start_mistral.sh  # Primary botanical AI"
echo "  ./start_pllama.sh   # Specialist plant science"
