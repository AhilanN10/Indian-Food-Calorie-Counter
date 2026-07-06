"""
test_portion_accuracy_regression.py
====================================
Standalone regression check for the Portion Accuracy phase: katori
portions, piece-count portions, and the optional oil/ghee add-on.

Background: serving_size_g is NULL for the large majority of dishes in
every category this phase touches. katori/piece-count math falls back to
a derived value (energy_kcal_per_serving / energy_kcal_per_100g * 100)
that manual-weight-entry deliberately does NOT use (manual weight keeps
its existing NULL-gated behavior, verified in
test_dietary_filters_regression.py's sibling checklist entries). This
script guards the derived-value fallback, the category-specific katori
gram conversion, the linear piece-count math, the additive oil/ghee kcal
math, and eligibility gating (portion_eligibility.py) against regressions.

Run with the backend NOT already running elsewhere — this uses an
in-process TestClient (fresh import of main.py), so it always reflects
the code on disk.
"""

import os
os.chdir('/Users/ahilannayani/Personal Python Projects/Indian Food Calorie Counter')

from fastapi.testclient import TestClient
import main
import portion_eligibility as pe

client = TestClient(main.app)

FAILURES: list[str] = []


def check(label: str, condition: bool, detail: str = ""):
    status = "PASS" if condition else "FAIL"
    print(f"  [{status}] {label}" + (f" — {detail}" if detail and not condition else ""))
    if not condition:
        FAILURES.append(label)


# ---------------------------------------------------------------------
# Katori math — Dal makhani (OSR139), no raw serving_size_g, derived
# serving grams = 261.62567.../74.04019... * 100 = 353.4g
# 1 katori = 150g dal_legume baseline -> scale = 150/353.4 = 0.4245
# ---------------------------------------------------------------------
r = client.post("/dish/calculate", json={"food_code": "OSR139", "qa_answers": {"katori_count": 1}})
body = r.json()
check(
    "katori: Dal makhani 1 katori uses derived serving grams (no raw serving_size_g)",
    r.status_code == 200 and body["katori_used"] is True,
    detail=str(body),
)
check(
    "katori: Dal makhani 1 katori scale ~= 0.4245 (150g / 353.4g derived)",
    any("scale_0.42" in a or "scale_0.43" in a for a in body["adjustments_applied"]),
    detail=str(body["adjustments_applied"]),
)

r2 = client.post("/dish/calculate", json={"food_code": "OSR139", "qa_answers": {"katori_count": 1.5}})
body2 = r2.json()
check(
    "katori: 1.5 katori is exactly 1.5x the 1-katori kcal (linear in count)",
    abs(body2["kcal_estimate"] - body["kcal_estimate"] * 1.5) < 0.5,
    detail=f"1kat={body['kcal_estimate']} 1.5kat={body2['kcal_estimate']}",
)

# ---------------------------------------------------------------------
# Katori dry/curry vegetable split — same dish, gravy_type flips the
# category-specific gram baseline (150g dry vs 200g curry)
# ---------------------------------------------------------------------
r_dry = client.post("/dish/calculate", json={
    "food_code": "ASC171", "qa_answers": {"katori_count": 1, "gravy_type": "dry"}
})
r_curry = client.post("/dish/calculate", json={
    "food_code": "ASC171", "qa_answers": {"katori_count": 1, "gravy_type": "thick"}
})
check(
    "katori: vegetable dry (150g) produces a smaller scale than curry (200g) for the same dish",
    r_dry.json()["kcal_estimate"] < r_curry.json()["kcal_estimate"],
    detail=f"dry={r_dry.json()['adjustments_applied']} curry={r_curry.json()['adjustments_applied']}",
)

# ---------------------------------------------------------------------
# Piece-count math — Chapati (ASC096), per-serving IS the per-piece
# basis (1 chapati = 1 serving). 2 pieces -> exactly 2x the 1-piece
# result (kcal_estimate is always recomputed from scaled macros, see
# calculator.py Step 4, so compare against the engine's own 1-piece
# output rather than the raw DB energy_kcal_per_serving field).
# ---------------------------------------------------------------------
r3a = client.post("/dish/calculate", json={"food_code": "ASC096", "qa_answers": {"piece_count": 1}})
r3 = client.post("/dish/calculate", json={"food_code": "ASC096", "qa_answers": {"piece_count": 2}})
body3a, body3 = r3a.json(), r3.json()
check(
    "piece_count: Chapati x2 is exactly 2x the x1 kcal (linear)",
    body3["piece_count_used"] is True and abs(body3["kcal_estimate"] - body3a["kcal_estimate"] * 2) < 0.5,
    detail=f"x1={body3a['kcal_estimate']} x2={body3['kcal_estimate']}",
)

# ---------------------------------------------------------------------
# Oil/ghee additive — 2 tsp on top of Dal makhani 1 katori should add
# exactly 2 * 40 = 80 kcal (and ~8.89g fat) on top, not scale anything
# ---------------------------------------------------------------------
r4 = client.post("/dish/calculate", json={
    "food_code": "OSR139", "qa_answers": {"katori_count": 1, "oil_ghee_tsp": 2}
})
body4 = r4.json()
check(
    "oil_ghee: 2 tsp adds exactly 80 kcal on top of the katori-scaled base",
    abs(body4["kcal_estimate"] - (body["kcal_estimate"] + 80)) < 0.5,
    detail=f"base={body['kcal_estimate']} with_oil={body4['kcal_estimate']}",
)
check(
    "oil_ghee: 0 tsp (default/skip) leaves kcal unchanged",
    client.post("/dish/calculate", json={"food_code": "OSR139", "qa_answers": {"katori_count": 1}}).json()["kcal_estimate"]
    == body["kcal_estimate"],
)

# ---------------------------------------------------------------------
# Validation — katori_count/piece_count <= 0 and negative oil_ghee_tsp
# are rejected with 400, mirroring the existing manual_weight_g < 5 check
# ---------------------------------------------------------------------
check(
    "validation: katori_count <= 0 rejected with 400",
    client.post("/dish/calculate", json={"food_code": "OSR139", "qa_answers": {"katori_count": -1}}).status_code == 400,
)
check(
    "validation: piece_count <= 0 rejected with 400",
    client.post("/dish/calculate", json={"food_code": "ASC096", "qa_answers": {"piece_count": 0}}).status_code == 400,
)
check(
    "validation: negative oil_ghee_tsp rejected with 400",
    client.post("/dish/calculate", json={"food_code": "OSR139", "qa_answers": {"oil_ghee_tsp": -1}}).status_code == 400,
)

# ---------------------------------------------------------------------
# manual_weight_g still takes precedence over katori_count when both
# are supplied (existing manual-weight semantics are untouched)
# ---------------------------------------------------------------------
r5 = client.post("/dish/calculate", json={
    "food_code": "OSR139", "qa_answers": {"katori_count": 2, "manual_weight_g": 100}
})
body5 = r5.json()
check(
    "precedence: manual_weight_g path is evaluated before katori_count (katori_used stays False)",
    body5["katori_used"] is False,
    detail=str(body5["adjustments_applied"]),
)

# ---------------------------------------------------------------------
# Eligibility gating (portion_eligibility.py) — spot checks against the
# live DB for the categories/food_codes this phase actually touches
# ---------------------------------------------------------------------
gravy_paneer = client.get("/dish/ASC195").json()   # Paneer curry
solid_paneer = client.get("/dish/BFP424").json()   # Paneer cutlet
poori        = client.get("/dish/ASC107").json()   # Poori (flagged multi-piece)
chapati      = client.get("/dish/ASC096").json()   # Chapati (piece eligible)
dal_bowl     = client.get("/dish/OSR139").json()   # Dal makhani (katori eligible)

check("eligibility: gravy paneer (Paneer curry) is katori-eligible", gravy_paneer["katori_eligible"] is True)
check("eligibility: solid paneer (Paneer cutlet) is NOT katori-eligible", solid_paneer["katori_eligible"] is False)
check("eligibility: Poori is excluded from piece-count (flagged multi-piece suspect)", poori["piece_count_eligible"] is False)
check("eligibility: Chapati is piece-count eligible", chapati["piece_count_eligible"] is True)
check("eligibility: Dal makhani is katori-eligible", dal_bowl["katori_eligible"] is True)
check("eligibility: Dal makhani is oil/ghee eligible", dal_bowl["oil_ghee_eligible"] is True)
check("eligibility: Chapati (bread) is NOT oil/ghee eligible", chapati["oil_ghee_eligible"] is False)

print()
if FAILURES:
    print(f"{len(FAILURES)} check(s) FAILED: {FAILURES}")
    raise SystemExit(1)
print("All Portion Accuracy regression checks passed.")
