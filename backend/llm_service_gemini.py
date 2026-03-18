import os
from typing import List
import re

import requests

_GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
_DEFAULT_MODEL = os.getenv("GEMINI_MODEL_NAME", "gemini-1.5-flash")
_GEMINI_BASE_URL = os.getenv(
    "GEMINI_BASE_URL",
    "https://generativelanguage.googleapis.com/v1beta/models",
)


def _build_translation_prompt(text: str, dialect: str) -> str:
    return (
        "You are a professional translator. "
        "Translate the input into the requested dialect or language exactly. "
        "Preserve meaning, tone, and names. "
        "Return only the translated text. "
        "Do not include labels, explanations, quotes, or markdown. "
        "The output must be in the requested dialect or language.\n\n"
        f"Target dialect or language: {dialect}\n"
        f"Input: {text.strip()}\n"
        "Translation:"
    )


def _extract_translation_only(answer: str) -> str:
    cleaned = (answer or "").strip()
    if not cleaned:
        return ""

    # Remove common model-added labels such as "Translation:".
    cleaned = re.sub(r"^\s*(translation|translated text|output)\s*:\s*", "", cleaned, flags=re.IGNORECASE)

    # Remove wrapping quotes while preserving internal punctuation.
    if len(cleaned) >= 2 and cleaned[0] == cleaned[-1] and cleaned[0] in {'"', "'"}:
        cleaned = cleaned[1:-1].strip()

    return cleaned


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

    return _extract_translation_only(answer)


def generate_translation_gemini(
    text: str,
    dialect: str,
    max_new_tokens: int = 256,
    temperature: float = 0.2,
    top_p: float = 0.9,
) -> str:
    clean_text = (text or "").strip()
    if not clean_text:
        raise ValueError("text is required")
    if not _GEMINI_API_KEY:
        raise ValueError("GEMINI_API_KEY is not set")

    prompt = _build_translation_prompt(clean_text, dialect)
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