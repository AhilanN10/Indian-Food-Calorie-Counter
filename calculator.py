"""
calculator.py
=============
Multiplier-based calorie/macro estimation engine.

Main entry point: calculate_macros(dish: dict, qa_answers: dict) -> dict
"""

import os
os.chdir('/Users/ahilannayani/Personal Python Projects/Indian Food Calorie Counter')

# ---------------------------------------------------------------------------
# Scale tables
# ---------------------------------------------------------------------------

PORTION_SCALE = {
    "tiny":        0.35,
    "small":       0.60,
    "standard":    1.00,
    "large":       1.60,
    "extra_large": 2.20,
}

RICE_SCALE = {
    "small_scoop":    0.40,
    "half_cup":       0.65,
    "standard_cup":   1.00,
    "large_serving":  1.65,
    "full_bowl":      2.45,
}

MEAT_SCALE = {
    "light":      0.50,
    "moderate":   1.00,
    "heavy":      1.60,
    "very_heavy": 2.20,
}

CONTEXT_FAT_ADD_G = {
    "home":                  0,
    "homestyle_restaurant":  6,
    "restaurant":           12,
    "dhaba":                18,
    "street_fried":          8,
    "street_nonfried":       3,
    "wedding_banquet":      20,
}

GRAVY_FAT_ADD_G = {
    "dry":        -5,
    "thin":       -3,
    "medium":      0,
    "thick":       7,
    "very_thick": 12,
}

COOKING_METHOD_FAT_ADJUST_G = {
    "steamed":          -8,
    "boiled":           -6,
    "tandoor":          -4,
    "shallow_fried":     0,
    "deep_fried_thin":   9,
    "deep_fried_thick": 14,
    "deep_fried_dough": 11,
}

FLAT_ADDITIONS: dict[str, dict] = {
    "cream_dollop":       {"kcal": 85,  "fat_g": 9,  "protein_g": 1, "carb_g": 1},
    "butter_standard":    {"kcal": 72,  "fat_g": 8,  "protein_g": 0, "carb_g": 0},
    "butter_extra":       {"kcal": 108, "fat_g": 12, "protein_g": 0, "carb_g": 0},
    "paneer_extra":       {"kcal": 110, "fat_g": 8,  "protein_g": 7, "carb_g": 2},
    "egg_whole":          {"kcal": 78,  "fat_g": 5,  "protein_g": 6, "carb_g": 0},
    "cashews_visible":    {"kcal": 55,  "fat_g": 4,  "protein_g": 2, "carb_g": 3},
    "coconut_milk_base":  {"kcal": 65,  "fat_g": 6,  "protein_g": 1, "carb_g": 2},
    "coconut_fresh_heavy":{"kcal": 45,  "fat_g": 4,  "protein_g": 1, "carb_g": 2},
    "sev_papdi_topping":  {"kcal": 95,  "fat_g": 5,  "protein_g": 2, "carb_g": 10},
    "raita_side":         {"kcal": 55,  "fat_g": 2,  "protein_g": 3, "carb_g": 5},
    "papad_one":          {"kcal": 35,  "fat_g": 1,  "protein_g": 2, "carb_g": 5},
    "naan_vs_roti_extra": {"kcal": 40,  "fat_g": 3,  "protein_g": 1, "carb_g": 4},
}

CONFIDENCE_BANDS: dict = {
    0:            0.10,
    1:            0.18,
    2:            0.28,
    3:            0.40,
    "ml_fallback": 0.50,
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _safe(val, default: float = 0.0) -> float:
    """Return val as float, or default if None/missing."""
    return float(val) if val is not None else default


def _confidence(skipped: int) -> float:
    if skipped in CONFIDENCE_BANDS:
        return CONFIDENCE_BANDS[skipped]
    if skipped > 3:
        return CONFIDENCE_BANDS[3]
    return CONFIDENCE_BANDS["ml_fallback"]


# ---------------------------------------------------------------------------
# Main engine
# ---------------------------------------------------------------------------

def calculate_macros(dish: dict, qa_answers: dict) -> dict:
    """
    Apply multiplier logic to a dish row and a set of QA answers.

    qa_answers keys (all optional – defaults are "standard" / "home" / "medium"):
      portion_size, rice_amount, meat_amount, cooking_context,
      gravy_type, cooking_method, flat_additions, questions_skipped
    """
    adjustments: list[str] = []

    # -----------------------------------------------------------------------
    # Step 1 – Determine portion scale multiplier
    # -----------------------------------------------------------------------
    food_cat   = (dish.get("food_category") or "").lower()
    is_rice    = food_cat == "rice"
    is_meat    = food_cat == "meat_fish"

    if is_rice and qa_answers.get("rice_amount"):
        scale = RICE_SCALE.get(qa_answers["rice_amount"], 1.0)
        adjustments.append(f"rice_scale_{qa_answers['rice_amount']}_{scale}")
    elif is_meat and qa_answers.get("meat_amount"):
        scale = MEAT_SCALE.get(qa_answers["meat_amount"], 1.0)
        adjustments.append(f"meat_scale_{qa_answers['meat_amount']}_{scale}")
    else:
        ps    = qa_answers.get("portion_size", "standard")
        scale = PORTION_SCALE.get(ps, 1.0)
        adjustments.append(f"portion_scale_{scale}")

    # Base macros (per-serving from DB)
    protein_g = _safe(dish.get("protein_g_per_serving")) * scale
    fat_g     = _safe(dish.get("fat_g_per_serving"))     * scale
    carb_g    = _safe(dish.get("carb_g_per_serving"))    * scale
    fibre_g   = _safe(dish.get("fibre_g_per_serving"))   * scale

    # -----------------------------------------------------------------------
    # Step 2 – Fat context / gravy / cooking method adjustments
    # -----------------------------------------------------------------------
    has_dairy   = bool(dish.get("dairy_fat_already_counted"))
    has_cream   = bool(dish.get("has_cream_in_base"))
    has_butter  = bool(dish.get("has_butter_in_base"))

    cooking_method = qa_answers.get("cooking_method")
    cooking_ctx    = qa_answers.get("cooking_context", "home")
    gravy_type     = qa_answers.get("gravy_type", "medium")

    if cooking_method and cooking_method in COOKING_METHOD_FAT_ADJUST_G:
        # cooking_method takes priority over context fat
        fat_adj = COOKING_METHOD_FAT_ADJUST_G[cooking_method]
        fat_g  += fat_adj
        adjustments.append(f"cooking_method_{cooking_method}_{'+' if fat_adj >= 0 else ''}{fat_adj}g")
    else:
        # Context fat
        ctx_fat = CONTEXT_FAT_ADD_G.get(cooking_ctx, 0)
        fat_g  += ctx_fat
        adjustments.append(f"context_fat_{cooking_ctx}_{'+' if ctx_fat >= 0 else ''}{ctx_fat}g")

        # Gravy fat – skip if dairy already counted AND gravy is thick/very_thick
        skip_gravy = has_dairy and gravy_type in ("thick", "very_thick")
        if skip_gravy:
            adjustments.append(f"gravy_{gravy_type}_skipped_dairy_already_counted")
        else:
            gravy_fat = GRAVY_FAT_ADD_G.get(gravy_type, 0)
            fat_g    += gravy_fat
            adjustments.append(f"gravy_{gravy_type}_{'+' if gravy_fat >= 0 else ''}{gravy_fat}g")

    # -----------------------------------------------------------------------
    # Step 3 – Flat additions
    # -----------------------------------------------------------------------
    for addition_key in (qa_answers.get("flat_additions") or []):
        if addition_key not in FLAT_ADDITIONS:
            continue

        # Skip cream/butter additions if already in base
        is_cream_add  = addition_key in ("cream_dollop",)
        is_butter_add = addition_key in ("butter_standard", "butter_extra")

        if is_cream_add and has_cream:
            adjustments.append(f"flat_{addition_key}_skipped_already_in_base")
            continue
        if is_butter_add and has_butter:
            adjustments.append(f"flat_{addition_key}_skipped_already_in_base")
            continue

        add = FLAT_ADDITIONS[addition_key]
        fat_g     += _safe(add.get("fat_g"))
        protein_g += _safe(add.get("protein_g"))
        carb_g    += _safe(add.get("carb_g"))
        adjustments.append(
            f"flat_{addition_key}_+{add['kcal']}kcal"
        )

    # Clamp negatives (fat can theoretically go below 0 with steamed adjustments)
    fat_g     = max(0.0, fat_g)
    protein_g = max(0.0, protein_g)
    carb_g    = max(0.0, carb_g)
    fibre_g   = max(0.0, fibre_g)

    # -----------------------------------------------------------------------
    # Step 4 – Recompute kcal from final macros
    # -----------------------------------------------------------------------
    kcal_estimate = (fat_g * 9) + (protein_g * 4) + (carb_g * 4)

    # -----------------------------------------------------------------------
    # Step 5 – Confidence band
    # -----------------------------------------------------------------------
    skipped   = int(qa_answers.get("questions_skipped", 0))
    band_pct  = _confidence(skipped)
    kcal_low  = round(kcal_estimate * (1 - band_pct))
    kcal_high = round(kcal_estimate * (1 + band_pct))

    dairy_flag_applied = has_dairy or has_cream or has_butter

    return {
        "kcal_estimate":       round(kcal_estimate, 1),
        "kcal_low":            kcal_low,
        "kcal_high":           kcal_high,
        "protein_g":           round(protein_g, 1),
        "fat_g":               round(fat_g, 1),
        "carb_g":              round(carb_g, 1),
        "fibre_g":             round(fibre_g, 1),
        "confidence_band_pct": band_pct,
        "questions_skipped":   skipped,
        "dairy_flag_applied":  dairy_flag_applied,
        "adjustments_applied": adjustments,
    }
