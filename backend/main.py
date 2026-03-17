from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import uvicorn
import os
from dotenv import load_dotenv
from ocr_service import capture_and_ocr

# Load environment variables
load_dotenv()

APP_NAME = os.getenv("APP_NAME", "Gov Translate AI API")
API_VERSION = os.getenv("API_VERSION", "1.0.0")
DEBUG = os.getenv("DEBUG", "True").lower() == "true"
HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "8000"))
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

origins_raw = os.getenv("ALLOWED_ORIGINS", "*").strip()
ALLOWED_ORIGINS = ["*"] if origins_raw == "*" else [
    origin.strip() for origin in origins_raw.split(",") if origin.strip()
]

app = FastAPI(title=APP_NAME, version=API_VERSION, debug=DEBUG)

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

# Mock AI Logic (Replace with Gemini/OpenAI integration later)
def mock_translate(text: str, dialect: str) -> str:
    dialects = {
        "Kedah": "Hang nak pi mana tu? (Kedah version of: " + text[:20] + "...)",
        "Kelantan": "Demo nak g mano tu? (Kelantan version of: " + text[:20] + "...)",
        "Terengganu": "Mung nak gi mane tu? (Terengganu version of: " + text[:20] + "...)",
    }
    return dialects.get(dialect, f"(Standard) {text}")

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
    
    # Simulate processing
    translated = mock_translate(request.text, request.target_dialect)
    
    return TranslationResponse(
        original_text=request.text,
        translated_text=translated,
        dialect=request.target_dialect,
        summary="This is a generated summary of your translation request."
    )

@app.post("/summarize", response_model=SummaryResponse)
async def summarize_text(request: SummaryRequest):
    if not request.text:
        raise HTTPException(status_code=400, detail="Text is required")
    
    return SummaryResponse(
        summary=f"Summary: The input text contains {len(request.text)} characters. (Mock summary logic)"
    )

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
