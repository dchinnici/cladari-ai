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
