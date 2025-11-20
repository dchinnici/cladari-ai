#!/bin/bash
# Quick start script for Cladari AI - uses smaller model for immediate testing

echo "🌿 CLADARI AI - Quick Start"
echo "=========================="
echo ""

# Check PlantDB
if curl -s http://localhost:3000/api/plants > /dev/null 2>&1; then
    echo "✅ PlantDB is running"
else
    echo "⚠️  PlantDB not running. Starting it..."
    cd ~/cladari && ./scripts/dev --bg
    sleep 5
fi

echo ""
echo "For immediate testing, you have 3 options:"
echo ""
echo "OPTION 1: Use existing Hermes on F2 (fastest)"
echo "  Pros: Already running, immediate use"
echo "  Cons: Configured for beliefs, not optimized for plants"
echo ""
echo "OPTION 2: Use Phi-3 Mini (lightweight, fast setup)"
echo "  Pros: Only 2.3GB download, runs well on 4090"
echo "  Cons: Less capable than Mistral-Nemo"
echo ""
echo "OPTION 3: Full setup with Mistral-Nemo (best)"
echo "  Pros: Best quality, optimized for botanical queries"
echo "  Cons: 24GB download, takes ~20 minutes"
echo ""

# Create a temporary test adapter using Phi-3 for quick testing
cat > ~/cladari/ai/quick_test.py << 'PYTHON'
#!/usr/bin/env python3
"""Quick test using Phi-3 Mini or fallback to Hermes"""
import requests
import json

def test_with_phi3(message):
    """Test with Phi-3 Mini (requires setup on F2)"""
    try:
        # Assume Phi-3 is on port 8090
        response = requests.post(
            "http://100.70.249.44:8090/v1/completions",
            json={
                "model": "phi-3",
                "prompt": f"You are a botanical assistant. User: {message}\nAssistant:",
                "max_tokens": 500,
                "temperature": 0.7
            },
            timeout=5
        )
        if response.status_code == 200:
            return response.json()["choices"][0]["text"]
    except:
        pass
    return None

def test_with_hermes(message):
    """Fallback to existing Hermes"""
    try:
        response = requests.post(
            "http://100.70.249.44:9001/v1/chat/completions",
            json={
                "model": "hermes-3-llama-8b",
                "messages": [
                    {"role": "system", "content": "You are a botanical assistant. Answer the user's plant questions."},
                    {"role": "user", "content": message}
                ],
                "max_tokens": 500
            },
            timeout=5
        )
        if response.status_code == 200:
            content = response.json()["choices"][0]["message"]["content"]
            # Clean up belief extraction JSON if present
            if "beliefs" in content:
                lines = content.split('\n')
                clean_lines = [l for l in lines if not l.strip().startswith('{"beliefs')]
                return '\n'.join(clean_lines).strip() or "I can help with your plants."
            return content
    except Exception as e:
        return f"Error: {e}"
    return "Could not connect to AI server"

def get_plant_count():
    """Get actual plant count from PlantDB"""
    try:
        response = requests.get("http://localhost:3000/api/plants", timeout=2)
        if response.status_code == 200:
            plants = response.json()
            return len(plants)
    except:
        pass
    return None

# Test
if __name__ == "__main__":
    import sys
    message = " ".join(sys.argv[1:]) if len(sys.argv) > 1 else "How many plants do I have?"

    # Try to get actual plant count
    count = get_plant_count()
    if count and "how many" in message.lower():
        print(f"You have {count} plants in your collection.")
    else:
        # Try Phi-3 first, then Hermes
        response = test_with_phi3(message)
        if not response:
            response = test_with_hermes(message)
        print(response)
PYTHON

chmod +x ~/cladari/ai/quick_test.py

# Create F2 quick setup for Phi-3
cat > ~/cladari/ai/scripts/setup_phi3_quick.sh << 'SCRIPT'
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
SCRIPT

chmod +x ~/cladari/ai/scripts/setup_phi3_quick.sh

echo ""
echo "Testing connection to F2..."
if timeout 2 curl -s http://100.70.249.44:9001/health > /dev/null; then
    echo "✅ Can reach F2 Hermes - ready for immediate testing!"
    echo ""
    echo "Quick test:"
    python3 ~/cladari/ai/quick_test.py "How many plants are in my collection?"
else
    echo "⚠️  Cannot reach F2. Please check Tailscale connection."
fi

echo ""
echo "To proceed:"
echo ""
echo "1. For immediate testing with Hermes:"
echo "   python3 ~/cladari/ai/quick_test.py 'your question'"
echo ""
echo "2. To set up Phi-3 Mini (quick, 2.3GB):"
echo "   scp ~/cladari/ai/scripts/setup_phi3_quick.sh f2:~/"
echo "   ssh f2 'bash setup_phi3_quick.sh'"
echo ""
echo "3. For full Mistral-Nemo setup (best quality):"
echo "   ssh f2 'bash setup_cladari.sh'"
echo ""
echo "4. Start the Cladari web UI:"
echo "   cd ~/cladari/ai && python3 server.py"
echo "   Then open http://localhost:8090"