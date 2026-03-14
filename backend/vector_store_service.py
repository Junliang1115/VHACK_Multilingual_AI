import os
import uuid
from typing import List

import chromadb
from chromadb.config import Settings

_CHROMA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "chroma_db")
_CLIENT: chromadb.PersistentClient | None = None


def _get_client() -> chromadb.PersistentClient:
    global _CLIENT
    if _CLIENT is None:
        _CLIENT = chromadb.PersistentClient(
            path=_CHROMA_DIR,
            settings=Settings(anonymized_telemetry=False),
        )
    return _CLIENT


def _get_collection(collection_name: str) -> chromadb.Collection:
    return _get_client().get_or_create_collection(
        name=collection_name,
        metadata={"hnsw:space": "cosine"},
    )


def store_chunks(
    chunks: List[str],
    embeddings: List[List[float]],
    collection_name: str = "default",
    doc_id: str | None = None,
) -> List[str]:
    """
    Store pre-chunked text and their embeddings into ChromaDB.

    Args:
        chunks: Text chunks from chunking_service.
        embeddings: Corresponding vectors from embedding_service.
        collection_name: Target ChromaDB collection.
        doc_id: Optional document identifier stored as metadata.

    Returns:
        List of IDs assigned to the stored chunks.
    """
    if len(chunks) != len(embeddings):
        raise ValueError("chunks and embeddings must have the same length")

    base_id = doc_id or str(uuid.uuid4())
    ids = [f"{base_id}__chunk_{i}" for i in range(len(chunks))]
    metadatas = [{"doc_id": base_id, "chunk_index": i} for i in range(len(chunks))]

    collection = _get_collection(collection_name)
    collection.upsert(
        ids=ids,
        embeddings=embeddings,
        documents=chunks,
        metadatas=metadatas,
    )
    return ids


def query_collection(
    query_embeddings: List[List[float]],
    collection_name: str = "default",
    top_k: int = 5,
) -> List[dict]:
    """
    Search ChromaDB for the closest chunks to the given query embedding(s).

    Returns:
        List of result dicts, one per query, each with keys:
        ids, documents, distances, metadatas.
    """
    collection = _get_collection(collection_name)
    results = collection.query(
        query_embeddings=query_embeddings,
        n_results=top_k,
        include=["documents", "distances", "metadatas"],
    )

    output = []
    for i in range(len(results["ids"])):
        output.append({
            "ids": results["ids"][i],
            "documents": results["documents"][i],
            "distances": results["distances"][i],
            "metadatas": results["metadatas"][i],
        })
    return output


def delete_collection(collection_name: str) -> bool:
    """Delete named collection. Returns True if deleted, False if not found."""
    client = _get_client()
    existing = [c.name for c in client.list_collections()]
    if collection_name not in existing:
        return False
    client.delete_collection(collection_name)
    return True


def list_collections() -> List[str]:
    """Return names of all existing collections."""
    return [c.name for c in _get_client().list_collections()]
