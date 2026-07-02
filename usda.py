"""
usda.py
=======
USDA FoodData Central API wrapper.
Reads USDA_API_KEY from environment / .env file.
"""

import os
os.chdir('/Users/ahilannayani/Personal Python Projects/Indian Food Calorie Counter')

import requests
from dotenv import load_dotenv

load_dotenv()

USDA_API_KEY  = os.getenv("USDA_API_KEY", "DEMO_KEY")
USDA_BASE_URL = "https://api.nal.usda.gov/fdc/v1"


def _extract_nutrient(nutrients: list, nutrient_id: int) -> float | None:
    """Pull a specific nutrient value by nutrient number from a food's nutrients list."""
    for n in nutrients:
        if n.get("nutrientId") == nutrient_id or n.get("nutrientNumber") == str(nutrient_id):
            return n.get("value")
    return None


def _shape_food(food: dict) -> dict:
    """Normalise a USDA food object into our standard shape."""
    # FoodData search results use "foodNutrients" list
    nutrients = food.get("foodNutrients", [])

    # Nutrient IDs: 1008=energy(kcal), 1003=protein, 1004=fat, 1005=carb
    return {
        "fdcId":             food.get("fdcId"),
        "description":       food.get("description"),
        "calories_per_100g": _extract_nutrient(nutrients, 1008),
        "protein_per_100g":  _extract_nutrient(nutrients, 1003),
        "fat_per_100g":      _extract_nutrient(nutrients, 1004),
        "carb_per_100g":     _extract_nutrient(nutrients, 1005),
    }


def search_usda(query: str) -> list:
    """
    Search USDA FoodData Central for a query string.
    Returns up to 5 results as standardised dicts.
    """
    try:
        resp = requests.get(
            f"{USDA_BASE_URL}/foods/search",
            params={
                "query":    query,
                "dataType": "SR Legacy,Foundation",
                "pageSize": 5,
                "api_key":  USDA_API_KEY,
            },
            timeout=10,
        )
        resp.raise_for_status()
        data  = resp.json()
        foods = data.get("foods", [])
        return [_shape_food(f) for f in foods]
    except Exception as exc:
        print(f"[usda.search_usda] error: {exc}")
        return []


def get_usda_food(fdc_id: int) -> dict | None:
    """
    Fetch a single food by FDC ID from USDA FoodData Central.
    Returns a standardised dict or None on failure.
    """
    try:
        resp = requests.get(
            f"{USDA_BASE_URL}/food/{fdc_id}",
            params={"api_key": USDA_API_KEY},
            timeout=10,
        )
        resp.raise_for_status()
        food = resp.json()
        return _shape_food(food)
    except Exception as exc:
        print(f"[usda.get_usda_food] error: {exc}")
        return None
