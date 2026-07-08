#!/usr/bin/env python3
"""
Rosemere Voice Server
A simple HTTP server that generates voice MP3 files for Godot to play.
Godot sends text + voice parameters, this server generates the audio and returns the filename.
"""

import http.server
import socketserver
import urllib.parse
import os
import hashlib
import json
from pathlib import Path

# Configuration
AUDIO_DIR = Path("audio")
PORT = 8765

# Voice settings mapping
VOICE_CONFIGS = {
    "gareth": {"language": "en-GB", "gender": "masculine", "use_case": "characters", "index": 0},
    "elora": {"language": "en-GB", "gender": "feminine", "use_case": "characters", "index": 1},
    "player": {"language": "en-US", "gender": "masculine", "use_case": "narration", "index": 0},
}

def generate_filename(text: str, voice_type: str) -> str:
    """Generate unique filename based on text hash"""
    text_hash = hashlib.md5((text + voice_type).encode()).hexdigest()[:12]
    return f"voice_{voice_type}_{text_hash}.mp3"

class VoiceHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        print(f"[VoiceServer] {args[0]}")
    
    def do_GET(self):
        if self.path.startswith("/health"):
            self.send_response(200)
            self.send_header("Content-type", "text/plain")
            self.end_headers()
            self.wfile.write(b"OK")
            return
        
        self.send_response(404)
        self.end_headers()
    
    def do_POST(self):
        if self.path != "/speak":
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b"Unknown endpoint")
            return
        
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length).decode("utf-8")
        
        try:
            data = json.loads(body)
            text = data.get("text", "")
            voice_type = data.get("voice", "player")
            
            if not text:
                raise ValueError("Empty text")
            
            # Get voice config
            config = VOICE_CONFIGS.get(voice_type, VOICE_CONFIGS["player"])
            
            # Generate filename
            filename = generate_filename(text, voice_type)
            filepath = AUDIO_DIR / filename
            
            # Check if already generated (cache)
            if not filepath.exists():
                print(f"[VoiceServer] Generating: {filepath}")
                
                # Call the speech generation tool
                import subprocess
                
                # Build the prompt for generate_speech
                cmd = [
                    "python3", "-c",
                    f"""
import sys
sys.path.insert(0, '.')
from tools import generate_speech_local

generate_speech_local(
    text=\\"{text.replace('"', '\\\\\\"')}\\",
    file_path=\\"{filepath}\\",
    language=\\"{config['language']}\\",
    gender=\\"{config['gender']}\\",
    use_case=\\"{config['use_case']}\\",
    index={config['index']}
)
"""
                ]
                
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
                
                if result.returncode != 0:
                    print(f"[VoiceServer] Generation failed: {result.stderr}")
                    raise Exception("Voice generation failed")
            
            # Return success with filename
            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            response = json.dumps({"success": True, "filename": str(filepath)})
            self.wfile.write(response.encode())
            
        except Exception as e:
            self.send_response(500)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            response = json.dumps({"success": False, "error": str(e)})
            self.wfile.write(response.encode())

if __name__ == "__main__":
    AUDIO_DIR.mkdir(exist_ok=True)
    
    print(f"🎤 Rosemere Voice Server starting on port {PORT}")
    print(f"   Audio directory: {AUDIO_DIR.absolute()}")
    print(f"   Endpoints: POST /speak, GET /health")
    
    with socketserver.TCPServer(("", PORT), VoiceHandler) as httpd:
        print(f"   Ready! Waiting for requests...")
        httpd.serve_forever()