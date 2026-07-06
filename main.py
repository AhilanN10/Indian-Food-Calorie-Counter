"""
main.py
=======
FastAPI backend for the Indian Food Calorie & Macro Tracker.

Endpoints:
  GET  /health
  GET  /dish/search?q=<name>&limit=8&category=<cat>   ← always returns list
  GET  /dish/browse                                    ← grouped by category
  GET  /dish/{food_code}
  POST /dish/calculate
  GET  /usda/search?q=<query>
  GET  /categories
"""

import os
os.chdir('/Users/ahilannayani/Personal Python Projects/Indian Food Calorie Counter')

from dotenv import load_dotenv
load_dotenv()

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

import db
import aliases
import calculator
import usda

# ---------------------------------------------------------------------------
# App setup
# ---------------------------------------------------------------------------
app = FastAPI(
    title="Indian Food Calorie Tracker API",
    description="Calorie and macro estimation engine backed by the Indian Nutrient Databank (INDB).",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------------------------------------------------------------------------
# Pydantic models
# ---------------------------------------------------------------------------
class QAAnswers(BaseModel):
    portion_size:      str | None = "standard"
    rice_amount:       str | None = None
    meat_amount:       str | None = None
    cooking_context:   str | None = "home"
    gravy_type:        str | None = "medium"
    cooking_method:    str | None = None
    flat_additions:    list[str]  = []
    questions_skipped: int        = 0
    manual_weight_g:   float | None = None   # exact grams – overrides portion buckets


class CalculateRequest(BaseModel):
    food_code:  str
    qa_answers: QAAnswers


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def _dish_row_to_dict(row) -> dict:
    return dict(row) if row else None


DIETARY_FILTER_COLUMNS: dict[str, str] = {
    "vegetarian":      "is_vegetarian",
    "vegan":           "is_vegan",
    "jain":            "is_jain",
    "no_onion_garlic": "is_no_onion_garlic",
    "gluten_free":     "is_gluten_free",
    "dairy_free":      "is_dairy_free",
}

# Fasting Mode (Navratri/Ekadashi) — a separate concept from dietary filters
# in the UI, but reuses the exact same AND-of-flag-columns filtering plumbing
# on the backend (_passes_dietary_filters / diet_clause) rather than a
# parallel filtering path.
FASTING_FILTER_COLUMNS: dict[str, str] = {
    "navratri": "navratri_permitted",
    "ekadashi": "ekadashi_permitted",
}


def _parse_dietary_filters(raw: str | None) -> list[str]:
    """
    Parse a comma-separated dietaryFilters param into flag column names.
    Raises 400 on unknown filter names.
    """
    if not raw:
        return []
    columns = []
    for token in raw.split(","):
        token = token.strip().lower()
        if not token:
            continue
        if token not in DIETARY_FILTER_COLUMNS:
            raise HTTPException(
                status_code=400,
                detail=f"Unknown dietary filter '{token}'. "
                       f"Valid values: {', '.join(sorted(DIETARY_FILTER_COLUMNS))}",
            )
        columns.append(DIETARY_FILTER_COLUMNS[token])
    return columns


def _parse_fasting_mode(raw: str | None) -> str | None:
    """Parse the fastingMode param into a flag column name. Raises 400 on unknown values."""
    if not raw:
        return None
    token = raw.strip().lower()
    if token not in FASTING_FILTER_COLUMNS:
        raise HTTPException(
            status_code=400,
            detail=f"Unknown fasting mode '{token}'. "
                   f"Valid values: {', '.join(sorted(FASTING_FILTER_COLUMNS))}",
        )
    return FASTING_FILTER_COLUMNS[token]


def _passes_dietary_filters(dish_dict: dict, filter_columns: list[str]) -> bool:
    """ALL requested flags must be exactly 1. NULL (unknown) does not pass."""
    return all(dish_dict.get(col) == 1 for col in filter_columns)


# ---------------------------------------------------------------------------
# GET /health
# ---------------------------------------------------------------------------
@app.get("/health", tags=["meta"])
def health():
    """Liveness check – returns DB dish count."""
    conn = db.get_db()
    try:
        cur = conn.cursor()
        cur.execute(
            "SELECT COUNT(*) FROM dishes "
            "WHERE is_recipe_level = 0 OR is_recipe_level IS NULL"
        )
        count = cur.fetchone()[0]
    finally:
        conn.close()
    return {"status": "ok", "dishes_available": count}


# ---------------------------------------------------------------------------
# GET /dish/search  (always returns a list)
# ---------------------------------------------------------------------------
@app.get("/dish/search", tags=["dishes"])
def dish_search(
    q:        str       = Query(..., description="Dish name to search for"),
    limit:    int       = Query(8,   ge=1, le=20, description="Max results (default 8, max 20)"),
    category: str | None = Query(None, description="Filter by food_category"),
    dietaryFilters: str | None = Query(
        None,
        description="Comma-separated: vegetarian, vegan, jain, no_onion_garlic, gluten_free, dairy_free. "
                    "All must be satisfied; dishes with unknown (NULL) flags are excluded.",
    ),
    fastingMode: str | None = Query(
        None,
        description="Optional: navratri or ekadashi. Combines with dietaryFilters using AND logic "
                    "(same flag-column plumbing); dishes with unknown (NULL) flags are excluded.",
    ),
):
    """
    Three-tier lookup (exact → alias → fuzzy).
    Always returns {query, results[], total} – never a bare dict.
    Excludes is_recipe_level = 1 rows.
    """
    diet_columns = _parse_dietary_filters(dietaryFilters)
    fasting_column = _parse_fasting_mode(fastingMode)
    if fasting_column:
        diet_columns.append(fasting_column)

    def _to_result(dish_dict: dict, match_type: str, score: int) -> dict | None:
        """Convert a dish row to a SearchResult dict, applying category filter."""
        if dish_dict is None:
            return None
        if dish_dict.get("is_recipe_level") == 1:
            return None
        if category and dish_dict.get("food_category") != category:
            return None
        if diet_columns and not _passes_dietary_filters(dish_dict, diet_columns):
            return None
        return {
            "food_code":              dish_dict.get("food_code"),
            "food_name":              dish_dict.get("food_name"),
            "energy_kcal_per_serving": dish_dict.get("energy_kcal_per_serving"),
            "match_type":             match_type,
            "match_score":            score,
            "food_category":          dish_dict.get("food_category"),
        }

    result  = aliases.resolve_dish_name(q, limit=limit)
    results = []

    if result["match_type"] in ("exact", "alias"):
        score = 100 if result["match_type"] == "exact" else 95
        row   = _to_result(result["dish"], result["match_type"], score)
        if row:
            results = [row]

    elif result["match_type"] == "fuzzy":
        for candidate in result.get("candidates", [])[:limit]:
            row = _to_result(candidate, "fuzzy", int(candidate.get("fuzzy_score", 0)))
            if row:
                results.append(row)
            if len(results) >= limit:
                break

    # If alias/exact was filtered out by category and nothing came back, try fuzzy
    if not results and result["match_type"] in ("exact", "alias"):
        fallback = aliases.resolve_dish_name(q, force_fuzzy=True, limit=limit)
        for candidate in fallback.get("candidates", [])[:limit]:
            row = _to_result(candidate, "fuzzy", int(candidate.get("fuzzy_score", 0)))
            if row:
                results.append(row)

    # Determine confidence level
    top_score     = results[0]["match_score"] if results else 0
    low_confidence = top_score < 80 or len(results) == 0
    if not results:
        suggestion = "No close match found. Try a different search term."
    elif low_confidence:
        suggestion = (
            "No exact match found. Showing closest results. "
            "You can still select one or try a different search term."
        )
    else:
        suggestion = None

    response = {"query": q, "results": results, "total": len(results)}
    if low_confidence:
        response["low_confidence"] = True
        response["suggestion"]     = suggestion
    return response



# ---------------------------------------------------------------------------
# GET /dish/browse
# ---------------------------------------------------------------------------
@app.get("/dish/browse", tags=["dishes"])
def dish_browse(
    dietaryFilters: str | None = Query(
        None,
        description="Comma-separated: vegetarian, vegan, jain, no_onion_garlic, gluten_free, dairy_free. "
                    "All must be satisfied; dishes with unknown (NULL) flags are excluded.",
    ),
    fastingMode: str | None = Query(
        None,
        description="Optional: navratri or ekadashi. Combines with dietaryFilters using AND logic "
                    "(same flag-column plumbing); dishes with unknown (NULL) flags are excluded.",
    ),
):
    """
    Return dishes grouped by food_category (max 10 per category).
    Only includes available dishes (is_recipe_level = 0 or NULL).
    """
    diet_columns = _parse_dietary_filters(dietaryFilters)
    fasting_column = _parse_fasting_mode(fastingMode)
    if fasting_column:
        diet_columns.append(fasting_column)
    diet_clause  = "".join(f" AND {col} = 1" for col in diet_columns)

    conn = db.get_db()
    try:
        cur = conn.cursor()
        cur.execute(f"""
            SELECT food_code, food_name, energy_kcal_per_serving, food_category
            FROM   dishes
            WHERE  (is_recipe_level = 0 OR is_recipe_level IS NULL)
              AND  food_category IS NOT NULL
              {diet_clause}
            ORDER BY food_category, food_name
        """)
        rows = cur.fetchall()
    finally:
        conn.close()

    grouped: dict[str, list] = {}
    counts:  dict[str, int]  = {}
    for row in rows:
        cat = row["food_category"]
        if counts.get(cat, 0) >= 10:
            continue
        grouped.setdefault(cat, []).append({
            "food_code":              row["food_code"],
            "food_name":              row["food_name"],
            "energy_kcal_per_serving": row["energy_kcal_per_serving"],
        })
        counts[cat] = counts.get(cat, 0) + 1

    return {"categories": grouped}


# ---------------------------------------------------------------------------
# GET /dish/{food_code}
# ---------------------------------------------------------------------------
@app.get("/dish/{food_code}", tags=["dishes"])
def dish_detail(food_code: str):
    """
    Return full dish details including ingredient list.
    Returns 404 for recipe-level dishes or unknown codes.
    """
    conn = db.get_db()
    try:
        cur = conn.cursor()

        # Fetch dish
        cur.execute(
            "SELECT * FROM dishes WHERE food_code = ?",
            (food_code.upper(),),
        )
        dish = cur.fetchone()

        if dish is None:
            raise HTTPException(status_code=404, detail="Dish not found.")

        dish_dict = _dish_row_to_dict(dish)

        if dish_dict.get("is_recipe_level") == 1:
            raise HTTPException(
                status_code=404,
                detail="This entry is a recipe-level (full-batch) record and is not available for single-serving lookup.",
            )

        # Fetch ingredients
        cur.execute(
            "SELECT * FROM ingredients WHERE recipe_code = ?",
            (food_code.upper(),),
        )
        ingredients = [_dish_row_to_dict(r) for r in cur.fetchall()]
        dish_dict["ingredients"] = ingredients

    finally:
        conn.close()

    return dish_dict


# ---------------------------------------------------------------------------
# POST /dish/calculate
# ---------------------------------------------------------------------------
@app.post("/dish/calculate", tags=["calculator"])
def dish_calculate(body: CalculateRequest):
    """
    Calculate adjusted macros for a dish given a set of QA answers.
    """
    mw = body.qa_answers.manual_weight_g
    if mw is not None and mw < 5:
        raise HTTPException(
            status_code=400,
            detail="Manual weight must be at least 5 grams.",
        )

    conn = db.get_db()
    try:
        cur = conn.cursor()
        cur.execute(
            "SELECT * FROM dishes WHERE food_code = ? "
            "AND (is_recipe_level = 0 OR is_recipe_level IS NULL)",
            (body.food_code.upper(),),
        )
        dish = cur.fetchone()
    finally:
        conn.close()

    if dish is None:
        raise HTTPException(
            status_code=404,
            detail="Dish not found or is marked as recipe-level.",
        )

    dish_dict   = _dish_row_to_dict(dish)
    qa_dict     = body.qa_answers.model_dump()
    result      = calculator.calculate_macros(dish_dict, qa_dict)

    return {
        "food_code": body.food_code.upper(),
        "food_name": dish_dict.get("food_name"),
        **result,
    }


# ---------------------------------------------------------------------------
# GET /usda/search
# ---------------------------------------------------------------------------
@app.get("/usda/search", tags=["usda"])
def usda_search(q: str = Query(..., description="Food name to search on USDA FoodData Central")):
    """Proxy to USDA FoodData Central search."""
    results = usda.search_usda(q)
    return {"query": q, "results": results}


# ---------------------------------------------------------------------------
# GET /categories
# ---------------------------------------------------------------------------
@app.get("/categories", tags=["meta"])
def categories():
    """Return count of available dishes per food_category."""
    conn = db.get_db()
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT   food_category, COUNT(*) AS count
            FROM     dishes
            WHERE    is_recipe_level = 0 OR is_recipe_level IS NULL
            GROUP BY food_category
            ORDER BY count DESC
        """)
        rows = cur.fetchall()
    finally:
        conn.close()

    return {
        "categories": [
            {"food_category": r["food_category"] or "uncategorised", "count": r["count"]}
            for r in rows
        ]
    }
