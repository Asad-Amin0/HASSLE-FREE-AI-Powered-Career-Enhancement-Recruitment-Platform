import re

def calculate_employability_score(resume_data, interview_data=None, test_data=None):
    """
    Calculates a score from 0-100 based on the refined request:
    - Experience (Max 40 pts): 2+ years = 40 points.
    - Education (Max 30 pts): 20 for 4-year degree, 10 for college/school.
    - Certificates (Max 10 pts): Presence of certificates = 10 points.
    - Skills (Max 20 pts): 1.2 points per skill (Max 20).
    
    Total: 100 Points.
    """
    total_score = 0.0
    
    # --- 1. Experience (Max 40 pts) ---
    exp_text = resume_data.get('experience', '').lower()
    exp_points = 0.0
    year_match = re.search(r'(\d+)\s*\+?\s*year', exp_text)
    if year_match:
        years = int(year_match.group(1))
        if years >= 2:
            exp_points = 40.0
        else:
            exp_points = (years / 2.0) * 40.0
    else:
        num_exp_lines = len([l for l in exp_text.split('\n') if len(l.strip()) > 10])
        if num_exp_lines >= 3:
            exp_points = 40.0
        elif num_exp_lines > 0:
            exp_points = 20.0
    total_score += exp_points

    # --- 2. Education (Max 30 pts) ---
    edu_text = resume_data.get('education', '').lower()
    edu_points = 0.0
    # 20 points for 4-year degree
    if any(marker in edu_text for marker in ['bachelor', 'bs', 'b.e', 'btech', 'b.tech', 'be']):
        edu_points += 20.0
    # 10 points for college/school
    if any(m in edu_text for m in ['college', 'school', 'academy', 'high school', 'intermediate']):
        edu_points += 10.0
    total_score += edu_points

    # --- 3. Certificates (Max 10 pts) ---
    cert_keywords = ['certificate', 'certified', 'certification', 'license', 'nanodegree']
    full_text = (edu_text + " " + exp_text + " " + resume_data.get('text', '').lower())
    cert_matches = [kw for kw in cert_keywords if kw in full_text]
    cert_points = 10.0 if cert_matches else 0.0
    total_score += cert_points

    # --- 4. Skills (Max 20 pts) ---
    skills = resume_data.get('skills', [])
    num_skills = len(skills)
    skill_points = min(num_skills * 1.2, 20.0)
    total_score += skill_points

    # --- Badge Awarding Logic ---
    badges = []
    if total_score >= 85:
        badges.append("Highly Employable")
    if skill_points >= 18: # 15+ skills
        badges.append("Top Skilled")
    if skill_points >= 12 and exp_points >= 30:
        badges.append("Technical Specialist")

    return {
        "overall_score": round(min(total_score, 100.0), 1),
        "scale": 100,
        "breakdown": {
            "experience": round(exp_points, 1),
            "education": round(edu_points, 1),
            "certificates": round(cert_points, 1),
            "skills": round(skill_points, 1)
        },
        "badges": badges
    }
