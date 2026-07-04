
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
