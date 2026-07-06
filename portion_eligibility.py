"""
portion_eligibility.py
=======================
Eligibility rules and gram derivation for the Portion Accuracy phase
(katori portions + piece-count portions). Consumed by calculator.py
(math) and main.py (API response flags for the iOS Q&A UI).

Design context (see FEATURE_ROADMAP.md / testchecklist.md "Portion Accuracy"):

serving_size_g is NULL for the large majority of dishes in every category
this phase touches (0% populated for bread/snack_street, ~10-15% for
dal_legume/rice/vegetable/paneer_dairy). It is always exactly reproducible
as energy_kcal_per_serving / energy_kcal_per_100g * 100 (verified against
every row where serving_size_g IS populated - matches exactly). So katori
and piece-count math use the derived value as a fallback. This is a
deliberate divergence from manual-weight-entry, which still only appears
when the raw serving_size_g column is populated (see QuestionView.swift
manualWeightAvailable) - that existing behavior is left untouched.
"""

# ---------------------------------------------------------------------------
# Katori gram baselines (category-specific, approximate - not verified
# figures, see FEATURE_ROADMAP.md Portion Accuracy notes)
# ---------------------------------------------------------------------------
KATORI_GRAMS = {
    "dal_legume":       150,
    "rice":             165,   # midpoint of the given 150-180g range
    "vegetable_dry":    150,   # dry sabzi
    "vegetable_curry":  200,   # gravy-based, higher liquid content
    "paneer_dairy":     200,   # only gravy-style paneer dishes are katori-eligible at all
}

# Serving units that read as "a bowl of X" for each katori-eligible category.
# Anything outside this whitelist (pickles/chutneys/condiments, fried
# snack-shaped items, sandwiches, whole-stuffed-vegetable pieces, etc. that
# happen to be miscategorised into these food_category buckets) is excluded
# from katori and flagged for manual review - see testchecklist.md.
KATORI_SERVING_UNITS = {
    "dal_legume": {"bowl", "curry bowl"},
    "rice":       {"bowl", "small bowl", "plate"},
    "vegetable":  {"bowl", "small bowl", "soup bowl"},
}

# paneer_dairy has no reliable serving_unit signal for gravy-vs-solid (raita/
# kheer/curd sides share "bowl" with actual paneer-curry dishes). Resolved by
# explicit keyword match against food_name, confirmed against the live DB:
# gravy/curry-style paneer dishes only. Raita, kheer/payasam, curd-based
# sides, and solid/piece paneer (tikka, cutlet, patty, samosa, sandwich,
# cheela, rasmalai, souffle) are excluded and flagged - see testchecklist.md.
PANEER_GRAVY_FOOD_CODES = {
    "ASC191",  # Pea paneer curry (Matar paneer)
    "ASC195",  # Paneer curry
    "ASC215",  # Spinach paneer (Palak paneer)
    "ASC221",  # Shahi paneer
    "ASC222",  # Paneer in butter sauce
    "ASC223",  # Methi malai paneer
    "ASC226",  # Kadhai Paneer
    "BFP091",  # Veg paneer stew
    "OSR077",  # Paneer lababdar
}

# ---------------------------------------------------------------------------
# Piece-count eligibility
# ---------------------------------------------------------------------------

# Bread: per-dish implied gram weight (energy_kcal_per_serving /
# energy_kcal_per_100g * 100) is a plausible single-piece weight for every
# bread dish EXCEPT the poori and appam families, where implied weight
# (75-155g for poori, 153-290g for appam) is 2-4x a realistic single piece
# (poori ~30-50g, appam ~40-70g) - suggesting the DB "serving" already bundles
# multiple pieces. These are excluded from true piece-count math and kept on
# the existing bread_pieces bucket-scale question, flagged for manual review.
BREAD_MULTI_PIECE_SUSPECT_CODES = {
    "BFP153", "OSR110",  # Appam, Banana appam
    "BFP114", "BFP116", "ASC110", "BFP115", "ASC109",
    "BFP117", "ASC107", "ASC111", "ASC108", "ASC464",  # poori family (10)
}

# snack_street: only these two have an implied single-piece weight
# consistent with one realistic discrete piece. Everything else in the
# category is either a bowl/plate serving (upma, sev, papdi - not discrete)
# or has an implied weight suggesting the DB serving bundles several pieces
# (cutlet, kachori, pakora, tikki, vada - flagged, see testchecklist.md).
SNACK_PIECE_ELIGIBLE_CODES = {
    "BFP431",  # Vegetable samosa
    "OSR118",  # Jackfruit fritters (mulik/fritter)
}

# sweet_dessert: ladoo entries are all plausible single-piece weights
# (27-48g). A subset of "biscuit"/"piece"/"gulab jamun" entries are too - the
# rest of those serving_units have implied weights 3-10x a realistic single
# piece (gulab jamun ~150-300g implied vs ~40-50g real, halwa mislabeled as
# "piece" when it isn't a discrete item at all) and are excluded/flagged.
SWEET_PIECE_ELIGIBLE_CODES = {
    "ASC341", "ASC342", "ASC343", "ASC344",
    "ASC470", "ASC471", "BFP571", "OSR021",  # ladoo (8)
    "ASC441", "ASC444",                       # biscuit (2)
    "BFP404", "BFP406", "BFP407", "BFP563",   # piece (4)
}

PIECE_COUNT_CATEGORIES = {"bread", "snack_street", "sweet_dessert"}
KATORI_CATEGORIES = {"dal_legume", "rice", "vegetable", "paneer_dairy"}

# Categories where the optional oil/ghee add-on question applies (home-cooked
# oil/ghee variance is significant; bread/beverage/sweet_dessert/snack_street/
# condiment_side are excluded per spec).
OIL_GHEE_CATEGORIES = {"dal_legume", "vegetable", "meat_fish", "paneer_dairy"}

KCAL_PER_TSP_OIL_GHEE = 40


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def derive_serving_grams(dish: dict) -> float | None:
    """
    Return the dish's per-serving weight in grams: the raw serving_size_g
    column if populated, else derived from energy_kcal_per_serving /
    energy_kcal_per_100g * 100 (verified to match exactly wherever both
    values are available). None if neither is computable.
    """
    ssg = dish.get("serving_size_g")
    if ssg is not None and ssg > 0:
        return float(ssg)

    kcal_serving = dish.get("energy_kcal_per_serving")
    kcal_100g    = dish.get("energy_kcal_per_100g")
    if kcal_serving is not None and kcal_100g:
        try:
            derived = float(kcal_serving) / float(kcal_100g) * 100
        except (TypeError, ZeroDivisionError):
            return None
        return derived if derived > 0 else None
    return None


def katori_eligible(dish: dict) -> bool:
    """Whether this dish should offer a katori-count portion input."""
    category = (dish.get("food_category") or "").lower()
    if category == "paneer_dairy":
        return dish.get("food_code") in PANEER_GRAVY_FOOD_CODES
    if category in KATORI_SERVING_UNITS:
        unit = (dish.get("serving_unit") or "").strip().lower()
        return unit in KATORI_SERVING_UNITS[category]
    return False


def katori_grams_per_unit(dish: dict, qa_answers: dict | None = None) -> float:
    """Category-specific grams-per-katori baseline for this dish."""
    category = (dish.get("food_category") or "").lower()
    if category == "vegetable":
        gravy_type = (qa_answers or {}).get("gravy_type", "medium")
        return KATORI_GRAMS["vegetable_dry"] if gravy_type == "dry" else KATORI_GRAMS["vegetable_curry"]
    return KATORI_GRAMS.get(category, KATORI_GRAMS["dal_legume"])


def piece_count_eligible(dish: dict) -> bool:
    """Whether this dish should offer a true count x per-piece portion input."""
    category   = (dish.get("food_category") or "").lower()
    food_code  = dish.get("food_code")
    if category == "bread":
        return food_code not in BREAD_MULTI_PIECE_SUSPECT_CODES
    if category == "snack_street":
        return food_code in SNACK_PIECE_ELIGIBLE_CODES
    if category == "sweet_dessert":
        return food_code in SWEET_PIECE_ELIGIBLE_CODES
    return False


def oil_ghee_eligible(dish: dict) -> bool:
    category = (dish.get("food_category") or "").lower()
    return category in OIL_GHEE_CATEGORIES
