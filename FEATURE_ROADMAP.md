# Indian Food Calorie Counter — Feature Roadmap

Living document. Check items off as they're designed, implemented, and verified (not just implemented). Follows the same review-workflow standard as CLAUDE.md: don't check something off on the basis of an asserted "done," check it off once root cause / verification is actually established.

---

## Completed & Verified

- [x] Backend (FastAPI, multiplier engine, all endpoints)
- [x] SQLite DB (950 dishes), 3-tier name resolution (exact/alias/fuzzy)
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

## Already Scoped in Roadmap (context, not yet built)

- [ ] Higher accuracy ML model (Phase 8, target 85%+ accuracy)
- [ ] Data collection — log user corrections as labeled training data (Phase 7)
- [ ] Subscription model (Phase 9, $4.99/mo premium)

## Open Question — Needs a Decision Before Next Related Work

- [ ] **"Fuzzy" tag visibility conflict.** Original brainstorm said "make fuzzy tag go away." The Search Page Rework just shipped a fuzzy/alias match badge on result cards as part of the visual redesign. These directly contradict. Resolve intent: is the goal to hide the fact that a match isn't exact, or just to stop showing internal-sounding terminology like "Fuzzy" to end users (e.g. relabel as "Similar match" instead of removing the signal)? Decide before touching search result UI again.

---

## Next Up

- [ ] **Fasting-day mode** — permitted-food filtering for Navratri, Ramzan, Ekadashi, etc. (e.g. no grains during Navratri, only kuttu/singhara flours). Flagged as the strongest "nobody else has built this" differentiator for observant Indian users. Ramzan out of scope (time-window, not food-composition based). **Navratri + Ekadashi: data tagging + backend filtering + iOS UI implemented and verified in Simulator 2026-07-06 — see testchecklist.md "Fasting Mode" section.** Not checked off yet: 27-dish ambiguous-tagging review needs Ahilan's manual sign-off, NULL-flag banner text untested, real-device testing pending.

---

## Backlog — Indian-Eating-Pattern Specific

- [ ] Thali/mixed-plate multi-food recognition — architecturally significant, needs object detection/segmentation before classification, not just retraining. Scope carefully, this changes the vision pipeline.
- [ ] Count-based portion units — katori, piece counts (ladoo/piece counts for sweets), rather than only grams/cups
- [ ] Reheated/leftover food calorie adjustment — oil re-absorption changes calorie density slightly, minor but authentic
- [ ] Family/multi-serving logging — log one dish cooked for N people, split per person
- [ ] Cooking oil/ghee as a separate loggable quantity — Indian home cooking has wide oil/ghee variance per household that a fixed per-dish average can't capture; a simple "add extra oil/ghee (tsp)" adjustment on top of base dish estimate, feeds directly into existing multiplier engine, no ML changes
- [ ] Regional cuisine profile at onboarding — user tags home region (Punjabi, Tamil, Bengali, Gujarati, etc.) once, used to bias fuzzy match ranking and default/suggested dishes toward what they're actually likely to log. No new data needed, just reweighting existing dishes.

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

*Last updated after Search Page Rework completion. Add new items under the relevant category; don't reorganize categories without discussing here first.*
