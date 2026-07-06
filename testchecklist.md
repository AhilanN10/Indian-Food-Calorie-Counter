
## Phase 6a — Apple Health Integration

*(Real device required for all items. On the simulator, HealthKit is unavailable, no permission prompt ever appears, and the status line shows "Apple Health not connected" — expected, not a bug.)*

### Authorization
- [ ] Fresh install → tap "Add to <meal>" on a Results screen → HealthKit permission sheet appears (auth is requested lazily on first log, NOT at app launch)
- [ ] Permission sheet lists exactly 5 write types: Dietary Energy, Protein, Carbohydrates, Total Fat, Fiber
- [ ] Grant all 5 → status line under the log button shows red heart + "Also logged to Apple Health"
- [ ] Deny → meal still logs to SwiftData normally; status line shows heart.slash + "Apple Health not connected"; no crash
- [ ] Deny, then enable later in Settings → Health → Data Access → next logged meal writes successfully without reinstalling

### Data accuracy (5 dietary quantities per meal)
- [ ] Log a meal in-app, then open Health app → Browse → Nutrition: entries exist for Dietary Energy, Protein, Carbohydrates, Total Fat, Fiber at the log time
- [ ] Health app values match the Results screen exactly: kcal = the big orange number (kcal_estimate), protein/carbs/fat/fibre = the macro card values in grams
- [ ] Tap into a sample in Health app → detail shows the dish name (written as food-type metadata on every sample)
- [ ] Log a barcode product → same 5 quantities written under the product name, using the serving-adjusted display values

### Duplicate prevention
- [ ] After tapping "Add to <meal>" the button turns green "Logged!" and is disabled → repeated tapping cannot double-write (there is no meal editing feature; re-logging requires a fresh scan, which is a legitimate second entry)
- [ ] One logged meal = exactly one sample per quantity type in Health (no doubles from a single tap)

## Phase 6b — Barcode Scanner

*(Real device required — the simulator has no camera. On the simulator the scanner shows a "No Camera" alert and returns cleanly — expected, not a bug.)*

### Entry points
- [ ] Log tab → "Scan Barcode" button opens the camera scanner
- [ ] Search screen (in the scan flow) → barcode viewfinder icon opens the same scanner
- [ ] Scanner UI shows: camera preview, orange 260×160 frame with corner accents, "Point camera at barcode" label, Cancel top-right
- [ ] Cancel returns to idle (tabs visible, no stuck overlay)

### Scanning behavior
- [ ] EAN-13 barcode (most Indian packaged products) scans successfully
- [ ] EAN-8, UPC-E, Code 128, Code 39, and QR codes are also recognized (full supported symbology list)
- [ ] Device vibrates once on successful scan
- [ ] Holding the camera on the same barcode does NOT fire multiple lookups (one-shot scan guard; capture session stops on first read)
- [ ] After a scan, the "Identifying your dish…" spinner shows while the Open Food Facts lookup runs

### Found-product flow
- [ ] Known product (e.g. a Maggi/Haldiram's packet) → "Product Found" screen shows product name, brand, and barcode number
- [ ] Kcal + protein/carbs/fat/fibre cards populate from Open Food Facts data
- [ ] Product WITH per-serving data on OFF → "Use serving size (…)" toggle appears and is ON by default; values shown are per-serving
- [ ] Toggle OFF → values switch to per-100g basis
- [ ] Product WITHOUT per-serving data → no toggle shown; values are per-100g (servings 1.0 = 100g)
- [ ] Servings stepper: +/− adjusts in 0.5 steps, floors at 0.5, all displayed values scale live (spot-check: 2.0 servings = exactly double 1.0)
- [ ] Missing individual macros on OFF show as 0, not blank/NaN (kcal is required; a product with no kcal data at all is treated as not found)
- [ ] Select meal type → "Add to <meal>" → button turns green "Logged!" and disables (no double-log)
- [ ] Logged item appears in History with the product name and serving-adjusted macros
- [ ] Logged item writes to Apple Health (see Phase 6a) using the serving-adjusted values
- [ ] Dashboard calorie ring and macro bars include the barcode item

### Not-found flow
- [ ] Scan a barcode not on Open Food Facts (or one whose product has no calorie data) → error screen: "No product found for barcode: <code>… Try searching manually."
- [ ] "Try Again" returns cleanly to idle; scanner can be reopened immediately
- [ ] Airplane mode → scan → lookup fails gracefully into the same not-found screen (no hang or crash)

## Phase 5c — Profile / TDEE

### Profile Form — save & load
- [ ] Fill in all fields (age, sex, height, weight, activity, goal) and tap Save → profile summary card appears
- [ ] Force-quit and relaunch → profile fields still populated (UserDefaults persistence)
- [ ] Tap "Edit" → form pre-fills with exact values previously entered
- [ ] Tap "Clear Profile" → summary disappears; setup prompt shown; Dashboard falls back to 2000 kcal

### Unit Toggle — conversion accuracy
- [ ] Enter 175 cm → switch to Imperial → should show 5′ 9″ (175 / 2.54 = 68.9 in → 5′ 8.9″)
- [ ] Enter 70 kg → switch to Imperial → should show 154.3 lb (70 × 2.20462)
- [ ] Switch back to Metric → stored canonical values unchanged (no drift: round-trip error < 0.1 cm / 0.1 kg)
- [ ] Enter 5′ 11″ in Imperial → switch to Metric → should show ~180.3 cm

### BMR / TDEE math
- [ ] Male, 25 yrs, 70 kg, 175 cm, Moderate activity (×1.55)
  - BMR = 10×70 + 6.25×175 − 5×25 + 5 = 700 + 1093.75 − 125 + 5 = **1673.75 kcal**
  - TDEE = 1673.75 × 1.55 = **2594.3 kcal**
  - Displayed TDEE should be ~2594 kcal
- [ ] Female, 30 yrs, 60 kg, 165 cm, Sedentary (×1.2)
  - BMR = 10×60 + 6.25×165 − 5×30 − 161 = 600 + 1031.25 − 150 − 161 = **1320.25 kcal**
  - TDEE = 1320.25 × 1.2 = **1584.3 kcal**

### Calorie floor enforcement
- [ ] Set Cut −750 kcal with a very low TDEE (e.g. female, sedentary, small stature where TDEE < 1950)
  → Daily goal should never display below **1200 kcal**

### Goal adjustments
- [ ] Select "Cut" → deficit picker shows −250 / −500 / −750; live preview updates accordingly
- [ ] Select "Bulk" → surplus picker shows +250 / +500; live preview updates accordingly
- [ ] Select "Maintain" → adjustment resets to 0; live preview == TDEE

### Dashboard integration
- [ ] After saving profile → Dashboard calorie ring goal matches ProfileView displayed goal
- [ ] After clearing profile → Dashboard calorie ring reverts to **2000 kcal**
- [ ] Profile setup banner appears on Dashboard when no profile is set
- [ ] Tapping ✕ on banner dismisses it for the session (does not reappear until next launch)
- [ ] Dashboard macro bars (protein/carbs/fat) goals update to TDEE-derived values after profile save

### Edit flow
- [ ] Edit age → save → summary card shows updated age and recalculated TDEE
- [ ] Switch from Maintain → Cut −500 → save → daily goal decreases by ~500 kcal

### Macro goal accuracy

**Worked example 1 — Female, 30 yrs, 60 kg, 165 cm, Sedentary, Cut −500:**
- BMR = 10×60 + 6.25×165 − 5×30 − 161 = 1320.25 kcal
- TDEE = 1320.25 × 1.2 = 1584.3 kcal
- Raw goal = 1584.3 − 500 = 1084.3 → floored to **1200 kcal**
- Protein = 60 × 2.2 = **132 g** (528 kcal)
- Fat = 1200 × 0.25 / 9 = **33.3 g** (300 kcal)
- Carbs remaining = (1200 − 528 − 300) / 4 = 372 / 4 = **93 g**
- [ ] Verify: ProfileView summary shows protein ~132 g, fat ~33 g, carbs ~93 g
- [ ] Verify: Dashboard macro bars reflect same values

**Worked example 2 — Male, 25 yrs, 70 kg, 175 cm, Moderate, Maintain:**
- BMR = 10×70 + 6.25×175 − 5×25 + 5 = 1673.75 kcal
- TDEE = 1673.75 × 1.55 = 2594.3 → goal **2594 kcal**
- Protein = 70 × 1.6 = **112 g** (448 kcal)
- Fat = 2594 × 0.25 / 9 = **71.9 g** ≈ 72 g (647 kcal)
- Carbs = (2594 − 448 − 647) / 4 = 1499 / 4 = **374.8 g** ≈ 375 g
- [ ] Verify: ProfileView shows protein ~112 g, fat ~72 g, carbs ~375 g

**Clamp test — protein+fat exceed daily goal:**
- Use a profile where raw protein×4 + raw fat×9 > daily goal (e.g. female, very low TDEE on Cut −750, very high body weight)
- [ ] Verify: carbs shows 0, not negative
- [ ] Verify: protein+fat in grams are scaled down proportionally
- [ ] Verify: no crash or NaN displayed anywhere

### Manual macro override

- [ ] Toggle "Customize Macros" ON → protein/carbs/fat fields pre-fill with the calculated values (not 0 or blank)
- [ ] Modify protein to 160 g, carbs to 200 g, fat to 50 g → live kcal readout shows 160×4 + 200×4 + 50×9 = **1890 kcal**
- [ ] Tap Save → Dashboard protein/carbs/fat bars match the custom values (160/200/50 g)
- [ ] Profile summary card shows "✎" suffix and "Custom macros active" badge
- [ ] Toggle "Customize Macros" OFF → tap Save → Dashboard reverts to calculated values; badge disappears
- [ ] Force-quit and relaunch → custom override values survive (not reverted to calculated)
- [ ] Open Edit with an active override → protein/carbs/fat fields show the previously saved custom values, not the calculated ones
- [ ] Edit an existing override value (e.g. protein 160 → 180) → tap Save → Dashboard reflects the updated custom value

## Manual Weight Entry

### Scope / visibility
- [ ] "Enter exact weight instead?" link appears on the portion question for: dal_legume, meat_fish, vegetable, paneer_dairy, snack_street, sweet_dessert, condiment_side
- [ ] Link appears on rice's "How much rice is there?" question
- [ ] Link does NOT appear for bread (piece count) or beverage (volume-based)
- [ ] Link does NOT appear for a dish whose serving_size_g is NULL/0 in the DB (backend would ignore the weight)

### UI toggle behavior
- [ ] Tapping the link swaps bucket buttons for a numeric field + "Use This Weight" button
- [ ] "Choose a portion size instead" restores the bucket buttons and clears any entered weight
- [ ] Navigating Back to a question answered with manual weight re-shows the entry field pre-filled with the entered value
- [ ] Selecting a bucket after toggling back works normally (manual value fully discarded)

### Units
- [ ] Profile set to Metric → field shows "g"; Imperial → field shows "oz"
- [ ] Imperial entry converts correctly: enter 7 oz → backend receives ~198.4g (7 × 28.3495)
- [ ] Standard serving helper text shows correct per-dish value ("Standard serving: 150g"; in Imperial: "5.3 oz (150g)")
- [ ] No profile set → defaults to grams

### Validation
- [ ] Entry below 5g (e.g. 3) → red border + "Minimum is 5g" message, "Use This Weight" disabled
- [ ] Non-numeric / empty entry → "Use This Weight" disabled
- [ ] Entry over 5x standard serving (e.g. 800g for a 150g serving) → "Large portion" confirmation alert
- [ ] Alert Cancel → returns to editing with value intact; Confirm → proceeds to next question
- [ ] Backend rejects manual_weight_g < 5 with HTTP 400 "Manual weight must be at least 5 grams." (POST /dish/calculate directly)

### Calculation accuracy
- [ ] Worked example: dish with serving_size_g = 150 and protein 23.8g/serving → enter 300g → protein ≈ 47.7g (scale 2.0), all macros exactly 2x baseline (verified in code test 2026-07-03)
- [ ] Entered weight equal to standard serving → macros match bucket "standard" exactly
- [ ] adjustments_applied includes "manual_weight_<g>g_of_<serving>g_scale_<x>" entry

### Confidence band tightening
- [ ] Same dish, 1 skipped question: bucket path shows ±18%, manual weight path shows ±10% (verified in code test 2026-07-03)
- [ ] 2 skipped: bucket ±28% vs manual ±18%
- [ ] 0 skipped + manual weight: stays ±10% (never tighter than best tier)

### Precedence / compatibility
- [ ] Manual weight on a meat_fish dish overrides both portion_size and meat_amount buckets
- [ ] Requests without manual_weight_g (old bucket flow) behave exactly as before
- [ ] No-serving_size_g fallback: POST /dish/calculate for food_code=ASC042 (Paneer pea sandwich, toasted — serving_size_g is NULL) with manual_weight_g=200 → manual_weight_used=false in the response, adjustments_applied contains "manual_weight_ignored_no_serving_size_g" followed by a normal "portion_scale_*" entry, and the bucket portion scale is used instead (verified in code test 2026-07-05)

## Dietary Filters

### Known bug (fixed 2026-07-05): stale backend process served pre-fix code
Reported: searching "paneer kathi roll" (and other paneer dishes) with the Vegan filter
active returned paneer results even though every paneer dish in the DB is correctly
tagged `is_vegan=0`.

Root cause was **not** a plumbing defect in the current source — `resolve_dish_name()`
in aliases.py (exact/alias/fuzzy tiers) and `_to_result()` in main.py already applied
the diet-filter check identically across all three tiers. Verified directly:
- "paneer kathi roll" resolves via the **fuzzy tier** (no exact/alias match exists for
  that exact spelling — the real dish is "Paneer kaathi roll").
- "shahi paneer" resolves via the **exact tier**; "matar paneer" via the **alias tier**.
  Both were confirmed to filter correctly against the current source.
- Every paneer dish in indb.sqlite is `is_vegan=0` — confirmed directly from the DB,
  ruling out a data-tagging error.

The actual cause: a `uvicorn main:app` process (no `--reload`) had been running since
before the entire dietaryFilters feature was written and was never restarted, so it
kept serving stale in-memory code indefinitely while the source on disk was already
correct. Restarting the process fixed the live bug immediately with zero code changes.

**Fix applied:** restarted the backend process. **Regression coverage added:**
`test_dietary_filters_regression.py` (project root, run with `python3
test_dietary_filters_regression.py`) exercises all three tiers by dish *name* (not
food_code) with the Vegan filter active and asserts no paneer dish survives.
- [ ] If this bug ever resurfaces, check for a stale non-`--reload` backend process
  BEFORE assuming the filter logic regressed — this has already fooled one investigation
- [ ] Run `test_dietary_filters_regression.py` after any change to aliases.py, main.py's
  dietary filter logic, or the diet tagging columns — all checks must pass

### Tagging script output (phase_diet_tagging.py)
- [ ] Re-running the script is idempotent (columns already exist, counts unchanged)
- [ ] Summary distribution sanity: ~643 vegetarian, ~273 vegan, ~368 jain, ~625 no-onion-garlic, ~572 gluten-free, ~346 dairy-free of 950 tagged; 64 recipe-level dishes NULL across all six flags
- [ ] Spot-check known dishes in DB:
  - Paneer butter masala → is_vegetarian=1, is_vegan=0, is_dairy_free=0
  - Chicken curry → is_vegetarian=0, is_vegan=0, is_jain=0
  - Fish curry (Machli curry) → is_vegetarian=0 (fish is listed by species "Rohu"; caught by extended keyword list)
  - Idli → all six flags = 1
  - Aloo paratha → is_jain=0 (potato), is_gluten_free=0 (atta), is_vegetarian=1
  - Gulab Jamun with khoya → is_dairy_free=0 (khoa spelling caught), is_vegan=0
- [ ] Extended keyword false-positive checks: dish using coconut/almond milk NOT marked dairy; peanut butter NOT dairy; buckwheat NOT gluten; "Eggless cake" still is_vegetarian=1 (no egg ingredient)
- [ ] diet_tags_source = 'auto' for all 1014 rows (manual review workflow comes later)

### Backend filtering (GET /dish/search, /dish/browse)
- [ ] `/dish/search?q=chicken curry&dietaryFilters=vegetarian` → 0 results; same query unfiltered finds it (verified in code test 2026-07-03)
- [ ] AND semantics: `q=paneer butter masala&dietaryFilters=vegetarian` finds it; `dietaryFilters=vegetarian,vegan` excludes it (verified 2026-07-03)
- [ ] `/dish/browse?dietaryFilters=jain,gluten_free` → every returned dish has both flags = 1 (verified: 86 dishes, all checked)
- [ ] NULL flags never pass a filter: a dish with is_X NULL is excluded when filter X is requested (unknown ≠ compliant)
- [ ] Unknown filter name (e.g. `dietaryFilters=keto`) → HTTP 400 listing valid values
- [ ] No dietaryFilters param → search/browse behave exactly as before

### Profile dietary preferences (iOS)
- [ ] Profile form shows six toggles: Vegetarian, Vegan, Jain, No Onion/Garlic, Gluten-Free, Dairy-Free
- [ ] Select some → Save → summary grid "Diet" tile lists the chosen labels (or "None")
- [ ] Force-quit and relaunch → preferences persist
- [ ] IMPORTANT (migration): a profile saved BEFORE this feature still loads after update — not wiped back to setup prompt (custom decoder defaults missing dietaryPreferences to empty)
- [ ] Edit profile → previously chosen preferences pre-checked

### Search filter chips (iOS)
- [ ] Opening search with profile prefs set → matching chips pre-selected, results already filtered
- [ ] Toggling a chip re-runs both search results and browse tiles immediately
- [ ] Chip toggles are session-local: change chips in search, then open Profile → saved preferences unchanged
- [ ] Reopening search later → chips reset to profile preferences (not the previous session's toggles)
- [ ] No profile at all → no chips selected, unfiltered results
- [ ] Browse mode (empty query) respects active chips, not just typed searches

### Scan-flow conflict warning (iOS)
- [ ] With Vegan preference set: scan/select a paneer dish → results screen shows yellow banner "Contains animal products, which conflicts with your Vegan preference"
- [ ] With Vegetarian preference: chicken/fish dish → banner names the Vegetarian conflict
- [ ] Multiple conflicting preferences → one banner listing each conflict on its own line
- [ ] Dish with NULL diet flags + any active preference → banner says "Diet info unavailable for this dish" (never silently passes as compliant)
- [ ] Banner X dismisses it for that result screen only; logging still works before and after dismissal (never blocks)
- [ ] No preferences set → no banner ever, even for meat dishes
- [ ] Compliant dish (e.g. Idli with Vegetarian pref) → no banner
- [ ] Warning is computed when the dish is resolved (camera AND search selection paths both show it)

### Known limitations (documented, not bugs)
- [ ] Barcode products are NOT diet-checked (Open Food Facts flow untouched this phase)
- [ ] Jelly crystals/gum drops (possible gelatin), margarine (possible dairy), fresh ginger (strict Jain) left for manual review — tags may be optimistic for dishes containing them

## Search Quality — Fuzzy Match Threshold & Data Audit (fixed 2026-07-05)

### Bug: "Bhel puri" search returned a garbage fuzzy match
Reported: searching "Bhel puri" returned exactly one result, "Oatmeal Porridge," tagged
as a "fuzzy" match — an unrelated dish with no textual similarity to the query.

Root cause (two independent issues):
1. `aliases.py`'s fuzzy tier used `score_cutoff=60`, too loose for fuzzywuzzy's WRatio
   on short multi-word dish names. "Bhel puri" vs "Oatmeal Porridge" and vs "Poori"
   both scored exactly 60 — the current search pool's best (and only) matches, sitting
   right on the old cutoff.
2. The real "Bhel puri" dish IS in indb.sqlite (food_code OSR114) but has
   `is_recipe_level=1`, correctly excluding it from all three resolution tiers — this
   flag is a deliberate, consistently-applied "no per-serving nutrition computed"
   marker (confirmed: all 64 `is_recipe_level=1` rows have `energy_kcal_per_serving
   IS NULL`, and zero `is_recipe_level=0` rows do; see main.py's own error message at
   the single-dish lookup endpoint). It was **not** mistagged relative to its peers —
   this is expected/by-design behavior, not a bug. It also had two hygiene issues
   fixed regardless: a trailing space in `food_name` and `food_category='bread'`
   (corrected to `snack_street`, matching sibling dishes `Khakhra chaat` / `Spicy corn
   chaat`, which share the same recipe-level flag).

Full-DB audit performed before fixing:
- 46 of 950 dishes had leading/trailing whitespace in `food_name` — all trimmed.
- All 64 `is_recipe_level=1` dishes checked individually; confirmed correct via the
  NULL-kcal correlation — none required flipping.
- Keyword sweep for category mismatches (chaat/snack, dessert, dal, meat terms)
  found one clear hit (Bhel puri, above). ~20 `kheer` (milk-based dessert) dishes are
  categorized `paneer_dairy` instead of `sweet_dessert` — flagged as a possible
  separate categorization question, intentionally NOT changed (looks like a scheme
  choice, not an unambiguous bug; out of scope for this fix).

Fixes applied:
- [x] `dishes.food_name`: trimmed whitespace on all 46 affected rows
- [x] `Bhel puri` (OSR114): `food_category` corrected from `bread` to `snack_street`
- [x] `aliases.py`: `FUZZY_SCORE_CUTOFF` raised from 60 to 70 — validated against real
  typo/alt-spelling cases via the alias table and manual test queries (e.g. "samber"
  → Sambar 83, "gulab jamon" → Gulab Jamun 86, "masala dsoa" → Masala dosa 91, "idly"
  → Idli 75, the lowest legitimate case found). Safe window was empirically 61–75;
  70 was chosen with margin on both sides.
- [x] `aliases.py`: `resolve_dish_name()` hardcoded fuzzy `limit=3` replaced with a
  `limit` parameter, threaded through from `main.py`'s `/dish/search?limit=` query
  param (both the primary and category-fallback fuzzy call sites)
- [x] `main.py`: zero-results `suggestion` message no longer says "Showing closest
  results" when there are no results — now "No close match found. Try a different
  search term." (separate from the "found weak fuzzy matches" message)

Decision, not a bug: searching "Bhel puri" (and any other `is_recipe_level=1` dish by
its exact/common name) now correctly returns **zero results** rather than a garbage
match, since the dish has no per-serving nutrition data to show. This was a deliberate
call — recipe-level dishes are not surfaced in search at all, in any form.

### Regression checks
- [ ] `/dish/search?q=Bhel puri` → `{"results": [], "total": 0, "low_confidence": true, "suggestion": "No close match found. Try a different search term."}`
- [ ] `/dish/search?q=samber` (typo) → still returns Sambar (score 83) and Sambar powder (score 75) as fuzzy matches — cutoff raise did not break legitimate typo matching
- [ ] `/dish/search?q=Sambar` (correct spelling) → exact match, score 100
- [ ] `/dish/search?q=idly` (alt spelling) → still returns Idli (score 75) — the tightest legitimate case in the validated cutoff window
- [ ] `/dish/search?q=<anything>&limit=15` with a query that has >3 real fuzzy candidates → confirm more than 3 fuzzy results can now be returned (hardcoded limit=3 no longer caps below the caller's requested limit)
- [ ] Full whitespace re-scan: `SELECT COUNT(*) FROM dishes WHERE food_name != TRIM(food_name)` → 0
- [ ] `Bhel puri` row: `food_category = 'snack_street'`, `food_name` has no trailing space
- [ ] iOS SearchView: searching "Bhel puri" shows the "No dishes found" empty state (fork/knife icon), not a stray unrelated result

## Fasting Mode — Navratri & Ekadashi (added 2026-07-06)

Scope: Navratri and Ekadashi only. Ramzan is out of scope (time-window based, not
food-composition based — separate design work later).

### ⚠️ MANUAL SIGN-OFF REQUIRED — ambiguous dish review list
`phase_fasting_tagging.py`'s keyword pass left **37 dishes NULL** rather than
guessing (27 with no restricted/permitted keyword signal at all, plus 10 more added
2026-07-06 after a correction — see below). These are excluded from fasting-filtered
results until manually adjudicated. **This item is not to be marked verified by
Claude — needs Ahilan's manual sign-off.**
- [ ] Review and adjudicate (permitted / restricted / leave as unknown) each of:
  Apple oats chia seed smoothie OSR007 · Baked vegetables ASC208 · Bengal 5 Spice
  Blend (Panch Phoran) OSR082 · Brinjal pickle (Baingan ka achaar) BFP597 · Broccoli
  delight BFP279 · Cabbage and peas (Pattagobhi aur matar) ASC173 · Canjee BFP029 ·
  Carrot and fenugreek leaves (Gajar methi) ASC174 · Carrot murabba (Gajar ka
  murabba) ASC504 · Cauliflower canjee (Phoolgobhi ki canjee) BFP030 · Chat masala
  BFP002 · Cucumber sharbat (Kheere ka sharbat) OSR006 · Finger millet biscuit (Ragi
  biscuit) OSR031 · Fruit salad (Phalon ka salaad) ASC265 · Garam masala BFP001 ·
  Ginger candy (Adrak ki candy) ASC506 · Green chilli sauce BFP163 · Green tomato
  pickle (Haray tamatar ka achaar) OSR057 · Hot cherry sauce BFP360 · Jam filling
  BFP480 · Jhatpat achar with carrot (Jhatpat achaar gajar ke saath) BFP599 · Kulfi
  ASC321 · Lotus stem pickle (Kamal kakdi ka achar) OSR050 · Makki ki roti ASC150 ·
  Masala arbi BFP264 · Oatmeal Porridge ASC050 · Oats burfi OSR019 · Pasta cheese
  sauce ASC132 · Pav bhaji masala OSR097 · Pickled cabbage OSR058 · Pickled mustard
  greens OSR055 · Saunth/Sonth chutney with tamarind/imli ASC281 · Sesame ladoo (Til
  ke ladoo) ASC344 · Stuffed bittergourd (dry) (Bharwa karela) BFP604 · Stuffed
  brinjal (Bharwa baingan) ASC187 · Stuffed okra (Bharwa bhindi) ASC184 · Tomato
  puree ASC515

### Correction applied 2026-07-06, before commit (caught in review, not silently left)
The first pass tagged 10 of the dishes above as **permitted=1** on the strength of
an incidental dairy/fruit/nut ingredient (e.g. ghee), without the dish's actual
starch (millet/corn/oats/ragi) ever being evaluated against the permitted list —
since corn/oats/ragi were never on the permitted-starch list (only kuttu, singhara,
rajgira, sabudana are), a permitted=1 tag resting entirely on a side ingredient is a
likely-incorrect tag, not a defensible judgment call. Root cause: the tagging logic
only checked "is there a permitted signal AND no restricted signal," which doesn't
verify the *grain itself* was the source of that signal.
- [x] Added `GRAIN_NO_SIGNAL_KEYWORDS` check to `phase_fasting_tagging.py`: any
  dish containing jowar/bajra/ragi/maize/corn/oat/quinoa/barley now gets its
  provisional `permitted=1` downgraded to `NULL` instead, same as any other
  unresolved case. Baked into the reusable script, not a one-off DB patch — a
  from-scratch rerun reproduces this correctly.
- [x] Re-ran full script against a fresh restore of the pre-tagging DB backup;
  confirmed via direct SQL: all 10 affected dishes (Apple oats chia seed smoothie,
  Baked vegetables, Finger millet biscuit, Fruit salad, Hot cherry sauce, Kulfi,
  Makki ki roti, Oatmeal Porridge, Oats burfi, Pasta cheese sauce) now read
  `navratri_permitted = NULL, ekadashi_permitted = NULL`; prior fixes (Amaranth
  ladoo, Gooseberry marmalade still = 1; Carrot murabba still correctly NULL) did
  not regress.
- [x] Counts after correction: `navratri_permitted` / `ekadashi_permitted` — 166
  permitted(1), 747 restricted(0), 101 NULL each (was 176/747/91 before the fix).

### Known limitations (documented, not bugs)
- [ ] "Salt" is generic in this DB (no distinct sendha namak/rock salt vs. iodized
  table salt ingredient token) — deliberately not used as a keyword at all, since it
  would blanket-restrict nearly every dish. Not fixable without better source data.
- [ ] Root vegetables besides potato/sweet potato (beetroot, radish, carrot, turnip,
  colocasia/arbi, yam) and generic non-root vegetables (spinach, cauliflower, bottle
  gourd, etc.) are genuinely disputed by region/tradition and intentionally NOT
  tagged either direction — a dish whose only signal is one of these lands in the
  37-item review list above, not silently resolved.
- [ ] Millets/oats/corn/quinoa/barley are treated as no-signal (neither permitted
  nor restricted — spec only named wheat/rice explicitly) — as of the 2026-07-06
  correction above, a dish containing one of these can no longer resolve to
  permitted=1 via an unrelated ingredient; it now correctly lands in the review
  list instead.
- [ ] Ekadashi non-veg/alcohol restriction was extended by assumption — the spec's
  Ekadashi-restricted bullet list only explicitly named grains/lentils/onion/garlic;
  non-veg/alcohol restriction was added on the reasoning that an Ekadashi fast
  wouldn't permit either. Flag if this doesn't match actual practice.
- [ ] The two flag columns (`navratri_permitted`, `ekadashi_permitted`) are
  numerically identical for every dish in the current DB (166 permitted / 747
  restricted / 101 NULL each) — not a bug, just a fact about this ingredient data:
  the Navratri-only extras (kuttu/buckwheat, singhara, rajgira/amaranth, sendha
  namak) either don't appear as a dish's sole distinguishing ingredient, or the dish
  also independently qualifies under Ekadashi's shared fruit/dairy/nut/potato/sabudana
  list. Could diverge with future data.

### Data tagging bugs found and fixed before verification (see phase_fasting_tagging.py)
- Root cause: "buckwheat" contains "wheat" as a substring, so every kuttu/buckwheat
  dish was self-triggering the wheat-grain restriction — exactly the dishes this
  column exists to mark permitted. Fixed by blanking "buckwheat" out of the
  restricted-keyword pass only (permitted-keyword pass still sees it intact).
- Root cause: Latin binomial names in ingredient strings caused false substring
  matches — "Prunus amygdalus" (almond) contains "dal", "Saccharum officinarum"
  (jaggery/cane sugar) contains "rum". Fixed by stripping parenthetical content
  before keyword matching.
- Root cause: "ham"/"rum" as plain substrings matched "Banana...montham" and
  "Drumstick". Fixed with word-boundary regex for these two keywords specifically.
- Root cause: "orange"/"cherry" fruit keywords matched "Carrot, orange" (color
  descriptor), "Pumpkin, orange, round", and "Tomatoes, cherry" (variety name, not
  the fruit). Fixed with targeted exception phrases.
- Gap found: "Amla" (Indian gooseberry) wasn't caught by the "gooseberr" keyword
  since the DB uses the Hindi name as its own ingredient token — added "amla" as a
  fruit keyword.
- [x] Re-ran full false-positive audit against all 391 distinct ingredient names in
  the DB after each fix — verified via direct SQL (see conversation record 2026-07-06)

### Backend filtering (GET /dish/search, /dish/browse) — verified live 2026-07-06
- [x] `/dish/search?q=idli&fastingMode=ramzan` → HTTP 400, `"Unknown fasting mode
  'ramzan'. Valid values: ekadashi, navratri"`
- [x] `/dish/search?q=aloo paratha&fastingMode=navratri` → 0 results (wheat);
  unfiltered control for the same query still finds a match
- [x] AND logic: `/dish/search?q=amaranth ladoo&fastingMode=navratri` → 1 result;
  adding `&dietaryFilters=vegan` → 0 results (ghee in the dish correctly excludes it
  once vegan is ANDed in)
- [x] AND logic on browse: `/dish/browse?fastingMode=navratri` → 66 dishes;
  `&dietaryFilters=jain` → 60 dishes
- [x] NULL fasting flags never pass a filter (same semantics as existing dietary
  filter columns — reuses `_passes_dietary_filters`/`diet_clause`, not a parallel
  filtering path)

### iOS UI — verified in Simulator (iPhone 17, iOS 26.5) 2026-07-06
- [x] Fasting Mode card in Profile tab is visible even with no profile set up
  (independent of UserProfile/ProfileStore — own UserDefaults key via
  FastingModeStore)
- [x] Three-state segmented picker: None / Navratri / Ekadashi, all three selectable
- [x] Persistence: selected Navratri → force-terminated app (not just backgrounded)
  → relaunched → Navratri still selected
- [x] Search view shows a read-only "Fasting: Navratri" pill (orange when active,
  grey "Fasting Mode" when None) separate from the existing Filters pill/sheet — no
  seventh toggle was added to DietaryFiltersSheet
- [x] Tapping the Fasting pill in Search dismisses the scan flow and jumps to the
  Profile tab (confirmed via screenshot before/after)
- [x] Search/browse results live-update when Fasting Mode changes, and reflect
  whatever the store currently holds on every fresh Search view open (confirmed via
  backend request log: reopening Search after switching Profile to Ekadashi sent
  `fastingMode=ekadashi` with no other action needed)
- [x] AND logic in UI: toggled Vegan in Filters sheet while Navratri active →
  browse results changed (dairy-containing "Cold coffee with cream" and "Makki ki
  roti" dropped out; confirmed via screenshot + Filters pill showing "(1)" alongside
  "Fasting: Navratri")
- [x] Conflict banner: selected "Masala dosa" (Favorite, not backend-filtered,
  rice-based → navratri_permitted=0) with Navratri active → results screen showed
  "⚠ Not permitted during Navratri fasting" banner
- [x] Banner is dismissible (X button) and non-blocking — "Add to Lunch" still
  available before and after dismissal
- [x] NULL-flag banner: favorited "Makki ki roti" (confirmed NULL for both fasts
  after the grain-contamination correction above) while Fasting Mode = None,
  switched to Navratri, selected it from Favorites → results screen showed
  "⚠ Fasting info unavailable for this dish", dismissible, non-blocking (verified
  2026-07-06 after restarting the backend against the corrected DB)
- [ ] NOT yet tested: real-device behavior (only verified in Simulator this session)

### Assumptions made this session (flagging per CLAUDE.md review workflow)
- Fasting Mode entry point placement: picker lives in Profile (source of truth),
  read-only indicator pill in Search jumps to Profile to change it — this was a
  design choice presented to and confirmed by Ahilan before implementation, not
  something inferred silently.
- Backend: `fastingMode` is a separate query param (not folded into
  `dietaryFilters`'s comma list) that gets merged into the same flag-column list
  server-side before filtering — reuses all existing AND-filtering plumbing.
- `FastingModeStore.swift` was added to the Xcode target programmatically (via the
  `xcodeproj` Ruby gem, installed this session for this purpose) rather than left
  for manual Xcode-GUI addition, so the project would build for Simulator
  verification. Mirrors exactly where `ProfileStore.swift` sits in the project
  structure (Services group).
  - [x] Verified 2026-07-06: opened the actual `.xcodeproj` in Xcode itself (not
    just read the diff) — no repair/recovery prompt on open, no red or missing
    file references anywhere in the navigator, no duplicate entries, no
    "Recovered References" group. File Inspector on FastingModeStore.swift shows
    correct full path and "IndianFoodApp" checked under Target Membership.
    Triggered Product → Build from the Xcode UI directly (not the CLI) →
    succeeded. `git diff` on `project.pbxproj` shows only the expected addition
    (file ref + build file + Services group membership) plus incidental
    alphabetical resorting of two pre-existing entries and removal of an empty
    `packageProductDependencies = ();` line — both harmless side effects of the
    gem rewriting the file, not scope creep.

## Portion Accuracy — Katori portions, piece-count portions, oil/ghee add-on

Backend: `portion_eligibility.py` (new), `calculator.py`, `main.py`. iOS: `DishModels.swift`, `QuestionEngine.swift`, `QuestionView.swift` (all existing files, no new Swift files — nothing to add to the Xcode target this phase). Regression script: `test_portion_accuracy_regression.py` (same in-process `TestClient` pattern as `test_dietary_filters_regression.py`).

### Design note: serving_size_g fallback (read before touching this code again)
`serving_size_g` is NULL for the large majority of dishes in every category this phase touches (0% populated for bread/snack_street, ~10-15% for dal_legume/rice/vegetable/paneer_dairy). It is exactly reproducible as `energy_kcal_per_serving / energy_kcal_per_100g * 100` — verified against every row where the raw column IS populated, matches exactly. Katori and piece-count math use this derived value (`portion_eligibility.derive_serving_grams`). This is a **deliberate divergence** from manual-weight-entry, which still only appears when the raw `serving_size_g` column is populated (unchanged — see `QuestionView.swift manualWeightAvailable` and the existing regression case for food_code ASC042 in the Manual Weight Entry section above). Do not "fix" manual weight to use the derived value without a separate discussion — that wasn't in scope here and changes previously-verified behavior.

### Backend — verified via `test_portion_accuracy_regression.py` (all checks passing) and live `curl` against `uvicorn main:app --reload` 2026-07-06
- [x] Katori math uses derived serving grams when the raw column is NULL
- [x] Katori scale is linear in count (1.5 katori = 1.5x the 1-katori kcal)
- [x] Vegetable katori gram baseline switches on the `gravy_type` answer already collected by the existing Q&A (dry → 150g, anything else → 200g) — no new per-dish tagging needed for this split
- [x] Piece-count scale is linear in count (per-serving data IS the per-piece basis for eligible dishes)
- [x] Oil/ghee add-on is a pure additive: +40 kcal/tsp on top of the already-scaled base, implemented as +4.44g fat per tsp (consistent with how existing `FLAT_ADDITIONS` like `butter_standard` represent kcal as fat grams, so `kcal_estimate` stays internally consistent = 9F+4P+4C after the addition)
- [x] 0 tsp (skip/default) leaves kcal unchanged
- [x] `katori_count <= 0`, `piece_count <= 0`, negative `oil_ghee_tsp` all rejected with HTTP 400 (same pattern as the existing `manual_weight_g < 5` check)
- [x] `manual_weight_g` still takes precedence over `katori_count`/`piece_count` when more than one is supplied in the same request
- [x] `/dish/{food_code}` now returns `katori_eligible`, `piece_count_eligible`, `oil_ghee_eligible` booleans, computed per-request from `portion_eligibility.py` (not stored in the DB)

### Worked examples (hand-calculated, matches both the regression script and live simulator output)
- **Katori — Dal makhani (OSR139), dal_legume:** no raw `serving_size_g`. Derived serving grams = 261.626 / 74.040 × 100 = **353.4g**. 1 katori = 150g (dal_legume baseline) → scale = 150 / 353.4 = **0.4245**. Base per-serving kcal recomputes to 109.0 kcal (9×4.6 fat + 4×5.0 protein + 4×11.9 carb — engine always recomputes from scaled macros, not the raw DB kcal field). 1.5 katori → scale 0.6367 → **163.5 kcal**, exactly 1.5× the 1-katori result. Confirmed live in Simulator: `katori_1.5_x_150g_of_353.4g_scale_0.637`.
- **Katori dry/curry split — Potato cauliflower/Aloo gobhi (ASC171), vegetable:** derived serving grams = 175.7g. 1 katori, gravy_type=dry → 150g baseline → scale 0.853 → kcal lower than gravy_type=thick → 200g baseline → scale 1.138. Confirmed: dry variant kcal < curry variant kcal for the identical dish and katori count.
- **Piece-count — Chapati/Roti (ASC096), bread:** per-serving = 72.83 kcal ≈ 1 chapati (matches a realistic single-piece weight, unlike the poori family below). 3 pieces → scale 3.0 → kcal recomputes to 3× the 1-piece result (214 kcal live in Simulator for 3 pieces, home-cooked, no stuffing).
- **Piece-count — Sesame ladoo/Til ke ladoo (ASC344), sweet_dessert:** per-serving = 27.5g, a plausible single-ladoo weight. 2 pieces → scale 2.0 → 216.5 kcal, exactly 2× the 1-piece 108.25 kcal.
- **Oil/ghee additive — Potato cauliflower (ASC171), 1 katori (curry, thick gravy):** base = 272.4 kcal, 23.3g fat. +1 tsp oil/ghee → **312.4 kcal, 27.7g fat** — an increase of exactly 40.0 kcal and 4.4g fat (40/9), confirmed both via `curl` and live in Simulator (`oil_ghee_1.0tsp_+40kcal`).

### iOS UI — verified live in Simulator (iPhone 17, iOS 26.5) 2026-07-06
- [x] Backend confirmed running/reachable ("Backend connected" shown on Log tab) before testing
- [x] Dal makhani (dal_legume, katori-eligible, no raw serving_size_g so no manual-weight link): "Enter katori count instead?" link appears below the existing Small/Standard/Large/Very large bucket options — bucket options still fully present and selectable, not replaced
- [x] Katori stepper: defaults to "1 katori", +/- steps by 0.5, correct singular/plural text ("1 katori" vs "1.5 katoris"), "1 katori ≈ a small bowl" hint, "Use This Amount" commits and advances, "Choose a portion size instead" reverts to buckets
- [x] Confirmed end-to-end: 1.5 katori + 2 tsp oil/ghee on Dal makhani → Results screen shows 243 kcal, "Adjustments applied" expands to show `katori_1.5_x_150g_of_353.4g_scale_0.637` and `oil_ghee_2.0tsp_+80kcal` — matches the hand-calculated worked example above (163.5 + 80 = 243.5, displayed rounded)
- [x] Chapati/Roti (bread, piece-count eligible): existing "1 piece / 2 pieces / 3 pieces / 4+ pieces" bucket question unchanged, "Enter piece count instead?" link appears alongside it (same coexistence pattern as katori)
- [x] Piece-count stepper: defaults to "1 piece", +/- steps by 1, correct singular/plural ("1 piece" vs "3 pieces"), "Use This Count" commits and advances
- [x] Confirmed end-to-end: 3 pieces on Chapati/Roti (home cooked, plain) → Results screen shows 214 kcal
- [x] Poori (bread, flagged multi-piece suspect — see ambiguous list below): "How many pieces?" bucket question appears with NO "Enter piece count instead?" link — confirms the exclusion list is wired correctly, not just present in code
- [x] Paneer cutlet (paneer_dairy, solid — NOT katori-eligible): portion question shows only the standard bucket options, no katori link and no manual-weight link — confirms the gravy/solid paneer split excludes solid items
- [x] Paneer cutlet still shows "Add extra oil or ghee?" as the last (5th) question — confirms oil/ghee eligibility is category-wide (dal_legume/vegetable/meat_fish/paneer_dairy), not gated by the same gravy/solid split as katori
- [x] Oil/ghee stepper: defaults to "0 tsp" with "Add" button disabled/greyed out, +/- steps by 0.5, "≈ 40 kcal per tsp of oil or ghee" hint, "Add" enables once > 0 and commits+advances; the existing "Skip" button (question is required:false) leaves it at 0/unanswered
- [ ] NOT yet tested: real-device behavior (only verified in Simulator this session, batched with the other pending device tests)

### Assumptions made this session (flagging per CLAUDE.md review workflow — none of these were explicitly specified in the original prompt)
- **Confidence band is NOT tightened for katori or piece-count** (unlike manual weight, which tightens one confidence tier). Rationale: katori-count and piece-count are still estimates multiplied by another estimate (the category gram baseline, or the assumption that per-serving = 1 piece), not an exact measurement the way a typed gram value is. This is a judgment call, not specified in the brief — worth a gut check.
- **Rice katori baseline uses 165g** (the numeric midpoint of the given "150-180g" range), rather than a range or a second dry/wet split like vegetable. Rice wasn't described as needing a dry/curry distinction in the brief, so a single value was used.
- **Manual-weight-entry's existing NULL-gated behavior was deliberately left untouched** rather than also benefiting from the derived-serving-grams fallback used for katori. This means manual weight remains non-functional for most dishes in these categories even though a derived value is now computed elsewhere in the same request — an inconsistency between two "exact quantity" input methods that exists after this phase. Flagging in case that inconsistency should be resolved later (out of scope for this session, changes previously-verified behavior).
- **paneer_dairy raita/kheer/curd-based dishes were excluded from katori entirely**, not force-classified as gravy or solid. The spec's illustrative example ("paneer curry, not plain paneer cubes") doesn't map cleanly onto raita (yogurt+veg) or kheer (milk pudding) — these are structurally different dishes that happen to share the paneer_dairy category and "bowl" serving_unit. A case could be made that raita/kheer should also get katori (they are bowl-served), but that wasn't a confident call to make unilaterally — see the ambiguous list below.

### Dishes flagged for manual review — awaiting Ahilan's sign-off (same treatment as the Fasting Mode ambiguous list; NOT silently resolved)

**Reconciliation note (2026-07-06):** the counts below were re-verified directly against the live DB with explicit SQL queries (NULL-safe — `serving_unit IS NULL` rows were being silently dropped from both sides of an earlier ad-hoc count, which is why an earlier draft of this section had the paneer_dairy sub-categories summing to 55 instead of 60, and the roadmap said "~112" total instead of the correct 116). Every number below is `eligible + excluded == total` for its category, verified by query, not recalled from memory.

**Katori — excluded, category-to-portion-method mapping doesn't cleanly fit "a bowl of X" (116 of 227 across the 4 katori categories):**
- dal_legume (22 of 56, 34 eligible): blank/no serving_unit (8), `plate` (4: Sprouted moong dal chat, Sprouted moong daliya, Sprouted moong poha, Namkeen daliya — dry chaat/snack mixtures, not liquid dal, despite the category), `burfi` (1), `cheela` (1), `piece` (4), `triangle` (1, a sandwich), `vada` (3). 8+4+1+1+4+1+3 = 22.
- rice (9 of 42, 33 eligible): blank/no serving_unit (6), `cheela` (1), `piece` (1, Rice murukku — a fried snack), `puttu` (1). 6+1+1+1 = 9.
- vegetable (25 of 60, 35 eligible): blank/no serving_unit (9: pickles/chutneys/jams/squash), `bonda` (1), `kachori` (1), `kofta` (1), `samosa` (1), `brinjal` (1), `tomato` (1, whole stuffed-vegetable pieces), `roll` (1), `piece` (1, a burfi), `thepla` (1, bread-like), `toasted triangle` (1), `triangle` (2, sandwiches), `tablespoon` (2, chutneys), `glass` (1), `jar` (1). 9+1+1+1+1+1+1+1+1+1+1+2+2+1+1 = 25.
- paneer_dairy (60 of 69, 9 eligible): raita (21: Banana, Bathua, Bottle gourd, Cabbage, Carrot and spinach, Carrot, Cucumber, Grapes, Green chilli, Guava, Mango, Mint, Onion, Peanut, Pineapple, Pomegranate, Potato, Pumpkin, Spinach, Sweet, Tomato onion), kheer/payasam (12: Apple kheer, Apple sago payasam, Bottle gourd kheer, Cabbage kheer, Carrot kheer, Cauliflower kheer, Coconut kheer, Makhana kheer, Paneer kheer, Pumpkin kheer, Semolina kheer, Vermicelli kheer), curd-based sides/dips/salads (10: Curd dip, Curd dressing, Curd mint dip, Curd vegetable dip, Curd with potatoes, Lemon curd filling, Cucumber and yogurt salad, Mixed vegetable salad with curd sauce, Poha with curd, Potato with curd), solid/piece paneer (10: Paneer and pea samosa, Paneer cutlet, Paneer kaathi roll, Paneer patties, Paneer pea sandwich (toasted), Paneer shaslik/tikka, Paneer stuffed cheela/chilla, Rasmalai, Spaghetti with paneer balls and tomato sauce, Spinach and paneer souffle), soups (2: Cold cucumber soup, Paneer soup), **and 5 more that don't fit any of the above buckets** — Chenna murki (crumbled Bengali sweet), Cucumber sandwich, Tomato and cucumber sandwich (plain sandwiches, no paneer/curd), Dahi vadas/Dahi bhalla (fried lentil dumplings in yogurt — curd-adjacent but distinct from the dip/dressing set), Paneer/apple/pineapple salad (fruit salad, no curd sauce). 21+12+10+10+2+5 = 60.
- **Katori exclusion total: 22 + 9 + 25 + 60 = 116.**

**Katori — included but worth a gut-check** (derived serving grams > 500g, i.e. a "1 katori" selection computes to a noticeably small fraction of the DB serving — mathematically consistent, just flagging the scale of the gap): rice `Mutton pulao` (663g), `Chicken pulao` (668g), `Mexican rice` (518g), `Plain khichdi` (574g); vegetable `Green pea soup` (556g), `Spinach soup` (503g). Checked the low end too (negative, zero, or < 20g derived grams) across all 7 categories in this phase, including bread — no negative/zero/NULL cases exist anywhere. Only 4 dishes fall under 20g, none of them eligible-set members that would need re-deriving: `Sweet and salty biscuit` (10.7g) and `Sweet plain biscuit` (14.3g) are legitimately tiny single biscuits (already counted correctly in the sweet_dessert piece-count eligible set below, not a red flag), and `Tomato ginger chutney` (16.4g) / `Mint tomato chutney` (18.9g) are vegetable-category chutneys already excluded from katori by the serving_unit rule (`tablespoon`, not a bowl unit) regardless of their gram value.

**Piece-count — excluded, implied per-serving weight (energy_kcal_per_serving / energy_kcal_per_100g × 100) is 2-4x a realistic single piece, suggesting the DB "serving" already bundles multiple pieces (49 of 97 across the 3 piece-count categories):**
- bread (12 of 44, 32 eligible): the entire `poori` family — Bathua poori, Beetroot poori, Dal stuffed poori, Gram flour poori, Methi poori, Peas poori, Poori (plain), Potato stuffed poori, Spinach poori, Sweet poori (implied 75-155g vs. a realistic ~30-50g single poori) — and both `appam` entries — Appam, Banana appam (implied 153g/290g vs. a realistic ~40-70g single appam). 10+2 = 12.
- snack_street (10 of 12, 2 eligible): 6 flagged as likely-multi-piece — Sago cutlet/vadas, Khasta kachori, Masala onion pakora, Masala green chilli pakora, Soyabean tikki, Semolina carrot vada (all implied 70-211g vs. realistic 15-60g single pieces for these fried snacks) — plus 4 more that are structurally bowl/plate desserts-or-namkeen, not discrete pieces at all, so not really "ambiguous," just excluded by category fit — Vermicelli porridge, Vermicelli upma, Sev, Papdi. 6+4 = 10.
- sweet_dessert (27 of 41, 14 eligible): 5 flagged as likely-multi-piece or mislabeled — Sweet potato biscuit (151g vs ~10-15g for a biscuit), Gulab Jamun with khoya (157g) and Gulab jamun with milk powder (302g) (vs ~40-50g for a real gulab jamun), Lotus seed halwa and Gram flour halwa (both filed under serving_unit `piece` at 149-363g, but halwa isn't a discrete item at all — likely a serving_unit data-entry inconsistency, not a real "piece") — plus 22 more that are structurally bowl/glass/jar/large-slice/plate/small-plate/triangle desserts (puddings, halwas, kheer-adjacent items, one mis-filed pickle) or scoops, not discrete pieces, so excluded by category fit rather than flagged as uncertain. 5+22 = 27.
- **Piece-count exclusion total: 12 + 10 + 27 = 49.**

**Grand total flagged/excluded across both portion methods: 116 + 49 = 165** (out of 56+42+60+69+44+12+41 = 324 dishes across the 7 categories this phase touches).
