"""
phase3a_remap.py
================
Attempt three additional INDB lookup strategies for every class where
needs_manual_mapping = true in class_map.json.

Strategy 1 – split & search: search food_name for each underscore-token,
             take intersection of results.
Strategy 2 – longest token LIKE: LIKE '%longest_token%', accept if exactly
             one match returned.
Strategy 3 – indian_food.csv fuzzy cross-reference: fuzzy-match class name
             against CSV name column (score > 75), then re-query INDB with
             the matched CSV name.

Unresolved after all three → fallback: "usda"
Updates class_map.json in place.
"""

import os
os.chdir('/Users/ahilannayani/Personal Python Projects/Indian Food Calorie Counter')

import json
import sqlite3

import pandas as pd
from fuzzywuzzy import process as fwprocess

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
CLASS_MAP_PATH = "class_map.json"
INDB_SQLITE    = "indb.sqlite"
METADATA_CSV   = "Food Data/indian_food.csv"

# ---------------------------------------------------------------------------
# Load class_map.json
# ---------------------------------------------------------------------------
with open(CLASS_MAP_PATH) as f:
    class_map = json.load(f)

# ---------------------------------------------------------------------------
# Connect to INDB
# ---------------------------------------------------------------------------
conn = sqlite3.connect(INDB_SQLITE)
conn.row_factory = sqlite3.Row
cur  = conn.cursor()

# Pre-fetch all available dish rows (is_recipe_level=0) for Strategy 2/3
cur.execute("""
    SELECT food_code, food_name
    FROM   dishes
    WHERE  is_recipe_level = 0 OR is_recipe_level IS NULL
""")
all_dishes = cur.fetchall()
all_food_names = [r["food_name"] for r in all_dishes]
name_to_code   = {r["food_name"]: r["food_code"] for r in all_dishes}

# ---------------------------------------------------------------------------
# Load indian_food.csv
# ---------------------------------------------------------------------------
meta_df = pd.read_csv(METADATA_CSV)
meta_df["name_norm"] = (
    meta_df["name"].str.strip().str.lower()
    .str.replace(r"[\s\-]+", "_", regex=True)
)
csv_names_raw  = meta_df["name"].tolist()          # for fuzzywuzzy
csv_names_norm = meta_df["name_norm"].tolist()


# ===========================================================================
# Lookup helpers
# ===========================================================================

def indb_like(token: str) -> list[dict]:
    """Return all INDB dishes where food_name LIKE '%token%'."""
    cur.execute(
        "SELECT food_code, food_name FROM dishes "
        "WHERE LOWER(food_name) LIKE ? "
        "  AND (is_recipe_level = 0 OR is_recipe_level IS NULL)",
        (f"%{token.lower()}%",),
    )
    return [dict(r) for r in cur.fetchall()]


def strategy1_split_intersect(cls_name: str) -> dict | None:
    """
    Split on underscore, search food_name for each token,
    take the intersection of matching food_codes.
    Accept if exactly one dish survives the intersection.
    """
    tokens = [t for t in cls_name.split("_") if len(t) > 2]
    if not tokens:
        return None

    # Start with results for first token
    sets = []
    for token in tokens:
        results = indb_like(token)
        sets.append({r["food_code"]: r for r in results})

    if not sets:
        return None

    # Intersect food_codes across all token sets
    common_codes = set(sets[0].keys())
    for s in sets[1:]:
        common_codes &= set(s.keys())

    if len(common_codes) == 1:
        code = next(iter(common_codes))
        return sets[0][code]   # return the dish dict

    # Relax: try with just the first two tokens if full intersection empty
    if len(tokens) > 2 and len(common_codes) == 0:
        common_codes = set(sets[0].keys()) & set(sets[1].keys())
        if len(common_codes) == 1:
            code = next(iter(common_codes))
            return sets[0][code]

    return None


def strategy2_longest_token(cls_name: str) -> dict | None:
    """
    Take the longest token, do LIKE '%token%'.
    Accept only if exactly one result.
    """
    tokens = sorted(cls_name.split("_"), key=len, reverse=True)
    for token in tokens:
        if len(token) <= 2:
            continue
        results = indb_like(token)
        if len(results) == 1:
            return results[0]
    return None


def strategy3_csv_fuzzy(cls_name: str) -> dict | None:
    """
    Fuzzy-match cls_name against indian_food.csv name column (score > 75).
    Use the matched CSV name to query INDB.
    """
    # fuzzywuzzy against raw CSV names
    readable = cls_name.replace("_", " ")
    match = fwprocess.extractOne(readable, csv_names_raw, score_cutoff=75)
    if match is None:
        return None

    matched_csv_name, score = match[0], match[1]
    # Use individual words from the CSV name as search tokens
    words = [w for w in matched_csv_name.lower().split() if len(w) > 2]

    for word in words:
        results = indb_like(word)
        if len(results) == 1:
            return results[0]

    # Try full name as LIKE
    results = indb_like(matched_csv_name.replace(" ", "%"))
    if len(results) >= 1:
        return results[0]

    return None


# ===========================================================================
# Main remap loop
# ===========================================================================
print("=" * 65)
print("phase3a_remap.py – Extended INDB mapping for unresolved classes")
print("=" * 65)

recovered_s1    = []
recovered_s2    = []
recovered_s3    = []
still_unresolved = []
usda_fallback   = []

classes = class_map["classes"]

for cls_name, entry in classes.items():
    if not entry.get("needs_manual_mapping", False):
        continue   # already mapped, skip

    resolved = None
    strategy_used = None

    # ── Strategy 1: split & intersect ──────────────────────────────────────
    result = strategy1_split_intersect(cls_name)
    if result:
        resolved      = result
        strategy_used = "strategy1_split_intersect"
        recovered_s1.append(cls_name)

    # ── Strategy 2: longest token ───────────────────────────────────────────
    if not resolved:
        result = strategy2_longest_token(cls_name)
        if result:
            resolved      = result
            strategy_used = "strategy2_longest_token"
            recovered_s2.append(cls_name)

    # ── Strategy 3: CSV fuzzy cross-reference ───────────────────────────────
    if not resolved:
        result = strategy3_csv_fuzzy(cls_name)
        if result:
            resolved      = result
            strategy_used = "strategy3_csv_fuzzy"
            recovered_s3.append(cls_name)

    # ── Update class_map entry ──────────────────────────────────────────────
    if resolved:
        entry["indb_food_code"]      = resolved["food_code"]
        entry["indb_food_name"]      = resolved["food_name"]
        entry["needs_manual_mapping"] = False
        entry["mapping_strategy"]    = strategy_used
        entry.pop("fallback", None)
        print(f"  [RECOVERED-{strategy_used[-1]}] {cls_name:<35} → {resolved['food_code']}  {resolved['food_name']}")
    else:
        entry["fallback"]            = "usda"
        entry["needs_manual_mapping"] = True
        entry["mapping_strategy"]    = None
        usda_fallback.append(cls_name)
        still_unresolved.append(cls_name)
        print(f"  [USDA FALLBACK]   {cls_name}")

conn.close()

# ===========================================================================
# Write updated class_map.json
# ===========================================================================
with open(CLASS_MAP_PATH, "w") as f:
    json.dump(class_map, f, indent=2)

print(f"\n  class_map.json updated → {os.path.abspath(CLASS_MAP_PATH)}\n")

# ===========================================================================
# Final report
# ===========================================================================
print("=" * 65)
print("FINAL REMAP REPORT")
print("=" * 65)
print(f"""
  Strategy 1 (split & intersect) recovered : {len(recovered_s1):>3}
    {recovered_s1}

  Strategy 2 (longest token LIKE) recovered : {len(recovered_s2):>3}
    {recovered_s2}

  Strategy 3 (CSV fuzzy cross-ref) recovered: {len(recovered_s3):>3}
    {recovered_s3}

  Still needs manual mapping               : {len(still_unresolved):>3}
  Flagged for USDA fallback at inference   : {len(usda_fallback):>3}
""")

if usda_fallback:
    print("  USDA fallback classes:")
    for cls in sorted(usda_fallback):
        print(f"    - {cls}")

total_mapped = sum(
    1 for e in classes.values() if not e.get("needs_manual_mapping", True)
)
print(f"\n  Total classes with confirmed INDB mapping : {total_mapped} / {len(classes)}")
print("=" * 65)
