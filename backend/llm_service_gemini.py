import os
from typing import List

import requests

_GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
_DEFAULT_MODEL = os.getenv("GEMINI_MODEL_NAME", "gemini-1.5-flash")
_GEMINI_BASE_URL = os.getenv(
    "GEMINI_BASE_URL",
    "https://generativelanguage.googleapis.com/v1beta/models",
)


def _build_prompt(question: str, contexts: List[str]) -> str:
    context_block = "\n\n".join(
        f"[{idx + 1}] {chunk.strip()}" for idx, chunk in enumerate(contexts) if chunk.strip()
    )
    return (
        "You are a multilingual government assistant. "
        "Answer using the provided context first. "
        "If the context is insufficient, say what is missing clearly.\n\n"
        f"Context:\n{context_block}\n\n"
        f"Question: {question.strip()}\n"
        "Answer:"
    )


def _extract_text(response_json: dict) -> str:
    candidates = response_json.get("candidates") or []
    for candidate in candidates:
        content = candidate.get("content") or {}
        parts = content.get("parts") or []
        text = "".join(part.get("text", "") for part in parts).strip()
        if text:
            return text
    return ""


def generate_rag_answer_gemini(
    question: str,
    contexts: List[str],
    max_new_tokens: int = 256,
    temperature: float = 0.2,
    top_p: float = 0.9,
) -> str:
    clean_question = (question or "").strip()
    if not clean_question:
        raise ValueError("question is required")
    if not contexts:
        raise ValueError("contexts cannot be empty")
    if not _GEMINI_API_KEY:
        raise ValueError("GEMINI_API_KEY is not set")

    prompt = _build_prompt(clean_question, contexts)
    payload = {
        "contents": [
            {
                "role": "user",
                "parts": [{"text": prompt}],
            }
        ],
        "generationConfig": {
            "temperature": temperature,
            "topP": top_p,
            "maxOutputTokens": max_new_tokens,
        },
    }

    try:
        response = requests.post(
            f"{_GEMINI_BASE_URL}/{_DEFAULT_MODEL}:generateContent?key={_GEMINI_API_KEY}",
            json=payload,
            timeout=180,
        )
    except requests.RequestException as exc:
        raise RuntimeError("Failed to reach Gemini API") from exc

    if response.status_code != 200:
        raise RuntimeError(f"Gemini generation failed: {response.text}")

    answer = _extract_text(response.json())
    if not answer:
        raise RuntimeError("Gemini returned an empty response")

    return answer