import io
import os
import re
import subprocess
import sys
import time

import cv2
import numpy as np
from PIL import Image

# Global state to keep track of seen text across multiple scans (for scrolling)
_seen_lines_history = []
_MAX_HISTORY = 1000
_MIN_OCR_CONFIDENCE = 0.35

_OCR_ENGINES = {}
_LANGUAGE_MAP = {
    "ch": "ch",
    "chi": "ch",
    "chi_sim": "ch",
    "chi_tra": "ch",
    "en": "en",
    "eng": "en",
    "latin": "latin",
    "msa": "latin",
    "mal": "latin",
    "ms": "latin",
}


def _resolve_paddle_languages(lang):
    requested = [code.strip().lower() for code in (lang or "").split("+") if code.strip()]
    if not requested:
        requested = ["eng", "msa", "chi_sim"]

    resolved = []
    unsupported = []
    for code in requested:
        paddle_lang = _LANGUAGE_MAP.get(code)
        if paddle_lang is None:
            unsupported.append(code)
            continue
        if paddle_lang not in resolved:
            resolved.append(paddle_lang)

    if not resolved:
        raise ValueError(
            "Unsupported OCR language selection. "
            f"Requested: {lang}. Supported codes: {', '.join(sorted(_LANGUAGE_MAP))}"
        )

    return resolved, unsupported


def _get_ocr_engine(lang):
    try:
        from paddleocr import PaddleOCR
    except ModuleNotFoundError as exc:
        py_ver = f"{sys.version_info.major}.{sys.version_info.minor}"
        raise RuntimeError(
            "PaddleOCR dependencies are not installed correctly. "
            "Install backend requirements in a dedicated virtual environment, "
            "and use Python 3.10 or 3.11 for best compatibility. "
            f"Current Python: {py_ver}. Original error: {exc}"
        ) from exc

    if lang not in _OCR_ENGINES:
        _OCR_ENGINES[lang] = PaddleOCR(use_angle_cls=True, lang=lang, show_log=False)
    return _OCR_ENGINES[lang]


def _extract_lines(result):
    lines = []
    for page in result or []:
        if not isinstance(page, list):
            continue
        for item in page:
            if not item or len(item) < 2:
                continue
            text_info = item[1]
            if isinstance(text_info, (list, tuple)) and len(text_info) >= 2:
                text = text_info[0]
                confidence = text_info[1]
                if isinstance(text, str) and text.strip() and isinstance(confidence, (int, float)):
                    lines.append((text.strip(), float(confidence)))
    return lines


def _normalize_line_key(text):
    # Normalize whitespace/case so OCR duplicates across models can be merged.
    return " ".join(text.split()).casefold()


def _contains_cjk(text):
    return re.search(r"[\u4e00-\u9fff]", text) is not None


def _is_meaningful_line(text):
    stripped = text.strip()
    if not stripped:
        return False
    if _contains_cjk(stripped):
        return len(stripped) >= 1
    return len(stripped) > 2


def _build_preprocessed_images(image_bgr):
    # Use two variants: one for natural UI text, another high-contrast one for tiny/noisy text.
    base_rgb = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
    gray = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2GRAY)
    denoised = cv2.bilateralFilter(gray, 5, 75, 75)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8)).apply(denoised)
    _, thresh = cv2.threshold(clahe, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)

    h, w = thresh.shape
    if min(h, w) < 1100:
        thresh = cv2.resize(thresh, None, fx=1.6, fy=1.6, interpolation=cv2.INTER_CUBIC)

    high_contrast_rgb = cv2.cvtColor(thresh, cv2.COLOR_GRAY2RGB)
    return [base_rgb, high_contrast_rgb]


def _clear_debug_screenshots():
    debug_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "debug_img")
    if not os.path.exists(debug_dir):
        return

    for filename in os.listdir(debug_dir):
        if not filename.startswith("screenshot_") or not filename.endswith(".png"):
            continue
        file_path = os.path.join(debug_dir, filename)
        if os.path.isfile(file_path):
            os.remove(file_path)

def capture_and_ocr(region=None, lang="eng+msa+chi_sim+chi_tra", reset=False):
    """
    Captures the Android phone/emulator screen using ADB and performs OCR.
    """
    global _seen_lines_history

    print(f"DEBUG: capture_and_ocr called reset={reset} lang={lang} region={region}")
    
    if reset:
        _seen_lines_history = []
        try:
            _clear_debug_screenshots()
        except Exception as e:
            print(f"DEBUG: Failed to clear debug screenshots: {e}")

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
    
    # 3. Preprocess image variants tuned for mixed Chinese and Malay UI text.
    processed_images = _build_preprocessed_images(image_bgr)
    
    # 4. Extract text using PaddleOCR.
    paddle_languages, unsupported_languages = _resolve_paddle_languages(lang)
    best_line_candidates = {}

    for paddle_lang in paddle_languages:
        ocr_engine = _get_ocr_engine(paddle_lang)
        for processed_image in processed_images:
            result = ocr_engine.ocr(processed_image, cls=True)
            for line, confidence in _extract_lines(result):
                if confidence < _MIN_OCR_CONFIDENCE:
                    continue
                key = _normalize_line_key(line)
                previous = best_line_candidates.get(key)
                if previous is None or confidence > previous[1]:
                    best_line_candidates[key] = (line, confidence)

    if unsupported_languages:
        print(
            "DEBUG: Ignoring unsupported OCR language codes for PaddleOCR: "
            + ", ".join(unsupported_languages)
        )
    
    # 5. Filter out lines we've already seen (for scrolling) to prevent overlapping texts are extracted
    combined_lines = [entry[0] for entry in sorted(best_line_candidates.values(), key=lambda item: item[1], reverse=True)]
    new_lines = []
    
    for line in combined_lines:
        clean_line = line.strip()
        
        # Keep short Chinese words while suppressing short Latin OCR noise.
        if not _is_meaningful_line(clean_line):
            continue
            
        # If the line is not in our recent history, it's new
        if clean_line not in _seen_lines_history:
            new_lines.append(clean_line)
            _seen_lines_history.append(clean_line)
            
    # Keep history bounded
    if len(_seen_lines_history) > _MAX_HISTORY:
        _seen_lines_history = _seen_lines_history[-_MAX_HISTORY:]

    if not new_lines:
        print("DEBUG: OCR completed but no new text was extracted.")
    else:
        print(f"DEBUG: OCR extracted {len(new_lines)} new lines.")
        
    return "\n".join(new_lines)
