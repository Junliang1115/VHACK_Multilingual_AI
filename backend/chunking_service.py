from typing import List

from langchain_text_splitters import RecursiveCharacterTextSplitter


def chunk_text(
    text: str,
    chunk_size: int = 500,
    chunk_overlap: int = 50,
    separators: List[str] | None = None,
) -> List[str]:
    """
    Split text into chunks using LangChain's recursive splitter.

    Args:
        text: Input text to split.
        chunk_size: Max chunk size in characters.
        chunk_overlap: Number of overlapping characters between adjacent chunks.
        separators: Optional split priority list.

    Returns:
        List of non-empty text chunks.
    """
    clean_text = (text or "").strip()
    if not clean_text:
        return []

    if chunk_size <= 0:
        raise ValueError("chunk_size must be greater than 0")
    if chunk_overlap < 0:
        raise ValueError("chunk_overlap must be >= 0")
    if chunk_overlap >= chunk_size:
        raise ValueError("chunk_overlap must be smaller than chunk_size")

    splitter = RecursiveCharacterTextSplitter(
        chunk_size=chunk_size,
        chunk_overlap=chunk_overlap,
        separators=separators or ["\n\n", "\n", ". ", " ", ""],
        length_function=len,
        is_separator_regex=False,
    )

    return [chunk for chunk in splitter.split_text(clean_text) if chunk.strip()]