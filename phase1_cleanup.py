"""
phase1_cleanup.py
=================
Phase 1: Fix anomalous high-kcal dishes and add food_category column.

  Task 1 – Flag & null out is_recipe_level dishes (kcal/serving > 2000)
  Task 2 – Add and populate food_category column via keyword matching
  Task 3 – Final database health check / summary report
"""

import os
os.chdir('/Users/ahilannayani/Personal Python Projects/Indian Food Calorie Counter')

import sqlite3

DB_PATH = os.path.join(os.getcwd(), "indb.sqlite")

if not os.path.exists(DB_PATH):
    raise FileNotFoundError(f"Database not found: {DB_PATH}\nRun phase0_pipeline.py and phase0b_cleanup.py first.")

conn = sqlite3.connect(DB_PATH)
conn.row_factory = sqlite3.Row
cur  = conn.cursor()


# ===========================================================================
# TASK 1 – Flag and null out anomalous high-kcal dishes
# ===========================================================================
print("=" * 65)
print("TASK 1 – Flagging recipe-level dishes (kcal/serving > 2000)")
print("=" * 65)

# Add is_recipe_level column if it doesn't exist
cur.execute("PRAGMA table_info(dishes)")
existing_cols = {r["name"] for r in cur.fetchall()}

if "is_recipe_level" not in existing_cols:
    cur.execute("ALTER TABLE dishes ADD COLUMN is_recipe_level INTEGER DEFAULT 0")
    print("  Added column: is_recipe_level")

# Identify anomalous rows
cur.execute("""
    SELECT food_code, food_name, energy_kcal_per_serving
    FROM   dishes
    WHERE  energy_kcal_per_serving > 2000
""")
anomalous = cur.fetchall()
print(f"\n  Dishes to flag: {len(anomalous)}")
for row in anomalous:
    print(f"    {row['food_code']}  {row['food_name'][:55]}  "
          f"({row['energy_kcal_per_serving']:.0f} kcal/srv)")

# Set is_recipe_level = 1 and NULL out all per-serving columns
cur.execute("""
    UPDATE dishes
    SET    is_recipe_level          = 1,
           energy_kcal_per_serving  = NULL,
           protein_g_per_serving    = NULL,
           fat_g_per_serving        = NULL,
           carb_g_per_serving       = NULL,
           fibre_g_per_serving      = NULL
    WHERE  energy_kcal_per_serving > 2000
""")
flagged_count = cur.rowcount
conn.commit()

print(f"\n  Rows flagged (is_recipe_level = 1) : {flagged_count}")
print(f"  Per-serving columns set to NULL    : {flagged_count} rows")
print(f"\n[OK] TASK 1 COMPLETE – recipe-level dishes flagged.\n")


# ===========================================================================
# TASK 2 – Add and populate food_category column
# ===========================================================================
print("=" * 65)
print("TASK 2 – Adding and populating food_category column")
print("=" * 65)

if "food_category" not in existing_cols:
    cur.execute("ALTER TABLE dishes ADD COLUMN food_category TEXT")
    print("  Added column: food_category")

# Category rules: priority order, first match wins.
# Each entry: (category_name, [keywords])
CATEGORY_RULES = [
    ("beverage", [
        "tea", "coffee", "juice", "lassi", "chai", "sherbet",
        "sharbat", "drink", "water", "buttermilk", "chaas",
    ]),
    ("rice", [
        "rice", "biryani", "pulao", "khichdi", "pongal", "fried rice",
    ]),
    ("bread", [
        "roti", "chapati", "naan", "paratha", "puri", "poori",
        "bhatura", "kulcha", "dosa", "uttapam", "idli", "appam",
        "pesarattu",
    ]),
    ("dal_legume", [
        "dal", "daal", "sambar", "rasam", "kadhi", "chole", "chhole",
        "rajma", "lobia", "moong", "chana", "toor", "urad", "masoor",
    ]),
    ("meat_fish", [
        "chicken", "mutton", "fish", "prawn", "lamb", "beef",
        "pork", "egg", "keema", "kheema",
    ]),
    ("paneer_dairy", [
        "paneer", "chenna", "kheer", "payasam", "raita", "lassi",
        "dahi", "curd", "malai",
    ]),
    ("vegetable", [
        "sabzi", "aloo", "gobi", "bhindi", "baingan", "palak",
        "methi", "matar", "korma", "curry", "kootu", "aviyal",
    ]),
    ("snack_street", [
        "samosa", "pakora", "bhajia", "vada", "vadai", "tikki",
        "chaat", "pani puri", "bhel", "sev", "papdi", "kachori",
    ]),
    ("sweet_dessert", [
        "halwa", "kheer", "ladoo", "barfi", "gulab jamun", "jalebi",
        "payasam", "kesari", "modak", "mithai", "sweet", "dessert",
        "pudding",
    ]),
    ("condiment_side", [
        "chutney", "pickle", "achaar", "papad", "raita", "salad",
    ]),
]

def classify_food(food_name: str) -> str:
    """Return the first matching category for a food name."""
    lower = food_name.lower()
    for category, keywords in CATEGORY_RULES:
        if any(kw in lower for kw in keywords):
            return category
    return "other"

# Fetch all dishes
cur.execute("SELECT food_code, food_name FROM dishes")
all_dishes = cur.fetchall()

category_counts: dict[str, int] = {}
update_batch = []

for row in all_dishes:
    cat = classify_food(row["food_name"])
    update_batch.append((cat, row["food_code"]))
    category_counts[cat] = category_counts.get(cat, 0) + 1

cur.executemany(
    "UPDATE dishes SET food_category = ? WHERE food_code = ?",
    update_batch,
)
conn.commit()

print(f"\n  Categories assigned to {len(all_dishes):,} dishes:\n")
col_w = [20, 6]
header = f"  {'Category':<20}  {'Count':>6}"
sep    = "  " + "-" * 28
print(header)
print(sep)
for cat, cnt in sorted(category_counts.items(), key=lambda x: -x[1]):
    print(f"  {cat:<20}  {cnt:>6}")

print(f"\n[OK] TASK 2 COMPLETE – food_category column populated.\n")


# ===========================================================================
# TASK 3 – Final database health check
# ===========================================================================
print("=" * 65)
print("TASK 3 – Final database health check")
print("=" * 65)

def q(sql, *args):
    cur.execute(sql, args)
    return cur.fetchone()[0]

total_dishes       = q("SELECT COUNT(*) FROM dishes")
available          = q("SELECT COUNT(*) FROM dishes WHERE is_recipe_level = 0 OR is_recipe_level IS NULL")
recipe_level       = q("SELECT COUNT(*) FROM dishes WHERE is_recipe_level = 1")
null_kcal          = q("SELECT COUNT(*) FROM dishes WHERE energy_kcal_per_serving IS NULL AND (is_recipe_level = 0 OR is_recipe_level IS NULL)")
default_serving    = q("SELECT COUNT(*) FROM dishes WHERE serving_size_is_default = 1")
total_aliases      = q("SELECT COUNT(*) FROM dish_aliases")
total_ingredients  = q("SELECT COUNT(*) FROM ingredients")

print(f"""
  ┌─────────────────────────────────────────────────────┐
  │              DATABASE HEALTH SUMMARY                │
  ├─────────────────────────────────────────────────────┤
  │  Total dishes in DB                  : {total_dishes:>6,}       │
  │  Available for lookup (is_recipe_level=0): {available:>4,}       │
  │  Flagged as recipe-level             : {recipe_level:>6,}       │
  │  NULL kcal/serving (non-recipe rows) : {null_kcal:>6,}       │
  │  Rows with default serving size      : {default_serving:>6,}       │
  │  Total aliases in dish_aliases       : {total_aliases:>6,}       │
  │  Total ingredients in ingredients    : {total_ingredients:>6,}       │
  └─────────────────────────────────────────────────────┘
""")

# Dishes per food_category
cur.execute("""
    SELECT food_category, COUNT(*) AS cnt
    FROM   dishes
    GROUP  BY food_category
    ORDER  BY cnt DESC
""")
cat_rows = cur.fetchall()

print("  Dishes per food_category:")
print(f"  {'Category':<22} {'Total':>6}  {'Available':>10}  {'Recipe-level':>12}")
print("  " + "-" * 55)
for r in cat_rows:
    cat = r["food_category"] or "NULL"
    cur.execute("""
        SELECT COUNT(*) FROM dishes
        WHERE food_category = ?
          AND (is_recipe_level = 0 OR is_recipe_level IS NULL)
    """, (r["food_category"],))
    avail = cur.fetchone()[0]
    rl = r["cnt"] - avail
    print(f"  {cat:<22} {r['cnt']:>6}  {avail:>10}  {rl:>12}")

conn.close()

print(f"\n[OK] TASK 3 COMPLETE – health check done.\n")
print("=" * 65)
print(f"  indb.sqlite path: {os.path.abspath(DB_PATH)}")
print("=" * 65)
