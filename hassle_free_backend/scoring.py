import re

def calculate_employability_score(resume_data, interview_data=None, test_data=None):
    """
    Calculates a score from 0-100 based on Resume and Interview performance:
    - Resume Score (60% weight): Experience, Education, Certificates, Skills.
    - Interview Score (40% weight): Clarity, Confidence, Technical Depth, Communication.
    """
    
    # --- 1. Resume Scoring (Base 100) ---
    resume_score = 0.0
    
    # Experience (Max 30)
    exp_text = resume_data.get('experience', '').lower()
    exp_points = 0.0
    num_exp_lines = len([l for l in exp_text.split('\n') if len(l.strip()) > 10])
    exp_points = 30.0 if num_exp_lines >= 3 else (15.0 if num_exp_lines > 0 else 0.0)
    resume_score += exp_points

    # Education (Max 20)
    edu_text = resume_data.get('education', '').lower()
    edu_points = 0.0
    # 4-year degree (Bachelor/BS): 10
    if any(m in edu_text for m in ['bachelor', 'bs', 'b.e', 'btech', 'b.tech', 'be']):
        edu_points += 10.0
    # 2-year degree (Associate/College/Intermediate): 10
    if any(m in edu_text for m in ['associate', '2 year', 'college', 'intermediate', 'diploma']):
        edu_points += 10.0
    # Masters/PhD can bolster the score if one is missing, but capped at 20
    if ('master' in edu_text or 'ms' in edu_text) and edu_points < 20:
        edu_points = min(edu_points + 5.0, 20.0)
    
    resume_score += edu_points

    # Skills (Max 30)
    skills = resume_data.get('skills', [])
    skill_points = min(len(skills) * 1.5, 30.0)
    resume_score += skill_points

    # Certificates (Max 10-20)
    certs = resume_data.get('certificates', [])
    if len(certs) > 4:
        # Fit within 20%
        cert_points = min(len(certs) * 4.0, 20.0)
    else:
        # Max 10%
        cert_points = min(len(certs) * 2.5, 10.0)
    resume_score += cert_points

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
