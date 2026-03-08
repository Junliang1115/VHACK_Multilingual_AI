import cv2
import pytesseract
import numpy as np
import os
import subprocess
import io
from PIL import Image

# Set Tesseract path if it's not in the system environment variables
TESSERACT_PATH = os.getenv("TESSERACT_PATH", r'C:/Program Files/Tesseract-OCR/tesseract.exe')
if os.path.exists(TESSERACT_PATH):
    pytesseract.pytesseract.tesseract_cmd = TESSERACT_PATH

# Global state to keep track of seen text across multiple scans (for scrolling)
_seen_lines_history = []
_MAX_HISTORY = 1000

def capture_and_ocr(region=None, lang="eng+msa+chi_sim+chi_tra", reset=False):
    """
    Captures the Android phone/emulator screen using ADB and performs OCR.
    """
    global _seen_lines_history
    
    if reset:
        _seen_lines_history = []

    # 1. Capture phone screen using ADB
    try:
        # 'exec-out' is faster for binary data than 'shell'
        cmd = ["adb", "exec-out", "screencap", "-p"]
        process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        png_data, err = process.communicate()
        
        if process.returncode != 0:
            raise Exception(f"ADB Error: {err.decode()}")
            
        screenshot = Image.open(io.BytesIO(png_data))
    except Exception as e:
        raise Exception(f"Failed to capture phone screen. Is ADB installed and device connected? Error: {str(e)}")

    # Handle region crop if provided (optional)
    if region and len(region) == 4:
        # ADB screencap is full resolution. Ensure region matches phone dimensions.
        left, top, width, height = region
        screenshot = screenshot.crop((left, top, left + width, top + height))
        
    # [DEBUG] Save screenshot to local directory
    try:
        import time
        debug_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "debug_img")
        if not os.path.exists(debug_dir):
            os.makedirs(debug_dir)
        filename = f"screenshot_{int(time.time())}.png"
        screenshot.save(os.path.join(debug_dir, filename))
        print(f"DEBUG: Saved screenshot to {os.path.join(debug_dir, filename)}")
    except Exception as e:
        print(f"DEBUG: Failed to save screenshot: {e}")
    
    # 2. Convert PIL Image to OpenCV format (BGR)
    open_cv_image = np.array(screenshot)
    image_bgr = cv2.cvtColor(open_cv_image, cv2.COLOR_RGB2BGR)
    
    # 3. Preprocess image with OpenCV (Grayscale + Thresholding) to remove the color noise
    gray = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2GRAY)
    _, thresh = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    
    # 4. Extract text using PyTesseract
    raw_text = pytesseract.image_to_string(thresh, lang=lang)
    
    # 5. Filter out lines we've already seen (for scrolling) to prevent overlapping texts are extracted
    lines = raw_text.split('\n')
    new_lines = []
    
    for line in lines:
        clean_line = line.strip()
        
        # Only process meaningful lines (more than 2 chars to avoid noise)
        if len(clean_line) <= 2:
            continue
            
        # If the line is not in our recent history, it's new
        if clean_line not in _seen_lines_history:
            new_lines.append(clean_line)
            _seen_lines_history.append(clean_line)
            
    # Keep history bounded
    if len(_seen_lines_history) > _MAX_HISTORY:
        _seen_lines_history = _seen_lines_history[-_MAX_HISTORY:]
        
    return "\n".join(new_lines)
