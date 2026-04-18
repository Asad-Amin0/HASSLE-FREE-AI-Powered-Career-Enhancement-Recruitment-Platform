from flask import Flask, request, jsonify
from flask_cors import CORS
from werkzeug.utils import secure_filename
import os
from resume_parser import analyze_resume
from scoring import calculate_employability_score


app = Flask(__name__)
# Explicitly ALLOW ALL Origins to prevent CORS issues
CORS(app, resources={r"/*": {"origins": "*"}})

# Configure upload settings securely
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16 MB limit
ALLOWED_EXTENSIONS = {'pdf', 'docx'}

def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@app.route('/api/upload-resume', methods=['POST'], strict_slashes=False)
def upload_resume():
    """Endpoint for uploading and parsing a resume."""
    print(f"--- Incoming request: {request.method} {request.url} ---")
    
    # 1. Check if the post request has the file part
    if 'resume' not in request.files:
        print("Error: No 'resume' key in request.files")
        return jsonify({"error": "No file part in the request under the key 'resume'"}), 400
        
    file = request.files['resume']
    
    # 2. Check if user submitted an empty file
    if file.filename == '':
        print("Error: Empty filename detected")
        return jsonify({"error": "No selected file"}), 400
        
    # 3. Process the upload if it's allowed
    if file and allowed_file(file.filename):
        filename = secure_filename(file.filename)
        print(f"File allowed: {filename}. Starting analysis...")
        
        # Process the resume using the parser module
        file_bytes = file.read()
        analysis_result = analyze_resume(file_bytes, filename)
        
        if "error" in analysis_result:
             print(f"Analysis failed: {analysis_result['error']}")
             return jsonify(analysis_result), 400
              
        # 4. Calculate initial score
        scoring_result = calculate_employability_score(analysis_result)
              
        response = {
            "message": "Resume uploaded and analyzed",
            "filename": filename,
            "name": analysis_result.get("name", "User"),
            "category": analysis_result.get("category", "Unknown"),
            "skills": analysis_result.get("skills", []),
            "experience": analysis_result.get("experience", "Not found"),
            "education": analysis_result.get("education", "Not found"),
            "text_preview": analysis_result.get("text_preview", ""),
            "score": scoring_result,
            "progress": 100 
        }
        
        print(f"Analysis complete for {filename}. Name extracted: {response['name']}. Score: {scoring_result['overall_score']}")
        return jsonify(response), 200
        
    else:
        print(f"Error: File type {file.filename} not allowed")
        return jsonify({"error": "File type not allowed. Supported formats: PDF, DOCX"}), 400

@app.route('/api/analyze-interview', methods=['POST'], strict_slashes=False)
def analyze_interview():
    """Endpoint for analyzing interview metrics synchronously (simulated for now)."""
    print("--- Incoming Interview Analysis ---")
    data = request.json
    if not data:
        return jsonify({"error": "No data provided"}), 400
        
    # In a real system, we might process audio/video blobs here
    # For now, we assume the frontend sends high-level metrics
    metrics = {
        "clarity": data.get("clarity", 0.5),
        "confidence": data.get("confidence", 0.5),
        "technical_depth": data.get("technical_depth", 0.5),
        "communication": data.get("communication", 0.5)
    }
    
    # Calculate detailed feedback labels (logic moved from frontend to backend)
    feedback = []
    if metrics["communication"] > 0.8:
        feedback.append({"label": "Communication", "score": metrics["communication"] * 100, "text": "Great eye contact and confident body language"})
    if metrics["clarity"] > 0.8:
        feedback.append({"label": "Clarity", "score": metrics["clarity"] * 100, "text": "Clear and concise explanation of concepts"})
    
    return jsonify({
        "status": "success",
        "detailed_feedback": feedback,
        "recommendation": "Try to provide more metrics in your technical answers" if metrics["technical_depth"] < 0.7 else "Strong technical profile"
    }), 200

@app.route('/api/candidate-score', methods=['POST'], strict_slashes=False)
def get_candidate_score():
    """Calculates employability score based on resume and interview datasets."""
    data = request.json
    if not data:
        return jsonify({"error": "No data provided"}), 400
        
    resume_data = data.get("resume_data", {})
    interview_data = data.get("interview_data", {})
    
    result = calculate_employability_score(resume_data, interview_data)
    return jsonify(result), 200

@app.route('/', methods=['GET'])
def health_check():
    print("Health check requested")
    return jsonify({"status": "healthy", "service": "Hassle-Free Resume Parser API", "port": 5002}), 200

if __name__ == '__main__':
    # Switch to port 5002 to avoid conflict with Flutter Web (often on 5000/5001)
    print("Starting Flask server on http://localhost:5002...")
    app.run(debug=True, host='0.0.0.0', port=5002)
