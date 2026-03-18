import os
from typing import List

import requests

_OLLAMA_URL = os.getenv("OLLAMA_BASE_URL", "http://127.0.0.1:11434")
_DEFAULT_MODEL = os.getenv("SAILOR2_MODEL_NAME", "sailor2:1b")


def _build_translation_prompt(text: str, dialect: str) -> str:
    return (
        "You are a professional translator. "
        "Translate the input into the requested dialect or language. "
        "Preserve meaning, tone, and names. "
        "Return only the translated text without extra commentary.\n\n"
        f"Target dialect or language: {dialect}\n"
        f"Input: {text.strip()}\n"
        "Translation:"
    )


def _build_prompt(question: str, contexts: List[str]) -> str:
    context_block = "\n\n".join(
        f"[{idx + 1}] {chunk.strip()}" for idx, chunk in enumerate(contexts) if chunk.strip()
    )
    return (
        "You are a multilingual government assistant. "
        "Answer using only the provided context when possible. "
        "If context is insufficient, say what is missing clearly.\n\n"
        f"Context:\n{context_block}\n\n"
        f"Question: {question.strip()}\n"
        "Answer:"
    )


def generate_rag_answer(
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

    prompt = _build_prompt(clean_question, contexts)
    payload = {
        "model": _DEFAULT_MODEL,
        "prompt": prompt,
        "stream": False,
        "options": {
            "temperature": temperature,
            "top_p": top_p,
            "num_predict": max_new_tokens,
        },
    }

    try:
        response = requests.post(
            f"{_OLLAMA_URL}/api/generate",
            json=payload,
            timeout=180,
        )
    except requests.RequestException as exc:
        raise RuntimeError(
            "Failed to reach local Ollama server. Ensure Ollama is running and the model is available."
        ) from exc

    if response.status_code != 200:
        raise RuntimeError(f"Ollama generation failed: {response.text}")

    data = response.json()
    answer = (data.get("response") or "").strip()
    if not answer:
        raise RuntimeError("Ollama returned an empty response")

    return answer


def generate_translation(
    text: str,
    dialect: str,
    max_new_tokens: int = 256,
    temperature: float = 0.2,
    top_p: float = 0.9,
) -> str:
    clean_text = (text or "").strip()
    if not clean_text:
        raise ValueError("text is required")

    prompt = _build_translation_prompt(clean_text, dialect)
    payload = {
        "model": _DEFAULT_MODEL,
        "prompt": prompt,
        "stream": False,
        "options": {
            "temperature": temperature,
            "top_p": top_p,
            "num_predict": max_new_tokens,
        },
    }

    try:
        response = requests.post(
            f"{_OLLAMA_URL}/api/generate",
            json=payload,
            timeout=180,
        )
    except requests.RequestException as exc:
        raise RuntimeError(
            "Failed to reach local Ollama server. Ensure Ollama is running and the model is available."
        ) from exc

    if response.status_code != 200:
        raise RuntimeError(f"Ollama generation failed: {response.text}")

    data = response.json()
    answer = (data.get("response") or "").strip()
    if not answer:
        raise RuntimeError("Ollama returned an empty response")

    return answer