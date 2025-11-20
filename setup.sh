#!/bin/bash
# Cladari AI Setup - Clean botanical intelligence system
# Powered by Sovria's consciousness framework

set -e  # Exit on error

echo "🌿 CLADARI AI SETUP"
echo "=================="
echo "Botanical Intelligence System"
echo "Powered by Sovria Consciousness Framework"
echo ""

# Configuration
CLADARI_ROOT="/Users/davidchinnici/cladari"
AI_DIR="$CLADARI_ROOT/ai"
F2_HOST="100.70.249.44"
F2_USER="${F2_USER:-davidchinnici}"  # Adjust if different

# Create directory structure
echo "1. Creating Cladari AI directory structure..."
mkdir -p $AI_DIR/{models,scripts,config,logs,ui}

# Create the main configuration
cat > $AI_DIR/config/cladari_config.json << EOF
{
  "name": "Cladari Botanical AI",
  "version": "1.0.0",
  "powered_by": "Sovria Consciousness Framework",

  "models": {
    "primary": {
      "name": "Mistral-Nemo-12B-Instruct",
      "location": "f2",
      "endpoint": "http://${F2_HOST}:8088",
      "purpose": "General botanical queries, database operations",
      "max_tokens": 2048,
      "temperature": 0.3
    },
    "specialist": {
      "name": "PLLaMa-7B",
      "location": "f2",
      "endpoint": "http://${F2_HOST}:8089",
      "purpose": "Deep botanical science, plant pathology",
      "max_tokens": 1500,
      "temperature": 0.4
    }
  },

  "plantdb": {
    "api_endpoint": "http://localhost:3000/api",
    "database": "$CLADARI_ROOT/plantDB/prisma/dev.db"
  },

  "features": {
    "vision_analysis": true,
    "care_automation": true,
    "disease_diagnosis": true,
    "breeding_recommendations": true
  }
}
EOF

echo "✅ Configuration created"

# Create F2 setup script
cat > $AI_DIR/scripts/setup_f2_models.sh << 'SCRIPT'
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
SCRIPT

chmod +x $AI_DIR/scripts/setup_f2_models.sh

# Create the Python API adapter
cat > $AI_DIR/cladari_ai.py << 'PYTHON'
#!/usr/bin/env python3
"""
Cladari AI - Clean botanical intelligence system
Powered by Sovria consciousness framework
"""
import json
import requests
import logging
from typing import Dict, Optional, List
from pathlib import Path

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("CladariAI")

class CladariAI:
    """Botanical AI with specialized routing"""

    def __init__(self, config_path: str = "config/cladari_config.json"):
        self.config = json.loads(Path(config_path).read_text())
        self.mistral_url = self.config["models"]["primary"]["endpoint"]
        self.pllama_url = self.config["models"]["specialist"]["endpoint"]
        self.plantdb_url = self.config["plantdb"]["api_endpoint"]

        logger.info("🌿 Cladari AI initialized")
        logger.info(f"   Primary: {self.mistral_url}")
        logger.info(f"   Specialist: {self.pllama_url}")

    def query(self, message: str, context: Dict = None) -> str:
        """Route query to appropriate model"""

        # Determine query type
        query_type = self._classify_query(message)

        # Get PlantDB context if needed
        plant_context = self._get_plant_context(message) if self._is_plant_query(message) else ""

        # Route to appropriate model
        if query_type == "database":
            return self._query_mistral(message, plant_context, temperature=0.2)
        elif query_type == "science":
            return self._query_pllama(message, plant_context)
        else:
            return self._query_mistral(message, plant_context)

    def _classify_query(self, message: str) -> str:
        """Classify query type"""
        message_lower = message.lower()

        if any(word in message_lower for word in ["how many", "count", "list", "value", "total"]):
            return "database"
        elif any(word in message_lower for word in ["disease", "pathogen", "nutrient", "deficiency", "genetics"]):
            return "science"
        else:
            return "general"

    def _is_plant_query(self, message: str) -> bool:
        """Check if query is plant-related"""
        plant_keywords = ["plant", "anthurium", "water", "fertilize", "grow", "collection", "care"]
        return any(keyword in message.lower() for keyword in plant_keywords)

    def _get_plant_context(self, message: str) -> str:
        """Fetch relevant PlantDB context"""
        try:
            # Get plant summary
            response = requests.get(f"{self.plantdb_url}/plants", timeout=2)
            if response.status_code == 200:
                plants = response.json()
                context = f"Collection: {len(plants)} plants\n"

                # Add specific plant details if mentioned
                if "ANT-" in message:
                    # Extract plant ID and fetch details
                    import re
                    match = re.search(r'ANT-\d{4}-\d{4}', message)
                    if match:
                        plant_id = match.group(0)
                        detail_response = requests.get(f"{self.plantdb_url}/plants/{plant_id}", timeout=2)
                        if detail_response.status_code == 200:
                            plant = detail_response.json()
                            context += f"\n{plant_id}: {plant.get('name', 'Unknown')}"
                            context += f"\nLocation: {plant.get('location', 'Unknown')}"

                return context
        except Exception as e:
            logger.error(f"PlantDB context error: {e}")
        return ""

    def _query_mistral(self, message: str, context: str = "", temperature: float = 0.3) -> str:
        """Query Mistral-Nemo for general/database queries"""
        prompt = self._build_prompt(message, context, model="mistral")

        try:
            response = requests.post(
                f"{self.mistral_url}/v1/completions",
                json={
                    "model": "mistral-nemo-12b",
                    "prompt": prompt,
                    "max_tokens": 1500,
                    "temperature": temperature,
                    "stop": ["User:", "\n\n\n"]
                },
                timeout=10
            )

            if response.status_code == 200:
                return response.json()["choices"][0]["text"].strip()
            else:
                logger.error(f"Mistral error: {response.status_code}")
                return "Mistral model is not available."
        except Exception as e:
            logger.error(f"Mistral query error: {e}")
            return f"Connection error: {str(e)}"

    def _query_pllama(self, message: str, context: str = "") -> str:
        """Query PLLaMa for scientific queries"""
        prompt = self._build_prompt(message, context, model="pllama")

        try:
            response = requests.post(
                f"{self.pllama_url}/v1/completions",
                json={
                    "model": "pllama-7b",
                    "prompt": prompt,
                    "max_tokens": 1000,
                    "temperature": 0.4,
                    "stop": ["User:", "\n\n\n"]
                },
                timeout=10
            )

            if response.status_code == 200:
                return response.json()["choices"][0]["text"].strip()
            else:
                # Fallback to Mistral if PLLaMa not available
                logger.warning("PLLaMa not available, using Mistral")
                return self._query_mistral(message, context)
        except Exception as e:
            logger.warning(f"PLLaMa error, falling back: {e}")
            return self._query_mistral(message, context)

    def _build_prompt(self, message: str, context: str, model: str) -> str:
        """Build model-specific prompt"""
        if model == "mistral":
            system = "You are Cladari, a botanical AI assistant specializing in plant care and collection management."
        else:  # pllama
            system = "You are a plant science expert with deep knowledge of botany, pathology, and horticulture."

        if context:
            return f"{system}\n\nContext:\n{context}\n\nUser: {message}\n\nAssistant:"
        else:
            return f"{system}\n\nUser: {message}\n\nAssistant:"

# CLI interface
if __name__ == "__main__":
    import sys

    ai = CladariAI()

    if len(sys.argv) > 1:
        query = " ".join(sys.argv[1:])
        response = ai.query(query)
        print(f"\n🌿 Cladari: {response}\n")
    else:
        print("🌿 Cladari AI - Interactive Mode")
        print("Type 'exit' to quit\n")

        while True:
            query = input("You: ").strip()
            if query.lower() == "exit":
                break

            response = ai.query(query)
            print(f"\n🌿 Cladari: {response}\n")
PYTHON

chmod +x $AI_DIR/cladari_ai.py

# Create simple web UI
cat > $AI_DIR/ui/index.html << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>Cladari - Botanical AI</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, system-ui, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .container {
            width: 90%;
            max-width: 800px;
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            text-align: center;
        }
        .header h1 { font-size: 2em; margin-bottom: 5px; }
        .header p { opacity: 0.9; }
        .chat {
            height: 400px;
            overflow-y: auto;
            padding: 20px;
            background: #f9fafb;
        }
        .message {
            margin-bottom: 15px;
            display: flex;
            gap: 10px;
        }
        .message.user { justify-content: flex-end; }
        .message .bubble {
            max-width: 70%;
            padding: 12px 16px;
            border-radius: 18px;
            word-wrap: break-word;
        }
        .message.user .bubble {
            background: #667eea;
            color: white;
        }
        .message.bot .bubble {
            background: white;
            border: 1px solid #e5e7eb;
        }
        .input-area {
            padding: 20px;
            background: white;
            border-top: 1px solid #e5e7eb;
            display: flex;
            gap: 10px;
        }
        input {
            flex: 1;
            padding: 12px;
            border: 1px solid #d1d5db;
            border-radius: 10px;
            font-size: 16px;
        }
        button {
            padding: 12px 24px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            border-radius: 10px;
            cursor: pointer;
            font-weight: 600;
        }
        button:hover { opacity: 0.9; }
        .status {
            padding: 10px;
            background: #fef3c7;
            text-align: center;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🌿 Cladari</h1>
            <p>Botanical Intelligence System</p>
            <p style="font-size: 12px; opacity: 0.7;">Powered by Sovria</p>
        </div>
        <div class="status" id="status">Connecting to AI models...</div>
        <div class="chat" id="chat"></div>
        <div class="input-area">
            <input type="text" id="input" placeholder="Ask about your plants..." />
            <button onclick="sendMessage()">Send</button>
        </div>
    </div>

    <script>
        const API_URL = 'http://localhost:8090/chat';

        async function checkStatus() {
            try {
                const response = await fetch('http://localhost:8090/status');
                const data = await response.json();
                document.getElementById('status').style.display = 'none';
            } catch (e) {
                document.getElementById('status').textContent = 'AI server not running. Start with: python3 ai/server.py';
            }
        }

        function addMessage(text, isUser) {
            const chat = document.getElementById('chat');
            const message = document.createElement('div');
            message.className = 'message ' + (isUser ? 'user' : 'bot');
            message.innerHTML = '<div class="bubble">' + text + '</div>';
            chat.appendChild(message);
            chat.scrollTop = chat.scrollHeight;
        }

        async function sendMessage() {
            const input = document.getElementById('input');
            const text = input.value.trim();
            if (!text) return;

            addMessage(text, true);
            input.value = '';

            try {
                const response = await fetch(API_URL, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ message: text })
                });

                const data = await response.json();
                addMessage(data.response, false);
            } catch (e) {
                addMessage('Error: Could not connect to AI server', false);
            }
        }

        document.getElementById('input').addEventListener('keypress', (e) => {
            if (e.key === 'Enter') sendMessage();
        });

        checkStatus();

        // Welcome message
        setTimeout(() => {
            addMessage("Hello! I'm Cladari, your botanical AI assistant. Ask me about your plant collection!", false);
        }, 500);
    </script>
</body>
</html>
HTML

# Create the web server
cat > $AI_DIR/server.py << 'PYTHON'
#!/usr/bin/env python3
"""
Cladari Web Server
"""
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
import sys
import os

sys.path.append(os.path.dirname(__file__))
from cladari_ai import CladariAI

app = Flask(__name__)
CORS(app)

ai = CladariAI()

@app.route('/')
def index():
    return send_from_directory('ui', 'index.html')

@app.route('/status')
def status():
    return jsonify({"status": "ready", "models": ["mistral-nemo", "pllama"]})

@app.route('/chat', methods=['POST'])
def chat():
    data = request.json
    message = data.get('message', '')

    if not message:
        return jsonify({"error": "No message provided"}), 400

    response = ai.query(message)
    return jsonify({"response": response})

if __name__ == '__main__':
    print("🌿 Cladari AI Server")
    print("   http://localhost:8090")
    app.run(host='0.0.0.0', port=8090, debug=False)
PYTHON

chmod +x $AI_DIR/server.py

echo ""
echo "✅ Cladari AI infrastructure created!"
echo ""
echo "Directory structure:"
echo "  $AI_DIR/"
echo "  ├── config/          # Configuration"
echo "  ├── scripts/         # Setup scripts"
echo "  ├── logs/            # Server logs"
echo "  ├── ui/              # Web interface"
echo "  ├── cladari_ai.py    # Core AI system"
echo "  └── server.py        # Web server"
echo ""
echo "Next steps:"
echo ""
echo "1. Copy setup script to F2:"
echo "   scp $AI_DIR/scripts/setup_f2_models.sh f2:~/setup_cladari.sh"
echo ""
echo "2. SSH to F2 and run setup:"
echo "   ssh f2"
echo "   bash setup_cladari.sh"
echo ""
echo "3. Start the web server locally:"
echo "   cd $AI_DIR"
echo "   python3 server.py"
echo ""
echo "4. Open browser to http://localhost:8090"
echo ""
echo "This gives you a clean, focused botanical AI system!"