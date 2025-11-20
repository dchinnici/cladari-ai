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
from local_test import LocalCladariTest

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("CladariAI")

class CladariAI:
    """Botanical AI with specialized routing"""

    def __init__(self, config_path: str = "config/cladari_config.json"):
        self.config = json.loads(Path(config_path).read_text())
        self.mistral_url = self.config["models"]["primary"]["endpoint"]
        self.pllama_url = self.config["models"]["specialist"]["endpoint"]
        self.plantdb_url = self.config["plantdb"]["api_endpoint"]
        self.local_fallback = LocalCladariTest()

        logger.info("🌿 Cladari AI initialized")
        logger.info(f"   Primary: {self.mistral_url}")
        logger.info(f"   Specialist: {self.pllama_url}")

    def query(self, message: str, context: Dict = None) -> str:
        """Route query to appropriate model"""

        # Determine query type
        query_type = self._classify_query(message)

        # Use provided plant context if available, otherwise fetch from PlantDB
        if context and "plant_data" in context and context["plant_data"]:
            plant_context = context["plant_data"]
        elif self._is_plant_query(message):
            plant_context = self._get_plant_context(message)
        else:
            plant_context = ""

        # Route to appropriate model
        if query_type == "database":
            # Database queries use local fallback for 100% accuracy with real data
            logger.info("Using local fallback for database query")
            return self.local_fallback.query(message)
        elif query_type == "science":
            return self._query_pllama(message, plant_context)
        else:
            return self._query_mistral(message, plant_context)

    def _classify_query(self, message: str) -> str:
        """Classify query type"""
        message_lower = message.lower()

        # Queries that MUST use database (no LLM hallucination allowed)
        if any(word in message_lower for word in ["how many", "count", "list", "value", "total", "need water", "needs water", "watering today", "my plants", "my collection"]):
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
                f"{self.mistral_url}/generate",
                json={
                    "prompt": prompt,
                    "max_tokens": 1500,
                    "temperature": temperature
                },
                timeout=30
            )

            if response.status_code == 200:
                result = response.json()
                # Handle vLLM legacy API format: {"text": ["response"]}
                raw_text = ""
                if "text" in result and isinstance(result["text"], list):
                    raw_text = result["text"][0]
                elif "text" in result:
                    raw_text = result["text"]
                else:
                    logger.error(f"Unexpected response format: {result}")
                    return self.local_fallback.query(message)

                # Clean the response: remove the prompt echo
                cleaned = self._clean_response(raw_text, prompt)
                return cleaned.strip()
            else:
                logger.error(f"Mistral error: {response.status_code}")
                return self.local_fallback.query(message)
        except Exception as e:
            logger.warning(f"Mistral unavailable, using local fallback: {e}")
            return self.local_fallback.query(message)

    def _query_pllama(self, message: str, context: str = "") -> str:
        """Query PLLaMa for scientific queries"""
        prompt = self._build_prompt(message, context, model="pllama")

        try:
            response = requests.post(
                f"{self.pllama_url}/generate",
                json={
                    "prompt": prompt,
                    "max_tokens": 1000,
                    "temperature": 0.4
                },
                timeout=30
            )

            if response.status_code == 200:
                result = response.json()
                # Handle vLLM legacy API format
                raw_text = ""
                if "text" in result and isinstance(result["text"], list):
                    raw_text = result["text"][0]
                elif "text" in result:
                    raw_text = result["text"]
                else:
                    logger.warning("PLLaMa unexpected format, using Mistral")
                    return self._query_mistral(message, context)

                # Clean the response
                cleaned = self._clean_response(raw_text, prompt)
                return cleaned.strip()
            else:
                # Fallback to Mistral if PLLaMa not available
                logger.warning("PLLaMa not available, using Mistral")
                return self._query_mistral(message, context)
        except Exception as e:
            logger.warning(f"PLLaMa error, falling back: {e}")
            return self._query_mistral(message, context)

    def _clean_response(self, raw_text: str, prompt: str) -> str:
        """Clean LLM response by removing prompt echo"""
        # The response often contains the entire prompt + the actual answer
        # We want to extract only the answer part after "Assistant:"

        # Try to find the Assistant's response
        if "Assistant:" in raw_text:
            parts = raw_text.split("Assistant:", 1)
            if len(parts) > 1:
                return parts[1].strip()

        # Fallback: remove the prompt prefix if it's echoed
        if raw_text.startswith(prompt):
            return raw_text[len(prompt):].strip()

        # If no prompt markers found, return as-is
        return raw_text

    def _build_prompt(self, message: str, context: str, model: str) -> str:
        """Build model-specific prompt"""
        if model == "mistral":
            system = """You are Cladari, a botanical AI assistant specializing in plant care and collection management.

IMPORTANT RULES:
- Only use information from the Context section below
- If you don't have specific data, say "I don't have that information in the database"
- Never make up or hallucinate specific plant details like pot sizes, health status, or counts
- Provide general botanical knowledge when asked, but don't claim it's from the user's collection"""
        else:  # pllama
            system = """You are a plant science expert with deep knowledge of botany, pathology, and horticulture.

IMPORTANT: Provide accurate botanical knowledge. If asked about specific plants in a collection, only reference data provided in the Context section."""

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
