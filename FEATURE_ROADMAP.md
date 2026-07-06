# Indian Food Calorie Counter — Feature Roadmap

Living document. Check items off as they're designed, implemented, and verified (not just implemented). Follows the same review-workflow standard as CLAUDE.md: don't check something off on the basis of an asserted "done," check it off once root cause / verification is actually established.

---

## Completed & Verified

- [x] Backend (FastAPI, multiplier engine, all endpoints)
- [x] SQLite DB (950 available dishes, 1,014 total rows including 64 recipe-level entries), 3-tier name resolution (exact/alias/fuzzy)
- [x] EfficientNet-B0 classifier, Core ML export
- [x] SwiftUI app core (camera, Q&A flow, results, SwiftData meal logging)
- [x] Apple Health integration (Phase 6a) — verified on simulator, real-device writes still pending device-testing session
- [x] Barcode scanner + Open Food Facts — implemented, not yet tested on real device
- [x] Category-specific Q&A engine (Phase 5d, 11 categories)
- [x] Profile tab + TDEE goals (Phase 5c) — evidence-based macro splits, manual override
- [x] Manual weight entry — alternative to bucket-based portions for 7 categories + rice
- [x] Dietary filters — Vegetarian, Vegan, Jain, No Onion/Garlic, Gluten-Free, Dairy-Free
- [x] Search quality fix — whitespace, fuzzy cutoff, limit bug
- [x] Search Page Rework — recent searches, favorites, filter consolidation, debounce/cancellation, visual redesign
- [x] Fasting Mode (Navratri + Ekadashi) — commit `9bd20e9`. DB tagging (`navratri_permitted`/`ekadashi_permitted`), backend `fastingMode` param on `/dish/search` and `/dish/browse` (AND-logic with dietary filters), separate "Fasting Mode" entry point in Profile (not folded into Filters sheet), read-only pill in Search, non-blocking conflict banner, NULL-flag "info unavailable" banner. Verified live in simulator: persistence across relaunch, AND-combination, banner behavior, all three picker states. Backend and Xcode-build verified directly, not just by CLI/self-report. Not fully closed, see below.
- [x] Portion Accuracy — katori portions (dal_legume/rice/vegetable/gravy-paneer), piece-count portions (bread/snack_street/sweet_dessert), optional oil/ghee add-on (dal_legume/vegetable/meat_fish/paneer_dairy). New `portion_eligibility.py` module computes per-dish eligibility server-side (no DB schema change); katori/piece-count math falls back to a derived serving-weight when the raw `serving_size_g` column is NULL (it is, for ~85-100% of dishes in these categories) — see testchecklist.md "Portion Accuracy" for the full rationale. All three portion methods (bucket/manual-weight/katori-or-piece) coexist as user choices, same pattern as manual weight entry. Verified live in Simulator: katori stepper, piece-count stepper, oil/ghee stepper, and the eligibility-gated exclusions (Poori has no piece-count link, Paneer cutlet has no katori link but still gets the oil/ghee question). Backend verified via `test_portion_accuracy_regression.py` (all checks passing) plus live `curl`. Not fully closed, see below.

## Already Scoped in Roadmap (context, not yet built)

- [ ] Higher accuracy ML model (Phase 8, target 85%+ accuracy)
- [ ] Data collection — log user corrections as labeled training data (Phase 7)
- [ ] Subscription model (Phase 9, $4.99/mo premium)

## Open Question — Needs a Decision Before Next Related Work

- [ ] **"Fuzzy" tag visibility conflict.** Original brainstorm said "make fuzzy tag go away." The Search Page Rework just shipped a fuzzy/alias match badge on result cards as part of the visual redesign. These directly contradict. Resolve intent: is the goal to hide the fact that a match isn't exact, or just to stop showing internal-sounding terminology like "Fuzzy" to end users (e.g. relabel as "Similar match" instead of removing the signal)? Decide before touching search result UI again.

## Fasting Mode — Still Open, Not Silently Resolved

- [ ] **37-dish ambiguous review list awaiting manual sign-off** (in testchecklist.md). These are dishes where keyword tagging found no clear permitted or restricted signal for Navratri/Ekadashi (mostly spice blends, pickles/chutneys with no fruit/dairy/grain/legume signal, and vegetable-only dishes using produce not called out either way in the original spec). Currently left NULL, correctly excluded from fasting-filtered results until reviewed. This is a religious-observance judgment call, not an engineering one — ideally reviewed against actual regional/family tradition, not resolved from general knowledge.
- [ ] **Ekadashi non-veg/alcohol restriction** was extended by Claude Code beyond what was explicitly specified (spec only named grains/lentils/onion/garlic). Errs toward more restrictive, low risk, but worth a quick gut check against your own expectations.
- [ ] Real-device testing for Fasting Mode UI — simulator only so far, batch with the other pending device tests below.

## Portion Accuracy — Still Open, Not Silently Resolved

- [ ] **165 dishes excluded/flagged for manual review** — 116 across the 4 katori categories (dal_legume 22, rice 9, vegetable 25, paneer_dairy 60) + 49 across the 3 piece-count categories (bread 12, snack_street 10, sweet_dessert 27). Exact per-category breakdown with every dish enumerated is in testchecklist.md "Portion Accuracy" (re-verified 2026-07-06 by direct SQL query, not recalled from memory — an earlier draft had arithmetic errors here). Most are category-fit judgment calls (e.g. is a raita or kheer "close enough" to a paneer curry to get katori too?) plus a handful of implied-serving-weight red flags (gulab jamun/halwa entries whose DB serving looks like it bundles multiple pieces). Left excluded (falls back to bucket-scale) rather than guessed either way.
- [ ] **Manual-weight-entry is currently unavailable on ~90%+ of dishes in these same categories** (raw `serving_size_g` column is NULL for 50/56 dal_legume, 39/42 rice, 52/60 vegetable, 66/69 paneer_dairy, and 100% of bread/snack_street) because it stays gated on the raw column, while katori/piece-count now use a derived fallback (`energy_kcal_per_serving / energy_kcal_per_100g * 100`) computed from data that's already present for effectively every dish. This was a deliberate choice to avoid changing manual weight's previously-verified behavior without a separate discussion — not an oversight, but genuinely unresolved. Decide: extend manual weight to use the same derived fallback (makes it actually usable), or leave it as the more conservative/raw-data-only option.
- [ ] **Rice katori baseline (165g) and vegetable dry/curry split (150g/200g)** are single approximate values, not verified against real katori sizes — same "flag before re-deriving" treatment as the existing fuzzy-match cutoff in aliases.py.
- [ ] Real-device testing for the new katori/piece-count/oil-ghee UI — simulator only so far, batch with the other pending device tests below.

---

## Next Up

- [ ] Nothing queued yet. Pick the next priority from the backlog below when ready.

---

## Backlog — Indian-Eating-Pattern Specific

- [ ] Thali/mixed-plate multi-food recognition — architecturally significant, needs object detection/segmentation before classification, not just retraining. Scope carefully, this changes the vision pipeline.
- [ ] Reheated/leftover food calorie adjustment — oil re-absorption changes calorie density slightly, minor but authentic
- [ ] Family/multi-serving logging — log one dish cooked for N people, split per person
- [ ] Regional cuisine profile at onboarding — user tags home region (Punjabi, Tamil, Bengali, Gujarati, etc.) once, used to bias fuzzy match ranking and default/suggested dishes toward what they're actually likely to log. No new data needed, just reweighting existing dishes.
- [ ] Ramzan fasting mode — deferred from the Navratri/Ekadashi phase since it's structurally different: a time-window restriction (no eating dawn to dusk, specific pre-dawn/iftar foods) rather than a food-composition restriction. Needs its own data model and UI, not an extension of the existing Fasting Mode picker.

## Backlog — Health Differentiators

- [ ] Glycemic index / diabetes-relevant tagging per dish (white rice vs brown rice, refined vs whole wheat roti) — South Asian populations have disproportionately high Type 2 diabetes rates, genuinely useful and underserved
- [ ] Micronutrient tracking for vegetarian/vegan gaps — B12, iron, protein-quality flags matter disproportionately given the userbase skews vegetarian. Reuses infrastructure likely needed for GI/diabetes tagging.

## Backlog — Data & Personalization

- [ ] Recipe builder — user combines ingredients into a custom "dish" and saves it (already flagged as part of Premium tier, Phase 9)
- [ ] Multi-language support — scope early: UI strings only, or also voice/OCR on packaging in other languages for barcode/OFF lookups

## Backlog — Input Methods Beyond Photo

- [ ] Voice logging ("log a bowl of dal and two rotis")
- [ ] Home screen widget for quick-log
- [ ] Siri Shortcuts integration
- [ ] Reference-object portion calibration — coin or hand in-frame for scale, as an alternative/supplement to manual weight entry for improving ML portion estimation. Real vision-pipeline addition, same complexity tier as multi-food recognition, not a quick win.

## Backlog — Habit / Retention Mechanics

- [ ] Streaks (consecutive days logged)
- [ ] Weekly/monthly trend charts (weight over time, calorie adherence over time) — HealthKit weight data already available if user logs it there
- [ ] Water intake tracking

## Backlog — Database Growth / Moat

- [ ] Crowdsourced home-recipe contribution with regional tagging ("my mom's version of X," Gujarati vs Bengali vs Tamil variants of the same dish name) — builds a data moat, feeds Phase 7/8 retraining pipeline for free
- [ ] Restaurant menu OCR, broader than existing chain-specific Phase 6c plan — point camera at any local Indian restaurant menu, match against dish database via existing fuzzy resolution logic

## Backlog — Export / Portability

- [ ] Export logs to CSV/PDF for a nutritionist or personal record
- [ ] Dietitian-chart export — formatted export matching the specific diet-chart format Indian dietitians commonly prescribe, distinct from a raw CSV/PDF dump. India-specific angle.

## Backlog — Social / Sharing (lower priority, higher engineering cost)

- [ ] Share a meal log or progress screenshot
- [ ] Friend/family comparison — usually low priority, high engineering cost for privacy/backend

## More Food Options (distinct axis from accuracy)

- [ ] Expand dish/regional cuisine coverage — separate from Phase 8 accuracy work, which improves accuracy on the existing 92 classes rather than adding new ones. Worth its own phase if this is the goal.

---

## Design Direction (not a feature, tackle later)

- [ ] UI direction inspired by Cal.ai — pull up their actual UI and identify specific elements to borrow (calorie ring style, camera-first flow, etc.) before turning into an implementation prompt
- [ ] Initial login / onboarding flow

## Hard Requirements, Not Features (checklist items, not roadmap phases)

- [ ] Real-device camera testing (Vision classifier)
- [ ] Real-device barcode scanner testing
- [ ] Real-device HealthKit write testing

---

*Last updated after Portion Accuracy (katori/piece-count/oil-ghee) completion, 2026-07-06. Add new items under the relevant category; don't reorganize categories without discussing here first.*