from typing import List

from sentence_transformers import SentenceTransformer

_MODEL_NAME = "SEALD/seald-embedding"
_EMBEDDING_MODEL = None


def _get_model() -> SentenceTransformer:
    global _EMBEDDING_MODEL
    if _EMBEDDING_MODEL is None:
        _EMBEDDING_MODEL = SentenceTransformer(_MODEL_NAME)
    return _EMBEDDING_MODEL


def embed_texts(texts: List[str], normalize_embeddings: bool = True) -> List[List[float]]:
    """
    Convert a list of texts into embedding vectors.
    """
    clean_texts = [text.strip() for text in texts if text and text.strip()]
    if not clean_texts:
        return []

    model = _get_model()
    vectors = model.encode(
        clean_texts,
        convert_to_numpy=True,
        normalize_embeddings=normalize_embeddings,
    )
    return vectors.tolist()
