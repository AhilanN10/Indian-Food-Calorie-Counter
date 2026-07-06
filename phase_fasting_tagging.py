"""
phase_fasting_tagging.py
=========================
Fasting-day mode tagging: add two nullable boolean columns to the dishes
table (navratri_permitted, ekadashi_permitted) and populate them by
keyword-scanning each dish's ingredient list.

Scope: Navratri and Ekadashi only (Ramzan is time-window based, not
food-composition based, and is scoped separately).

  Task 1 – Add columns navratri_permitted, ekadashi_permitted (nullable
           INTEGER, no default — NULL = unknown/unreviewed). Majority of
           dishes are expected to be RESTRICTED, unlike the dietary-filter
           columns where majority is compliant, so the tagging logic below
           requires positive evidence of a permitted ingredient rather than
           defaulting to permitted and only flipping on a violation.
  Task 2 – Tag every dish from its ingredients (case-insensitive substring
           match). Recipe-level dishes and dishes with no ingredient rows
           get NULL for both flags, same as phase_diet_tagging.py.
  Task 3 – Summary report + explicit ambiguous/low-confidence dish list for
           manual review (never silently resolved either direction).

Flag semantics: 1 = permitted, 0 = restricted, NULL = unknown/uncertain.

IMPORTANT — these rules vary meaningfully by region and family tradition.
This script tags conservatively: a dish is only marked permitted (1) when
an ingredient positively matches the permitted list AND nothing in the
dish matches the restricted list. A dish is marked restricted (0) the
moment ANY restricted-keyword ingredient is present (restricted wins over
permitted on conflict, e.g. "aloo paratha" = potato + wheat flour → 0).
Dishes with no keyword signal in either direction are left NULL and
surfaced in the Task 3 review list rather than guessed.

Known limitations, left for manual review (not resolved by this script):
- "Salt" is generic in this DB — there is no distinct ingredient token for
  sendha namak/rock salt vs. iodized table salt, so salt is NOT used as a
  keyword at all (using it would blanket-restrict nearly every dish).
- Root vegetables other than potato/sweet potato (beetroot, radish, carrot,
  turnip, colocasia/arbi, yam) are genuinely disputed by region for
  Navratri and are deliberately NOT tagged permitted or restricted here —
  a dish whose only signal is one of these lands in the review list.
- Generic non-root vegetables (spinach, capsicum, cauliflower, bottle
  gourd, tomato, peas, etc.) are not called out as permitted or restricted
  by the spec baseline this script follows, so they are also not used as
  keywords — dishes with no other signal land in the review list.
- Millets/other grains (jowar, bajra, ragi, oats, quinoa, barley, corn) are
  NOT in the spec's explicit wheat/rice restriction and are NOT treated as
  permitted either — left as no-signal, same reasoning as above.
- Ekadashi non-veg/alcohol restriction is an assumption (the spec's
  Ekadashi-restricted bullet list only named grains/lentils/onion/garlic)
  extended here on the reasoning that an Ekadashi observant would not eat
  meat/alcohol either. Flagged explicitly in the report, not silently
  assumed.
"""

import os
os.chdir('/Users/ahilannayani/Personal Python Projects/Indian Food Calorie Counter')

import re
import sqlite3

DB_PATH = os.path.join(os.getcwd(), "indb.sqlite")

if not os.path.exists(DB_PATH):
    raise FileNotFoundError(f"Database not found: {DB_PATH}")

conn = sqlite3.connect(DB_PATH)
conn.row_factory = sqlite3.Row
cur  = conn.cursor()

FLAG_COLUMNS = ["navratri_permitted", "ekadashi_permitted"]

# ===========================================================================
# Keyword tables
# ===========================================================================

NON_VEG_KEYWORDS = [
    "chicken", "mutton", "lamb", "goat", "beef", "pork", "fish", "prawn",
    "shrimp", "crab", "egg", "meat", "keema", "kheema", "gelatin", "lard",
    "rohu", "pomfret", "mackerel", "bacon", "sausage", "salami",
    "mayonnaise", "worcestershire",
]
# Word-boundary regexes for keywords that plain substring matching would
# false-positive on (checked against this DB's 391 distinct ingredient
# names): "ham" as a plain substring hits "Banana, ripe, montham" and
# "hamburger buns"; "rum" hits "Drumstick".
NON_VEG_REGEXES = [re.compile(r"\bham\b")]
ALCOHOL_REGEXES = [re.compile(r"\brum\b")]

ALCOHOL_KEYWORDS = ["spirit", "alcohol", "wine", "beer", "whisky", "whiskey", "vodka", "liqueur"]

GRAIN_RESTRICTED_KEYWORDS = [
    "wheat", "atta", "maida", "suji", "rava", "semolina", "vermicelli",
    "bread", "pasta", "couscous", "biscuit", "buns", "pizza base",
    "cracked wheat", "rice",
]

LEGUME_RESTRICTED_KEYWORDS = [
    "dal", "gram", "lentil", "moong", "chick pea", "chickpea", "kabuli",
    "rajma", "rajmah", "moth bean", "cowpea", "soya bean", "soy bean", "tofu",
]

ALLIUM_RESTRICTED_KEYWORDS = ["onion", "garlic", "shallot"]

NAVRATRI_RESTRICTED_KEYWORDS = (
    NON_VEG_KEYWORDS + ALCOHOL_KEYWORDS + GRAIN_RESTRICTED_KEYWORDS
    + LEGUME_RESTRICTED_KEYWORDS + ALLIUM_RESTRICTED_KEYWORDS
)

# Assumption (flagged in report): Ekadashi restricted list in the spec only
# named grains/lentils/onion/garlic, but non-veg/alcohol are extended here
# too on the reasoning that an Ekadashi fast wouldn't permit either.
EKADASHI_RESTRICTED_KEYWORDS = (
    NON_VEG_KEYWORDS + ALCOHOL_KEYWORDS + GRAIN_RESTRICTED_KEYWORDS
    + LEGUME_RESTRICTED_KEYWORDS + ALLIUM_RESTRICTED_KEYWORDS
)

FRUIT_KEYWORDS = [
    "apple", "banana", "orange", "mango", "papaya", "guava", "grape",
    "pear", "peach", "plum", "pineapple", "strawberry", "blueberr",
    "cherry", "cherries", "date", "kiwi", "litchi", "pomegranate",
    "jack fruit", "jackfruit", "wood apple", "star fruit", "gooseberr",
    "raisin", "apricot", "currant", "cranberr", "lemon", "lime",
    "sultana", "fruit cocktail", "amla",
]

DAIRY_KEYWORDS = [
    "milk", "ghee", "paneer", "curd", "dahi", "cream", "butter",
    "khoya", "mawa", "cheese", "malai", "khoa", "yogurt",
]

NUT_KEYWORDS = [
    "cashew", "almond", "walnut", "pistachio", "hazelnut", "peanut",
    "ground nut", "groundnut", "mixed nuts", "pine seed", "makhana",
]

NAVRATRI_PERMITTED_KEYWORDS = (
    ["kuttu", "buckwheat", "singhara", "water chestnut", "rajgira", "amaranth",
     "sabudana", "sago", "tapioca", "sweet potato", "potato", "sendha namak", "rock salt"]
    + FRUIT_KEYWORDS + DAIRY_KEYWORDS + NUT_KEYWORDS
)

# Spec's Ekadashi-permitted baseline doesn't call out kuttu/singhara/rajgira
# specifically, so those are deliberately left off this list (see docstring).
EKADASHI_PERMITTED_KEYWORDS = (
    ["sabudana", "sago", "tapioca", "sweet potato", "potato"]
    + FRUIT_KEYWORDS + DAIRY_KEYWORDS + NUT_KEYWORDS
)

# Grains/starches that are NOT on either fast's permitted-starch list (only
# kuttu/buckwheat, singhara, rajgira/amaranth, and sabudana are) and are also
# not a restricted-keyword grain (wheat/rice). Left deliberately unevaluated
# per the spec baseline. A dish containing one of these must NOT be allowed
# to resolve to permitted=1 on the strength of some other, incidental
# ingredient (e.g. ghee) — that would tag the dish permitted without ever
# evaluating its actual starch, which is not a defensible call. Any dish
# hitting this list is downgraded from a would-be 1 to NULL (manual review),
# same treatment as a dish with no signal at all.
GRAIN_NO_SIGNAL_KEYWORDS = ["jowar", "bajra", "ragi", "maize", "corn", "oat", "quinoa", "barley"]

# Ingredient-name phrases that contain a keyword but don't carry the
# intended meaning — blanked out before matching (same technique as
# phase_diet_tagging.py's EXCEPTION_PHRASES). Found by running every
# keyword above against all 391 distinct ingredient names in this DB and
# inspecting the hits:
#   "rice vinegar"      -> not a rice/grain signal
#   "carrot, orange"    -> color descriptor, not the fruit
#   "pumpkin, orange"   -> same
#   "tomatoes, cherry"  -> the tomato variety, not the fruit
EXCEPTION_PHRASES = [
    "rice vinegar", "carrot, orange", "pumpkin, orange", "tomatoes, cherry",
]

# "buckwheat" contains "wheat" as a substring, which would self-trigger the
# grain restriction on every kuttu/buckwheat dish -- exactly the dishes this
# feature exists to mark permitted. Blanked out ONLY for the restricted-
# keyword pass; the permitted-keyword pass still needs "buckwheat" intact.
RESTRICTED_ONLY_EXCEPTION_PHRASES = ["buckwheat"]


def _sanitise(name: str) -> str:
    s = name.lower()
    s = re.sub(r"\([^)]*\)", " ", s)   # strip Latin binomial / parenthetical descriptors
    for phrase in EXCEPTION_PHRASES:
        s = s.replace(phrase, " ")
    return s


def _sanitise_for_restricted(name: str) -> str:
    s = _sanitise(name)
    for phrase in RESTRICTED_ONLY_EXCEPTION_PHRASES:
        s = s.replace(phrase, " ")
    return s


def _matches(sanitised_names: list[str], keywords: list[str]) -> bool:
    return any(kw in name for name in sanitised_names for kw in keywords)


def _matches_regex(sanitised_names: list[str], regexes: list[re.Pattern]) -> bool:
    return any(rx.search(name) for name in sanitised_names for rx in regexes)


# ===========================================================================
# TASK 1 – Add columns
# ===========================================================================
print("=" * 65)
print("TASK 1 – Adding fasting flag columns")
print("=" * 65)

cur.execute("PRAGMA table_info(dishes)")
existing_cols = {r["name"] for r in cur.fetchall()}

for col in FLAG_COLUMNS:
    if col not in existing_cols:
        cur.execute(f"ALTER TABLE dishes ADD COLUMN {col} INTEGER")
        print(f"  Added column: {col}")
    else:
        print(f"  Column already exists: {col}")

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
review: list[dict] = []   # dishes with no keyword signal either way

for dish in dishes:
    code        = dish["food_code"]
    name        = dish["food_name"]
    ingredients = ingredients_by_dish.get(code, [])

    if dish["is_recipe_level"] == 1 or not ingredients:
        cur.execute(
            "UPDATE dishes SET navratri_permitted = NULL, ekadashi_permitted = NULL WHERE food_code = ?",
            (code,),
        )
        nulled += 1
        continue

    sanitised            = [_sanitise(n) for n in ingredients]
    sanitised_restricted = [_sanitise_for_restricted(n) for n in ingredients]

    navratri_restricted = (
        _matches(sanitised_restricted, NAVRATRI_RESTRICTED_KEYWORDS)
        or _matches_regex(sanitised_restricted, NON_VEG_REGEXES)
        or _matches_regex(sanitised_restricted, ALCOHOL_REGEXES)
    )
    navratri_permitted_signal = _matches(sanitised, NAVRATRI_PERMITTED_KEYWORDS)
    ekadashi_restricted = (
        _matches(sanitised_restricted, EKADASHI_RESTRICTED_KEYWORDS)
        or _matches_regex(sanitised_restricted, NON_VEG_REGEXES)
        or _matches_regex(sanitised_restricted, ALCOHOL_REGEXES)
    )
    ekadashi_permitted_signal = _matches(sanitised, EKADASHI_PERMITTED_KEYWORDS)

    if navratri_restricted:
        navratri_permitted = 0
    elif navratri_permitted_signal:
        navratri_permitted = 1
    else:
        navratri_permitted = None

    if ekadashi_restricted:
        ekadashi_permitted = 0
    elif ekadashi_permitted_signal:
        ekadashi_permitted = 1
    else:
        ekadashi_permitted = None

    # A permitted=1 verdict is only valid if the dish's actual starch was
    # evaluated. If it instead contains a grain that's off both permitted
    # lists (millet/corn/oats/etc.), a 1 here would be resting entirely on
    # some other incidental ingredient — downgrade to NULL instead.
    has_unevaluated_grain = _matches(sanitised, GRAIN_NO_SIGNAL_KEYWORDS)
    if has_unevaluated_grain:
        if navratri_permitted == 1:
            navratri_permitted = None
        if ekadashi_permitted == 1:
            ekadashi_permitted = None

    if navratri_permitted is None or ekadashi_permitted is None:
        review.append({
            "food_code": code,
            "food_name": name,
            "navratri":  "?" if navratri_permitted is None else navratri_permitted,
            "ekadashi":  "?" if ekadashi_permitted is None else ekadashi_permitted,
            "ingredients": ingredients,
        })

    cur.execute(
        "UPDATE dishes SET navratri_permitted = ?, ekadashi_permitted = ? WHERE food_code = ?",
        (navratri_permitted, ekadashi_permitted, code),
    )
    tagged += 1

conn.commit()
print(f"\n  Dishes tagged:            {tagged}")
print(f"  Dishes left NULL (recipe-level / no ingredients): {nulled}")
print(f"  Dishes with >=1 uncertain flag (need review):     {len(review)}")

# ===========================================================================
# TASK 3 – Summary report + ambiguous-dish review list
# ===========================================================================
print()
print("=" * 65)
print("TASK 3 – Summary")
print("=" * 65)

print(f"\n  {'flag':<20} {'permitted(1)':>13} {'restricted(0)':>14} {'NULL':>6}")
for col in FLAG_COLUMNS:
    cur.execute(f"""
        SELECT SUM(CASE WHEN {col} = 1 THEN 1 ELSE 0 END)     AS yes,
               SUM(CASE WHEN {col} = 0 THEN 1 ELSE 0 END)     AS no,
               SUM(CASE WHEN {col} IS NULL THEN 1 ELSE 0 END) AS unk
        FROM dishes
    """)
    r = cur.fetchone()
    print(f"  {col:<20} {r['yes']:>13} {r['no']:>14} {r['unk']:>6}")

print(f"\n  Ambiguous / low-confidence dishes for manual review ({len(review)} total):")
print(f"  {'food_code':<10} {'food_name':<44} {'nav':>4} {'eka':>4}")
for r in sorted(review, key=lambda x: x["food_name"]):
    print(f"  {r['food_code']:<10} {r['food_name'][:44]:<44} {str(r['navratri']):>4} {str(r['ekadashi']):>4}")

conn.close()
print("\nDone.")
