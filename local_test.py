#!/usr/bin/env python3
"""
Cladari Local Test - Uses PlantDB directly without LLM
Fallback for when F2 is not available
"""
import requests
import json
import re

class LocalCladariTest:
    """Local testing using rule-based responses"""

    def __init__(self):
        # Try Tailscale IP first, fallback to localhost
        self.plantdb_url = "http://100.88.172.122:3000/api"
        self.plantdb_url_fallback = "http://localhost:3000/api"

    def query(self, message: str) -> str:
        """Process query with rule-based logic"""
        message_lower = message.lower()

        # Get plant data
        plant_data = self._get_plant_data()

        if not plant_data:
            return "PlantDB is not accessible. Please ensure it's running on port 3000."

        # Handle different query types
        if "how many" in message_lower and "plant" in message_lower:
            return f"You have {plant_data['count']} plants in your collection."

        elif "value" in message_lower or "worth" in message_lower:
            return f"Your collection is valued at ${plant_data['total_value']:,.2f} with {plant_data['count']} plants."

        elif "water" in message_lower or "care" in message_lower:
            # Try ML predictions first, fallback to basic info
            ml_info = self._get_watering_info()
            if "Could not get" not in ml_info:
                return ml_info

            # Fallback: provide general guidance
            return f"""I don't have real-time watering prediction data available.

For accurate watering needs, check your PlantDB:
• Go to Care Schedule tab on each plant
• Review care logs to see last watering dates
• Set up watering reminders based on your intervals

General Anthurium watering guidance:
• Water when top 1-2" of soil is dry
• Most Anthuriums need water every 7-10 days
• Adjust based on humidity, temperature, and pot size"""

        elif "location" in message_lower:
            locations = plant_data.get('locations', {})
            response = "Plants by location:\n"
            for loc, count in locations.items():
                response += f"  • {loc}: {count} plants\n"
            return response

        elif "recent" in message_lower or "new" in message_lower:
            recent = plant_data.get('recent', [])
            if recent:
                response = "Recent additions:\n"
                for plant in recent[:3]:
                    response += f"  • {plant['id']}: {plant.get('name', 'Unknown')}\n"
                return response
            return "No recent additions found."

        elif re.search(r'ANT-\d{4}-\d{4}', message, re.IGNORECASE):
            match = re.search(r'ANT-\d{4}-\d{4}', message, re.IGNORECASE)
            plant_id = match.group(0).upper()
            return self._get_plant_details(plant_id)

        else:
            # Default response with available commands
            return f"""I'm Cladari (local mode). I can tell you:
• You have {plant_data['count']} plants
• Collection value: ${plant_data['total_value']:,.2f}
• Try: "How many plants?", "What's the value?", "Which need water?", "Show locations"
• Or ask about a specific plant like ANT-2025-0042"""

    def _get_plant_data(self) -> dict:
        """Get basic plant data from PlantDB"""
        # Try Tailscale IP first, then localhost
        for url in [self.plantdb_url, self.plantdb_url_fallback]:
            try:
                response = requests.get(f"{url}/plants", timeout=2)
                if response.status_code == 200:
                    plants = response.json()

                    # Calculate statistics
                    total_value = sum(p.get('purchasePrice', 0) for p in plants)

                    # Group by location
                    locations = {}
                    for plant in plants:
                        loc = plant.get('currentLocation', {}).get('name', 'Unknown') if plant.get('currentLocation') else 'Unknown'
                        locations[loc] = locations.get(loc, 0) + 1

                    # Get recent additions
                    recent = sorted(plants, key=lambda p: p.get('createdAt', ''), reverse=True)[:5]

                    return {
                        'count': len(plants),
                        'total_value': total_value,
                        'locations': locations,
                        'recent': recent,
                        'plants': plants
                    }
            except Exception as e:
                print(f"PlantDB error for {url}: {e}")
        return None

    def _get_watering_info(self) -> str:
        """Get watering predictions"""
        for url in [self.plantdb_url, self.plantdb_url_fallback]:
            try:
                response = requests.post(
                    f"{url}/ml/predict-care",
                json={"careType": "water"},
                timeout=3
                )

                if response.status_code == 200:
                    data = response.json()
                    predictions = data.get('predictions', [])

                    needs_water = [p for p in predictions if p.get('daysUntilNext', 0) <= 1]

                    if needs_water:
                        response_text = f"{len(needs_water)} plants need water today:\n"
                        for plant in needs_water[:5]:
                            response_text += f"  • {plant['plantId']}: {plant.get('name', 'Unknown')}\n"
                        return response_text
                    return "No plants need water today. All looking good!"
            except:
                continue
        return "Could not get watering predictions."

    def _get_plant_details(self, plant_id: str) -> str:
        """Get specific plant details by plantId (ANT-2025-XXXX)"""
        plant_data = self._get_plant_data()
        if not plant_data or 'plants' not in plant_data:
            return f"Could not access plant database"

        # Search for plant by plantId
        matching_plant = None
        for plant in plant_data['plants']:
            if plant.get('plantId', '').upper() == plant_id.upper():
                matching_plant = plant
                break

        if not matching_plant:
            return f"Could not find plant {plant_id}. Try asking about a specific plant like ANT-2025-0002 or ANT-2025-0040."

        # Build detailed response
        details = f"Plant {plant_id}:\n"
        details += f"  • Species: {matching_plant.get('genus', '')} {matching_plant.get('species', '')}\n"
        details += f"  • Hybrid: {matching_plant.get('hybridName', 'N/A')}\n"

        if matching_plant.get('currentLocation'):
            details += f"  • Location: {matching_plant['currentLocation'].get('name', 'Unknown')}\n"

        if matching_plant.get('vendor'):
            details += f"  • Source: {matching_plant['vendor'].get('name', 'Unknown')}\n"

        if matching_plant.get('acquisitionCost'):
            details += f"  • Value: ${matching_plant['acquisitionCost']}\n"

        if matching_plant.get('healthStatus'):
            details += f"  • Health: {matching_plant['healthStatus']}\n"

        if matching_plant.get('notes'):
            details += f"  • Notes: {matching_plant['notes'][:100]}...\n"

        return details


if __name__ == "__main__":
    import sys

    cladari = LocalCladariTest()

    if len(sys.argv) > 1:
        query = " ".join(sys.argv[1:])
        response = cladari.query(query)
        print(f"\n🌿 Cladari (local): {response}\n")
    else:
        print("🌿 Cladari Local Test Mode")
        print("(No AI models required - using PlantDB directly)")
        print("Type 'exit' to quit\n")

        while True:
            query = input("You: ").strip()
            if query.lower() == 'exit':
                break

            response = cladari.query(query)
            print(f"\n🌿 Cladari: {response}\n")