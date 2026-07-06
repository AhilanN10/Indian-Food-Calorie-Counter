"""
test_dietary_filters_regression.py
===================================
Standalone regression check for GET /dish/search dietary filtering.

Background: on 2026-07-05 a Vegan-filtered search for "paneer kathi roll"
returned paneer dishes despite is_vegan=0 on every one of them. Root cause
was NOT a plumbing bug in the current source (all three name-resolution
tiers in aliases.py/resolve_dish_name — exact, alias, fuzzy — already apply
the same _to_result() diet-filter check identically). The actual cause was
a long-running `uvicorn main:app` process started before the dietaryFilters
feature existed, run without --reload, so it kept serving stale in-memory
code indefinitely. Restarting the server fixed it immediately.

This script exists so a *real* regression (should one ever be introduced
into one of the three tiers) fails loudly, and to guard against the same
stale-process class of bug being mistaken for a code defect again.

Run with the backend NOT already accounted for — this uses an in-process
TestClient (fresh import of main.py), so it always reflects the code on
disk, never a stale running process.
"""

import os
os.chdir('/Users/ahilannayani/Personal Python Projects/Indian Food Calorie Counter')

from fastapi.testclient import TestClient
import main

client = TestClient(main.app)

FAILURES: list[str] = []


def check(label: str, condition: bool, detail: str = ""):
    status = "PASS" if condition else "FAIL"
    print(f"  [{status}] {label}" + (f" — {detail}" if detail and not condition else ""))
    if not condition:
        FAILURES.append(label)


print("=" * 65)
print("Regression: Vegan filter must exclude paneer dishes on /dish/search")
print("(searched by name, not food_code, across all three resolution tiers)")
print("=" * 65)

# ---------------------------------------------------------------------
# Fuzzy tier — "paneer kathi roll" has no exact/alias match, resolves
# via fuzzy match to "Paneer kaathi roll" (ASC149, is_vegan=0) plus
# other paneer candidates. None should survive a Vegan filter.
# ---------------------------------------------------------------------
r = client.get("/dish/search", params={"q": "paneer kathi roll", "dietaryFilters": "vegan"})
names = [x["food_name"] for x in r.json()["results"]]
check(
    "fuzzy tier: 'paneer kathi roll' + vegan filter returns no paneer dish",
    r.status_code == 200 and not any("paneer" in n.lower() for n in names),
    detail=f"got {names}",
)

# Unfiltered control — the same query must still find the dish, proving
# the empty filtered result above is the filter working, not a broken query.
r_unfiltered = client.get("/dish/search", params={"q": "paneer kathi roll"})
check(
    "control: unfiltered 'paneer kathi roll' still finds a paneer dish",
    any("paneer" in x["food_name"].lower() for x in r_unfiltered.json()["results"]),
)

# ---------------------------------------------------------------------
# Exact tier — "Shahi paneer" is a literal food_name match (is_vegan=0)
# ---------------------------------------------------------------------
r = client.get("/dish/search", params={"q": "shahi paneer", "dietaryFilters": "vegan"})
check(
    "exact tier: 'shahi paneer' + vegan filter returns nothing",
    r.status_code == 200 and r.json()["total"] == 0,
    detail=str(r.json()["results"]),
)

# ---------------------------------------------------------------------
# Alias tier — "matar paneer" resolves via dish_aliases to ASC191
# "Pea paneer curry (Matar paneer)" (is_vegan=0)
# ---------------------------------------------------------------------
r = client.get("/dish/search", params={"q": "matar paneer", "dietaryFilters": "vegan"})
names = [x["food_name"] for x in r.json()["results"]]
check(
    "alias tier: 'matar paneer' + vegan filter excludes the non-vegan alias target",
    not any("matar paneer" in n.lower() or "pea paneer" in n.lower() for n in names),
    detail=f"got {names}",
)

# ---------------------------------------------------------------------
# Generic term — broad "paneer" query exercises many fuzzy candidates
# at once; every one of them is non-vegan in the current DB.
# ---------------------------------------------------------------------
r = client.get("/dish/search", params={"q": "paneer", "dietaryFilters": "vegan", "limit": 10})
names = [x["food_name"] for x in r.json()["results"]]
check(
    "broad 'paneer' query + vegan filter returns no paneer dish",
    not any("paneer" in n.lower() for n in names),
    detail=f"got {names}",
)

print()
if FAILURES:
    print(f"{len(FAILURES)} check(s) FAILED: {FAILURES}")
    raise SystemExit(1)
print("All dietary-filter regression checks passed.")
