import re

# =====================================================
# REGEX PATTERNS (compiled for performance)
# =====================================================

URL_PATTERN = re.compile(r"http\S+|www\S+")
MENTION_PATTERN = re.compile(r"@\w+")
HASHTAG_PATTERN = re.compile(r"#(\w+)")
SPECIAL_CHARS_PATTERN = re.compile(r"[^a-zA-Z0-9\s]")
MULTIPLE_SPACES_PATTERN = re.compile(r"\s+")
REPEATED_CHARS_PATTERN = re.compile(r"(.)\1{2,}")  # e.g. soooo → soo


# =====================================================
# MAIN CLEAN FUNCTION
# =====================================================

def clean_text(text: str) -> str:
    """
    Advanced text cleaning for NLP & mental health analysis
    """

    if not text:
        return ""

    # 1. Lowercase
    text = text.lower()

    # 2. Remove URLs
    text = URL_PATTERN.sub("", text)

    # 3. Remove mentions (@user)
    text = MENTION_PATTERN.sub("", text)

    # 4. Convert hashtags (#happy → happy)
    text = HASHTAG_PATTERN.sub(r"\1", text)

    # 5. Normalize repeated characters (soooo → soo)
    text = REPEATED_CHARS_PATTERN.sub(r"\1\1", text)

    # 6. Remove special characters
    text = SPECIAL_CHARS_PATTERN.sub("", text)

    # 7. Remove extra spaces
    text = MULTIPLE_SPACES_PATTERN.sub(" ", text)

    return text.strip()


# =====================================================
# OPTIONAL: EXTENDED CLEAN (FOR FUTURE USE)
# =====================================================

def clean_text_advanced(text: str, remove_numbers: bool = False) -> str:
    """
    Extended cleaner with optional number removal
    """

    text = clean_text(text)

    if remove_numbers:
        text = re.sub(r"\d+", "", text)

    return text.strip()