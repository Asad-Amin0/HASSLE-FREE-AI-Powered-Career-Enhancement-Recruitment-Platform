// server/index.js
import express from "express";
import cors from "cors";
import bodyParser from "body-parser";
import fetch from "node-fetch"; // npm install node-fetch@2
import OpenAI from "openai";

const app = express();
app.use(cors({ origin: '*' }));
app.use(bodyParser.json());

app.get("/", (req, res) => {
  res.send("🟢 Mock-Interview API is running and ready for requests!");
});


const OPENAI_API_KEY = process.env.OPENAI_API_KEY; // set in .env
const openai = new OpenAI({
  apiKey: OPENAI_API_KEY,
  baseURL: "https://generativelanguage.googleapis.com/v1beta/openai/"
});

function buildQuestionPrompt({ jobRole, skills, count }) {
  return `
You are a senior interview‑question designer. Produce ${count} distinct interview
questions (including the ideal answer) for a ${jobRole} candidate whose main
skills are: ${skills.join(", ")}.

Return a JSON array, each entry containing:
{
  "id": "<unique-id>",
  "question": "<question text>",
  "idealAnswer": "<model answer>",
  "keyPhrases": ["important","keywords","to match"],
  "skill": "<related skill>",
  "difficulty": "beginner|intermediate|advanced",
  "category": "technical|behavioral|situational",
  "facialExpression": "smile|curious|serious",
  "avatarAnimation": "Talking_0"
}
`;
}

app.post("/generateInterviewQuestions", async (req, res) => {
  try {
    const { jobRole, skills, count = 7 } = req.body;
    const prompt = buildQuestionPrompt({ jobRole, skills, count });
    const response = await openai.chat.completions.create({
      model: "gemini-1.5-flash",
      messages: [{ role: "user", content: prompt }],
      temperature: 0.7,
    });
    let content = response.choices[0].message.content;
    // Strip markdown code blocks if present
    content = content.replace(/```json|```/g, "").trim();
    const json = JSON.parse(content);
    res.json({ questions: json });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to generate questions" });
  }
});

function evaluateLocally({ question, userAnswer }) {
  const lower = userAnswer.toLowerCase();
  const matched = question.keyPhrases.filter(p => lower.includes(p.toLowerCase()));
  const missed = question.keyPhrases.filter(p => !matched.includes(p));
  const keywordScore = question.keyPhrases.length ? matched.length / question.keyPhrases.length : 0.5;
  const wordCount = userAnswer.trim().split(/\s+/).length;
  const lengthBonus = wordCount < 10 ? -0.15 : wordCount > 30 ? 0.1 : 0.0;
  const score = Math.min(1, Math.max(0, keywordScore + lengthBonus));
  const passed = score >= 0.55;
  const feedback = score >= 0.8
    ? `Excellent answer! You covered: ${matched.join(", ")}.`
    : score >= 0.55
        ? `Good answer. You mentioned: ${matched.join(", ")}. Consider: ${missed.slice(0,3).join(", ")}.`
        : `Answer needs more detail. Missing: ${missed.slice(0,4).join(", ")}.`;
  const encouragement = passed ? "Great job! Keep it up." : "Keep practicing – you can improve this.";
  return { score, matchedPhrases: matched, missedPhrases: missed, feedback, encouragement, passed, points: Math.round(score * 10) };
}

app.post("/evaluateAnswer", async (req, res) => {
  try {
    const { questionId, questionText, idealAnswer, keyPhrases, userAnswer, skill, difficulty } = req.body;
    const prompt = `
You are an interview evaluator. Given the question and the ideal answer, grade the candidate's response.

Question: ${questionText}
Ideal answer: ${idealAnswer}
Candidate answer: ${userAnswer}

Provide a JSON with {"score":0-1,"matchedPhrases":[],"missedPhrases":[],"feedback":"...","encouragement":"...","passed":true|false}`;
    let result;
    try {
      const ai = await openai.chat.completions.create({
        model: "gemini-1.5-flash",
        messages: [{ role: "user", content: prompt }],
        temperature: 0.2,
      });
      let content = ai.choices[0].message.content;
      // Strip markdown code blocks if present
      content = content.replace(/```json|```/g, "").trim();
      result = JSON.parse(content);
    } catch (_) {
      result = evaluateLocally({ question: { keyPhrases }, userAnswer });
    }
    res.json({
      questionId,
      questionText,
      userAnswer,
      idealAnswer,
      ...result,
      answeredAt: Date.now(),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Evaluation failed" });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`🟢 Mock‑Interview API listening on ${PORT}`));
