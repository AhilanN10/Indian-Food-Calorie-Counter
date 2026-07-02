"""
phase0b_cleanup.py
==================
Phase 0b: In-place data cleanup on indb.sqlite.

  Issue 1 – Report anomalous per-serving kcal values (> 2000), no writes.
  Issue 2 – Fill NULL kcal/serving rows using per-100g data + default serving sizes.
  Issue 3 – Seed the dish_aliases table with canonical lookups.
  Final    – Summary report + re-run QA from Phase 0.
"""

import os
import sqlite3
import pandas as pd

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR   = os.path.dirname(os.path.abspath(__file__))
DB_PATH      = os.path.join(SCRIPT_DIR, "indb.sqlite")
INDB_XLSX    = os.path.join(SCRIPT_DIR, "INDB.xlsx")

if not os.path.exists(DB_PATH):
    raise FileNotFoundError(f"Database not found: {DB_PATH}\nRun phase0_pipeline.py first.")

conn = sqlite3.connect(DB_PATH)
conn.row_factory = sqlite3.Row
cur  = conn.cursor()


# ===========================================================================
# ISSUE 1 – Anomalous per-serving kcal values (> 2000)  [read-only report]
# ===========================================================================
print("=" * 70)
print("ISSUE 1 – Anomalous per-serving kcal values (energy_kcal_per_serving > 2000)")
print("=" * 70)

cur.execute("""
    SELECT food_code, food_name, energy_kcal_per_serving
    FROM   dishes
    WHERE  energy_kcal_per_serving > 2000
    ORDER  BY energy_kcal_per_serving DESC
""")
anomalous = cur.fetchall()

# Count ingredients per recipe_code
cur.execute("""
    SELECT recipe_code, COUNT(*) AS cnt
    FROM   ingredients
    GROUP  BY recipe_code
""")
ingr_counts = {r["recipe_code"]: r["cnt"] for r in cur.fetchall()}

# Pull servings_unit from INDB.xlsx for these food_codes
anomalous_codes = [r["food_code"] for r in anomalous]
indb_df = pd.read_excel(INDB_XLSX, engine="openpyxl")
indb_df.columns = [c.strip().lower() for c in indb_df.columns]
serving_unit_map = dict(zip(indb_df["food_code"], indb_df["servings_unit"]))

# Print report
col_w = [10, 44, 22, 16, 22]
headers = ["food_code", "food_name", "kcal_per_serving", "ingr_count", "servings_unit"]
sep = "-" * (sum(col_w) + 2 * (len(col_w) - 1))

def fmt_row(vals, widths):
    return "  ".join(str(v)[:w].ljust(w) for v, w in zip(vals, widths))

print(f"\n  {len(anomalous)} dishes found with kcal/serving > 2000:\n")
print("  " + fmt_row(headers, col_w))
print("  " + sep)
for row in anomalous:
    fc   = row["food_code"]
    name = row["food_name"]
    kcal = f"{row['energy_kcal_per_serving']:.1f}"
    cnt  = str(ingr_counts.get(fc, 0))
    sunit = str(serving_unit_map.get(fc, "N/A"))
    print("  " + fmt_row([fc, name, kcal, cnt, sunit], col_w))

print(f"\n  NOTE: These rows have NOT been modified.")
print(f"        Likely cause: INDB serving_unit is the full recipe yield,")
print(f"        not a single-portion serving size.\n")
print(f"\n[OK] ISSUE 1 COMPLETE – anomaly report printed (no writes).\n")


# ===========================================================================
# ISSUE 2 – Fix NULL kcal/serving rows with default serving sizes
# ===========================================================================
print("=" * 70)
print("ISSUE 2 – Filling NULL kcal/serving rows with default serving sizes")
print("=" * 70)

# 2a. Add new columns if they don't already exist
for col_def in [
    "serving_size_g REAL",
    "serving_size_is_default INTEGER DEFAULT 0",
]:
    col_name = col_def.split()[0]
    cur.execute("PRAGMA table_info(dishes)")
    existing_cols = [r["name"] for r in cur.fetchall()]
    if col_name not in existing_cols:
        cur.execute(f"ALTER TABLE dishes ADD COLUMN {col_def}")
        print(f"  Added column: {col_name}")

conn.commit()

# 2b. Fetch all dishes where kcal/serving is NULL but per-100g data exists
cur.execute("""
    SELECT food_code, food_name,
           energy_kcal_per_100g, protein_g_per_100g, fat_g_per_100g,
           carb_g_per_100g, fibre_g_per_100g
    FROM   dishes
    WHERE  energy_kcal_per_serving IS NULL
      AND  energy_kcal_per_100g IS NOT NULL
""")
null_rows = cur.fetchall()
print(f"\n  Found {len(null_rows)} NULL kcal/serving rows with valid per-100g data.\n")

# 2c. Keyword → (default_grams, category_label) rules (ordered: most-specific first)
SERVING_RULES = [
    # beverages
    (["tea", "coffee", "juice", "drink", "lassi", "chai", "water",
      "sherbet", "sharbat"],
     200, "beverages"),
    # rice dishes
    (["rice", "biryani", "pulao", "khichdi", "pongal"],
     200, "rice_dishes"),
    # breads
    (["roti", "chapati", "naan", "paratha", "phulka",
      "bread", "puri", "poori", "bhatura"],
     100, "breads"),
    # dal/curry
    (["dal", "sambar", "rasam", "curry", "sabzi", "gravy", "kadhi"],
     150, "dal_curry"),
    # South Indian tiffin
    (["idli", "dosa", "uttapam", "vada", "vadai"],
     120, "south_tiffin"),
    # sweets/desserts
    (["halwa", "kheer", "payasam", "dessert", "sweet",
      "ladoo", "barfi", "mithai"],
     100, "sweets"),
    # condiments/sides
    (["salad", "raita", "chutney", "pickle", "achaar"],
     50, "condiments"),
]
DEFAULT_G = 150

def classify_serving(food_name: str):
    """Return (grams, category) for a dish name."""
    lower = food_name.lower()
    for keywords, grams, category in SERVING_RULES:
        if any(kw in lower for kw in keywords):
            return grams, category
    return DEFAULT_G, "other"

# 2d. Compute and update
category_counts: dict[str, int] = {}

def safe_mul(val, factor):
    """Multiply val by factor; return None if val is None."""
    if val is None:
        return None
    return val * factor

for row in null_rows:
    food_code = row["food_code"]
    food_name = row["food_name"]
    grams, category = classify_serving(food_name)
    factor = grams / 100.0

    kcal    = safe_mul(row["energy_kcal_per_100g"], factor)
    protein = safe_mul(row["protein_g_per_100g"],   factor)
    fat     = safe_mul(row["fat_g_per_100g"],        factor)
    carb    = safe_mul(row["carb_g_per_100g"],       factor)
    fibre   = safe_mul(row["fibre_g_per_100g"],      factor)

    cur.execute("""
        UPDATE dishes
        SET    energy_kcal_per_serving  = ?,
               protein_g_per_serving   = ?,
               fat_g_per_serving       = ?,
               carb_g_per_serving      = ?,
               fibre_g_per_serving     = ?,
               serving_size_g          = ?,
               serving_size_is_default = 1
        WHERE  food_code = ?
    """, (kcal, protein, fat, carb, fibre, float(grams), food_code))

    category_counts[category] = category_counts.get(category, 0) + 1

conn.commit()

total_updated = sum(category_counts.values())
print("  Rows updated per category:")
for cat, cnt in sorted(category_counts.items(), key=lambda x: -x[1]):
    print(f"    {cat:<20} : {cnt:>4} rows  (default {dict([(k,v) for kw,v,k in SERVING_RULES] + [('other', DEFAULT_G)]).get(cat, DEFAULT_G)} g)")
print(f"\n  Total rows updated : {total_updated}")
print(f"\n[OK] ISSUE 2 COMPLETE – NULL serving rows filled.\n")


# ===========================================================================
# ISSUE 3 – Seed the dish_aliases table
# ===========================================================================
print("=" * 70)
print("ISSUE 3 – Seeding dish_aliases table")
print("=" * 70)

# Format: (alias, search_term_for_canonical, region, variant_flag)
aliases = [
    # Chole variants
    ("chole",        "chhole",   None,                  None),
    ("channay",      "chhole",   "Punjab/Pakistani",    None),
    ("chana masala", "chhole",   None,                  None),
    ("kadala curry", "chhole",   "Kerala",              "black_chickpea"),
    # Dal variants
    ("pappu",        "dal",      "Telugu",              None),
    ("parippu",      "dal",      "Malayalam",           None),
    ("tovve",        "dal",      "Kannada",             None),
    # Dosa variants
    ("dosai",        "dosa",     "Tamil Nadu",          None),
    ("dose",         "dosa",     "Karnataka",           None),
    # Poha variants
    ("aval upma",    "poha",     "Kerala/Tamil Nadu",   None),
    ("chivda",       "poha",     "Maharashtra",         None),
    ("avalakki",     "poha",     "Karnataka",           None),
    # Upma variants
    ("uppitu",       "upma",     "Karnataka",           None),
    ("uppma",        "upma",     None,                  None),
    ("rava upma",    "upma",     "South India",         None),
    # Roti variants
    ("chapati",      "roti",     None,                  None),
    ("phulka",       "roti",     "North India",         None),
    # Khichdi variants
    ("khichri",      "khichdi",  "North India",         None),
    ("huggi",        "khichdi",  "Karnataka",           None),
    ("pongal",       "khichdi",  "Tamil Nadu",          "ven_pongal"),
    # Halwa variants
    ("sooji halwa",  "halwa",    "North India",         None),
    ("kesari",       "halwa",    "South India",         "saffron_heavy"),
    ("sheera",       "halwa",    "Maharashtra",         None),
    # Other common variants
    ("biriyani",     "biryani",  "Kerala/Tamil",        None),
    ("sambhar",      "sambar",   "North India spelling",None),
    ("pulav",        "pulao",    None,                  None),
    ("kadhi",        "kadhi",    None,                  None),
    ("mor kuzhambu", "kadhi",    "Tamil Nadu",          "coconut_base"),
    ("batata bhaji", "aloo",     "Maharashtra",         None),
    ("chenna",       "paneer",   "Bengal",              None),
]

inserted = 0
failed   = 0

for alias, search_term, region, variant_flag in aliases:
    # Find canonical dish via case-insensitive LIKE search
    cur.execute(
        "SELECT food_code, food_name FROM dishes "
        "WHERE LOWER(food_name) LIKE ? LIMIT 1",
        (f"%{search_term.lower()}%",),
    )
    match = cur.fetchone()

    if match is None:
        print(f"  WARNING: No match found for search_term='{search_term}' "
              f"(alias='{alias}') – skipping.")
        failed += 1
        continue

    canonical_code = match["food_code"]
    canonical_name = match["food_name"]

    cur.execute(
        """
        INSERT OR REPLACE INTO dish_aliases
            (alias, canonical_food_code, canonical_food_name, region, variant_flag)
        VALUES (?, ?, ?, ?, ?)
        """,
        (alias, canonical_code, canonical_name, region, variant_flag),
    )
    inserted += 1

conn.commit()
print(f"\n  Aliases inserted successfully : {inserted}")
print(f"  Alias inserts failed (warned) : {failed}")
print(f"\n[OK] ISSUE 3 COMPLETE – dish_aliases seeded.\n")


# ===========================================================================
# FINAL REPORT
# ===========================================================================
print("=" * 70)
print("FINAL REPORT")
print("=" * 70)

print(f"""
  Summary
  -------
  Issue 1 – Anomalous kcal/serving (> 2000)     : {len(anomalous)} dishes identified (not modified)
  Issue 2 – NULL serving rows fixed              : {total_updated} dishes updated across {len(category_counts)} categories
  Issue 3 – Aliases inserted                     : {inserted} inserted, {failed} failed
""")

# Re-run QA from Phase 0 with updated terms (now includes 'chhole', 'dal')
QA_TERMS = [
    "biryani", "chhole", "dal", "idli", "dosa",
    "roti", "sambar", "paneer", "poha", "upma",
]

QA_COLS = [
    "food_code", "food_name",
    "energy_kcal_per_serving", "protein_g_per_serving",
    "fat_g_per_serving", "carb_g_per_serving",
    "dairy_fat_already_counted",
]

col_w2 = [10, 42, 12, 15, 12, 12, 10]
headers2 = ["food_code", "food_name", "kcal/srv", "prot_g/srv", "fat_g/srv", "carb_g/srv", "dairy"]
sep2 = "-" * (sum(col_w2) + 2 * (len(col_w2) - 1))

def fmt_val(v):
    if v is None:
        return "NULL"
    if isinstance(v, float):
        return f"{v:.1f}"
    return str(v)

print("  QA re-run (post-cleanup):")
for term in QA_TERMS:
    cur.execute(
        "SELECT " + ", ".join(QA_COLS) + " FROM dishes "
        "WHERE LOWER(food_name) LIKE ?",
        (f"%{term.lower()}%",),
    )
    rows = cur.fetchall()
    print(f"\n  Search: '{term}'  ->  {len(rows)} match(es)")
    if not rows:
        # Also check aliases table
        cur.execute(
            "SELECT canonical_food_code, canonical_food_name FROM dish_aliases "
            "WHERE LOWER(alias) LIKE ? LIMIT 1",
            (f"%{term.lower()}%",),
        )
        alias_match = cur.fetchone()
        if alias_match:
            print(f"    (alias maps to: {alias_match['canonical_food_code']} – "
                  f"{alias_match['canonical_food_name']})")
        else:
            print("    (no matches in dishes or aliases)")
        continue

    print("  " + fmt_row(headers2, col_w2))
    print("  " + sep2)
    for row in rows[:10]:  # cap at 10 rows per term to keep output readable
        print("  " + fmt_row([fmt_val(v) for v in row], col_w2))
    if len(rows) > 10:
        print(f"  ... and {len(rows) - 10} more rows (truncated for brevity)")

print()
conn.close()
print("=" * 70)
print(f"  Database updated at: {DB_PATH}")
print("=" * 70)
