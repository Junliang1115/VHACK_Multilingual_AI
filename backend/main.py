import os
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import uvicorn
from ocr_service import capture_and_ocr
from chunking_service import chunk_text
from embedding_service import embed_texts
from vector_store_service import store_chunks, query_collection, delete_collection, list_collections
from llm_service import generate_rag_answer, generate_translation
from llm_service_gemini import generate_rag_answer_gemini, generate_translation_gemini

# Load environment variables
load_dotenv()

# Configuration from environment variables
APP_NAME = os.getenv("APP_NAME", "Gov Translate AI")
API_VERSION = os.getenv("API_VERSION", "1.0.0")
DEBUG = os.getenv("DEBUG", "True").lower() == "true"
HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "8000"))
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "*").split(",")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

app = FastAPI(title=f"{APP_NAME} API")

# Enable CORS for Flutter (necessary for web/mobile)
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Data Models
class TranslationRequest(BaseModel):
    text: str
    target_dialect: str = "Standard Malay"

class TranslationResponse(BaseModel):
    original_text: str
    translated_text: str
    dialect: str
    summary: Optional[str] = None

class SummaryRequest(BaseModel):
    text: str

class SummaryResponse(BaseModel):
    summary: str

# Chunking Service from LangChain
class ChunkRequest(BaseModel):
    text: str
    chunk_size: int = 500
    chunk_overlap: int = 50


class ChunkResponse(BaseModel):
    chunks: List[str]
    chunk_count: int


class ChunkEmbeddingRequest(BaseModel):
    text: str
    chunk_size: int = 500
    chunk_overlap: int = 50
    normalize_embeddings: bool = True


class ChunkEmbeddingResponse(BaseModel):
    chunks: List[str]
    embeddings: List[List[float]]
    chunk_count: int
    embedding_dimension: int
    model_name: str


class EmbedChunksRequest(BaseModel):
    chunks: List[str]
    normalize_embeddings: bool = True


class EmbedChunksResponse(BaseModel):
    embeddings: List[List[float]]
    chunk_count: int
    embedding_dimension: int
    model_name: str


# Vector Store Models
class IngestRequest(BaseModel):
    text: str
    collection_name: str = "default"
    doc_id: Optional[str] = None
    chunk_size: int = 500
    chunk_overlap: int = 50


class IngestResponse(BaseModel):
    collection_name: str
    doc_id: str
    chunk_count: int
    ids: List[str]


class SearchRequest(BaseModel):
    query: Optional[str] = None
    query_embedding: Optional[List[float]] = None
    normalize_embeddings: bool = True
    collection_name: str = "default"
    top_k: int = 5


class SearchResult(BaseModel):
    id: str
    document: str
    distance: float
    metadata: dict


class SearchResponse(BaseModel):
    results: List[SearchResult]
    collection_name: str


class QueryEmbeddingRequest(BaseModel):
    query: str
    normalize_embeddings: bool = True


class QueryEmbeddingResponse(BaseModel):
    embedding: List[float]
    embedding_dimension: int
    model_name: str


class RagGenerateRequest(BaseModel):
    query: str
    collection_name: str = "default"
    top_k: int = 5
    normalize_embeddings: bool = True
    max_new_tokens: int = 256
    temperature: float = 0.2
    top_p: float = 0.9


class RagGenerateResponse(BaseModel):
    query: str
    answer: str
    collection_name: str
    sources: List[SearchResult]

# Mock AI Logic (Replace with Gemini/OpenAI integration later)
def mock_translate(text: str, dialect: str) -> str:
    dialects = {
        "Kedah": "Hang nak pi mana tu? (Kedah version of: " + text[:20] + "...)",
        "Kelantan": "Demo nak g mano tu? (Kelantan version of: " + text[:20] + "...)",
        "Terengganu": "Mung nak gi mane tu? (Terengganu version of: " + text[:20] + "...)",
    }
    return dialects.get(dialect, f"(Standard) {text}")


def _normalize_dialect(dialect: str) -> str:
    dialect_map = {
        "Kelate": "Kelantan",
        "Hokkien": "Hokkien",
        "Cantonese": "Cantonese",
        "English": "English",
        "Standard": "Standard Malay",
        "Standard Malay": "Standard Malay",
    }
    return dialect_map.get(dialect, dialect)

@app.get("/")
async def root():
    return {
        "status": "ok",
        "message": "Gov Translate AI Backend is running",
        "version": API_VERSION,
        "ai_configured": bool(GEMINI_API_KEY or OPENAI_API_KEY)
    }

@app.post("/translate", response_model=TranslationResponse)
async def translate_text(request: TranslationRequest):
    if not request.text:
        raise HTTPException(status_code=400, detail="Text is required")

    print(
        f"DEBUG: /translate dialect={request.target_dialect} text_length={len(request.text)}"
    )

    normalized_dialect = _normalize_dialect(request.target_dialect)

    try:
        # if GEMINI_API_KEY:
        #     translated = generate_translation_gemini(
        #         text=request.text,
        #         dialect=normalized_dialect,
        #     )
        translated = generate_translation(
            text=request.text,
            dialect=normalized_dialect,
        )
    except Exception as exc:
        print(f"DEBUG: /translate error => {exc}")
        # Fall back to mock translation so the UI still responds.
        translated = mock_translate(request.text, normalized_dialect)

    return TranslationResponse(
        original_text=request.text,
        translated_text=translated,
        dialect=normalized_dialect,
    )

@app.post("/summarize", response_model=SummaryResponse)
async def summarize_text(request: SummaryRequest):
    if not request.text:
        raise HTTPException(status_code=400, detail="Text is required")
    
    return SummaryResponse(
        summary=f"Summary: The input text contains {len(request.text)} characters. (Mock summary logic)"
    )


@app.post("/chunk", response_model=ChunkResponse)
async def chunk_input_text(request: ChunkRequest):
    if not request.text or not request.text.strip():
        raise HTTPException(status_code=400, detail="Text is required")

    try:
        chunks = chunk_text(
            text=request.text,
            chunk_size=request.chunk_size,
            chunk_overlap=request.chunk_overlap,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    return ChunkResponse(chunks=chunks, chunk_count=len(chunks))


@app.post("/chunk-embed", response_model=ChunkEmbeddingResponse)
async def chunk_and_embed_input_text(request: ChunkEmbeddingRequest):
    if not request.text or not request.text.strip():
        raise HTTPException(status_code=400, detail="Text is required")

    try:
        chunks = chunk_text(
            text=request.text,
            chunk_size=request.chunk_size,
            chunk_overlap=request.chunk_overlap,
        )
        embeddings = embed_texts(
            chunks,
            normalize_embeddings=request.normalize_embeddings,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Embedding failed: {str(e)}")

    embedding_dimension = len(embeddings[0]) if embeddings else 0

    return ChunkEmbeddingResponse(
        chunks=chunks,
        embeddings=embeddings,
        chunk_count=len(chunks),
        embedding_dimension=embedding_dimension,
        model_name="SEALD/seald-embedding",
    )


@app.post("/embed-chunks", response_model=EmbedChunksResponse)
async def embed_existing_chunks(request: EmbedChunksRequest):
    if not request.chunks:
        raise HTTPException(status_code=400, detail="chunks is required")

    try:
        embeddings = embed_texts(
            request.chunks,
            normalize_embeddings=request.normalize_embeddings,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Embedding failed: {str(e)}")

    embedding_dimension = len(embeddings[0]) if embeddings else 0
    return EmbedChunksResponse(
        embeddings=embeddings,
        chunk_count=len(embeddings),
        embedding_dimension=embedding_dimension,
        model_name="SEALD/seald-embedding",
    )

@app.post("/ingest", response_model=IngestResponse)
async def ingest_text(request: IngestRequest):
    """Chunk → embed → store into ChromaDB in one call."""
    if not request.text or not request.text.strip():
        raise HTTPException(status_code=400, detail="Text is required")

    try:
        chunks = chunk_text(
            text=request.text,
            chunk_size=request.chunk_size,
            chunk_overlap=request.chunk_overlap,
        )
        embeddings = embed_texts(chunks)
        ids = store_chunks(
            chunks=chunks,
            embeddings=embeddings,
            collection_name=request.collection_name,
            doc_id=request.doc_id,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Ingest failed: {str(e)}")

    return IngestResponse(
        collection_name=request.collection_name,
        doc_id=ids[0].split("__chunk_")[0],
        chunk_count=len(chunks),
        ids=ids,
    )


@app.post("/search", response_model=SearchResponse)
async def search_text(request: SearchRequest):
    """Search by raw query text or a precomputed query embedding."""
    if request.top_k < 1:
        raise HTTPException(status_code=400, detail="top_k must be >= 1")

    has_query_text = bool(request.query and request.query.strip())
    has_query_embedding = bool(request.query_embedding)

    if has_query_text == has_query_embedding:
        raise HTTPException(
            status_code=400,
            detail="Provide exactly one of 'query' or 'query_embedding'",
        )

    try:
        if has_query_embedding:
            query_embeddings = [request.query_embedding]
        else:
            query_embeddings = embed_texts(
                [request.query],
                normalize_embeddings=request.normalize_embeddings,
            )

        raw_results = query_collection(
            query_embeddings=query_embeddings,
            collection_name=request.collection_name,
            top_k=request.top_k,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Search failed: {str(e)}")

    results = [
        SearchResult(
            id=rid,
            document=doc,
            distance=dist,
            metadata=meta,
        )
        for rid, doc, dist, meta in zip(
            raw_results[0]["ids"],
            raw_results[0]["documents"],
            raw_results[0]["distances"],
            raw_results[0]["metadatas"],
        )
    ]
    return SearchResponse(results=results, collection_name=request.collection_name)


@app.post("/embed-query", response_model=QueryEmbeddingResponse)
async def embed_user_query(request: QueryEmbeddingRequest):
    """Embed user query into a single vector for retrieval pipelines."""
    if not request.query or not request.query.strip():
        raise HTTPException(status_code=400, detail="Query is required")

    try:
        embeddings = embed_texts(
            [request.query],
            normalize_embeddings=request.normalize_embeddings,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Query embedding failed: {str(e)}")

    if not embeddings:
        raise HTTPException(status_code=500, detail="No embedding generated")

    query_embedding = embeddings[0]
    return QueryEmbeddingResponse(
        embedding=query_embedding,
        embedding_dimension=len(query_embedding),
        model_name="SEALD/seald-embedding",
    )


@app.post("/rag-generate", response_model=RagGenerateResponse)
async def rag_generate(request: RagGenerateRequest):
    """RAG pipeline: embed query -> search vectors -> generate answer with Sailor2."""
    clean_query = (request.query or "").strip()
    if not clean_query:
        raise HTTPException(status_code=400, detail="Query is required")
    if request.top_k < 1:
        raise HTTPException(status_code=400, detail="top_k must be >= 1")
    if request.max_new_tokens < 1:
        raise HTTPException(status_code=400, detail="max_new_tokens must be >= 1")
    if request.temperature < 0:
        raise HTTPException(status_code=400, detail="temperature must be >= 0")
    if request.top_p <= 0 or request.top_p > 1:
        raise HTTPException(status_code=400, detail="top_p must be between 0 and 1")

    try:
        query_embeddings = embed_texts(
            [clean_query],
            normalize_embeddings=request.normalize_embeddings,
        )
        raw_results = query_collection(
            query_embeddings=query_embeddings,
            collection_name=request.collection_name,
            top_k=request.top_k,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Retrieval failed: {str(e)}")

    if not raw_results or not raw_results[0]["documents"]:
        raise HTTPException(
            status_code=404,
            detail=f"No context found in collection '{request.collection_name}'",
        )

    sources = [
        SearchResult(
            id=rid,
            document=doc,
            distance=dist,
            metadata=meta,
        )
        for rid, doc, dist, meta in zip(
            raw_results[0]["ids"],
            raw_results[0]["documents"],
            raw_results[0]["distances"],
            raw_results[0]["metadatas"],
        )
    ]

    try:
        answer = generate_rag_answer(
            question=clean_query,
            contexts=[s.document for s in sources],
            max_new_tokens=request.max_new_tokens,
            temperature=request.temperature,
            top_p=request.top_p,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Generation failed: {str(e)}")

    return RagGenerateResponse(
        query=clean_query,
        answer=answer,
        collection_name=request.collection_name,
        sources=sources,
    )


@app.post("/rag-generate-gemini", response_model=RagGenerateResponse)
async def rag_generate_gemini(request: RagGenerateRequest):
    """RAG pipeline: embed query -> search vectors -> generate answer with Gemini."""
    clean_query = (request.query or "").strip()
    if not clean_query:
        raise HTTPException(status_code=400, detail="Query is required")
    if request.top_k < 1:
        raise HTTPException(status_code=400, detail="top_k must be >= 1")
    if request.max_new_tokens < 1:
        raise HTTPException(status_code=400, detail="max_new_tokens must be >= 1")
    if request.temperature < 0:
        raise HTTPException(status_code=400, detail="temperature must be >= 0")
    if request.top_p <= 0 or request.top_p > 1:
        raise HTTPException(status_code=400, detail="top_p must be between 0 and 1")

    try:
        query_embeddings = embed_texts(
            [clean_query],
            normalize_embeddings=request.normalize_embeddings,
        )
        raw_results = query_collection(
            query_embeddings=query_embeddings,
            collection_name=request.collection_name,
            top_k=request.top_k,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Retrieval failed: {str(e)}")

    if not raw_results or not raw_results[0]["documents"]:
        raise HTTPException(
            status_code=404,
            detail=f"No context found in collection '{request.collection_name}'",
        )

    sources = [
        SearchResult(
            id=rid,
            document=doc,
            distance=dist,
            metadata=meta,
        )
        for rid, doc, dist, meta in zip(
            raw_results[0]["ids"],
            raw_results[0]["documents"],
            raw_results[0]["distances"],
            raw_results[0]["metadatas"],
        )
    ]

    try:
        answer = generate_rag_answer_gemini(
            question=clean_query,
            contexts=[s.document for s in sources],
            max_new_tokens=request.max_new_tokens,
            temperature=request.temperature,
            top_p=request.top_p,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Generation failed: {str(e)}")

    return RagGenerateResponse(
        query=clean_query,
        answer=answer,
        collection_name=request.collection_name,
        sources=sources,
    )


@app.get("/collections")
async def get_collections():
    """List all ChromaDB collections."""
    return {"collections": list_collections()}


@app.delete("/collections/{collection_name}")
async def remove_collection(collection_name: str):
    """Delete a ChromaDB collection by name."""
    deleted = delete_collection(collection_name)
    if not deleted:
        raise HTTPException(status_code=404, detail=f"Collection '{collection_name}' not found")
    return {"deleted": collection_name}


class OCRRequest(BaseModel):
    region: Optional[List[int]] = None
    lang: str = "eng+msa+chi_sim+chi_tra"
    reset: bool = False

class OCRResponse(BaseModel):
    extracted_text: str

@app.post("/scan-screen", response_model=OCRResponse)
async def scan_screen(request: OCRRequest):
    """
    Scans the screen and extracts text using the OCR service.
    Set reset=True to clear scrolling history.
    """
    try:
        extracted_text = capture_and_ocr(
            region=request.region, 
            lang=request.lang, 
            reset=request.reset
        )
        print(
            f"DEBUG: /scan-screen reset={request.reset} lang={request.lang} extracted_length={len(extracted_text)}"
        )
        return OCRResponse(extracted_text=extracted_text)
        
    except Exception as e:
        error_msg = str(e)
        if "unsupported ocr language" in error_msg.lower():
            error_msg = f"OCR Error: {error_msg}"
        raise HTTPException(status_code=500, detail=error_msg)

if __name__ == "__main__":
    print(f"Starting {APP_NAME} v{API_VERSION}")
    print(f"Server: http://{HOST}:{PORT}")
    print(f"API Docs: http://{HOST}:{PORT}/docs")
    print(f"AI Keys Configured: {'Yes' if (GEMINI_API_KEY or OPENAI_API_KEY) else 'No (using mock data)'}")
    uvicorn.run("main:app", host=HOST, port=PORT, reload=DEBUG)
