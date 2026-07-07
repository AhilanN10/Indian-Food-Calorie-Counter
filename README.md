# Indian Food Calorie Counter

An iOS calorie and macro tracker for Indian cuisine: a FastAPI + SQLite backend (built against the **Indian Nutrient Databank, INDB**) paired with a SwiftUI + SwiftData iOS client that classifies a photo of food with a Core ML vision model, asks a handful of category-specific questions to refine the portion, and logs the result — with Apple Health sync, barcode scanning, dietary/fasting filters, and a Profile/TDEE goal system.

---

## Project Status

The backend and iOS app are both built and in active use; this is a live, ongoing project, not a fixed "phase N of M." **[FEATURE_ROADMAP.md](FEATURE_ROADMAP.md)** is the authoritative, continuously-updated list of what's shipped vs. still open — check there first, this README gives the overview.

**Completed & verified so far:**
- FastAPI backend — multiplier-based macro engine, 3-tier dish name resolution, dietary/fasting filters
- SQLite DB — 1,014 total dishes (950 available for lookup + 64 recipe-level), diet-tagged and fasting-tagged
- EfficientNet-B0 Core ML classifier — 92 food classes, ~72.5% accuracy
- SwiftUI app — camera capture, barcode scanning (Open Food Facts), category-specific Q&A flow, results screen, SwiftData meal logging, HealthKit sync, Profile tab with TDEE/macro goals, search with recents/favorites, Dietary Filters, Fasting Mode (Navratri/Ekadashi), and three coexisting portion-input methods (bucket-scale, manual weight, katori/piece-count) plus an optional oil/ghee add-on

**Still open** (see FEATURE_ROADMAP.md for full detail): a handful of ambiguous-dish review lists awaiting manual sign-off (fasting tagging, portion-method eligibility), a UI terminology decision on the "Fuzzy" match badge, and real-device testing for camera/barcode/HealthKit/the newest portion UI (verified in Simulator so far).

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
├── phase3a_data_prep.py               # Vision-model training data prep
├── phase3a_remap.py / phase3a_manual_fix.py  # Classifier class-map remapping/fixes
├── phase_diet_tagging.py              # Vegetarian/vegan/Jain/no-onion-garlic/gluten-free/dairy-free tagging
├── phase_fasting_tagging.py           # Navratri/Ekadashi permitted-food tagging
├── patch_aliases.py                   # Alias table maintenance
│
├── main.py                            # FastAPI app (entry point)
├── db.py                              # SQLite connection utility
├── aliases.py                         # 3-tier dish name resolution
├── calculator.py                      # Multiplier-based macro engine
├── portion_eligibility.py             # Katori/piece-count/oil-ghee eligibility rules + gram derivation
├── usda.py                            # USDA FoodData Central API wrapper
│
├── test_dietary_filters_regression.py    # Standalone regression check (dietary filters)
├── test_portion_accuracy_regression.py   # Standalone regression check (katori/piece-count/oil-ghee)
│
├── class_map.json                     # Vision-classifier class index → food_code mapping
├── IndianFoodClassifier.mlpackage     # Compiled Core ML model
│
├── IndianFoodApp/                     # SwiftUI iOS app (Xcode project)
│   ├── IndianFoodApp.xcodeproj
│   └── Sources/
│       ├── App/                       # App entry point
│       ├── Models/                    # DishMatch/QAAnswers/MealLog/UserProfile/FavoriteDish (SwiftData)
│       ├── Services/                  # APIService, QuestionEngine, HealthKitService, BarcodeScanner,
│       │                              #   OpenFoodFactsService, ProfileStore, FastingModeStore,
│       │                              #   RecentSearchesStore, TDEECalculator, VisionService
│       ├── Views/                     # Camera, Search, QuestionView, Results, Dashboard, Log,
│       │                              #   MealHistory, Profile, BarcodeResult
│       └── IndianFoodClassifier.mlpackage
│
├── FEATURE_ROADMAP.md                 # Living roadmap — completed/open items, source of truth for status
├── testchecklist.md                  # Living QA checklist — worked examples, ambiguous-dish review lists
├── CLAUDE.md                          # Dev conventions/instructions for AI-assisted work on this repo (gitignored)
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
| `serving_size_g` | REAL | Populated for only a minority of rows — see "Portion methods" below for why this matters |
| `serving_size_is_default` | INTEGER | 1 = estimated default (82 rows) |
| `has_cream_in_base` | INTEGER | 1 if cream/malai/coconut in ingredients |
| `has_butter_in_base` | INTEGER | 1 if butter in ingredients |
| `has_ghee_in_base` | INTEGER | 1 if ghee in ingredients |
| `dairy_fat_already_counted` | INTEGER | 1 if any dairy flag set (443 dishes) |
| `is_recipe_level` | INTEGER | 1 = full-batch yield, not a single serving (64 dishes) |
| `food_category` | TEXT | See categories below |
| `is_vegetarian`, `is_vegan`, `is_jain`, `is_no_onion_garlic`, `is_gluten_free`, `is_dairy_free` | INTEGER | 1 compliant / 0 violates / NULL unknown — tagged for all 950 available dishes |
| `diet_tags_source` | TEXT | `'auto'` (keyword-tagged) vs. manually reviewed |
| `navratri_permitted`, `ekadashi_permitted` | INTEGER | 1 permitted / 0 restricted / NULL unreviewed — tagged for 913 of 950 dishes; the remaining 37 are an explicit ambiguous-review list (see testchecklist.md) |

**Food categories:** `beverage`, `rice`, `bread`, `dal_legume`, `meat_fish`, `paneer_dairy`, `vegetable`, `snack_street`, `sweet_dessert`, `condiment_side`, `other`

Katori-portion, piece-count-portion, and oil/ghee-add-on eligibility are **not** stored as DB columns — they're computed per-request in `portion_eligibility.py` from `food_category` + `serving_unit` + a small set of explicit keyword/exclusion rules, and exposed via the API (see below).

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

### `dish_aliases` table (74 rows seeded)

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

Always include `--reload` — without it, code changes won't take effect and you'll be testing against stale code.

Interactive API docs: http://localhost:8000/docs

---

## Running the iOS App

Open `IndianFoodApp/IndianFoodApp.xcodeproj` in Xcode and run on a simulator or device. The app talks to the backend at `http://127.0.0.1:8000` by default (`APIService.swift`) — for a real device, swap in your Mac's LAN IP and set `NSAppTransportSecurity` in `Info.plist`, since the backend must be running for the app to do anything useful.

New Swift files must be manually added to the Xcode target after creation (right-click the target folder → Add Files to "IndianFoodApp" → check the target) — this doesn't happen automatically from disk.

---

## API Endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/health` | Liveness check, returns `dishes_available` count |
| `GET` | `/dish/search?q=biryani` | 3-tier name resolution (exact → alias → fuzzy). Optional `category`, `dietaryFilters`, `fastingMode`, `limit` params. Always returns `{query, results[], total}`. |
| `GET` | `/dish/browse` | Dishes grouped by `food_category` (max 10/category). Same `dietaryFilters`/`fastingMode` params as search. |
| `GET` | `/dish/{food_code}` | Full dish detail + ingredients, plus computed `katori_eligible`, `piece_count_eligible`, `oil_ghee_eligible` booleans |
| `POST` | `/dish/calculate` | Macro estimation with QA multipliers (see below) |
| `GET` | `/usda/search?q=chicken` | USDA FoodData Central proxy |
| `GET` | `/categories` | Dish counts per food category |

`dietaryFilters` is a comma-separated list of `vegetarian`, `vegan`, `jain`, `no_onion_garlic`, `gluten_free`, `dairy_free` (AND logic; NULL/unknown flags never pass a filter). `fastingMode` is `navratri` or `ekadashi`, combined with `dietaryFilters` via the same AND-of-flag-columns plumbing.

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
    "questions_skipped": 0,
    "manual_weight_g": null,
    "katori_count": null,
    "piece_count": null,
    "oil_ghee_tsp": 0
  }
}
```

`manual_weight_g`, `katori_count`, and `piece_count` are three alternative ways to specify portion size — at most one is meaningful per request, and `manual_weight_g` takes precedence if more than one is supplied. `oil_ghee_tsp` is independent of all three and always optional (defaults to 0/skip).

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
  "manual_weight_used": false,
  "katori_used": false,
  "piece_count_used": false,
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

The macro engine applies multipliers/adjustments in this order:

1. **Portion scale** — one of four methods, in priority order:
   - `manual_weight_g` ÷ `serving_size_g` (exact grams), if both are present and the raw DB column is populated — else falls back to the next method
   - `katori_count` × a category-specific grams-per-katori baseline (dal_legume 150g, rice 165g, vegetable 150g dry/200g curry depending on `gravy_type`, paneer_dairy 200g for gravy-style dishes only), ÷ a *derived* serving weight (`energy_kcal_per_serving / energy_kcal_per_100g × 100`, used because the raw `serving_size_g` column is NULL for the large majority of dishes in these categories)
   - `piece_count` directly as the scale (per-serving nutrition data IS the per-piece basis for eligible bread/snack_street/sweet_dessert dishes)
   - otherwise, the fixed bucket lookup — `PORTION_SCALE`, `RICE_SCALE`, or `MEAT_SCALE` depending on `food_category`

   Which of katori/piece-count a given dish offers is decided by `portion_eligibility.py` (category + serving_unit + a keyword/exclusion list — not every dish in a katori/piece-count-capable category actually gets the option; see FEATURE_ROADMAP.md/testchecklist.md for the ~165-dish exclusion list).

2. **Fat adjustment** — `CONTEXT_FAT_ADD_G` (cooking context) + `GRAVY_FAT_ADD_G`, or `COOKING_METHOD_FAT_ADJUST_G` if `cooking_method` is set. Gravy fat skipped if `dairy_fat_already_counted=1` and gravy is `thick`/`very_thick`.
3. **Flat additions** — additive kcal/macro bumps (cream dollop, butter, egg, etc.). `cream_dollop` skipped if `has_cream_in_base=1`; butter skipped if `has_butter_in_base=1`.
4. **Oil/ghee add-on** — optional, additive: `oil_ghee_tsp × 40 kcal`, represented as `+4.44g fat` per tsp (consistent with how the other flat additions represent kcal as fat grams). Offered only for `dal_legume`, `vegetable`, `meat_fish`, `paneer_dairy`.
5. **kcal recomputed** from final macros: `(fat×9) + (protein×4) + (carb×4)` — always, so the oil/ghee add-on and every other adjustment stay internally consistent with the displayed macros.
6. **Confidence band** — ±10% (0 skipped) → ±40% (3+ skipped); tightened one tier when `manual_weight_g` is used (never below ±10%). Katori/piece-count do **not** currently tighten the band — they're estimates on top of another estimate, not an exact measurement.

### Valid QA answer values

| Field | Options |
|---|---|
| `portion_size` | `tiny`, `small`, `standard`, `large`, `extra_large` |
| `rice_amount` | `small_scoop`, `half_cup`, `standard_cup`, `large_serving`, `full_bowl` |
| `meat_amount` | `light`, `moderate`, `heavy`, `very_heavy` |
| `cooking_context` | `home`, `homestyle_restaurant`, `restaurant`, `dhaba`, `street_fried`, `street_nonfried`, `wedding_banquet` |
| `gravy_type` | `dry`, `thin`, `medium`, `thick`, `very_thick` (also selects the vegetable katori dry/curry gram baseline) |
| `cooking_method` | `steamed`, `boiled`, `tandoor`, `shallow_fried`, `deep_fried_thin`, `deep_fried_thick`, `deep_fried_dough` |
| `flat_additions` | `cream_dollop`, `butter_standard`, `butter_extra`, `paneer_extra`, `egg_whole`, `cashews_visible`, `coconut_milk_base`, `coconut_fresh_heavy`, `sev_papdi_topping`, `raita_side`, `papad_one`, `naan_vs_roti_extra` |
| `manual_weight_g` | any float ≥ 5 (rejected with HTTP 400 below that) |
| `katori_count` | any float > 0, e.g. `0.5`, `1`, `1.5` |
| `piece_count` | any float > 0, e.g. `1`, `2`, `3` |
| `oil_ghee_tsp` | any float ≥ 0 (0/omitted = skip) |

---

## Environment Variables (`.env`)

```
USDA_API_KEY=DEMO_KEY
```

Replace `DEMO_KEY` with a real key from https://fdc.nal.usda.gov/api-guide.html for production use.

---

## Data Pipeline Scripts

> Most of these are run once to build/enrich `indb.sqlite` from the raw Excel files or to backfill a tagging pass. You don't need to re-run them unless the source data or tagging rules change.

```bash
# All scripts must be run from the project root
cd "/Users/<you>/Personal Python Projects/Indian Food Calorie Counter"

python3 phase0_pipeline.py       # Parse INDB.xlsx + recipes.xlsx → indb.sqlite
python3 phase0b_cleanup.py       # Fix NULLs, anomalies, seed aliases
python3 phase1_cleanup.py        # Flag recipe-level rows, add food_category
python3 phase_diet_tagging.py    # Backfill vegetarian/vegan/Jain/no-onion-garlic/gluten-free/dairy-free flags
python3 phase_fasting_tagging.py # Backfill navratri_permitted/ekadashi_permitted flags
```

`phase3a_data_prep.py`, `phase3a_remap.py`, and `phase3a_manual_fix.py` are one-off scripts from building the vision-model training set and class map — not part of the regular DB-build pipeline.

---

## Testing

There's no pytest suite. The convention in this repo is standalone, runnable regression scripts that use an in-process `TestClient` (so they always reflect the code on disk, never a stale running server):

```bash
python3 test_dietary_filters_regression.py
python3 test_portion_accuracy_regression.py
```

For anything involving real math (portion scaling, TDEE/macros, additive kcal), hand-calculated worked examples live in **[testchecklist.md](testchecklist.md)** alongside device-testing checklists for camera/barcode/HealthKit (batched into occasional large sessions rather than run after every feature).

---

## Where to Look Next

This README covers the shape of the system. For what's actually done vs. still open, and why:

- **[FEATURE_ROADMAP.md](FEATURE_ROADMAP.md)** — the living roadmap: completed & verified features, open decisions, and the full backlog
- **[testchecklist.md](testchecklist.md)** — per-feature QA checklists, worked examples, and every dish-level ambiguous-review list (fasting tagging, portion-method eligibility) awaiting manual sign-off

---

*Last updated: July 6, 2026 — after the Portion Accuracy phase (katori portions, piece-count portions, oil/ghee add-on).*
