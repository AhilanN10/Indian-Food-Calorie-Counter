"""
phase3a_manual_fix.py
=====================
Apply three targeted manual corrections to class_map.json:

  1. aloo_tikki        – wrong match (Soyabean tikki) → search properly or USDA
  2. chole_bhatura     – single match (Bhatura only) → composite with chhole + bhatura
  3. sohan_papdi       – wrong match (Papdi cracker) → USDA fallback
"""

import os
os.chdir('/Users/ahilannayani/Personal Python Projects/Indian Food Calorie Counter')

import json
import sqlite3
import copy

CLASS_MAP_PATH = "class_map.json"
INDB_SQLITE    = "indb.sqlite"

# ---------------------------------------------------------------------------
# Load assets
# ---------------------------------------------------------------------------
with open(CLASS_MAP_PATH) as f:
    class_map = json.load(f)

conn = sqlite3.connect(INDB_SQLITE)
conn.row_factory = sqlite3.Row
cur  = conn.cursor()

def like_search(*patterns) -> list[dict]:
    """Run a series of LIKE patterns with OR, return matching dish rows."""
    clauses = " OR ".join(["LOWER(food_name) LIKE ?" for _ in patterns])
    cur.execute(
        f"SELECT food_code, food_name FROM dishes "
        f"WHERE ({clauses}) "
        f"  AND (is_recipe_level = 0 OR is_recipe_level IS NULL)",
        tuple(p.lower() for p in patterns),
    )
    return [dict(r) for r in cur.fetchall()]

def first_match(*patterns) -> dict | None:
    results = like_search(*patterns)
    return results[0] if results else None

sep = "=" * 65

# ===========================================================================
# Fix 1 – aloo_tikki
# ===========================================================================
print(sep)
print("Fix 1 – aloo_tikki")
print(sep)

entry        = class_map["classes"]["aloo_tikki"]
before       = copy.deepcopy(entry)

# Try targeted searches
match = first_match("%aloo%tikki%", "%tikki%aloo%")

if match:
    entry["indb_food_code"]       = match["food_code"]
    entry["indb_food_name"]       = match["food_name"]
    entry["needs_manual_mapping"] = False
    entry["mapping_strategy"]     = "manual_fix_aloo_tikki"
    entry.pop("fallback",   None)
    entry.pop("usda_query", None)
    print(f"  INDB match found → {match['food_code']}  {match['food_name']}")
else:
    entry["indb_food_code"]       = None
    entry["indb_food_name"]       = None
    entry["needs_manual_mapping"] = False
    entry["mapping_strategy"]     = "manual_fix_aloo_tikki"
    entry["fallback"]             = "usda"
    entry["usda_query"]           = "aloo tikki potato patty"
    print("  No INDB match found → setting USDA fallback")
    print(f"  usda_query: \"{entry['usda_query']}\"")

print(f"\n  BEFORE: food_code={before.get('indb_food_code')}  "
      f"food_name={before.get('indb_food_name')}")
print(f"  AFTER : food_code={entry.get('indb_food_code')}  "
      f"fallback={entry.get('fallback')}  "
      f"usda_query={entry.get('usda_query')}")

# ===========================================================================
# Fix 2 – chole_bhatura (composite)
# ===========================================================================
print(f"\n{sep}")
print("Fix 2 – chole_bhatura (composite)")
print(sep)

entry  = class_map["classes"]["chole_bhatura"]
before = copy.deepcopy(entry)

# Look up chhole component
chhole_match  = first_match("%chhole%", "%chole%chana%", "%chickpea%curry%")
bhatura_match = first_match("%bhatura%", "%bhatoora%")

chhole_code  = chhole_match["food_code"]  if chhole_match  else None
chhole_name  = chhole_match["food_name"]  if chhole_match  else None
bhatura_code = bhatura_match["food_code"] if bhatura_match else None
bhatura_name = bhatura_match["food_name"] if bhatura_match else None

print(f"  chhole  match → {chhole_code}  {chhole_name}")
print(f"  bhatura match → {bhatura_code}  {bhatura_name}")

entry["indb_food_code"]       = None          # no single code for composite
entry["indb_food_name"]       = None
entry["composite"]            = True
entry["components"] = [
    {
        "search":        "chhole",
        "food_code":     chhole_code,
        "food_name":     chhole_name,
        "weight_pct":    0.45,
    },
    {
        "search":        "bhatura",
        "food_code":     bhatura_code,
        "food_name":     bhatura_name,
        "weight_pct":    0.55,
    },
]
entry["needs_manual_mapping"] = False
entry["mapping_strategy"]     = "manual_fix_composite"
entry["fallback"]             = "composite"
entry.pop("usda_query", None)

print(f"\n  BEFORE: food_code={before.get('indb_food_code')}  "
      f"food_name={before.get('indb_food_name')}")
print(f"  AFTER : composite=True  fallback=composite")
print(f"          components:")
for c in entry["components"]:
    print(f"            {c['weight_pct']*100:.0f}%  {c['food_code']}  {c['food_name']}")

# ===========================================================================
# Fix 3 – sohan_papdi
# ===========================================================================
print(f"\n{sep}")
print("Fix 3 – sohan_papdi")
print(sep)

entry  = class_map["classes"]["sohan_papdi"]
before = copy.deepcopy(entry)

entry["indb_food_code"]       = None
entry["indb_food_name"]       = None
entry["needs_manual_mapping"] = False
entry["mapping_strategy"]     = "manual_fix_sohan_papdi"
entry["fallback"]             = "usda"
entry["usda_query"]           = "sohan papdi Indian sweet flaky dessert"
entry.pop("composite",   None)
entry.pop("components",  None)

print(f"  BEFORE: food_code={before.get('indb_food_code')}  "
      f"food_name={before.get('indb_food_name')}")
print(f"  AFTER : food_code=None  fallback=usda  "
      f"usda_query=\"{entry['usda_query']}\"")

# ===========================================================================
# Save + summary
# ===========================================================================
conn.close()

with open(CLASS_MAP_PATH, "w") as f:
    json.dump(class_map, f, indent=2)

# Recount totals
total     = len(class_map["classes"])
confirmed = sum(1 for e in class_map["classes"].values()
                if not e.get("needs_manual_mapping", True))
composite = sum(1 for e in class_map["classes"].values()
                if e.get("composite", False))
usda_fb   = sum(1 for e in class_map["classes"].values()
                if e.get("fallback") == "usda")

print(f"\n{sep}")
print("SUMMARY – class_map.json updated")
print(sep)
print(f"""
  Total classes                     : {total}
  Confirmed INDB mapping            : {confirmed}
  Composite dish entries            : {composite}
  USDA fallback at inference        : {usda_fb}
  Still needs_manual_mapping = true : {total - confirmed}

  class_map.json saved → {os.path.abspath(CLASS_MAP_PATH)}
""")
print(sep)
