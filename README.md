# Indian Food Calorie Counter — Backend

A Python data pipeline + FastAPI backend that powers an iOS Indian food calorie and macro tracking app. Built against the **Indian Nutrient Databank (INDB)**.

---

## Project Status

**Current phase: Phase 2 complete.**
The full data pipeline (Phases 0, 0b, 1) and the FastAPI backend (Phase 2) are implemented and tested. The next phase is the iOS frontend or extending the API with user-session tracking / meal logging.

---

## Directory Structure

```
Indian Food Calorie Counter/
├── Indian-Nutrient-Databank-INDB-/   # Raw INDB source files (not pushed – see note)
│   ├── INDB.xlsx                      # ~1,014 dishes, full nutrient panel
│   └── recipes.xlsx                   # ~10,271 ingredient rows
│
├── indb.sqlite                        # ✅ Compiled SQLite database (primary artifact)
├── phase0_pipeline.py                 # Phase 0: parse Excel → SQLite
├── phase0b_cleanup.py                 # Phase 0b: fix NULLs, anomalies, seed aliases
├── phase1_cleanup.py                  # Phase 1: flag recipe-level rows, add food_category
│
├── main.py                            # FastAPI app (entry point)
├── db.py                              # SQLite connection utility
├── aliases.py                         # 3-tier dish name resolution
├── calculator.py                      # Multiplier-based macro engine
├── usda.py                            # USDA FoodData Central API wrapper
│
├── .env                               # API keys (USDA_API_KEY=DEMO_KEY)
└── README.md
```

> **Note on INDB source files:** `INDB.xlsx` and `recipes.xlsx` are large proprietary files. They are kept in the `Indian-Nutrient-Databank-INDB-/` subdirectory and excluded from git via `.gitignore`. The compiled `indb.sqlite` is the working artifact — it already contains all parsed and cleaned data.

---

## Database Schema (`indb.sqlite`)

### `dishes` table (1,014 rows total, 950 available for lookup)

| Column | Type | Notes |
|---|---|---|
| `food_code` | TEXT PK | e.g. `ASC122` |
| `food_name` | TEXT | e.g. `Mutton biryani/biriyani` |
| `energy_kcal_per_100g` | REAL | Per-100g macros from INDB |
| `protein_g_per_100g` | REAL | |
| `fat_g_per_100g` | REAL | |
| `carb_g_per_100g` | REAL | |
| `fibre_g_per_100g` | REAL | |
| `energy_kcal_per_serving` | REAL | NULL for is_recipe_level=1 rows |
| `protein_g_per_serving` | REAL | |
| `fat_g_per_serving` | REAL | |
| `carb_g_per_serving` | REAL | |
| `fibre_g_per_serving` | REAL | |
| `serving_unit` | TEXT | e.g. `plate`, `bowl`, `piece` |
| `serving_size_g` | REAL | Added in Phase 0b |
| `serving_size_is_default` | INTEGER | 1 = estimated default (82 rows) |
| `has_cream_in_base` | INTEGER | 1 if cream/malai/coconut in ingredients |
| `has_butter_in_base` | INTEGER | 1 if butter in ingredients |
| `has_ghee_in_base` | INTEGER | 1 if ghee in ingredients |
| `dairy_fat_already_counted` | INTEGER | 1 if any dairy flag set (443 dishes) |
| `is_recipe_level` | INTEGER | 1 = full-batch yield, not a single serving (64 dishes) |
| `food_category` | TEXT | See categories below |

**Food categories:** `beverage`, `rice`, `bread`, `dal_legume`, `meat_fish`, `paneer_dairy`, `vegetable`, `snack_street`, `sweet_dessert`, `condiment_side`, `other`

### `ingredients` table (10,271 rows)

| Column | Type |
|---|---|
| `id` | INTEGER PK |
| `recipe_code` | TEXT (FK → dishes.food_code) |
| `recipe_name` | TEXT |
| `ingredient_food_code` | TEXT |
| `ingredient_name` | TEXT |
| `amount` | REAL |
| `unit` | TEXT |

### `dish_aliases` table (26 rows seeded)

| Column | Type |
|---|---|
| `alias` | TEXT PK |
| `canonical_food_code` | TEXT |
| `canonical_food_name` | TEXT |
| `region` | TEXT |
| `variant_flag` | TEXT |

Example aliases: `chole → chhole`, `chapati → roti`, `dosai → dosa`, `biriyani → biryani`, `sambhar → sambar`, `chenna → paneer`, etc.

---

## Running the Backend

### Prerequisites

```bash
pip3 install fastapi uvicorn python-dotenv requests fuzzywuzzy python-levenshtein pandas openpyxl
```

### Start the server

```bash
cd "/Users/<you>/Personal Python Projects/Indian Food Calorie Counter"
uvicorn main:app --reload --port 8000
```

Interactive API docs: http://localhost:8000/docs

---

## API Endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/health` | Liveness check, returns `dishes_available` count |
| `GET` | `/dish/search?q=biryani` | 3-tier name resolution (exact → alias → fuzzy) |
| `GET` | `/dish/{food_code}` | Full dish detail + ingredients |
| `POST` | `/dish/calculate` | Macro estimation with QA multipliers |
| `GET` | `/usda/search?q=chicken` | USDA FoodData Central proxy |
| `GET` | `/categories` | Dish counts per food category |

### `POST /dish/calculate` — Request shape

```json
{
  "food_code": "ASC122",
  "qa_answers": {
    "portion_size": "standard",
    "rice_amount": null,
    "meat_amount": null,
    "cooking_context": "home",
    "gravy_type": "medium",
    "cooking_method": null,
    "flat_additions": ["cream_dollop"],
    "questions_skipped": 0
  }
}
```

### `POST /dish/calculate` — Response shape

```json
{
  "food_code": "ASC122",
  "food_name": "Mutton biryani/biriyani",
  "kcal_estimate": 819.1,
  "kcal_low": 737,
  "kcal_high": 901,
  "protein_g": 25.3,
  "fat_g": 45.5,
  "carb_g": 77.1,
  "fibre_g": 8.3,
  "confidence_band_pct": 0.10,
  "questions_skipped": 0,
  "dairy_flag_applied": false,
  "adjustments_applied": [
    "rice_scale_large_serving_1.65",
    "context_fat_restaurant_+12g",
    "gravy_thick_+7g"
  ]
}
```

---

## Calculator Logic (`calculator.py`)

The macro engine applies multipliers in this order:

1. **Portion scale** — `PORTION_SCALE`, `RICE_SCALE`, or `MEAT_SCALE` depending on `food_category`
2. **Fat adjustment** — `CONTEXT_FAT_ADD_G` (cooking context) + `GRAVY_FAT_ADD_G`, or `COOKING_METHOD_FAT_ADJUST_G` if `cooking_method` is set. Gravy fat skipped if `dairy_fat_already_counted=1` and gravy is `thick`/`very_thick`.
3. **Flat additions** — additive kcal/macro bumps (cream dollop, butter, egg, etc.). `cream_dollop` skipped if `has_cream_in_base=1`; butter skipped if `has_butter_in_base=1`.
4. **kcal recomputed** from final macros: `(fat×9) + (protein×4) + (carb×4)`
5. **Confidence band** — ±10% (0 skipped) → ±40% (3+ skipped)

### Valid QA answer values

| Field | Options |
|---|---|
| `portion_size` | `tiny`, `small`, `standard`, `large`, `extra_large` |
| `rice_amount` | `small_scoop`, `half_cup`, `standard_cup`, `large_serving`, `full_bowl` |
| `meat_amount` | `light`, `moderate`, `heavy`, `very_heavy` |
| `cooking_context` | `home`, `homestyle_restaurant`, `restaurant`, `dhaba`, `street_fried`, `street_nonfried`, `wedding_banquet` |
| `gravy_type` | `dry`, `thin`, `medium`, `thick`, `very_thick` |
| `cooking_method` | `steamed`, `boiled`, `tandoor`, `shallow_fried`, `deep_fried_thin`, `deep_fried_thick`, `deep_fried_dough` |
| `flat_additions` | `cream_dollop`, `butter_standard`, `butter_extra`, `paneer_extra`, `egg_whole`, `cashews_visible`, `coconut_milk_base`, `coconut_fresh_heavy`, `sev_papdi_topping`, `raita_side`, `papad_one`, `naan_vs_roti_extra` |

---

## Environment Variables (`.env`)

```
USDA_API_KEY=DEMO_KEY
```

Replace `DEMO_KEY` with a real key from https://fdc.nal.usda.gov/api-guide.html for production use.

---

## Data Pipeline Scripts

> These are run once to build `indb.sqlite` from the raw Excel files. You don't need to re-run them unless the source data changes.

```bash
# All scripts must be run from the project root
cd "/Users/<you>/Personal Python Projects/Indian Food Calorie Counter"

python3 phase0_pipeline.py    # Parse INDB.xlsx + recipes.xlsx → indb.sqlite
python3 phase0b_cleanup.py    # Fix NULLs, anomalies, seed aliases
python3 phase1_cleanup.py     # Flag recipe-level rows, add food_category
```

---

## Known Issues / Next Steps

### Data issues (low priority, document for partner)
- **64 dishes flagged `is_recipe_level=1`**: These have per-serving kcal > 2,000 because INDB stored the full recipe yield as one serving. Their per-serving columns are NULL. They remain in the DB for reference but are excluded from all lookups. A future enhancement could divide by typical recipe yield.
- **82 dishes have `serving_size_is_default=1`**: These had no per-serving data in INDB so a default serving size was estimated from the dish name (e.g. 150g for curries, 100g for breads). The values are reasonable estimates but not verified.
- **`food_category = "other"` is large (465 dishes)**: The keyword classifier didn't match many dishes. Refining the keyword lists would improve category-based filtering in the iOS UI.

### Phase 3 — iOS App (recommended next steps for partner)
The backend is fully functional at `http://localhost:8000`. The iOS app should:
1. Call `GET /dish/search?q=<user_input>` as the user types
2. If `match_type == "fuzzy"`, show the `candidates` list for the user to confirm
3. Once a dish is confirmed, ask the QA questions (portion size, cooking context, etc.)
4. Call `POST /dish/calculate` with the confirmed `food_code` and QA answers
5. Display `kcal_estimate` with the `kcal_low`–`kcal_high` confidence range
6. Show a breakdown: protein, fat, carbs, fibre

---

## Handoff Prompt (copy-paste for partner's AI)

```
We are building an Indian food calorie and macro tracking iOS app.
The Python backend is complete and pushed to:
https://github.com/AhilanN10/Indian-Food-Calorie-Counter.git

── What's already built ──────────────────────────────────────────

DATABASE: indb.sqlite (SQLite, already compiled and in repo)
  - 1,014 dishes from the Indian Nutrient Databank (INDB)
  - 950 available for lookup (64 flagged as recipe-level full-batch yields)
  - Tables: dishes, ingredients (10,271 rows), dish_aliases (26 rows)
  - Key columns on dishes: food_code, food_name, energy_kcal_per_serving,
    protein/fat/carb/fibre _per_serving and _per_100g, serving_unit,
    serving_size_g, serving_size_is_default, has_cream_in_base,
    has_butter_in_base, has_ghee_in_base, dairy_fat_already_counted,
    is_recipe_level, food_category

FASTAPI BACKEND (main.py) — runs on port 8000:
  GET  /health                      → liveness + dishes_available count
  GET  /dish/search?q=<name>        → 3-tier lookup: exact → alias → fuzzy top-3
  GET  /dish/{food_code}            → full dish + ingredients list
  POST /dish/calculate              → multiplier-based macro estimation
  GET  /usda/search?q=<query>       → USDA FoodData Central proxy
  GET  /categories                  → dish count per food_category

CALCULATOR (calculator.py):
  Applies in order: portion scale → fat context/gravy/cooking method →
  flat additions → recompute kcal from macros → confidence band (±10% to ±40%)
  Full logic documented in README.md

ALIAS RESOLUTION (aliases.py):
  Tier 1: exact match on food_name
  Tier 2: dish_aliases table (regional names like chole, chapati, dosai, etc.)
  Tier 3: fuzzywuzzy top-3 candidates (score > 60)

── To start the server ───────────────────────────────────────────

  cd "Indian Food Calorie Counter"
  uvicorn main:app --reload --port 8000

── Phase 3 task (iOS app) ────────────────────────────────────────

Build a SwiftUI iOS app that:
1. Search screen: text field → calls GET /dish/search?q= → shows results
   (if fuzzy, show a picker for the user to confirm the dish)
2. QA screen: after dish confirmed, ask these questions in order:
   a. Portion size (tiny/small/standard/large/extra_large)
   b. Cooking context (home/restaurant/dhaba/street_fried/wedding_banquet/etc.)
   c. Gravy type if applicable (dry/thin/medium/thick/very_thick)
   d. Any extras? (cream dollop, butter, extra paneer, egg, etc.)
3. Result screen: POST /dish/calculate → show kcal_estimate with kcal_low/high
   range, and macro breakdown (protein, fat, carb, fibre)
4. Meal log: allow user to add multiple dishes to a daily log,
   sum up totals, persist with SwiftData or CoreData

The backend base URL for development: http://localhost:8000
For device testing you will need to run the server on your local IP
(e.g. http://192.168.x.x:8000) and set NSAppTransportSecurity in Info.plist.
```

---

*Last updated: June 27, 2026 — Phase 2 complete.*
