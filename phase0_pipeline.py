"""
phase0_pipeline.py
==================
Phase 0 data pipeline for the Indian Food Calorie & Macro Tracker.

Tasks:
  1. Build indb.sqlite with tables: dishes, ingredients, dish_aliases
  2. Annotate dairy/fat flag columns in dishes
  3. QA report for 10 target dishes
  4. Summary statistics
"""

import os
import sqlite3
import pandas as pd

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
INDB_XLSX    = os.path.join(SCRIPT_DIR, "INDB.xlsx")
RECIPES_XLSX = os.path.join(SCRIPT_DIR, "recipes.xlsx")
DB_PATH      = os.path.join(SCRIPT_DIR, "indb.sqlite")

# ---------------------------------------------------------------------------
# Helper: convert pandas NA to None so sqlite3 stores NULL (not 0 / "nan")
# ---------------------------------------------------------------------------
def nan_to_none(value):
    """Return None if value is NaN/NaT/pd.NA, otherwise return value."""
    try:
        if pd.isna(value):
            return None
    except (TypeError, ValueError):
        pass
    return value


# ===========================================================================
# TASK 1 - Build SQLite database
# ===========================================================================
print("=" * 60)
print("TASK 1 - Loading Excel files and building indb.sqlite")
print("=" * 60)

# -- 1a. Load INDB.xlsx ------------------------------------------------------
print("  Loading INDB.xlsx ...")
indb_df = pd.read_excel(INDB_XLSX, engine="openpyxl")

# Normalise column names (strip whitespace, lowercase)
indb_df.columns = [c.strip().lower() for c in indb_df.columns]

# Columns we need (per-100g macros + per-serving macros)
INDB_COL_MAP = {
    "food_code":                   "food_code",
    "food_name":                   "food_name",
    "energy_kcal":                 "energy_kcal_per_100g",
    "protein_g":                   "protein_g_per_100g",
    "fat_g":                       "fat_g_per_100g",
    "carb_g":                      "carb_g_per_100g",
    "fibre_g":                     "fibre_g_per_100g",
    "unit_serving_energy_kcal":    "energy_kcal_per_serving",
    "unit_serving_protein_g":      "protein_g_per_serving",
    "unit_serving_fat_g":          "fat_g_per_serving",
    "unit_serving_carb_g":         "carb_g_per_serving",
    "unit_serving_fibre_g":        "fibre_g_per_serving",
    "servings_unit":               "serving_unit",
}

missing = [c for c in INDB_COL_MAP if c not in indb_df.columns]
if missing:
    raise ValueError(f"INDB.xlsx is missing expected columns: {missing}")

dishes_df = indb_df[list(INDB_COL_MAP.keys())].rename(columns=INDB_COL_MAP).copy()

# Add flag columns defaulting to 0
for flag in ("has_cream_in_base", "has_butter_in_base", "has_ghee_in_base",
             "dairy_fat_already_counted"):
    dishes_df[flag] = 0

print(f"  Loaded {len(dishes_df):,} rows from INDB.xlsx.")

# -- 1b. Load recipes.xlsx ---------------------------------------------------
print("  Loading recipes.xlsx ...")
recipes_df = pd.read_excel(RECIPES_XLSX, engine="openpyxl")
recipes_df.columns = [c.strip().lower() for c in recipes_df.columns]

RECIPE_COL_MAP = {
    "recipe_code":  "recipe_code",
    "recipe_name":  "recipe_name",
    "food_code":    "ingredient_food_code",
    "food_name":    "ingredient_name",
    "amount":       "amount",
    "unit":         "unit",
}

missing_r = [c for c in RECIPE_COL_MAP if c not in recipes_df.columns]
if missing_r:
    raise ValueError(f"recipes.xlsx is missing expected columns: {missing_r}")

ingredients_df = recipes_df[list(RECIPE_COL_MAP.keys())].rename(columns=RECIPE_COL_MAP).copy()
print(f"  Loaded {len(ingredients_df):,} rows from recipes.xlsx.")

# -- 1c. Create / reset the SQLite database ----------------------------------
if os.path.exists(DB_PATH):
    os.remove(DB_PATH)
    print("  Removed existing indb.sqlite.")

conn = sqlite3.connect(DB_PATH)
cur  = conn.cursor()

cur.executescript("""
PRAGMA journal_mode=WAL;

CREATE TABLE IF NOT EXISTS dishes (
    food_code                 TEXT PRIMARY KEY,
    food_name                 TEXT NOT NULL,
    energy_kcal_per_100g      REAL,
    protein_g_per_100g        REAL,
    fat_g_per_100g            REAL,
    carb_g_per_100g           REAL,
    fibre_g_per_100g          REAL,
    energy_kcal_per_serving   REAL,
    protein_g_per_serving     REAL,
    fat_g_per_serving         REAL,
    carb_g_per_serving        REAL,
    fibre_g_per_serving       REAL,
    serving_unit              TEXT,
    has_cream_in_base         INTEGER DEFAULT 0,
    has_butter_in_base        INTEGER DEFAULT 0,
    has_ghee_in_base          INTEGER DEFAULT 0,
    dairy_fat_already_counted INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS ingredients (
    id                    INTEGER PRIMARY KEY AUTOINCREMENT,
    recipe_code           TEXT NOT NULL,
    recipe_name           TEXT,
    ingredient_food_code  TEXT,
    ingredient_name       TEXT,
    amount                REAL,
    unit                  TEXT
);

CREATE TABLE IF NOT EXISTS dish_aliases (
    alias                TEXT PRIMARY KEY,
    canonical_food_code  TEXT NOT NULL,
    canonical_food_name  TEXT NOT NULL,
    region               TEXT,
    variant_flag         TEXT
);
""")

# -- 1d. Insert dishes --------------------------------------------------------
dishes_cols = [
    "food_code", "food_name",
    "energy_kcal_per_100g", "protein_g_per_100g", "fat_g_per_100g",
    "carb_g_per_100g", "fibre_g_per_100g",
    "energy_kcal_per_serving", "protein_g_per_serving", "fat_g_per_serving",
    "carb_g_per_serving", "fibre_g_per_serving",
    "serving_unit",
    "has_cream_in_base", "has_butter_in_base", "has_ghee_in_base",
    "dairy_fat_already_counted",
]

dishes_rows = []
for _, row in dishes_df.iterrows():
    dishes_rows.append(tuple(nan_to_none(row[c]) for c in dishes_cols))

cur.executemany(
    f"INSERT OR REPLACE INTO dishes ({', '.join(dishes_cols)}) "
    f"VALUES ({', '.join(['?'] * len(dishes_cols))})",
    dishes_rows,
)

# -- 1e. Insert ingredients --------------------------------------------------
ingr_cols = ["recipe_code", "recipe_name", "ingredient_food_code",
             "ingredient_name", "amount", "unit"]

ingr_rows = []
for _, row in ingredients_df.iterrows():
    ingr_rows.append(tuple(nan_to_none(row[c]) for c in ingr_cols))

cur.executemany(
    "INSERT INTO ingredients (recipe_code, recipe_name, ingredient_food_code, "
    "ingredient_name, amount, unit) VALUES (?, ?, ?, ?, ?, ?)",
    ingr_rows,
)

conn.commit()
print("\n[OK] TASK 1 COMPLETE - SQLite database created with tables: "
      "dishes, ingredients, dish_aliases.\n")


# ===========================================================================
# TASK 2 - Dairy / fat flag annotation
# ===========================================================================
print("=" * 60)
print("TASK 2 - Annotating dairy/fat flags in dishes table")
print("=" * 60)

GHEE_KEYWORDS   = ["ghee"]
BUTTER_KEYWORDS = ["butter"]
CREAM_KEYWORDS  = ["cream", "malai", "coconut milk", "coconut cream"]

# Build a lookup: recipe_code -> list of lower-cased ingredient names
cur.execute("SELECT recipe_code, ingredient_name FROM ingredients")
recipe_ingr = {}
for recipe_code, ingredient_name in cur.fetchall():
    if ingredient_name is None:
        continue
    recipe_ingr.setdefault(recipe_code, []).append(ingredient_name.lower())

def contains_any(name_list, keywords):
    return any(kw in name for name in name_list for kw in keywords)

cur.execute("SELECT food_code FROM dishes")
food_codes = [r[0] for r in cur.fetchall()]

update_count = 0
for food_code in food_codes:
    names = recipe_ingr.get(food_code, [])
    if not names:
        continue  # No recipe data -> leave flags at 0

    has_ghee   = 1 if contains_any(names, GHEE_KEYWORDS)   else 0
    has_butter = 1 if contains_any(names, BUTTER_KEYWORDS) else 0
    has_cream  = 1 if contains_any(names, CREAM_KEYWORDS)  else 0
    dairy_flag = 1 if (has_ghee or has_butter or has_cream) else 0

    if dairy_flag:
        cur.execute(
            """
            UPDATE dishes
            SET has_ghee_in_base          = ?,
                has_butter_in_base        = ?,
                has_cream_in_base         = ?,
                dairy_fat_already_counted = ?
            WHERE food_code = ?
            """,
            (has_ghee, has_butter, has_cream, dairy_flag, food_code),
        )
        update_count += 1

conn.commit()
print(f"  Updated dairy/fat flags for {update_count:,} dishes.")
print("\n[OK] TASK 2 COMPLETE - Dairy/fat annotation done.\n")


# ===========================================================================
# TASK 3 - QA report for 10 target dishes
# ===========================================================================
print("=" * 60)
print("TASK 3 - QA report for 10 target dishes")
print("=" * 60)

QA_TERMS = [
    "biryani", "dal makhani", "idli", "dosa", "roti",
    "sambar", "paneer", "chole", "poha", "upma",
]

QA_COLS = [
    "food_code", "food_name",
    "energy_kcal_per_serving", "protein_g_per_serving",
    "fat_g_per_serving", "carb_g_per_serving",
    "dairy_fat_already_counted",
]

col_widths = [10, 42, 14, 17, 14, 14, 18]
header_labels = [
    "food_code", "food_name",
    "kcal/srv", "protein_g/srv",
    "fat_g/srv", "carb_g/srv",
    "dairy_fat",
]

def fmt_row(values, widths):
    return "  ".join(str(v)[:w].ljust(w) for v, w in zip(values, widths))

def fmt_val(v):
    if v is None:
        return "NULL"
    if isinstance(v, float):
        return f"{v:.2f}"
    return str(v)

separator = "-" * (sum(col_widths) + 2 * (len(col_widths) - 1))

for term in QA_TERMS:
    cur.execute(
        "SELECT " + ", ".join(QA_COLS) + " FROM dishes "
        "WHERE LOWER(food_name) LIKE ?",
        (f"%{term.lower()}%",),
    )
    rows = cur.fetchall()

    print(f"\n  Search: '{term}'  ->  {len(rows)} match(es)")
    if not rows:
        print("    (no matches)")
        continue

    print("  " + fmt_row(header_labels, col_widths))
    print("  " + separator)
    for row in rows:
        print("  " + fmt_row([fmt_val(v) for v in row], col_widths))

print("\n[OK] TASK 3 COMPLETE - QA report printed.\n")


# ===========================================================================
# TASK 4 - Summary statistics
# ===========================================================================
print("=" * 60)
print("TASK 4 - Summary statistics")
print("=" * 60)

cur.execute("SELECT COUNT(*) FROM dishes")
total_dishes = cur.fetchone()[0]

cur.execute("SELECT COUNT(*) FROM ingredients")
total_ingr = cur.fetchone()[0]

cur.execute("SELECT COUNT(*) FROM dishes WHERE dairy_fat_already_counted = 1")
dairy_count = cur.fetchone()[0]

cur.execute("SELECT COUNT(*) FROM dishes WHERE energy_kcal_per_serving IS NULL")
null_kcal_count = cur.fetchone()[0]

print(f"  Total dishes loaded            : {total_dishes:,}")
print(f"  Total ingredients loaded       : {total_ingr:,}")
print(f"  Dishes with dairy/fat flag = 1 : {dairy_count:,}")
print(f"  Dishes with NULL kcal/serving  : {null_kcal_count:,}")

print("\n[OK] TASK 4 COMPLETE - Summary statistics printed.\n")

# ---------------------------------------------------------------------------
# Close DB and print final path
# ---------------------------------------------------------------------------
conn.close()
print("=" * 60)
print(f"  indb.sqlite saved to: {DB_PATH}")
print("=" * 60)
