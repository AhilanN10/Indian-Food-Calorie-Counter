"""
phase_diet_tagging.py
=====================
Dietary filter tagging: add six diet-flag columns to the dishes table and
populate them by keyword-scanning each dish's ingredient list.

  Task 1 – Add columns: is_vegetarian, is_vegan, is_jain, is_no_onion_garlic,
           is_gluten_free, is_dairy_free (nullable – NULL = unknown/unreviewed),
           plus diet_tags_source ('auto' | 'manually_reviewed').
  Task 2 – Tag every dish from its ingredients (case-insensitive substring
           match). Recipe-level dishes and dishes with no ingredient rows get
           NULL for all six flags.
  Task 3 – Summary report + 10-dish spot-check sample.

Flag semantics: 1 = compliant, 0 = violates, NULL = unknown.
A flag is only 0 when a violating keyword is found; otherwise 1.
"""

import os
os.chdir('/Users/ahilannayani/Personal Python Projects/Indian Food Calorie Counter')

import sqlite3

DB_PATH = os.path.join(os.getcwd(), "indb.sqlite")

if not os.path.exists(DB_PATH):
    raise FileNotFoundError(f"Database not found: {DB_PATH}")

conn = sqlite3.connect(DB_PATH)
conn.row_factory = sqlite3.Row
cur  = conn.cursor()

# ===========================================================================
# Keyword tables
#
# Base lists per spec, extended with keywords verified against the actual
# 382 distinct ingredient names in this DB (each extension matches only its
# intended ingredient — checked for false positives before inclusion):
#   non-veg : fish species (rohu/pomfret/mackerel), bacon/sausage/salami,
#             mayonnaise (standard retail = egg), worcestershire (anchovy),
#             "ham" as word-boundary regex (plain substring would hit
#             "hamburger buns" and "banana ... montham")
#   dairy   : "khoa" (DB spelling of khoya), "whey"
#   root    : "beet root" (DB spells it with a space — "beetroot" misses it),
#             shallot, colocasia (arbi), lotus root/stem, yam
#   gluten  : bread, pasta, couscous, biscuit, buns, pizza base, semolina
#   vegan   : honey (not vegan, but vegetarian/dairy-free)
# Known limitations left for manual review (diet_tags_source stays 'auto'):
# jelly/gum-drop gelatin ambiguity, margarine composition, fresh ginger for
# strict Jain, nannari root.
# ===========================================================================

import re

NON_VEG_KEYWORDS = [
    "chicken", "mutton", "lamb", "goat", "beef", "pork", "fish", "prawn",
    "shrimp", "crab", "egg", "meat", "keema", "kheema", "gelatin", "lard",
    "rohu", "pomfret", "mackerel", "bacon", "sausage", "salami",
    "mayonnaise", "worcestershire",
]

NON_VEG_REGEXES = [re.compile(r"\bham\b")]

DAIRY_KEYWORDS = [
    "milk", "ghee", "paneer", "curd", "dahi", "cream", "butter",
    "khoya", "mawa", "cheese", "malai", "khoa", "whey",
]

# Not dairy and not meat, but still not vegan
VEGAN_ONLY_KEYWORDS = ["honey"]

# Jain: no root vegetables / alliums / fungi
ROOT_KEYWORDS = [
    "onion", "garlic", "potato", "carrot", "radish", "beetroot",
    "turnip", "mushroom", "beet root", "shallot", "colocasia",
    "lotus root", "lotus stem", "yam",
]

ALLIUM_KEYWORDS = ["onion", "garlic", "shallot"]

GLUTEN_KEYWORDS = [
    "wheat", "atta", "maida", "suji", "rava", "barley",
    "bread", "pasta", "couscous", "biscuit", "buns", "pizza base", "semolina",
]

# Data-verified false positives in this DB: these phrases contain a keyword
# but do not violate the diet (e.g. "Coconut milk" is not dairy, "Buckwheat,
# groats" is gluten-free). They are blanked out of the ingredient name before
# keyword matching.
EXCEPTION_PHRASES = [
    "coconut milk", "almond milk", "soy milk", "soya milk", "oat milk",
    "peanut butter", "cocoa butter", "buckwheat",
]

FLAG_COLUMNS = [
    "is_vegetarian", "is_vegan", "is_jain",
    "is_no_onion_garlic", "is_gluten_free", "is_dairy_free",
]


def _sanitise(name: str) -> str:
    """Lowercase an ingredient name and blank out known exception phrases."""
    s = name.lower()
    for phrase in EXCEPTION_PHRASES:
        s = s.replace(phrase, " ")
    return s


def _matches(sanitised_names: list[str], keywords: list[str]) -> bool:
    return any(kw in name for name in sanitised_names for kw in keywords)


# ===========================================================================
# TASK 1 – Add columns
# ===========================================================================
print("=" * 65)
print("TASK 1 – Adding diet flag columns")
print("=" * 65)

cur.execute("PRAGMA table_info(dishes)")
existing_cols = {r["name"] for r in cur.fetchall()}

for col in FLAG_COLUMNS:
    if col not in existing_cols:
        cur.execute(f"ALTER TABLE dishes ADD COLUMN {col} INTEGER")
        print(f"  Added column: {col}")

if "diet_tags_source" not in existing_cols:
    cur.execute("ALTER TABLE dishes ADD COLUMN diet_tags_source TEXT DEFAULT 'auto'")
    print("  Added column: diet_tags_source")

# ===========================================================================
# TASK 2 – Tag every dish
# ===========================================================================
print()
print("=" * 65)
print("TASK 2 – Tagging dishes from ingredient keywords")
print("=" * 65)

cur.execute("SELECT food_code, food_name, is_recipe_level FROM dishes")
dishes = cur.fetchall()

cur.execute("SELECT recipe_code, ingredient_name FROM ingredients WHERE ingredient_name IS NOT NULL")
ingredients_by_dish: dict[str, list[str]] = {}
for row in cur.fetchall():
    ingredients_by_dish.setdefault(row["recipe_code"], []).append(row["ingredient_name"])

tagged  = 0
nulled  = 0

for dish in dishes:
    code        = dish["food_code"]
    ingredients = ingredients_by_dish.get(code, [])

    # No reliable ingredient data → all flags stay NULL
    if dish["is_recipe_level"] == 1 or not ingredients:
        cur.execute(
            f"UPDATE dishes SET {', '.join(f'{c} = NULL' for c in FLAG_COLUMNS)}, "
            "diet_tags_source = 'auto' WHERE food_code = ?",
            (code,),
        )
        nulled += 1
        continue

    sanitised = [_sanitise(n) for n in ingredients]

    non_veg = _matches(sanitised, NON_VEG_KEYWORDS) or any(
        rx.search(name) for name in sanitised for rx in NON_VEG_REGEXES
    )
    dairy      = _matches(sanitised, DAIRY_KEYWORDS)
    vegan_only = _matches(sanitised, VEGAN_ONLY_KEYWORDS)
    root       = _matches(sanitised, ROOT_KEYWORDS)
    allium     = _matches(sanitised, ALLIUM_KEYWORDS)
    gluten     = _matches(sanitised, GLUTEN_KEYWORDS)

    is_vegetarian      = 0 if non_veg else 1
    is_vegan           = 0 if (non_veg or dairy or vegan_only) else 1
    is_jain            = 0 if (non_veg or root) else 1
    is_no_onion_garlic = 0 if allium else 1
    is_gluten_free     = 0 if gluten else 1
    is_dairy_free      = 0 if dairy else 1

    cur.execute(
        """UPDATE dishes SET
               is_vegetarian = ?, is_vegan = ?, is_jain = ?,
               is_no_onion_garlic = ?, is_gluten_free = ?, is_dairy_free = ?,
               diet_tags_source = 'auto'
           WHERE food_code = ?""",
        (is_vegetarian, is_vegan, is_jain,
         is_no_onion_garlic, is_gluten_free, is_dairy_free, code),
    )
    tagged += 1

conn.commit()
print(f"\n  Dishes tagged:            {tagged}")
print(f"  Dishes left NULL:         {nulled}  (recipe-level or no ingredient rows)")

# ===========================================================================
# TASK 3 – Summary report + spot-check sample
# ===========================================================================
print()
print("=" * 65)
print("TASK 3 – Summary")
print("=" * 65)

print(f"\n  {'flag':<20} {'=1':>6} {'=0':>6} {'NULL':>6}")
for col in FLAG_COLUMNS:
    cur.execute(f"""
        SELECT SUM(CASE WHEN {col} = 1 THEN 1 ELSE 0 END)     AS yes,
               SUM(CASE WHEN {col} = 0 THEN 1 ELSE 0 END)     AS no,
               SUM(CASE WHEN {col} IS NULL THEN 1 ELSE 0 END) AS unk
        FROM dishes
    """)
    r = cur.fetchone()
    print(f"  {col:<20} {r['yes']:>6} {r['no']:>6} {r['unk']:>6}")

print("\n  Spot-check sample (10 dishes):")
print(f"  {'dish':<44} veg vgn jain nog gf df")
cur.execute("""
    SELECT food_name, is_vegetarian, is_vegan, is_jain,
           is_no_onion_garlic, is_gluten_free, is_dairy_free
    FROM dishes
    WHERE food_code IN (
        SELECT food_code FROM dishes
        WHERE (is_recipe_level = 0 OR is_recipe_level IS NULL) AND (
              LOWER(food_name) LIKE '%paneer butter%'
           OR LOWER(food_name) LIKE '%chicken curry%'
           OR LOWER(food_name) LIKE '%dal fry%'
           OR LOWER(food_name) LIKE '%aloo%paratha%'
           OR LOWER(food_name) LIKE '%jain%'
           OR LOWER(food_name) LIKE '%fish curry%'
           OR LOWER(food_name) LIKE '%plain rice%'
           OR LOWER(food_name) LIKE '%gulab jamun%'
           OR LOWER(food_name) LIKE '%poha%'
           OR LOWER(food_name) LIKE '%idli%'
        )
        LIMIT 10
    )
""")
def _fmt(v):
    return "-" if v is None else str(v)
for r in cur.fetchall():
    print(f"  {r['food_name'][:44]:<44} {_fmt(r['is_vegetarian']):>3} "
          f"{_fmt(r['is_vegan']):>3} {_fmt(r['is_jain']):>4} "
          f"{_fmt(r['is_no_onion_garlic']):>3} {_fmt(r['is_gluten_free']):>2} "
          f"{_fmt(r['is_dairy_free']):>2}")

conn.close()
print("\nDone.")
