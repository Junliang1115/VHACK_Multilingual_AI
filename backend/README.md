# Backend API - Gov Translate AI

FastAPI backend for the Government Translator AI application.

## Setup

### 1. Install Python Dependencies

```bash
cd backend
pip install -r requirements.txt
```

### 2. Environment Variables

Copy the `.env.example` file to `.env`:

```bash
cp .env.example .env
```

Edit `.env` and add your API keys when integrating AI services:

```env
GEMINI_API_KEY=your_actual_api_key_here
OPENAI_API_KEY=your_openai_key_here
```

**Note**: The `.env` file is ignored by git for security reasons.

### 3. Run the Server

```bash
python main.py
```

Or with uvicorn directly:

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

The API will be available at: `http://localhost:8000`

## API Endpoints

### Health Check
```
GET /
```

### Translate Text
```
POST /translate
Content-Type: application/json

{
  "text": "Your text here",
  "target_dialect": "Kedah"
}
```

**Available dialects**: Kedah, Kelantan, Terengganu, Standard Malay

### Summarize Text
```
POST /summarize
Content-Type: application/json

{
  "text": "Your text here"
}
```

## API Documentation

Once the server is running, visit:
- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

## Development

The current implementation uses mock translation logic. To integrate real AI:

1. Install the AI SDK (e.g., `pip install google-generativeai`)
2. Add your API key to `.env`
3. Update the translation logic in `main.py`
