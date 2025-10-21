#!/usr/bin/env python3
"""
Simple AI Debate Tutor Server
Runs on port 5555 and handles debate coaching requests using local Ollama
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import requests
import json
from datetime import datetime

app = Flask(__name__)
CORS(app)  # Allow requests from Flutter app

OLLAMA_URL = "http://localhost:11434/api/chat"
MODEL = "mistral:7b"  # Upgraded from llama3.2:3b for better quality

def build_system_prompt(skill_level):
    """Build the AI tutor's system prompt"""
    skill_context = {
        'beginner': 'Focus on basic concepts, simple explanations, and encouragement. Avoid jargon.',
        'intermediate': 'Provide moderate complexity with some technical terms. Challenge them to think deeper.',
        'advanced': 'Use advanced techniques, complex scenarios, and expect high-level analysis.'
    }

    return f"""You are an expert debate coach and tutor for the Arena debate platform. Your role is to help users improve their debating skills through practice, feedback, and guidance.

Your expertise includes:
- Constructing strong arguments
- Finding logical fallacies
- Researching and citing evidence
- Effective rebuttal techniques
- Public speaking and persuasion
- Debate strategy and tactics

You are encouraging, patient, and provide constructive feedback. You adapt your teaching style to the user's skill level.

User Skill Level: {skill_level} - {skill_context.get(skill_level, skill_context['intermediate'])}"""

def build_user_prompt(tutor_mode, topic, position, skill_level, user_message):
    """Build the prompt based on tutor mode"""

    # Handle greetings naturally
    greeting_words = ['hello', 'hi', 'hey', 'greetings', 'howdy']
    if any(word in user_message.lower().strip() for word in greeting_words) and len(user_message.split()) <= 3:
        return f"""The user is greeting you. Respond warmly and briefly introduce yourself as their AI debate coach. Keep it to 2-3 sentences. Mention that you can help with practice debates, argument critique, research, strategy, tips, and identifying logical fallacies. End with asking how you can help them today."""

    if tutor_mode == 'practice':
        return f"""You are helping a {skill_level} debater practice.

Topic: {topic or 'No topic specified yet'}
User's Position: {position}

User says: "{user_message}"

Respond as their debate opponent (opposing position), then give them brief constructive feedback, and end with one follow-up question. Keep your entire response to 150 words or less - be concise and direct."""

    elif tutor_mode == 'critique':
        return f"""Analyze this {skill_level} debater's argument:

Topic: {topic}
Position: {position}
Argument: "{user_message}"

Give a brief critique covering: logic strength, evidence quality, potential weaknesses, and one specific improvement suggestion. Be honest but encouraging. Keep your entire response to 150 words or less."""

    elif tutor_mode == 'research':
        return f"""Help a {skill_level} debater research arguments.

Topic: {topic}
Position: {position}
User's Question: "{user_message}"

Provide 2-3 strong arguments for their position, key evidence points to research, and one main counterargument they'll face. Keep your entire response to 150 words or less - be direct and actionable."""

    elif tutor_mode == 'strategy':
        return f"""Provide debate strategy coaching for a {skill_level} debater.

Topic: {topic}
User's Position: {position}
User's Question: "{user_message}"

Give tactical advice covering: opening framing, top 2 arguments to prioritize, and one key rebuttal strategy. Be specific and direct. Keep your entire response to 150 words or less."""

    elif tutor_mode == 'tips':
        return f"""Provide debate tips and guidance.

User's Skill Level: {skill_level}
User's Question: "{user_message or 'How can I improve my debating skills?'}"

Give 2-3 specific actionable tips and one common mistake to avoid. Keep it practical and encouraging. Keep your entire response to 150 words or less."""

    elif tutor_mode == 'fallacies':
        return f"""Help identify and explain logical fallacies.

User's Text: "{user_message}"

Identify the main logical fallacy (if any), explain why it's a fallacy in 1-2 sentences, and show how to fix it. Be educational and clear for a {skill_level} level. Keep your entire response to 100 words or less."""

    else:
        return f"""You are a debate tutor having a conversation with a {skill_level} student.

Topic: {topic or 'General debate coaching'}
Student says: "{user_message}"

Respond as a helpful, encouraging debate coach. Provide guidance, answer questions, and help them improve."""


@app.route('/webhook/debate-tutor', methods=['POST'])
def debate_tutor():
    """Handle debate tutor requests"""
    try:
        data = request.json

        # Extract parameters
        user_id = data.get('userId')
        session_id = data.get('sessionId', 'new_session')
        tutor_mode = data.get('tutorMode', 'practice')
        topic = data.get('topic', '')
        position = data.get('position', 'affirmative')
        skill_level = data.get('skillLevel', 'intermediate')
        user_message = data.get('userMessage', '')

        if not user_id or not user_message:
            return jsonify({
                'success': False,
                'error': 'Missing userId or userMessage'
            }), 400

        # Build prompts
        system_prompt = build_system_prompt(skill_level)
        user_prompt = build_user_prompt(tutor_mode, topic, position, skill_level, user_message)

        # Call Ollama
        ollama_request = {
            "model": MODEL,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            "stream": False,
            "options": {
                "temperature": 0.8,
                "top_p": 0.9,
                "num_predict": 800
            }
        }

        print(f"[{datetime.now()}] Processing request for user {user_id}, mode: {tutor_mode}")

        response = requests.post(OLLAMA_URL, json=ollama_request, timeout=45)

        if response.status_code != 200:
            return jsonify({
                'success': False,
                'error': f'Ollama returned status {response.status_code}'
            }), 500

        ollama_response = response.json()
        tutor_response = ollama_response.get('message', {}).get('content', 'I apologize, but I could not generate a response. Please try again.')

        print(f"[{datetime.now()}] Successfully generated response ({len(tutor_response)} chars)")

        # Return formatted response
        return jsonify({
            'success': True,
            'tutorResponse': tutor_response,
            'sessionId': session_id,
            'userId': user_id,
            'tutorMode': tutor_mode,
            'topic': topic,
            'position': position,
            'skillLevel': skill_level,
            'timestamp': datetime.now().isoformat(),
            'model': MODEL
        })

    except requests.exceptions.Timeout:
        return jsonify({
            'success': False,
            'error': 'Request timed out. The AI model is taking too long to respond.'
        }), 504

    except Exception as e:
        print(f"[{datetime.now()}] Error: {str(e)}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    try:
        # Check if Ollama is responding
        response = requests.get("http://localhost:11434/api/tags", timeout=5)
        ollama_ok = response.status_code == 200
    except:
        ollama_ok = False

    return jsonify({
        'status': 'healthy' if ollama_ok else 'degraded',
        'ollama': 'connected' if ollama_ok else 'disconnected',
        'model': MODEL
    })


if __name__ == '__main__':
    print("=" * 60)
    print("AI Debate Tutor Server Starting")
    print("=" * 60)
    print(f"Model: {MODEL}")
    print(f"Port: 5555")
    print(f"Webhook URL: http://localhost:5555/webhook/debate-tutor")
    print("=" * 60)
    app.run(host='0.0.0.0', port=5555, debug=False)
