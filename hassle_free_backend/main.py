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
    """Endpoint for analyzing interview metrics and updating the overall score."""
    print("--- Incoming Interview Analysis ---")
    data = request.json
    if not data:
        return jsonify({"error": "No data provided"}), 400
        
    # Metrics from the interview (Full SDS Set)
    metrics = {
        "clarity": data.get("clarity", 0.5),
        "confidence": data.get("confidence", 0.5),
        "technical_depth": data.get("technical_depth", 0.5),
        "communication": data.get("communication", 0.5),
        "tone_modulation": data.get("tone_modulation", 0.5),
        "keyword_relevance": data.get("keyword_relevance", 0.5)
    }
    
    # Optional resume data to calculate the updated overall score
    resume_data = data.get("resume_data", {})
    scoring_result = calculate_employability_score(resume_data, metrics)
    
    # Generate detailed feedback based on SDS dimensions
    feedback = []
    
    # 1. Communication & Sentiment
    if metrics["communication"] > 0.8:
        feedback.append({"label": "Communication", "score": metrics["communication"] * 100, "text": "Great eye contact and confident body language"})
    else:
        feedback.append({"label": "Communication", "score": metrics["communication"] * 100, "text": "Work on maintaining more consistent eye contact"})

    # 2. Tone Modulation (SDS Page 8)
    if metrics["tone_modulation"] > 0.7:
        feedback.append({"label": "Tone", "score": metrics["tone_modulation"] * 100, "text": "Excellent vocal variety and professional pitch"})
    else:
        feedback.append({"label": "Tone", "score": metrics["tone_modulation"] * 100, "text": "Try to vary your pitch to avoid sounding monotonous"})

    # 3. Keyword Relevance (SDS Page 8)
    if metrics["keyword_relevance"] > 0.8:
        feedback.append({"label": "Keywords", "score": metrics["keyword_relevance"] * 100, "text": "Strong usage of relevant industry-standard terminology"})
    else:
        feedback.append({"label": "Keywords", "score": metrics["keyword_relevance"] * 100, "text": "Incorporate more role-specific keywords in your answers"})

    # 4. Clarity & Technical Depth
    if metrics["clarity"] > 0.8:
        feedback.append({"label": "Clarity", "score": metrics["clarity"] * 100, "text": "Clear and concise explanation of complex concepts"})
    
    # NEW: Satisfaction-driven Critique (What is Right and What is Wrong)
    critique = {
        "right": [],
        "wrong": []
    }
    
    # Logic for Critique
    if metrics["communication"] > 0.7:
        critique["right"].append("Strong eye contact and professional body language.")
    else:
        critique["wrong"].append("Body language appeared slightly closed; try to use more open gestures.")

    if metrics["tone_modulation"] > 0.7:
        critique["right"].append("Excellent vocal variety that kept the conversation engaging.")
    else:
        critique["wrong"].append("Tone was somewhat monotonous; vary your pitch to emphasize key points.")

    if metrics["keyword_relevance"] > 0.7:
        critique["right"].append("Good use of industry-standard terminology.")
    else:
        critique["wrong"].append("Missed key industry terms; try to link your experience to specific tools.")

    if metrics["technical_depth"] > 0.8:
        critique["right"].append("Demonstrated deep technical expertise in your answers.")
    else:
        critique["wrong"].append("Technical answers were surface-level; provide more metrics/examples.")

    return jsonify({
        "status": "success",
        "detailed_feedback": feedback,
        "score_update": scoring_result,
        "critique": critique,
        "recommendation": "Strong profile with high keyword relevance" if metrics["keyword_relevance"] > 0.7 else "Consider studying more industry-specific terminology"
    }), 200

@app.route('/api/generate-questions', methods=['POST'], strict_slashes=False)
def generate_questions():
    """Generates a dynamic set of interview questions based on user skills."""
    data = request.json
    skills = data.get("skills", [])
    
    # Base behavioral questions
    questions = [
        "Tell me about a project where you applied your strongest skills to solve a complex problem.",
        "How do you handle a situation where you lack the necessary expertise to complete a task?"
    ]
    
    # Skill-specific technical questions (Dynamic Mapping)
    skill_map = {
        "python": [
            "Explain the difference between deep copy and shallow copy in Python.",
            "How does Python's memory management work, particularly with garbage collection?",
            "What are decorators in Python and how are they used?"
        ],
        "flutter": [
            "What is the difference between a StatelessWidget and a StatefulWidget?",
            "How do you handle state management in large-scale Flutter applications?",
            "Explain the Flutter widget lifecycle."
        ],
        "dart": [
            "Explain the concept of 'mixins' in Dart.",
            "How does asynchronous programming work in Dart using Futures and Streams?",
            "What is the difference between 'final' and 'const' in Dart?"
        ],
        "react": [
            "What are React Hooks and why are they used?",
            "Explain the Virtual DOM and how React updates the UI efficiently.",
            "What is the difference between functional and class components?"
        ],
        "node.js": [
            "Explain the event loop in Node.js.",
            "What is the difference between setImmediate() and process.nextTick()?",
            "How do you handle streams in Node.js?"
        ],
        "aws": [
            "What is the difference between S3 and EBS?",
            "Explain the shared responsibility model in AWS.",
            "How does AWS Lambda work?"
        ],
        "docker": [
            "What is the difference between an image and a container?",
            "Explain Docker Compose and its use cases.",
            "How do you optimize a Dockerfile for smaller image sizes?"
        ],
        "c++": [
            "What are pointers and references in C++?",
            "Explain polymorphism and how it is achieved in C++.",
            "What is the RAII principle?"
        ],
        "java": [
            "What are the main principles of Object-Oriented Programming, and how does Java implement them?",
            "Explain the Java Virtual Machine (JVM) architecture.",
            "What is the difference between an interface and an abstract class?"
        ],
        "sql": [
            "What is the difference between an INNER JOIN and a LEFT JOIN?",
            "Explain database normalization and its importance.",
            "What are indexes and how do they improve query performance?"
        ],
        "machine learning": [
            "What is the difference between supervised and unsupervised learning?",
            "How do you handle overfitting in a machine learning model?",
            "Explain the concept of cross-validation."
        ],
        "ai": [
            "Explain the concept of Neural Networks and their basic architecture.",
            "What are the ethical considerations when developing AI systems?",
            "What is the difference between Narrow AI and General AI?"
        ]
    }
    
    # Add questions based on found skills
    for skill in skills:
        skill_lower = skill.lower().strip()
        for key in skill_map:
            if key in skill_lower or skill_lower in key:
                import random
                questions.append(random.choice(skill_map[key]))
            
    # Fallback if no specific skills found
    if len(questions) < 5:
        questions.append("Where do you see yourself professionally in the next five years?")
        questions.append("Why are you the best candidate for a role involving your current skillset?")
        questions.append("Describe a time you failed and how you handled it.")

    # Return top 5 unique questions
    import random
    random.shuffle(questions)
    return jsonify({"questions": list(dict.fromkeys(questions))[:5]}), 200

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
