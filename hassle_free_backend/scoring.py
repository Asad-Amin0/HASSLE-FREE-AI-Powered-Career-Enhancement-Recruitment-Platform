import re

def calculate_employability_score(resume_data, interview_data=None, test_data=None):
    """
    Calculates a score from 0-100 based on Resume and Interview performance:
    - Resume Score (60% weight): Experience, Education, Certificates, Skills.
    - Interview Score (40% weight): Clarity, Confidence, Technical Depth, Communication.
    """
    
    # --- 1. Resume Scoring (Base 100) ---
    resume_score = 0.0
    
    # Experience (Max 40)
    exp_text = resume_data.get('experience', '').lower()
    exp_points = 0.0
    year_match = re.search(r'(\d+)\s*\+?\s*year', exp_text)
    if year_match:
        years = int(year_match.group(1))
        exp_points = 40.0 if years >= 2 else (years / 2.0) * 40.0
    else:
        num_exp_lines = len([l for l in exp_text.split('\n') if len(l.strip()) > 10])
        exp_points = 40.0 if num_exp_lines >= 3 else (20.0 if num_exp_lines > 0 else 0.0)
    resume_score += exp_points

    # Education (Max 30)
    edu_text = resume_data.get('education', '').lower()
    edu_points = 0.0
    if any(m in edu_text for m in ['bachelor', 'bs', 'b.e', 'btech', 'b.tech', 'be']):
        edu_points += 20.0
    if any(m in edu_text for m in ['college', 'school', 'academy', 'high school', 'intermediate']):
        edu_points += 10.0
    resume_score += edu_points

    # Certificates (Max 10)
    cert_keywords = ['certificate', 'certified', 'certification', 'license', 'nanodegree']
    full_text = (edu_text + " " + exp_text + " " + resume_data.get('text', '').lower())
    cert_points = 10.0 if any(kw in full_text for kw in cert_keywords) else 0.0
    resume_score += cert_points

    # Skills (Max 20)
    skills = resume_data.get('skills', [])
    skill_points = min(len(skills) * 1.2, 20.0)
    resume_score += skill_points

    # --- 2. Interview Scoring (Base 100) ---
    interview_score = 0.0
    if interview_data:
        # 6 metrics based on SDS Page 8: Clarity, Confidence, Technical, Communication, Tone, Keywords
        metrics = [
            interview_data.get('clarity', 0.5),
            interview_data.get('confidence', 0.5),
            interview_data.get('technical_depth', 0.5),
            interview_data.get('communication', 0.5),
            interview_data.get('tone_modulation', 0.5),
            interview_data.get('keyword_relevance', 0.5)
        ]
        # Average of metrics scaled to 100
        interview_score = (sum(metrics) / len(metrics)) * 100.0
    else:
        interview_score = 0.0

    # --- 3. Weighted Final Score ---
    # If interview exists, weight is 60/40. If not, it's 100% resume for now.
    if interview_data:
        final_score = (resume_score * 0.6) + (interview_score * 0.4)
    else:
        final_score = resume_score

    # --- Badge Awarding Logic ---
    badges = []
    if final_score >= 85:
        badges.append("Highly Employable")
    if skill_points >= 18:
        badges.append("Top Skilled")
    if interview_score >= 80:
        badges.append("Great Communicator")
    if skill_points >= 12 and exp_points >= 30:
        badges.append("Technical Specialist")

    return {
        "overall_score": round(min(final_score, 100.0), 1),
        "resume_score": round(resume_score, 1),
        "interview_score": round(interview_score, 1),
        "breakdown": {
            "experience": round(exp_points, 1),
            "education": round(edu_points, 1),
            "certificates": round(cert_points, 1),
            "skills": round(skill_points, 1),
            "interview_performance": round(interview_score, 1)
        },
        "badges": badges
    }
