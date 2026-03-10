import re
import nltk
nltk.download('stopwords')
nltk.download('punkt')
from nltk.corpus import stopwords
from nltk.tokenize import word_tokenize #tokenizer
import spacy
from langdetect import detect

# Text cleaning
def clean_text(text):
    
    text = re.sub(r'<.*?>', '', text)        # remove html tags
    text = re.sub(r'[^a-zA-Z0-9\s]', '', text)  # remove symbols
    text = re.sub(r'\s+', ' ', text)         # remove extra spaces
    
    return text.strip()

#Normalization
abbreviations = {
    "govt": "government",
    "dept": "department",
    "svc": "service"
}

def normalize(text):
    for k,v in abbreviations.items():
        text = text.replace(k, v)
    return text

# Lowercasing
def lowercase(text):
    return text.lower()   

# Stopword removal
stop_words = set(stopwords.words('english'))

def remove_stopwords(text):
    words = text.split()
    filtered = [w for w in words if w not in stop_words]
    return " ".join(filtered)

# Tokenization
def tokenize(text):
    tokens = word_tokenize(text)
    return tokens

# Lemmatization
nlp = spacy.load("en_core_web_sm")

def lemmatize(text):
    doc = nlp(text)
    return " ".join([token.lemma_ for token in doc])

# Chunking
def chunk_text(text, chunk_size=300):
    
    words = text.split()
    
    chunks = []
    
    for i in range(0, len(words), chunk_size):
        chunk = " ".join(words[i:i+chunk_size])
        chunks.append(chunk)
        
    return chunks



# Language Detection
def detect_language(text):
    language = detect(text)
    return language

def preprocess(text):
    language = detect_language(text)

    text = clean_text(text)
    
    text = normalize(text)
    
    text = lowercase(text)
    
    text = remove_stopwords(text)

    text = tokenize(text)
    
    text = lemmatize(text)
    
    chunks = chunk_text(text)
    
    return { "chunks": chunks, "language": language }