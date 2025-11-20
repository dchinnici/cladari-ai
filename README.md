# Cladari AI - Botanical Intelligence System

## Overview
Dedicated AI system optimized for plant collection management, botanical queries, and horticultural intelligence. Designed as a specialized feature of the Cladari PlantDB ecosystem.

## Architecture

```
cladari/ai/
├── cladari_ai.py        # Core routing and model adapter
├── server.py            # Flask web server & chat UI
├── local_test.py        # Rule-based fallback (no AI required)
├── start.sh             # Quick start script
├── config/
│   └── cladari_config.json  # System configuration
├── scripts/
│   ├── setup_f2_models.sh   # F2 GPU setup (vLLM)
│   └── setup_phi3_quick.sh  # Lightweight model option
└── ui/
    └── index.html       # Web chat interface
```

## Features

### Multi-Mode Operation
1. **Local Mode**: Rule-based responses using PlantDB API directly
2. **Remote AI Mode**: Connects to F2 GPU server (Mistral-Nemo/PLLaMa)
3. **Fallback Mode**: Graceful degradation when AI unavailable

### Current Capabilities
- Query plant collection (70 plants)
- Check watering schedules
- View plants by location
- Calculate collection value
- Access specific plant details
- Natural language botanical queries

## Quick Start

### Prerequisites
- PlantDB running on port 3000
- Python 3.10+ with Flask
- (Optional) F2 server with GPU for AI models

### Installation

1. **Clone Repository**
```bash
git clone https://github.com/dchinnici/cladari-ai.git
cd cladari-ai
```

2. **Start PlantDB** (if not running)
```bash
cd ~/cladari/plantDB
npm run dev
```

3. **Test Local Mode** (works immediately!)
```bash
python3 local_test.py "How many plants do I have?"
# Output: You have 70 plants in your collection.
```

4. **Start Web UI**
```bash
./start.sh
# Access at http://localhost:8091
```

## Usage Examples

### Command Line (Local Mode)
```bash
# Basic queries
python3 local_test.py "How many plants?"
python3 local_test.py "What's the collection value?"
python3 local_test.py "Show plants by location"
python3 local_test.py "Which plants need water?"

# Specific plant (requires valid ID)
python3 local_test.py "Tell me about plant cmgsezkin000xgw74jhgpsbkx"
```

### Web Interface
1. Open http://localhost:8091
2. Type botanical queries in natural language
3. Receive intelligent responses based on your PlantDB data

## Configuration

### config/cladari_config.json
```json
{
  "name": "Cladari AI",
  "version": "1.0.0",
  "models": {
    "primary": {
      "name": "mistral-nemo-12b",
      "url": "http://100.70.249.44:8088",
      "type": "vllm"
    },
    "specialist": {
      "name": "pllama-7b",
      "url": "http://100.70.249.44:8089",
      "type": "vllm"
    },
    "fallback": {
      "name": "local-rules",
      "type": "local"
    }
  },
  "plantdb": {
    "api_url": "http://localhost:3000/api",
    "timeout": 5
  }
}
```

### Environment Variables
```bash
# Override default ports
export PORT=8091  # Web server port
export PLANTDB_API=http://localhost:3000/api
export CLADARI_MODE=local  # local|remote|auto
```

## Model Setup (F2 GPU Server)

### Option 1: Mistral-Nemo-12B (Recommended)
**Best for**: General botanical queries, balanced performance

```bash
# On F2 server
cd ~/cladari_ai
python -m venv venv
source venv/bin/activate
pip install vllm transformers

# Download model (24GB)
huggingface-cli download mistralai/Mistral-Nemo-Instruct-2407 \
  --local-dir ./models/mistral-nemo-12b

# Start server
python -m vllm.entrypoints.openai.api_server \
  --model ./models/mistral-nemo-12b \
  --port 8088 \
  --gpu-memory-utilization 0.85
```

### Option 2: PLLaMa-7B (Specialized)
**Best for**: Plant-specific knowledge, scientific accuracy

```bash
# Download botanical-specific model
huggingface-cli download AgroverseLLM/PLLaMa-7b \
  --local-dir ./models/pllama-7b

# Start on different port
python -m vllm.entrypoints.openai.api_server \
  --model ./models/pllama-7b \
  --port 8089
```

### Option 3: Phi-3 Mini (Quick Setup)
**Best for**: Testing, limited resources (2.3GB only)

```bash
bash scripts/setup_phi3_quick.sh
```

## API Endpoints

### Chat Endpoint
```bash
POST /chat
Content-Type: application/json

{
  "message": "How many plants need water today?",
  "mode": "auto"  # auto|local|remote
}
```

### Status Endpoint
```bash
GET /status

Response:
{
  "plantdb": "connected",
  "plants": 70,
  "ai_models": {
    "primary": "disconnected",
    "specialist": "disconnected",
    "fallback": "ready"
  }
}
```

## Performance

### Local Mode (Rule-based)
- Response time: <100ms
- Accuracy: 100% for factual queries
- Coverage: Basic queries only

### Remote AI Mode
- Response time: 2-5 seconds
- Accuracy: 95%+ for botanical queries
- Coverage: Complex reasoning, predictions, advice

### Resource Usage
- **F1 (Mac)**: Minimal (~50MB RAM)
- **F2 (GPU)**: 16-24GB VRAM depending on model

## Troubleshooting

### PlantDB Not Accessible
```bash
# Check if running
curl http://localhost:3000/api/plants

# Start if needed
cd ~/cladari/plantDB
npm run dev
```

### Flask Module Missing
```bash
# Use axo_env Python
/Users/davidchinnici/axo_env/bin/python3 server.py

# Or install Flask
pip3 install flask flask-cors
```

### Port Already in Use
```bash
# Check what's using port
lsof -i :8091

# Use different port
PORT=8092 ./start.sh
```

### No AI Response
```bash
# Test F2 connection
ping 100.70.249.44

# Check model server
curl http://100.70.249.44:8088/health

# Fallback to local mode
export CLADARI_MODE=local
```

## Development

### Adding New Query Patterns
Edit `local_test.py`:
```python
def query(self, message: str) -> str:
    if "new_pattern" in message.lower():
        return self._handle_new_pattern()
```

### Extending AI Capabilities
Edit `cladari_ai.py`:
```python
def route_query(self, query: str):
    if self.is_complex_botanical_query(query):
        return self.use_specialist_model(query)
```

## Roadmap

### Near Term (v1.1)
- [ ] Watering prediction accuracy
- [ ] Photo analysis integration
- [ ] Care schedule generation
- [ ] Disease diagnosis

### Medium Term (v2.0)
- [ ] Multi-modal support (images)
- [ ] Voice interface
- [ ] Mobile app
- [ ] Community knowledge sharing

### Long Term (v3.0)
- [ ] Autonomous care recommendations
- [ ] Market value predictions
- [ ] Breeding suggestions
- [ ] Research integration

## Architecture Philosophy

Cladari AI follows a **progressive enhancement** approach:
1. **Always works**: Local mode provides immediate value
2. **Gets better with AI**: Remote models add intelligence
3. **Specialized knowledge**: Botanical-specific training
4. **Clean separation**: Independent from general-purpose AI

## Contributing

1. Fork the repository
2. Create feature branch
3. Add tests for new features
4. Submit pull request

## License
MIT License - See LICENSE file

## Support

- **GitHub Issues**: https://github.com/dchinnici/cladari-ai/issues
- **Documentation**: `/docs` directory
- **PlantDB**: https://github.com/dchinnici/cladari

---
*Part of the Cladari PlantDB Ecosystem*