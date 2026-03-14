# 🌐 Gov Translate AI

A modern, AI-powered government translation application that converts text to various Malaysian dialects. Built with Flutter for cross-platform UI and FastAPI for the backend.

## 🚀 Features

- **Multi-Dialect Translation**: Translate to Kedah, Kelantan, Terengganu dialects
- **Cross-Platform**: Runs on Web, Windows, Android, iOS
- **Modern UI**: Responsive design with Material Design 3
- **Real-time Translation**: Fast API responses
- **Text Summarization**: AI-powered text summarization
- **History Sidebar**: Track translation history

## 🏗️ Tech Stack

### Frontend
- **Flutter** - Cross-platform UI framework
- **Provider** - State management
- **Google Fonts** - Typography
- **HTTP** - API communication

### Backend
- **FastAPI** - Modern Python web framework
- **Uvicorn** - ASGI server
- **Pydantic** - Data validation
- **Python 3.10+**

## 📋 Prerequisites

- Flutter SDK (3.0.0+)
- Python 3.10+
- Git

## 🛠️ Installation & Setup

### 1. Clone the Repository

```bash
git clone https://github.com/Junliang1115/VHACK_Multilingual_AI.git
cd VHACK_Multilingual_AI
```

### 2. Backend Setup

```bash
cd backend

# Create virtual environment
python -m venv venv

# Activate virtual environment
# Windows:
.\venv\Scripts\Activate.ps1
# macOS/Linux:
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Setup environment variables
cp .env.example .env
# Edit .env and add your API keys

# Run the server
python main.py
```

The backend will run on `http://localhost:8000`

### 3. Frontend Setup

```bash
# Navigate back to project root
cd ..

# Get Flutter dependencies
flutter pub get

# Run the app
flutter run -d chrome        # For web
flutter run -d windows       # For Windows
flutter run                  # For Android/iOS (with device/emulator)
```

## 🌐 Running the Application

### Start Backend (Terminal 1)
```bash
cd backend
python main.py
```

### Start Frontend (Terminal 2)
```bash
flutter run -d chrome
```

## 📱 Platform-Specific Notes

### Android Emulator
Update the API base URL in `lib/services/api_service.dart`:
```dart
final String baseUrl = 'http://10.0.2.2:8000';
```

### Web/Windows/iOS
```dart
final String baseUrl = 'http://localhost:8000';
```

## 🔑 Environment Variables

Create a `backend/.env` file with:

```env
# AI API Keys (when ready)
GEMINI_API_KEY=your_key_here
OPENAI_API_KEY=your_key_here

# Server Config
HOST=0.0.0.0
PORT=8000
DEBUG=True
```

**Note**: `.env` file is git-ignored for security.

## 📚 API Documentation

Once the backend is running, access interactive API docs:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## 🧪 Testing

```bash
# Backend tests
cd backend
python -m pytest

# Flutter tests
flutter test
```

## 📁 Project Structure

```
VHACK_Multilingual_AI/
├── lib/                    # Flutter frontend
│   ├── main.dart
│   ├── providers/         # State management
│   ├── screens/           # UI screens
│   ├── services/          # API services
│   ├── theme/             # App theming
│   └── widgets/           # Reusable components
├── backend/               # FastAPI backend
│   ├── main.py           # API endpoints
│   ├── requirements.txt  # Python dependencies
│   ├── .env.example      # Environment template
│   └── README.md         # Backend documentation
├── android/              # Android platform files
├── ios/                  # iOS platform files
├── web/                  # Web platform files
├── windows/              # Windows platform files
└── pubspec.yaml         # Flutter dependencies
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is part of V HACK 2026.

## 👥 Team

Built with ❤️ for V HACK 2026

## 🐛 Known Issues

- Minor UI overflow on some screen sizes (non-critical)
- Mock translation logic (pending AI integration)

## 🔮 Future Enhancements

- [ ] Integrate Google Gemini/OpenAI for real translations
- [ ] Add user authentication
- [ ] Support more Malaysian dialects
- [ ] Voice input/output
- [ ] Offline translation support
- [ ] Translation history persistence
