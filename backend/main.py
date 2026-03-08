from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import uvicorn
from ocr_service import capture_and_ocr

app = FastAPI(title="Gov Translate AI API")

# Enable CORS for Flutter (necessary for web/mobile)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your frontend URL
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
    return {"status": "ok", "message": "Gov Translate AI Backend is running"}

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
        return OCRResponse(extracted_text=extracted_text)
        
    except Exception as e:
        error_msg = str(e)
        if "tessdata" in error_msg.lower():
            error_msg = f"OCR Error: Language data missing for: {lang}. {error_msg}"
        raise HTTPException(status_code=500, detail=error_msg)

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
