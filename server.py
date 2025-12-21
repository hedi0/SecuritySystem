import face_recognition
import cv2
import numpy as np
from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import base64
import json
from datetime import datetime
import time

app = Flask(__name__)
#CORS(app)
CORS(app, resources={r"/*": {"origins": ["http://localhost", "http://your-ip"]}})

KNOWN_FACES_DIR = "known_faces"
INTRUDERS_DIR = "intruders"
PORT = 5000

os.makedirs(KNOWN_FACES_DIR, exist_ok=True)
os.makedirs(INTRUDERS_DIR, exist_ok=True)
os.makedirs("logs", exist_ok=True)

known_face_encodings = []
known_face_names = []

def log_message(message):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_line = f"[{timestamp}] {message}"
    print(log_line)
    try:
        # Safe write with proper encoding
        with open("logs/server.log", "a", encoding="utf-8", errors="ignore") as f:
            f.write(log_line + "\n")
    except Exception:
        pass  

def load_authorized_faces():
    global known_face_encodings, known_face_names
    
    known_face_encodings.clear()
    known_face_names.clear()
    
    log_message("Loading authorized faces...")
    
    supported_extensions = ('.jpg', '.jpeg', '.png')
    files = [f for f in os.listdir(KNOWN_FACES_DIR) 
             if f.lower().endswith(supported_extensions)]
    
    if not files:
        log_message("WARNING: No face images found in 'known_faces' folder!")
        log_message("Please add images like 'boyd.jpg', 'jim.jpg' to the folder.")
    
    for filename in files:
        image_path = os.path.join(KNOWN_FACES_DIR, filename)
        try:
            image = face_recognition.load_image_file(image_path)
            encodings = face_recognition.face_encodings(image)
            
            if len(encodings) > 0:
                known_face_encodings.append(encodings[0])
                name = os.path.splitext(filename)[0]
                known_face_names.append(name)
                log_message(f" Loaded: {name}")
            else:
                log_message(f" No face found in: {filename}")
                
        except Exception as e:
            log_message(f" Error loading {filename}: {str(e)}")
    
    log_message(f"Total loaded: {len(known_face_names)} authorized faces")

# Load faces on startup
load_authorized_faces()

@app.route('/')
def home():
    return jsonify({
        "status": "running",
        "authorized_faces": len(known_face_names),
        "server_time": datetime.now().isoformat(),
        "endpoints": {
            "/recognize": "POST with JSON {'image': 'base64_string'}",
            "/reload_faces": "GET - Reload faces from folder",
            "/status": "GET - Server status",
            "/test": "GET - Test connection"
        }
    })

@app.route('/status', methods=['GET'])
def status():
    return jsonify({
        "faces_loaded": len(known_face_names),
        "server_time": datetime.now().isoformat(),
        "memory_usage": "N/A"
    })

@app.route('/test', methods=['GET'])
def test():
    """Simple test endpoint"""
    return jsonify({"message": "Server is running!", "timestamp": datetime.now().isoformat()})

@app.route('/reload_faces', methods=['GET'])
def reload_faces():
    """Reload faces without restarting server"""
    load_authorized_faces()
    return jsonify({
        "message": f"Reloaded {len(known_face_names)} faces",
        "faces": known_face_names
    })

@app.route('/recognize', methods=['POST'])
def recognize_face():
    """Main endpoint for ESP32 to send images"""
    start_time = time.time()
    
    try:
        # Get image data
        data = request.get_json()
        if not data or 'image' not in data:
            return jsonify({"error": "No image data"}), 400
        
        # Decode base64 image
        image_data = base64.b64decode(data['image'])
        
        # Convert to numpy array
        nparr = np.frombuffer(image_data, np.uint8)
        image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if image is None:
            return jsonify({"error": "Failed to decode image"}), 400
        
        # Resize for faster processing (optional)
        height, width = image.shape[:2]
        if height > 480 or width > 640:
            scale = 480 / height
            new_width = int(width * scale)
            new_height = 480
            image = cv2.resize(image, (new_width, new_height))
        
        # Find all faces in the image
        face_locations = face_recognition.face_locations(image)
        face_encodings = face_recognition.face_encodings(image, face_locations)
        
        # Prepare response
        response = {
            "processing_time": round(time.time() - start_time, 2),
            "faces_detected": len(face_locations),
            "authorized": False,
            "name": "Unknown",
            "confidence": 0,
            "door_open": False,
            "image_size": f"{width}x{height}"
        }
        
        # If no faces found
        if len(face_encodings) == 0:
            log_message("No faces detected in image")
            return jsonify(response)
        
        # Check each face found
        for i, face_encoding in enumerate(face_encodings):
            # Compare with known faces
            matches = face_recognition.compare_faces(
                known_face_encodings, 
                face_encoding,
                tolerance=0.6
            )
            
            if True in matches:
                # Get face distances
                face_distances = face_recognition.face_distance(
                    known_face_encodings, 
                    face_encoding
                )
                best_match_index = np.argmin(face_distances)
                name = known_face_names[best_match_index]
                confidence = 1 - face_distances[best_match_index]
                
                response.update({
                    "authorized": True,
                    "name": name,
                    "confidence": round(float(confidence), 3),
                    "door_open": True
                })
                
                log_message(f"Authorized: {name} (confidence: {confidence:.2f})")
                break
            else:
                # Unauthorized face - save it
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                intruder_path = os.path.join(INTRUDERS_DIR, f"intruder_{timestamp}.jpg")
                cv2.imwrite(intruder_path, image)
                
                response.update({
                    "authorized": False,
                    "name": "Intruder",
                    "intruder_saved": intruder_path
                })
                
                log_message("INTRUDER DETECTED - Image saved")
        
        return jsonify(response)
        
    except Exception as e:
        log_message(f"ERROR in /recognize: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route('/add_face', methods=['POST'])
def add_face():
    """Add a new authorized face remotely"""
    try:
        data = request.get_json()
        if 'image' not in data or 'name' not in data:
            return jsonify({"error": "Need 'image' and 'name'"}), 400
        
        # Clean name for filename
        name = data['name'].replace(" ", "_").replace("/", "_").replace("\\", "_")
        image_data = base64.b64decode(data['image'])
        
        # Save the image
        filename = f"{name}.jpg"
        filepath = os.path.join(KNOWN_FACES_DIR, filename)
        
        with open(filepath, "wb") as f:
            f.write(image_data)
        
        # Reload faces
        load_authorized_faces()
        
        return jsonify({
            "success": True,
            "message": f"Added {name} as authorized",
            "filename": filename
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

def print_server_info():
    """Display server information"""
    import socket
    hostname = socket.gethostname()
    local_ip = socket.gethostbyname(hostname)
    
    print("\n" + "="*50)
    print("ESP32 Face Recognition Server - Windows 11")
    print("="*50)
    print(f"Local URL:    http://localhost:{PORT}")
    print(f"Network URL:  http://{local_ip}:{PORT}")
    print(f"Known Faces:  {len(known_face_names)} loaded")
    print("="*50)
    print("To test: Open browser to http://localhost:5000")
    print("="*50 + "\n")

if __name__ == '__main__':
    print_server_info()
    app.run(host='0.0.0.0', port=PORT, debug=False, threaded=True)