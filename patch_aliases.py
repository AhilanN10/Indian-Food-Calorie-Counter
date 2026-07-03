import os
os.chdir('/Users/ahilannayani/Personal Python Projects/Indian Food Calorie Counter')

import sqlite3

INDB = "indb.sqlite"

new_aliases = [
    ("bhindi masala",         "okra",             None,          None),
    ("okra curry",            "okra",             None,          None),
    ("lady finger",           "okra",             None,          None),
    ("bhindi",                "bhindi",            None,          None),
    ("aloo bhindi",           "bhindi",            None,          None),
    ("butter chicken masala", "butter chicken",    None,          None),
    ("murgh makhani",         "butter chicken",    "North India", None),
    ("chicken makhani",       "butter chicken",    None,          None),
    ("shahi paneer",          "paneer",            "North India", None),
    ("kadai paneer",          "paneer",            None,          None),
    ("palak paneer",          "palak",             None,          None),
    ("saag paneer",           "palak",             "North India", None),
    ("chicken curry",         "chicken",           None,          None),
    ("mutton curry",          "mutton",            None,          None),
    ("lamb curry",            "mutton",            None,          None),
    ("fish curry",            "fish",              None,          None),
    ("prawn curry",           "prawn",             None,          None),
    ("jeera rice",            "jeera",             None,          None),
    ("cumin rice",            "jeera",             None,          None),
    ("plain rice",            "rice",              None,          None),
    ("steamed rice",          "rice",              None,          None),
    ("vegetable biryani",     "biryani",           None,          None),
    ("veg biryani",           "biryani",           None,          None),
    ("egg biryani",           "biryani",           None,          None),
    ("chicken biryani",       "biryani",           "Hyderabad",   None),
    ("hyderabadi biryani",    "biryani",           "Hyderabad",   None),
    ("aloo paratha",          "paratha",           "North India", None),
    ("gobi paratha",          "paratha",           "North India", None),
    ("paneer paratha",        "paratha",           "North India", None),
    ("methi paratha",         "paratha",           "North India", None),
    ("masoor dal",            "dal",               None,          None),
    ("moong dal",             "dal",               None,          None),
    ("toor dal",              "toor",              None,          None),
    ("arhar dal",             "toor",              None,          None),
    ("chana dal",             "chana",             None,          None),
    ("urad dal",              "urad",              None,          None),
    ("black dal",             "dal makhani",       None,          None),
    ("mah di dal",            "dal makhani",       "Punjab",      None),
    ("rajma chawal",          "rajma",             None,          None),
    ("kidney beans curry",    "rajma",             None,          None),
    ("matar paneer",          "matar paneer",      None,          None),
    ("peas paneer",           "matar paneer",      None,          None),
    ("gobi aloo",             "aloo gobi",         None,          None),
    ("cauliflower potato",    "aloo gobi",         None,          None),
    ("baingan bharta",        "baingan",           None,          None),
    ("roasted eggplant",      "baingan",           None,          None),
    ("mixed veg",             "mixed vegetable",   None,          None),
    ("mix veg",               "mixed vegetable",   None,          None),
]

conn = sqlite3.connect(INDB)
conn.row_factory = sqlite3.Row
cur  = conn.cursor()

# Ensure the table has the region and variant_flag columns
cur.execute("PRAGMA table_info(dish_aliases)")
existing_cols = {row["name"] for row in cur.fetchall()}
if "region" not in existing_cols:
    cur.execute("ALTER TABLE dish_aliases ADD COLUMN region TEXT")
if "variant_flag" not in existing_cols:
    cur.execute("ALTER TABLE dish_aliases ADD COLUMN variant_flag TEXT")

inserted = 0
skipped_existing = 0
skipped_not_found = 0

for alias, search_term, region, variant_flag in new_aliases:
    # Skip if alias already exists (case-insensitive)
    cur.execute(
        "SELECT 1 FROM dish_aliases WHERE LOWER(alias) = LOWER(?)",
        (alias,)
    )
    if cur.fetchone():
        print(f"  [SKIP existing] {alias!r}")
        skipped_existing += 1
        continue

    # Find best match in dishes
    cur.execute(
        "SELECT food_code, food_name FROM dishes "
        "WHERE LOWER(food_name) LIKE ? "
        "  AND (is_recipe_level = 0 OR is_recipe_level IS NULL) "
        "ORDER BY food_name "
        "LIMIT 1",
        (f"%{search_term.lower()}%",)
    )
    row = cur.fetchone()
    if row is None:
        print(f"  [NOT FOUND]    {alias!r} → search_term={search_term!r}")
        skipped_not_found += 1
        continue

    cur.execute(
        "INSERT INTO dish_aliases (alias, canonical_food_code, canonical_food_name, region, variant_flag) "
        "VALUES (?, ?, ?, ?, ?)",
        (alias, row["food_code"], row["food_name"], region, variant_flag)
    )
    print(f"  [INSERTED]     {alias!r} → {row['food_code']} ({row['food_name']})")
    inserted += 1

conn.commit()
conn.close()

print(f"\nDone: {inserted} inserted, {skipped_existing} already existed, {skipped_not_found} not found.")
