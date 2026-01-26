from sentence_transformers import SentenceTransformer
from sklearn.metrics.pairwise import cosine_similarity
import numpy as np

# Load once (VERY IMPORTANT)
model = SentenceTransformer("all-MiniLM-L6-v2")

def semantic_search(query: str, texts: list[str], threshold=0.55):
    """
    query: user search input
    texts: list of history texts
    """
    if not texts:
        return []

    query_emb = model.encode([query])
    text_embs = model.encode(texts)

    similarities = cosine_similarity(query_emb, text_embs)[0]

    results = []
    for idx, score in enumerate(similarities):
        if score >= threshold:
            results.append({
                "index": idx,
                "score": float(score)
            })

    return results
