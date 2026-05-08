import PyPDF2
import io
import re
import os
import spacy
import nltk
from docx import Document
from nltk.corpus import stopwords
import pickle
import numpy as np

# Load NLP models and tools
try:
    nltk.download('stopwords', quiet=True)
    stop_words = set(stopwords.words('english'))
    nlp = spacy.load('en_core_web_sm')
except Exception as e:
    print(f"Warning: Error loading NLP tools: {e}")
    nlp = None

# For the AI Model
try:
    MODEL_PATH = "hassle_free_model"
    if os.path.exists(os.path.join(MODEL_PATH, "model.pkl")):
        with open(os.path.join(MODEL_PATH, "model.pkl"), 'rb') as f:
            model = pickle.load(f)
        with open(os.path.join(MODEL_PATH, "vectorizer.pkl"), 'rb') as f:
            vectorizer = pickle.load(f)
        classes = np.load('classes.npy', allow_pickle=True)
        HAS_AI_MODEL = True
    else:
        HAS_AI_MODEL = False
except Exception:
    HAS_AI_MODEL = False

# High-fidelity Skill Dictionary
KNOWN_SKILLS = {
    "python", "java", "javascript", "c++", "c#", "ruby", "php", "swift", "kotlin", "go", "rust", "typescript",
    "html", "css", "react", "angular", "vue", "next.js", "tailwind", "bootstrap", "jquery", "sass",
    "node.js", "django", "flask", "spring", "laravel", "dotnet", "fastapi", "express",
    "sql", "mysql", "postgresql", "mongodb", "nosql", "firebase", "redis", "oracle", "mariadb",
    "aws", "azure", "gcp", "docker", "kubernetes", "git", "ci/cd", "terraform", "ansible", "jenkins",
    "machine learning", "artificial intelligence", "data science", "nlp", "tensorflow", "pytorch", 
    "spacy", "pandas", "numpy", "matplotlib", "scikit-learn", "keras", "deep learning", "opencv",
    "flutter", "dart", "react native", "swiftui", "android studio", "xcode", "wireshark", "cisco packet tracer",
    "vs code", "visual studio", "sqlite", "rest api", "api", "json", "xml", "agile", "scrum", "excel", "powerpoint", "word"
}

# Extensive Tech/Section Blacklist
NAME_BLACKLIST = {
    "skill", "skills", "education", "experience", "profile", "summary", "contact", 
    "projects", "objective", "certifications", "interests", "languages", "language",
    "software", "technical", "personal", "soft", "proficiency", "hobbies", "project",
    "java", "kotlin", "firebase", "android", "studio", "python", "mysql", "git", "github",
    "linkedin", "email", "phone", "address", "curriculum", "vitae", "resume", "university", "college",
    "academy", "graduate", "certified", "certificate", "associate", "professional", "intern", "internship"
}

def extract_text(file_content, file_ext):
    text = ""
    try:
        if file_ext == 'pdf':
            reader = PyPDF2.PdfReader(io.BytesIO(file_content))
            for page in reader.pages:
                page_text = page.extract_text()
                if page_text:
                    page_text = page_text.replace('\u0000', '') 
                    text += page_text + "\n"
        elif file_ext == 'docx':
            doc = Document(io.BytesIO(file_content))
            for para in doc.paragraphs:
                text += para.text + "\n"
    except Exception as e:
        print(f"Extraction Error: {e}")
    return text

def clean_resume(text):
    if not text: return ""
    text = re.sub(r'http\S+\s*', ' ', text)
    text = re.sub(r'[^\x00-\x7f]', r' ', text) 
    text = re.sub(r'\s+', ' ', text).strip()
    return text

def is_valid_name_format(name):
    name = name.strip()
    if not name or len(name) < 4: return False
    words = name.split()
    if len(words) < 2 or len(words) > 4: return False
    
    # Check if words are plausible names (Starts with Capital)
    if not all(w[0].isupper() for w in words if w[0].isalpha()): return False
    
    # Check if any word is completely capitalized (often indicates a tech acronym)
    if any(w.isupper() and len(w) > 2 for w in words): return False
    
    # Check blacklist
    lower_name = name.lower()
    if any(k in lower_name for k in NAME_BLACKLIST): return False
    
    # No numbers or tech symbols
    if any(char.isdigit() or char in "[]{}()_/" for char in name): return False
    
    return True

def extract_name(text):
    if not text: return "Candidate"
    
    # NLP Page 1 scan
    if nlp:
        doc = nlp(text[:1500])
        for ent in doc.ents:
            if ent.label_ == "PERSON":
                cand = ent.text.strip()
                if is_valid_name_format(cand):
                    return cand.title()
    
    # Deep line scan
    lines = [l.strip() for l in text.split('\n') if len(l.strip()) > 3]
    for line in lines[:20]: 
        if is_valid_name_format(line):
            return line.title()
            
    return "Candidate"

def extract_skills(text):
    if not text: return []
    text_lower = text.lower()
    detected = {skill for skill in KNOWN_SKILLS if skill in text_lower}
    return sorted(list(detected))

def extract_sections(text):
    sections = {"experience": [], "education": [], "certificates": []}
    
    exp_headers = [r'experience', r'employment', r'work history', r'projects', r'job profile', r'professional background', r'work experience']
    edu_headers = [r'education', r'academic', r'qualifications', r'scholastic']
    cert_headers = [r'certifications', r'certificates', r'awards', r'courses', r'licenses', r'achievement']
    
    stop_headers = [r'skills', r'summary', r'languages', r'contact', r'interests', r'hobbies', r'references']
    
    lines = text.split('\n')
    current_section = None
    
    for line in lines:
        clean_line = line.strip().lower()
        if not clean_line or len(clean_line) < 3: continue
        
        # Check for Education Header
        if any(re.search(r'\b' + h + r'\b', clean_line) for h in edu_headers):
            current_section = "education"
            continue
            
        # Check for Certificates Header
        if any(re.search(r'\b' + h + r'\b', clean_line) for h in cert_headers):
            current_section = "certificates"
            continue
        
        # Check for Experience Header
        if any(re.search(r'\b' + h + r'\b', clean_line) for h in exp_headers):
            current_section = "experience"
            continue
            
        # Check for Stop Header
        if current_section and any(re.search(r'^' + s + r'$', clean_line) for s in stop_headers):
            current_section = None
            continue
            
        if current_section:
            sections[current_section].append(line.strip())
            if len(sections[current_section]) > 30: current_section = None

    # FALLBACK: If certificates section is empty, scan text for common certificate patterns
    if not sections["certificates"]:
        cert_patterns = [
            r'(?i)(certified\s+[\w\s]{3,30})',
            r'(?i)(certificate\s+in\s+[\w\s]{3,30})',
            r'(?i)(license\s+[\w\s]{3,30})',
            r'(?i)(awarded\s+[\w\s]{3,30})',
            r'(?i)([\w\s]{3,30}\s+certification)'
        ]
        text_full = " ".join(lines)
        for pattern in cert_patterns:
            matches = re.findall(pattern, text_full)
            for m in matches:
                if isinstance(m, str) and len(m) > 5:
                    sections["certificates"].append(m.strip())

    # De-duplicate certificates
    unique_certs = []
    seen = set()
    for c in sections["certificates"]:
        c_low = c.lower().strip()
        if c_low not in seen and len(c_low) > 4:
            unique_certs.append(c)
            seen.add(c_low)
            
    return {
        "experience": "\n".join(sections["experience"][:12]) if sections["experience"] else "No history found.",
        "education": "\n".join(sections["education"][:8]) if sections["education"] else "No history found.",
        "certificates": unique_certs[:10]
    }

def analyze_resume(file_bytes, filename):
    ext = filename.split('.')[-1].lower()
    raw_text = extract_text(file_bytes, ext)
    if not raw_text: return {"error": "Text extraction failed."}
    
    cleaned_all = clean_resume(raw_text)
    name = extract_name(raw_text)
    
    # Use AI for category
    if HAS_AI_MODEL:
        try:
            feats = vectorizer.transform([cleaned_all])
            cat = str(model.predict(feats)[0])
        except: cat = "Information Technology"
    else: cat = "Information Technology"
        
    skills = extract_skills(cleaned_all)
    sects = extract_sections(raw_text)
    
    return {
        "status": "success",
        "name": name,
        "category": cat,
        "skills": skills,
        "experience": sects["experience"],
        "education": sects["education"],
        "certificates": sects["certificates"],
        "text_preview": cleaned_all[:400] + "..."
    }
