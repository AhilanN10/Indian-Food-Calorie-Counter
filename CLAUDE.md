# Indian Food Calorie Counter

iOS calorie/macro tracker for Indian cuisine. FastAPI + SQLite backend, SwiftUI + SwiftData + HealthKit client, EfficientNet-B0 Core ML classifier (92 classes, 72.5% accuracy).

## Commands

- Start backend: `uvicorn main:app --reload --port 8000` (always use `--reload` — without it, code changes won't take effect and testing will silently run against stale code)
- No pytest/test framework in this repo. Follow the existing convention: standalone runnable scripts (see phase0_pipeline.py, phase0b_cleanup.py, test_dietary_filters_regression.py) for anything that needs a persisted regression test.

## Git

This repo has a history of losing its .git folder. If git commands fail unexpectedly, reinit:
```
git init
git remote add origin https://github.com/AhilanN10/Indian-Food-Calorie-Counter.git
git add .
git commit -m "message"
git branch -M main
git push -u origin main --force
```
testchecklist.md changes should be committed promptly, not left sitting locally — it's been lost to a .git wipe before.

After committing, always push to origin main (`git push origin main`) — don't leave commits sitting local-only, given the repo's history of losing its .git folder entirely.

## iOS workflow

New Swift files need to be manually added to the Xcode target after creation — right-click the correct folder in Xcode navigator → Add Files to "IndianFoodApp" → check "Add to target: IndianFoodApp". This doesn't happen automatically. Flag clearly when you've created new Swift files so this step isn't missed.

## Testing

testchecklist.md at the project root is a living QA checklist. Append a new section per feature/phase with specific, checkable items — including hand-calculated worked examples for anything involving math (e.g. TDEE/macro calculations). Device testing (camera, barcode scanner, HealthKit) is batched into occasional large sessions, not done after every feature, so keep the checklist accurate and complete between sessions rather than assuming recent items have already been verified.

## Data notes (indb.sqlite)

- Fuzzy match cutoff (aliases.py FUZZY_SCORE_CUTOFF) is 70, empirically validated against real typo/alt-spelling cases. Don't re-derive this from scratch — if it needs revisiting, test against known cases first (see testchecklist.md Search Page / search quality sections for the validation method used).
- is_recipe_level=1 (64 dishes) is a correct, intentional flag meaning "no computed per-serving nutrition yet" — it correlates 100% with energy_kcal_per_serving IS NULL. This is not a data bug, don't flag it as one without checking this correlation first.
- Dish name whitespace (46 dishes had trailing spaces) was cleaned as of the search quality fix. If new dishes are added to the DB later, trim on insert.

## Working style

Design decisions, edge cases, and data models get worked out in conversation before implementation. When a task is genuinely ambiguous in a way that changes the technical approach, ask — don't guess and proceed silently. When something breaks, state the actual root cause clearly before claiming it's fixed; don't assert "tested" or "fixed" without saying what was found.

## Review workflow

Design and implementation decisions get a second opinion in a separate conversation before being finalized — you are one part of a two-stage review, not the only check. Write reports accordingly:
- State root cause before stating resolution. If something failed and got fixed, say what failed and why, not just "fixed."
- Surface assumptions and scope decisions explicitly, especially ones you made without being asked (e.g. a methodology choice, a threshold value, a UX detail not specified in the prompt) — flag these clearly rather than folding them into the summary as if they were part of the spec.
- If verification was partial, incomplete, or you're inferring "should work" rather than having confirmed it, say so directly instead of asserting confidence.