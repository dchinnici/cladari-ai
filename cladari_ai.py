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
