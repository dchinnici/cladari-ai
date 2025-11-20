# Cladari AI - Complete Setup Guide

## Overview
This guide covers all setup options from simple local testing to full AI deployment with GPU acceleration.

## Table of Contents
1. [Quick Start (5 minutes)](#quick-start)
2. [Full F1 Setup (30 minutes)](#full-f1-setup)
3. [F2 GPU Setup (2 hours)](#f2-gpu-setup)
4. [Integration Testing](#integration-testing)
5. [Production Deployment](#production-deployment)

---

## Quick Start
*Get running in 5 minutes with rule-based responses*

### Step 1: Verify PlantDB
```bash
# Check if PlantDB is running
curl http://localhost:3000/api/plants | jq '. | length'
# Should return: 70

# If not running, start it:
cd ~/cladari/plantDB
npm run dev
```

### Step 2: Test Local Mode
```bash
cd ~/cladari/ai
python3 local_test.py "How many plants do I have?"
# Output: You have 70 plants in your collection.
```

### Step 3: Start Web UI
```bash
# Use the start script
./start.sh

# Or manually with axo_env
PORT=8091 /Users/davidchinnici/axo_env/bin/python3 server.py
```

### Step 4: Access Interface
Open http://localhost:8091 in your browser

✅ **Done!** You now have a working botanical query system.

---

## Full F1 Setup
*Complete local installation with all features*

### Prerequisites
```bash
# Check Python version
python3 --version  # Should be 3.10+

# Check Node.js
node --version     # Should be v18+

# Check available memory
vm_stat | grep "Pages free"
```

### Step 1: Clone Repository
```bash
cd ~/cladari
git clone https://github.com/dchinnici/cladari-ai.git ai
cd ai
```

### Step 2: Virtual Environment
```bash
# Create dedicated environment
python3 -m venv cladari_env
source cladari_env/bin/activate

# Install dependencies
pip install flask flask-cors requests

# Or use existing axo_env
# Already has all dependencies installed
```

### Step 3: Configure System
```bash
# Copy example config
cp config/cladari_config.example.json config/cladari_config.json

# Edit configuration
nano config/cladari_config.json
```

Configuration options:
```json
{
  "plantdb": {
    "api_url": "http://localhost:3000/api",
    "timeout": 5,
    "cache_ttl": 300
  },
  "ui": {
    "port": 8091,
    "host": "0.0.0.0",
    "debug": false
  },
  "models": {
    "mode": "local"  // local|remote|auto
  }
}
```

### Step 4: Create Launch Scripts
```bash
# Create desktop launcher
cat > ~/Desktop/Start_Cladari_AI.command << 'EOF'
#!/bin/bash
cd ~/cladari/ai
./start.sh
EOF

chmod +x ~/Desktop/Start_Cladari_AI.command
```

### Step 5: Test Installation
```bash
# Run test suite
python3 -m pytest tests/

# Manual test
./test_system.sh
```

---

## F2 GPU Setup
*High-performance AI with NVIDIA RTX 4090*

### F2 Prerequisites
- NVIDIA RTX 4090 (24GB VRAM)
- Ubuntu 22.04 or similar
- CUDA 12.0+
- Python 3.10+
- 64GB+ system RAM

### Step 1: SSH to F2
```bash
ssh f2@100.70.249.44
# Or use your configured alias
ssh f2
```

### Step 2: System Preparation
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install CUDA (if not present)
nvidia-smi  # Check CUDA version

# Install Python dependencies
sudo apt install python3-pip python3-venv git
```

### Step 3: Clone Repository
```bash
cd ~
git clone https://github.com/dchinnici/cladari-ai.git
cd cladari-ai
```

### Step 4: Create Virtual Environment
```bash
python3 -m venv venv
source venv/bin/activate

# Upgrade pip
pip install --upgrade pip
```

### Step 5: Install vLLM
```bash
# Install PyTorch with CUDA support
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# Install vLLM
pip install vllm

# Install additional dependencies
pip install transformers accelerate
```

### Step 6: Download Models

#### Option A: Mistral-Nemo-12B (Recommended)
```bash
# Create models directory
mkdir -p models

# Download Mistral-Nemo (24GB)
huggingface-cli download mistralai/Mistral-Nemo-Instruct-2407 \
  --local-dir ./models/mistral-nemo-12b \
  --local-dir-use-symlinks False

# This will take 15-30 minutes depending on connection
```

#### Option B: PLLaMa-7B (Botanical Specialist)
```bash
# Download PLLaMa
huggingface-cli download AgroverseLLM/PLLaMa-7b \
  --local-dir ./models/pllama-7b \
  --local-dir-use-symlinks False
```

#### Option C: Phi-3 Mini (Quick Test)
```bash
# Lightweight model (2.3GB)
huggingface-cli download microsoft/Phi-3-mini-4k-instruct \
  --local-dir ./models/phi-3-mini \
  --local-dir-use-symlinks False
```

### Step 7: Start vLLM Server

#### For Mistral-Nemo:
```bash
python -m vllm.entrypoints.openai.api_server \
  --model ./models/mistral-nemo-12b \
  --port 8088 \
  --host 0.0.0.0 \
  --gpu-memory-utilization 0.85 \
  --max-model-len 8192 \
  --dtype float16 \
  --trust-remote-code
```

#### For PLLaMa:
```bash
python -m vllm.entrypoints.openai.api_server \
  --model ./models/pllama-7b \
  --port 8089 \
  --host 0.0.0.0 \
  --gpu-memory-utilization 0.5 \
  --max-model-len 4096
```

### Step 8: Create Systemd Service
```bash
# Create service file
sudo nano /etc/systemd/system/cladari-vllm.service
```

Add content:
```ini
[Unit]
Description=Cladari vLLM Server
After=network.target

[Service]
Type=simple
User=f2user
WorkingDirectory=/home/f2user/cladari-ai
Environment="PATH=/home/f2user/cladari-ai/venv/bin"
ExecStart=/home/f2user/cladari-ai/venv/bin/python -m vllm.entrypoints.openai.api_server \
  --model ./models/mistral-nemo-12b \
  --port 8088 \
  --host 0.0.0.0 \
  --gpu-memory-utilization 0.85
Restart=always

[Install]
WantedBy=multi-user.target
```

Enable service:
```bash
sudo systemctl daemon-reload
sudo systemctl enable cladari-vllm
sudo systemctl start cladari-vllm
sudo systemctl status cladari-vllm
```

### Step 9: Test F2 Server
```bash
# From F2
curl http://localhost:8088/v1/models

# From F1
curl http://100.70.249.44:8088/v1/models
```

---

## Integration Testing

### Test Local → PlantDB
```bash
cd ~/cladari/ai
python3 << EOF
from local_test import LocalCladariTest
cladari = LocalCladariTest()
print(cladari.query("How many plants?"))
EOF
```

### Test F1 → F2 AI
```bash
# Test connection
curl -X POST http://100.70.249.44:8088/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mistral-nemo-12b",
    "prompt": "What are the best conditions for growing Anthuriums?",
    "max_tokens": 200,
    "temperature": 0.7
  }'
```

### Test Full Stack
```bash
# Start all services
cd ~/cladari/ai
./test_integration.sh

# Should test:
# 1. PlantDB connection ✓
# 2. Local mode queries ✓
# 3. Remote AI queries ✓
# 4. Web UI loading ✓
```

---

## Production Deployment

### Security Hardening
```bash
# Firewall rules (F2)
sudo ufw allow from 100.70.249.42 to any port 8088
sudo ufw enable

# SSL/TLS for web UI
# Use nginx reverse proxy with Let's Encrypt
```

### Performance Optimization

#### F1 Optimizations:
```bash
# Increase cache TTL
export PLANTDB_CACHE_TTL=600

# Enable response caching
export CLADARI_CACHE_RESPONSES=true
```

#### F2 Optimizations:
```bash
# Optimize vLLM
--gpu-memory-utilization 0.95 \
--enable-prefix-caching \
--enable-chunked-prefill \
--max-num-seqs 256
```

### Monitoring Setup
```bash
# Install monitoring
pip install prometheus-client

# Add to server.py
from prometheus_client import start_http_server
start_http_server(8000)  # Metrics on port 8000
```

### Backup Strategy
```bash
# Daily config backup
0 2 * * * tar -czf ~/backups/cladari-$(date +\%Y\%m\%d).tar.gz ~/cladari/ai/config/

# Model backup (one-time)
tar -czf ~/backups/models-cladari.tar.gz ~/cladari-ai/models/
```

---

## Troubleshooting

### Common Issues

#### GPU Out of Memory
```bash
# Reduce memory utilization
--gpu-memory-utilization 0.7

# Use smaller model
--model ./models/phi-3-mini
```

#### Slow Response Times
```bash
# Enable caching
--enable-prefix-caching

# Reduce max tokens
--max-model-len 4096
```

#### Connection Refused
```bash
# Check firewall
sudo ufw status

# Check binding
netstat -tlnp | grep 8088

# Test locally first
curl http://localhost:8088/health
```

---

## Advanced Configuration

### Multi-Model Routing
```python
# In cladari_ai.py
ROUTING_RULES = {
    "identification": "pllama",     # Botanical expertise
    "care_advice": "mistral-nemo",  # General reasoning
    "diagnosis": "specialist",      # Disease expert
    "chat": "phi-3"                # Light conversation
}
```

### Custom Prompts
```python
# In config/prompts.json
{
  "botanical_expert": "You are a botanical expert specializing in Anthurium cultivation...",
  "care_advisor": "Provide specific, actionable plant care advice...",
  "diagnostic": "Analyze plant symptoms and provide diagnosis..."
}
```

### Integration Webhooks
```python
# Notify on important events
WEBHOOKS = {
    "critical_care": "https://your-webhook.com/urgent",
    "weekly_report": "https://your-webhook.com/report"
}
```

---

## Next Steps

1. **Enhance Local Mode**: Add more query patterns
2. **Train Custom LoRA**: Fine-tune on your plant data
3. **Add Vision**: Integrate plant photo analysis
4. **Mobile App**: Create React Native interface
5. **Community Features**: Share knowledge with other growers

---

## Support Resources

- **GitHub**: https://github.com/dchinnici/cladari-ai
- **Documentation**: `/docs` directory
- **Discord**: [Coming Soon]
- **Email**: support@cladari.ai [Coming Soon]

---
*Setup Guide v1.0 - November 2025*