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
    plant_context = data.get('context', {})

    if not message:
        return jsonify({"error": "No message provided"}), 400

    # Build detailed context from plant data if provided
    context_str = ""
    if plant_context:
        context_str = f"Plant: {plant_context.get('genus', '')} {plant_context.get('species', '')}\n"
        context_str += f"Catalog ID: {plant_context.get('catalogId', 'Unknown')}\n"

        if plant_context.get('location'):
            context_str += f"Location: {plant_context['location']}\n"

        if plant_context.get('wateringFrequency'):
            context_str += f"Watering: {plant_context['wateringFrequency']}\n"

        if plant_context.get('lightRequirements'):
            context_str += f"Light: {plant_context['lightRequirements']}\n"

        if plant_context.get('soilType'):
            context_str += f"Soil: {plant_context['soilType']}\n"

        if plant_context.get('notes'):
            context_str += f"Notes: {plant_context['notes']}\n"

        if plant_context.get('lastWatered'):
            context_str += f"Last watered: {plant_context['lastWatered']}\n"

    response = ai.query(message, context={"plant_data": context_str})
    return jsonify({"response": response})

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8091))
    print("🌿 Cladari AI Server")
    print(f"   http://100.88.172.122:{port}")
    print(f"   http://localhost:{port}")
    app.run(host='0.0.0.0', port=port, debug=False)
