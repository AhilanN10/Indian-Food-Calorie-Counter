"""
phase3a_data_prep.py
====================
Phase 3a: Merge two Indian food image datasets into a unified
training-ready structure for EfficientNet fine-tuning.

Tasks:
  1 – Scan both datasets and print class/image inventory
  2 – Exclude non-Indian classes, normalize names, merge into all_classes/
  3 – Filter low-image classes (< 30) → low_data_classes/
  4 – Train / val / test split (80/10/10, seed=42)
  5 – Build class_map.json with INDB + indian_food.csv metadata
  6 – Dataset health report
"""

import os
os.chdir('/Users/ahilannayani/Personal Python Projects/Indian Food Calorie Counter')

import json
import random
import shutil
import sqlite3
from pathlib import Path

import pandas as pd

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
DATASET_80   = Path("Food Data/Food Images Dataset/Indian Food Images/Indian Food Images")
DATASET_20   = Path("Food Data/Food Classification")
METADATA_CSV = Path("Food Data/indian_food.csv")
INDB_SQLITE  = Path("indb.sqlite")
OUTPUT_DIR   = Path("Food Data/merged_dataset")

IMAGE_EXTS   = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}
MIN_IMAGES   = 30
RANDOM_SEED  = 42

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
EXCLUDE_CLASSES = {"burger", "pizza", "momos"}   # not Indian food

NORMALIZE = {
    "chole_bhature":  "chole_bhatura",
    "paani_puri":     "pani_puri",
    "kaathi_rolls":   "kathi_roll",
    "pakode":         "pakora",
    "butter_naan":    "naan",
    "kadai_paneer":   "paneer",
}


# ===========================================================================
# Helpers
# ===========================================================================

def normalize_class(name: str) -> str:
    """Lowercase + replace spaces/hyphens with underscores, then apply map."""
    n = name.strip().lower().replace(" ", "_").replace("-", "_")
    return NORMALIZE.get(n, n)


def list_images(folder: Path) -> list[Path]:
    """Return all image files directly inside a folder (non-recursive)."""
    return [f for f in folder.iterdir()
            if f.is_file() and f.suffix.lower() in IMAGE_EXTS]


def separator(char="=", width=65):
    print(char * width)


# ===========================================================================
# TASK 1 – Scan both datasets
# ===========================================================================
separator()
print("TASK 1 – Scanning datasets")
separator()

inventory: list[dict] = []   # {class_name, norm_name, image_count, source, original_path}

for cls_dir in sorted(DATASET_80.iterdir()):
    if not cls_dir.is_dir():
        continue
    norm = normalize_class(cls_dir.name)
    imgs = list_images(cls_dir)
    inventory.append({
        "class_name":    cls_dir.name,
        "norm_name":     norm,
        "image_count":   len(imgs),
        "source":        "80class",
        "original_path": cls_dir,
    })

for cls_dir in sorted(DATASET_20.iterdir()):
    if not cls_dir.is_dir():
        continue
    norm = normalize_class(cls_dir.name)
    imgs = list_images(cls_dir)
    inventory.append({
        "class_name":    cls_dir.name,
        "norm_name":     norm,
        "image_count":   len(imgs),
        "source":        "20class",
        "original_path": cls_dir,
    })

# Print inventory table
print(f"\n  {'Class Name':<35} {'Images':>7}  {'Source'}")
print("  " + "-" * 55)
for row in inventory:
    excl = "  ← EXCLUDED" if row["norm_name"] in EXCLUDE_CLASSES else ""
    print(f"  {row['class_name']:<35} {row['image_count']:>7}  {row['source']}{excl}")

print(f"\n  Total entries scanned : {len(inventory)}")
print(f"\n[OK] TASK 1 COMPLETE\n")


# ===========================================================================
# TASK 2 – Exclude, normalize, and merge into all_classes/
# ===========================================================================
separator()
print("TASK 2 – Merging into all_classes/")
separator()

ALL_CLASSES_DIR = OUTPUT_DIR / "all_classes"
ALL_CLASSES_DIR.mkdir(parents=True, exist_ok=True)

merged_counts: dict[str, int] = {}   # norm_name → total images copied
overlap_report: list[str] = []

for row in inventory:
    norm = row["norm_name"]

    if norm in EXCLUDE_CLASSES:
        continue

    src_dir: Path = row["original_path"]
    dst_dir: Path = ALL_CLASSES_DIR / norm
    dst_dir.mkdir(parents=True, exist_ok=True)

    imgs = list_images(src_dir)
    source_tag = row["source"]

    for img_path in imgs:
        new_name = f"{norm}_{source_tag}_{img_path.name}"
        dst_file = dst_dir / new_name
        # Avoid overwriting if file already exists (duplicate name edge-case)
        if dst_file.exists():
            stem   = img_path.stem
            suffix = img_path.suffix
            dst_file = dst_dir / f"{norm}_{source_tag}_{stem}_dup{suffix}"
        shutil.copy2(img_path, dst_file)

    merged_counts[norm] = merged_counts.get(norm, 0) + len(imgs)

# Detect overlaps (classes that appeared in both sources)
from collections import Counter
norm_source_pairs = [(r["norm_name"], r["source"])
                     for r in inventory if r["norm_name"] not in EXCLUDE_CLASSES]
norm_counter = Counter(n for n, _ in norm_source_pairs)
overlaps = [n for n, cnt in norm_counter.items() if cnt > 1]

print(f"\n  Excluded classes      : {sorted(EXCLUDE_CLASSES)}")
print(f"  Overlapping classes merged : {sorted(overlaps)}")
print(f"\n  Total merged classes  : {len(merged_counts)}")
print(f"  Total images copied   : {sum(merged_counts.values())}")
print(f"\n[OK] TASK 2 COMPLETE\n")


# ===========================================================================
# TASK 3 – Filter low-image classes (< MIN_IMAGES)
# ===========================================================================
separator()
print(f"TASK 3 – Filtering classes with < {MIN_IMAGES} images")
separator()

LOW_DATA_DIR = OUTPUT_DIR / "low_data_classes"
LOW_DATA_DIR.mkdir(parents=True, exist_ok=True)

low_classes:  list[str] = []
good_classes: list[str] = []

for norm_name, count in sorted(merged_counts.items()):
    if count < MIN_IMAGES:
        low_classes.append(norm_name)
        shutil.move(str(ALL_CLASSES_DIR / norm_name),
                    str(LOW_DATA_DIR / norm_name))
        print(f"  EXCLUDED  {norm_name:<35}  ({count} images < {MIN_IMAGES})")
    else:
        good_classes.append(norm_name)

print(f"\n  Classes excluded (low data) : {len(low_classes)}")
print(f"  Classes retained for training: {len(good_classes)}")
print(f"\n[OK] TASK 3 COMPLETE\n")


# ===========================================================================
# TASK 4 – Train / val / test split (80 / 10 / 10)
# ===========================================================================
separator()
print("TASK 4 – Train / val / test split (80/10/10, seed=42)")
separator()

random.seed(RANDOM_SEED)

TRAIN_DIR = OUTPUT_DIR / "train"
VAL_DIR   = OUTPUT_DIR / "val"
TEST_DIR  = OUTPUT_DIR / "test"
for d in (TRAIN_DIR, VAL_DIR, TEST_DIR):
    d.mkdir(parents=True, exist_ok=True)

split_counts: dict[str, dict] = {}   # class → {train, val, test}

print(f"\n  {'Class':<35} {'Train':>6}  {'Val':>5}  {'Test':>5}  {'Total':>6}")
print("  " + "-" * 58)

for cls in sorted(good_classes):
    src_dir  = ALL_CLASSES_DIR / cls
    all_imgs = sorted(list_images(src_dir))
    random.shuffle(all_imgs)

    n      = len(all_imgs)
    n_val  = max(1, round(n * 0.10))
    n_test = max(1, round(n * 0.10))
    n_train = n - n_val - n_test

    splits = {
        "train": all_imgs[:n_train],
        "val":   all_imgs[n_train:n_train + n_val],
        "test":  all_imgs[n_train + n_val:],
    }

    for split_name, files in splits.items():
        dst_cls_dir = OUTPUT_DIR / split_name / cls
        dst_cls_dir.mkdir(parents=True, exist_ok=True)
        for f in files:
            shutil.copy2(f, dst_cls_dir / f.name)

    split_counts[cls] = {
        "train": len(splits["train"]),
        "val":   len(splits["val"]),
        "test":  len(splits["test"]),
    }
    print(f"  {cls:<35} {len(splits['train']):>6}  {len(splits['val']):>5}  {len(splits['test']):>5}  {n:>6}")

totals = {
    "train": sum(v["train"] for v in split_counts.values()),
    "val":   sum(v["val"]   for v in split_counts.values()),
    "test":  sum(v["test"]  for v in split_counts.values()),
}
total_imgs = sum(totals.values())
print("  " + "-" * 58)
print(f"  {'TOTAL':<35} {totals['train']:>6}  {totals['val']:>5}  {totals['test']:>5}  {total_imgs:>6}")
print(f"\n[OK] TASK 4 COMPLETE\n")


# ===========================================================================
# TASK 5 – Build class_map.json
# ===========================================================================
separator()
print("TASK 5 – Building class_map.json")
separator()

# Load indian_food.csv for state/region metadata
meta_df = pd.read_csv(METADATA_CSV)
meta_df["name_norm"] = meta_df["name"].str.strip().str.lower().str.replace(r"[\s\-]+", "_", regex=True)

def lookup_csv_meta(cls_name: str) -> tuple[str | None, str | None]:
    """Find state/region from indian_food.csv by normalized name match."""
    # exact normalized match first
    match = meta_df[meta_df["name_norm"] == cls_name]
    if match.empty:
        # partial: cls_name is substring of csv name or vice versa
        match = meta_df[
            meta_df["name_norm"].str.contains(cls_name, na=False) |
            meta_df["name_norm"].apply(lambda x: cls_name in x)
        ]
    if not match.empty:
        row = match.iloc[0]
        state  = row.get("state")  if pd.notna(row.get("state"))  else None
        region = row.get("region") if pd.notna(row.get("region")) else None
        return state, region
    return None, None

# Connect to indb.sqlite
db_conn = sqlite3.connect(str(INDB_SQLITE))
db_conn.row_factory = sqlite3.Row
db_cur  = db_conn.cursor()

def lookup_indb(cls_name: str) -> tuple[str | None, str | None, bool]:
    """
    Try to match cls_name to an INDB dish.
    Returns (food_code, food_name, needs_manual_mapping).
    """
    # Tier 1: alias table exact match
    db_cur.execute(
        "SELECT canonical_food_code, canonical_food_name FROM dish_aliases "
        "WHERE LOWER(alias) = LOWER(?) LIMIT 1",
        (cls_name,),
    )
    row = db_cur.fetchone()
    if row:
        return row["canonical_food_code"], row["canonical_food_name"], False

    # Tier 2: dishes table LIKE match
    db_cur.execute(
        "SELECT food_code, food_name FROM dishes "
        "WHERE LOWER(food_name) LIKE ? "
        "  AND (is_recipe_level = 0 OR is_recipe_level IS NULL) "
        "LIMIT 1",
        (f"%{cls_name.replace('_', '%')}%",),
    )
    row = db_cur.fetchone()
    if row:
        return row["food_code"], row["food_name"], False

    return None, None, True   # needs manual mapping

class_map: dict = {
    "num_classes": len(good_classes),
    "classes": {},
}

needs_manual: list[str] = []

for idx, cls in enumerate(sorted(good_classes)):
    food_code, food_name, needs_manual_flag = lookup_indb(cls)
    state, region = lookup_csv_meta(cls)

    if needs_manual_flag:
        needs_manual.append(cls)

    class_map["classes"][cls] = {
        "class_idx":           idx,
        "indb_food_code":      food_code,
        "indb_food_name":      food_name,
        "needs_manual_mapping": needs_manual_flag,
        "state":               state,
        "region":              region,
        "image_count": {
            "train": split_counts[cls]["train"],
            "val":   split_counts[cls]["val"],
            "test":  split_counts[cls]["test"],
        },
    }
    status = "OK " if not needs_manual_flag else "???"
    print(f"  [{status}] {cls:<35}  INDB: {food_code or 'None':<10}  state: {state or '-'}")

db_conn.close()

with open("class_map.json", "w") as f:
    json.dump(class_map, f, indent=2)

print(f"\n  class_map.json written → {os.path.abspath('class_map.json')}")
print(f"\n[OK] TASK 5 COMPLETE\n")


# ===========================================================================
# TASK 6 – Dataset health report
# ===========================================================================
separator()
print("TASK 6 – Dataset health report")
separator()

all_train_counts = [v["train"] for v in split_counts.values()]
all_total_counts = [v["train"] + v["val"] + v["test"] for v in split_counts.values()]

min_cls = min(split_counts, key=lambda c: split_counts[c]["train"] + split_counts[c]["val"] + split_counts[c]["test"])
max_cls = max(split_counts, key=lambda c: split_counts[c]["train"] + split_counts[c]["val"] + split_counts[c]["test"])
avg_total = sum(all_total_counts) / len(all_total_counts)

confirmed_indb = len(good_classes) - len(needs_manual)

print(f"""
  ┌──────────────────────────────────────────────────────────┐
  │               DATASET HEALTH SUMMARY                    │
  ├──────────────────────────────────────────────────────────┤
  │  Total classes (training set)        : {len(good_classes):>5}             │
  │  Classes excluded (< {MIN_IMAGES} images)      : {len(low_classes):>5}             │
  │  Total images  – train               : {totals['train']:>6}            │
  │  Total images  – val                 : {totals['val']:>6}            │
  │  Total images  – test                : {totals['test']:>6}            │
  │  Total images  – combined            : {total_imgs:>6}            │
  │  Confirmed INDB mapping              : {confirmed_indb:>5}             │
  │  Needs manual mapping                : {len(needs_manual):>5}             │
  │  Class with fewest images            : {min_cls} ({split_counts[min_cls]['train']+split_counts[min_cls]['val']+split_counts[min_cls]['test']})
  │  Class with most images              : {max_cls} ({split_counts[max_cls]['train']+split_counts[max_cls]['val']+split_counts[max_cls]['test']})
  │  Average images per class            : {avg_total:>6.1f}            │
  └──────────────────────────────────────────────────────────┘
""")

if needs_manual:
    print(f"  Classes needing manual INDB mapping ({len(needs_manual)}):")
    for cls in sorted(needs_manual):
        total = split_counts[cls]["train"] + split_counts[cls]["val"] + split_counts[cls]["test"]
        print(f"    - {cls:<35}  ({total} images)")

if low_classes:
    print(f"\n  Low-data classes moved to low_data_classes/ ({len(low_classes)}):")
    for cls in sorted(low_classes):
        print(f"    - {cls}  ({merged_counts[cls]} images)")

print(f"\n[OK] TASK 6 COMPLETE\n")
separator()
print(f"  Output directory : {OUTPUT_DIR.resolve()}")
print(f"  class_map.json   : {os.path.abspath('class_map.json')}")
separator()
