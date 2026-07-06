"""
aliases.py
==========
Three-tier dish name resolution:
  Tier 1 – exact match on food_name
  Tier 2 – alias table lookup → canonical dish
  Tier 3 – fuzzy match via fuzzywuzzy (top candidates, score >= FUZZY_SCORE_CUTOFF)
"""

import os
os.chdir('/Users/ahilannayani/Personal Python Projects/Indian Food Calorie Counter')

from fuzzywuzzy import process
from db import get_db

# Empirically validated against real typo/alt-spelling cases (e.g. "idly" -> "Idli"
# scores 75, the lowest legitimate case found) and the "Bhel puri" -> "Oatmeal
# Porridge"/"Poori" garbage matches (score 60) that motivated raising this from 60.
FUZZY_SCORE_CUTOFF = 70


def _row_to_dict(row) -> dict:
    """Convert a sqlite3.Row to a plain dict."""
    return dict(row) if row is not None else None


def resolve_dish_name(name: str, force_fuzzy: bool = False, limit: int = 3) -> dict:
    """
    Resolve a user-supplied dish name to a canonical INDB dish.

    Returns:
    {
        "match_type": "exact" | "alias" | "fuzzy" | "none",
        "dish": { ...dish row... } | None,
        "candidates": [ ...top `limit` fuzzy matches... ],
        "region": str | None,
        "variant_flag": str | None
    }
    """
    conn = get_db()
    cur  = conn.cursor()
    result = {
        "match_type":   "none",
        "dish":          None,
        "candidates":    [],
        "region":        None,
        "variant_flag":  None,
    }

    try:
        # ------------------------------------------------------------------
        # Tier 1 – exact match (case-insensitive) on dishes.food_name
        # ------------------------------------------------------------------
        if not force_fuzzy:
            cur.execute(
                "SELECT * FROM dishes "
                "WHERE LOWER(food_name) = LOWER(?) "
                "  AND (is_recipe_level = 0 OR is_recipe_level IS NULL) "
                "LIMIT 1",
                (name,),
            )
            row = cur.fetchone()
            if row:
                result["match_type"] = "exact"
                result["dish"]       = _row_to_dict(row)
                return result

        # ------------------------------------------------------------------
        # Tier 2 – alias table lookup
        # ------------------------------------------------------------------
        if not force_fuzzy:
            cur.execute(
                "SELECT * FROM dish_aliases WHERE LOWER(alias) = LOWER(?) LIMIT 1",
                (name,),
            )
            alias_row = cur.fetchone()
            if alias_row:
                cur.execute(
                    "SELECT * FROM dishes WHERE food_code = ? "
                    "  AND (is_recipe_level = 0 OR is_recipe_level IS NULL) "
                    "LIMIT 1",
                    (alias_row["canonical_food_code"],),
                )
                dish_row = cur.fetchone()
                if dish_row:
                    result["match_type"]  = "alias"
                    result["dish"]        = _row_to_dict(dish_row)
                    result["region"]      = alias_row["region"]
                    result["variant_flag"] = alias_row["variant_flag"]
                    return result

        # ------------------------------------------------------------------
        # Tier 3 – fuzzy match
        # ------------------------------------------------------------------
        # SELECT * so downstream filters (category, diet flags) see all columns
        cur.execute(
            "SELECT * FROM dishes "
            "WHERE is_recipe_level = 0 OR is_recipe_level IS NULL"
        )
        all_dishes = cur.fetchall()

        # Build a name→row mapping for fast retrieval
        name_to_row  = {r["food_name"]: r for r in all_dishes}
        all_names    = list(name_to_row.keys())

        matches = process.extractBests(
            name, all_names, score_cutoff=FUZZY_SCORE_CUTOFF, limit=limit
        )

        if matches:
            candidates = []
            for food_name, score in matches:
                d = _row_to_dict(name_to_row[food_name])
                d["fuzzy_score"] = score
                candidates.append(d)
            result["match_type"] = "fuzzy"
            result["candidates"] = candidates
        # else result["match_type"] stays "none"

    finally:
        conn.close()

    return result
