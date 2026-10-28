#!/usr/bin/env python3
"""Build and verify the curated ABO demo catalog."""

from __future__ import annotations

import argparse
import csv
import gzip
import hashlib
import io
import json
import os
import re
import shutil
import sqlite3
import sys
import tarfile
import textwrap
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFont, ImageOps


TOOL_VERSION = "2.0.0"
SCRIPT_PATH = Path(__file__).resolve()
REPO_ROOT = SCRIPT_PATH.parents[3]
DEFAULT_MANIFEST = REPO_ROOT / "backend/sql/data/abo-curated-v2.json"
DEFAULT_SQL = REPO_ROOT / "backend/sql/local-demo-data.sql"
DEFAULT_ASSET_DIR = (
    REPO_ROOT / "backend/crmebimage/public/open-data/abo-curated-v2"
)
DEFAULT_CACHE = Path(os.environ.get("ABO_CACHE_DIR", "/tmp/crmeb-abo-cache"))
BLOCK_START = "-- BEGIN GENERATED ABO CURATED V2 PRODUCTS"
BLOCK_END = "-- END GENERATED ABO CURATED V2 PRODUCTS"
IMAGE_BASE_URL = (
    "https://amazon-berkeley-objects.s3.us-east-1.amazonaws.com/images/original/"
)
LISTINGS_ARCHIVE_URL = (
    "https://amazon-berkeley-objects.s3.amazonaws.com/archives/abo-listings.tar"
)
IMAGE_METADATA_URL = (
    "https://amazon-berkeley-objects.s3.amazonaws.com/images/metadata/images.csv.gz"
)
LICENSE_URL = (
    "https://amazon-berkeley-objects.s3.amazonaws.com/LICENSE-CC-BY-4.0.txt"
)
ATTRIBUTION_TEXT = """# Amazon Berkeley Objects Attribution

The product metadata and source images in this directory come from the
[Amazon Berkeley Objects (ABO) dataset](https://amazon-berkeley-objects.s3.amazonaws.com/index.html).

Credit for the data and images:

> Amazon.com

Credit for building the dataset, archives, and benchmark sets:

> Matthieu Guillaumin (Amazon.com), Thomas Dideriksen (Amazon.com),
> Kenan Deng (Amazon.com), Himanshu Arora (Amazon.com),
> Jasmine Collins (UC Berkeley), and Jitendra Malik (UC Berkeley)

ABO is licensed under the
[Creative Commons Attribution 4.0 International License](https://creativecommons.org/licenses/by/4.0/).
The complete license text is included in `LICENSE-CC-BY-4.0.txt`.

## Local modifications

- Selected 120 listings for balanced coverage of the local demo categories.
- Rewrote display titles and short descriptions in Chinese without adding
  unsupported product claims.
- Converted each approved main image to an 800x800 RGB JPEG by applying EXIF
  orientation, proportional Lanczos scaling, and white-background padding.
- Added deterministic local demo prices, inventory, sales, sorting, and SKU
  identifiers. These values do not come from ABO.

The source listing and image identifiers, source path, dimensions, and SHA-256
checksums are recorded in `backend/sql/data/abo-curated-v2.json`.

Amazon.com and the dataset builders do not endorse this project or the local
changes.
"""
PROHIBITED_LOCAL_TERMS = (
    "尼古丁",
    "戒烟",
    "壮阳",
    "成人用品",
    "枪支",
    "治疗痤疮",
    "治愈",
)


class CatalogError(RuntimeError):
    pass


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify the manifest, source mapping, images, and generated SQL",
    )
    parser.add_argument(
        "--offline",
        action="store_true",
        help="with --check, verify committed artifacts without the /tmp source cache",
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        default=DEFAULT_MANIFEST,
        help="curated manifest path",
    )
    parser.add_argument(
        "--sql",
        type=Path,
        default=DEFAULT_SQL,
        help="demo SQL path",
    )
    parser.add_argument(
        "--asset-dir",
        type=Path,
        default=DEFAULT_ASSET_DIR,
        help="generated image directory",
    )
    parser.add_argument(
        "--cache-dir",
        type=Path,
        default=DEFAULT_CACHE,
        help="ABO metadata and source image cache",
    )
    parser.add_argument(
        "--contact-sheets",
        type=Path,
        help="write category contact sheets to this directory",
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=8,
        help="parallel image download/normalization workers",
    )
    return parser.parse_args()


def load_manifest(path: Path) -> dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise CatalogError(f"Unable to load manifest {path}: {error}") from error


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate_manifest_structure(manifest: dict[str, Any]) -> list[dict[str, Any]]:
    if manifest.get("schema_version") != 2:
        raise CatalogError("Manifest schema_version must be 2")
    if manifest.get("catalog_id") != "abo-curated-v2":
        raise CatalogError("Manifest catalog_id must be abo-curated-v2")
    if manifest.get("derivation", {}).get("transform_version") != TOOL_VERSION:
        raise CatalogError(
            f"Manifest transform_version must match tool {TOOL_VERSION}"
        )

    products = manifest.get("products")
    if not isinstance(products, list) or len(products) != 120:
        raise CatalogError("Manifest must contain exactly 120 products")

    expected_ids = list(range(8101, 8221))
    actual_ids = [product.get("local_product_id") for product in products]
    if actual_ids != expected_ids:
        raise CatalogError("local_product_id values must be contiguous 8101-8220")

    for field in ("item_id", "main_image_id"):
        values = [product.get(field) for product in products]
        if any(not value for value in values) or len(set(values)) != len(values):
            raise CatalogError(f"{field} values must be present and unique")

    category_counts = Counter(
        product["catalog"]["category_id"] for product in products
    )
    if len(category_counts) != 34:
        raise CatalogError(
            f"Expected 34 leaf categories, found {len(category_counts)}"
        )
    if set(category_counts.values()) - {3, 4}:
        raise CatalogError(f"Every category must contain 3-4 products: {category_counts}")
    if Counter(category_counts.values()) != Counter({3: 16, 4: 18}):
        raise CatalogError(
            "Expected 16 categories with 3 products and 18 categories with 4"
        )

    expected_paths = set()
    for product in products:
        local_id = product["local_product_id"]
        catalog = product["catalog"]
        image = product["image"]
        title = catalog["title_zh"].strip()
        if not product.get("visual_reviewed"):
            raise CatalogError(f"{local_id}: visual_reviewed must be true")
        if not product.get("visual_review_note"):
            raise CatalogError(f"{local_id}: visual review note is missing")
        if not 8 <= len(title) <= 32:
            raise CatalogError(f"{local_id}: title length must be 8-32: {title}")
        local_text = " ".join(
            (title, catalog["subtitle_zh"], catalog["keywords"])
        )
        for term in PROHIBITED_LOCAL_TERMS:
            if term in local_text:
                raise CatalogError(f"{local_id}: prohibited local term: {term}")
        if product.get("approved_other_image_ids"):
            raise CatalogError(
                f"{local_id}: v2 catalog is main-image-only; approved others must be empty"
            )
        expected_path = (
            "crmebimage/public/open-data/abo-curated-v2/"
            f"{local_id}-main.jpg"
        )
        if image.get("local_path") != expected_path:
            raise CatalogError(f"{local_id}: invalid local image path")
        expected_paths.add(expected_path)
        if image.get("output_width") != 800 or image.get("output_height") != 800:
            raise CatalogError(f"{local_id}: output dimensions must be 800x800")
        if catalog.get("attr_name") != "款式" or catalog.get("attr_value") != "图示款":
            raise CatalogError(f"{local_id}: expected a single source-consistent SKU")
        if not 0 < catalog["cost"] <= catalog["price"] <= catalog["ot_price"]:
            raise CatalogError(f"{local_id}: invalid demo price ordering")

    if len(expected_paths) != 120:
        raise CatalogError("Local image paths must be unique")
    return products


def download_cache_file(url: str, target: Path, label: str) -> None:
    if target.exists():
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_suffix(target.suffix + ".part")
    last_error: Exception | None = None
    print(f"Downloading {label} to {target}...", flush=True)
    for attempt in range(3):
        try:
            request = urllib.request.Request(
                url, headers={"User-Agent": "crmeb-abo-catalog-builder/2.0"}
            )
            with urllib.request.urlopen(request, timeout=120) as response:
                with temporary.open("wb") as handle:
                    shutil.copyfileobj(response, handle, length=1024 * 1024)
            temporary.replace(target)
            return
        except (OSError, urllib.error.URLError, TimeoutError) as error:
            last_error = error
            temporary.unlink(missing_ok=True)
            time.sleep(1 + attempt * 2)
    raise CatalogError(f"Unable to download {label} from {url}: {last_error}")


def source_english_text(values: Any) -> str:
    if not isinstance(values, list) or not values:
        return ""
    selected = next(
        (
            value
            for value in values
            if isinstance(value, dict)
            and str(value.get("language_tag", "")).lower() == "en_us"
        ),
        values[0],
    )
    if not isinstance(selected, dict):
        return ""
    return str(selected.get("value", "")).strip()


def source_scalar(values: Any) -> str:
    if not isinstance(values, list) or not values or not isinstance(values[0], dict):
        return ""
    return str(values[0].get("value", "")).strip()


def build_listing_index(
    products: list[dict[str, Any]], archive_path: Path, database_path: Path
) -> None:
    if database_path.exists():
        return
    expected_keys = {
        (product["item_id"], product["domain_name"]) for product in products
    }
    products_by_key = {
        (product["item_id"], product["domain_name"]): product
        for product in products
    }
    rows: dict[tuple[str, str], tuple[Any, ...]] = {}
    print(
        f"Indexing {len(expected_keys)} selected listings from {archive_path}...",
        flush=True,
    )
    try:
        with tarfile.open(archive_path, "r") as archive:
            members = sorted(
                (
                    member
                    for member in archive.getmembers()
                    if re.fullmatch(
                        r"listings/metadata/listings_[0-9a-f]\.json\.gz",
                        member.name,
                    )
                ),
                key=lambda member: member.name,
            )
            if len(members) != 16:
                raise CatalogError(
                    f"Expected 16 listing metadata files, found {len(members)}"
                )
            for member in members:
                compressed = archive.extractfile(member)
                if compressed is None:
                    raise CatalogError(f"Unable to read {member.name}")
                with gzip.GzipFile(fileobj=compressed) as decoded:
                    with io.TextIOWrapper(decoded, encoding="utf-8") as text:
                        for line in text:
                            listing = json.loads(line)
                            key = (
                                str(listing.get("item_id", "")),
                                str(listing.get("domain_name", "")),
                            )
                            if key not in expected_keys:
                                continue
                            product = products_by_key[key]
                            expected_source = product["source"]
                            node_paths = " | ".join(
                                str(node.get("node_name") or node.get("path") or "")
                                for node in listing.get("node", [])
                                if isinstance(node, dict)
                            )
                            actual_source = {
                                "title_en": source_english_text(
                                    listing.get("item_name")
                                ),
                                "product_type": source_scalar(
                                    listing.get("product_type")
                                ),
                                "node_paths": node_paths,
                                "brand": source_english_text(listing.get("brand")),
                                "color": source_english_text(listing.get("color")),
                                "material": source_english_text(
                                    listing.get("material")
                                ),
                            }
                            for field, actual in actual_source.items():
                                if expected_source.get(field) != actual:
                                    raise CatalogError(
                                        f"{product['local_product_id']}: "
                                        f"official listing differs for {field}"
                                    )
                            rows[key] = (
                                key[0],
                                key[1],
                                expected_source["title_en"],
                                expected_source["product_type"],
                                expected_source["node_paths"],
                                expected_source["brand"],
                                expected_source["color"],
                                expected_source["material"],
                                str(listing.get("main_image_id", "")),
                                json.dumps(
                                    listing.get("other_image_id", []),
                                    ensure_ascii=False,
                                ),
                            )
    except (OSError, tarfile.TarError, gzip.BadGzipFile, json.JSONDecodeError) as error:
        raise CatalogError(f"Unable to index ABO listings: {error}") from error

    missing = expected_keys - rows.keys()
    if missing:
        raise CatalogError(
            f"{len(missing)} selected listings are missing from the official archive: "
            f"{sorted(missing)[:5]}"
        )

    temporary = database_path.with_suffix(database_path.suffix + ".part")
    temporary.unlink(missing_ok=True)
    connection = sqlite3.connect(temporary)
    try:
        connection.execute(
            """
            CREATE TABLE listings (
                item_id TEXT NOT NULL,
                domain_name TEXT NOT NULL,
                title_en TEXT NOT NULL,
                product_type TEXT NOT NULL,
                node_paths TEXT NOT NULL,
                brand TEXT NOT NULL,
                color TEXT NOT NULL,
                material TEXT NOT NULL,
                main_image_id TEXT NOT NULL,
                other_image_ids TEXT NOT NULL,
                PRIMARY KEY (item_id, domain_name)
            )
            """
        )
        connection.executemany(
            """
            INSERT INTO listings (
                item_id, domain_name, title_en, product_type, node_paths,
                brand, color, material, main_image_id, other_image_ids
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [rows[key] for key in sorted(rows)],
        )
        connection.commit()
    finally:
        connection.close()
    temporary.replace(database_path)


def prepare_source_metadata(
    products: list[dict[str, Any]], cache_dir: Path
) -> None:
    cache_dir.mkdir(parents=True, exist_ok=True)
    archive_path = cache_dir / "abo-listings.tar"
    images_path = cache_dir / "images.csv.gz"
    license_path = cache_dir / "LICENSE-CC-BY-4.0.txt"
    download_cache_file(
        LISTINGS_ARCHIVE_URL, archive_path, "ABO listing metadata archive"
    )
    download_cache_file(IMAGE_METADATA_URL, images_path, "ABO image metadata")
    download_cache_file(LICENSE_URL, license_path, "ABO license")
    build_listing_index(products, archive_path, cache_dir / "abo.sqlite3")


def load_image_metadata(path: Path, selected_ids: set[str]) -> dict[str, dict[str, Any]]:
    if not path.exists():
        raise CatalogError(f"Missing ABO image metadata: {path}")
    result: dict[str, dict[str, Any]] = {}
    with gzip.open(path, "rt", encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            image_id = row["image_id"]
            if image_id in selected_ids:
                result[image_id] = {
                    "path": row["path"],
                    "width": int(row["width"]),
                    "height": int(row["height"]),
                }
    missing = selected_ids - result.keys()
    if missing:
        raise CatalogError(
            f"{len(missing)} image IDs are missing from images.csv.gz: "
            f"{sorted(missing)[:5]}"
        )
    return result


def validate_source_mapping(
    products: list[dict[str, Any]], cache_dir: Path
) -> None:
    database_path = cache_dir / "abo.sqlite3"
    images_path = cache_dir / "images.csv.gz"
    if not database_path.exists():
        raise CatalogError(f"Missing indexed ABO listing metadata: {database_path}")

    selected_image_ids = {
        product["main_image_id"] for product in products
    } | {
        image_id
        for product in products
        for image_id in product["approved_other_image_ids"]
    }
    image_metadata = load_image_metadata(images_path, selected_image_ids)

    connection = sqlite3.connect(database_path)
    connection.row_factory = sqlite3.Row
    try:
        for product in products:
            local_id = product["local_product_id"]
            rows = connection.execute(
                """
                SELECT *
                FROM listings
                WHERE item_id = ? AND domain_name = ?
                """,
                (product["item_id"], product["domain_name"]),
            ).fetchall()
            if len(rows) != 1:
                raise CatalogError(
                    f"{local_id}: expected one source listing, found {len(rows)}"
                )
            row = dict(rows[0])
            if row["main_image_id"] != product["main_image_id"]:
                raise CatalogError(f"{local_id}: main_image_id does not match listing")
            source_other = set(json.loads(row["other_image_ids"] or "[]"))
            if not set(product["approved_other_image_ids"]) <= source_other:
                raise CatalogError(
                    f"{local_id}: approved image is not owned by source listing"
                )
            source = product["source"]
            comparisons = {
                "title_en": row["title_en"],
                "product_type": row["product_type"],
                "node_paths": row["node_paths"],
                "brand": row["brand"],
                "color": row["color"],
                "material": row["material"],
            }
            for key, actual in comparisons.items():
                if source.get(key) != actual:
                    raise CatalogError(f"{local_id}: source field drift: {key}")

            main_metadata = image_metadata[product["main_image_id"]]
            image = product["image"]
            if image["source_path"] != main_metadata["path"]:
                raise CatalogError(f"{local_id}: source image path mismatch")
            if image["source_width"] != main_metadata["width"]:
                raise CatalogError(f"{local_id}: source image width mismatch")
            if image["source_height"] != main_metadata["height"]:
                raise CatalogError(f"{local_id}: source image height mismatch")
    finally:
        connection.close()


def download_source_image(
    product: dict[str, Any], cache_dir: Path
) -> Path:
    source_path = product["image"]["source_path"]
    target = cache_dir / "curated-v2-source" / source_path
    if target.exists():
        return target
    target.parent.mkdir(parents=True, exist_ok=True)
    url = IMAGE_BASE_URL + urllib.parse.quote(source_path, safe="/")
    last_error: Exception | None = None
    for attempt in range(3):
        try:
            request = urllib.request.Request(
                url, headers={"User-Agent": "crmeb-abo-catalog-builder/2.0"}
            )
            with urllib.request.urlopen(request, timeout=60) as response:
                temporary = target.with_suffix(target.suffix + ".part")
                temporary.write_bytes(response.read())
                temporary.replace(target)
            return target
        except (OSError, urllib.error.URLError, TimeoutError) as error:
            last_error = error
            time.sleep(1 + attempt * 2)
    raise CatalogError(
        f"{product['local_product_id']}: unable to download {url}: {last_error}"
    )


def normalize_image(source_path: Path, target_path: Path) -> None:
    target_path.parent.mkdir(parents=True, exist_ok=True)
    temporary = target_path.with_suffix(".tmp.jpg")
    with Image.open(source_path) as opened:
        source = ImageOps.exif_transpose(opened)
        if source.mode in ("RGBA", "LA") or (
            source.mode == "P" and "transparency" in source.info
        ):
            rgba = source.convert("RGBA")
            background = Image.new("RGBA", rgba.size, "white")
            background.alpha_composite(rgba)
            source = background.convert("RGB")
        else:
            source = source.convert("RGB")
        source.thumbnail((800, 800), Image.Resampling.LANCZOS)
        canvas = Image.new("RGB", (800, 800), "white")
        canvas.paste(source, ((800 - source.width) // 2, (800 - source.height) // 2))
        canvas.save(
            temporary,
            "JPEG",
            quality=92,
            subsampling=0,
            optimize=False,
            progressive=False,
        )
    temporary.replace(target_path)


def build_one_image(
    product: dict[str, Any], cache_dir: Path, asset_dir: Path
) -> tuple[int, str, str]:
    source_path = download_source_image(product, cache_dir)
    target_path = asset_dir / f"{product['local_product_id']}-main.jpg"
    normalize_image(source_path, target_path)
    with Image.open(target_path) as image:
        if image.size != (800, 800) or image.mode != "RGB" or image.format != "JPEG":
            raise CatalogError(
                f"{product['local_product_id']}: normalized image is not RGB 800x800 JPEG"
            )
    return (
        product["local_product_id"],
        sha256_file(source_path),
        sha256_file(target_path),
    )


def build_images(
    products: list[dict[str, Any]],
    cache_dir: Path,
    asset_dir: Path,
    workers: int,
) -> None:
    asset_dir.mkdir(parents=True, exist_ok=True)
    results: dict[int, tuple[str, str]] = {}
    with ThreadPoolExecutor(max_workers=max(1, workers)) as executor:
        futures = {
            executor.submit(build_one_image, product, cache_dir, asset_dir): product
            for product in products
        }
        completed = 0
        for future in as_completed(futures):
            product = futures[future]
            try:
                local_id, source_hash, output_hash = future.result()
            except Exception as error:
                raise CatalogError(
                    f"Image build failed for {product['local_product_id']}: {error}"
                ) from error
            results[local_id] = (source_hash, output_hash)
            completed += 1
            if completed % 20 == 0 or completed == len(products):
                print(f"Built {completed}/{len(products)} images", flush=True)

    for product in products:
        source_hash, output_hash = results[product["local_product_id"]]
        product["image"]["source_sha256"] = source_hash
        product["image"]["output_sha256"] = output_hash


def ensure_source_images(
    products: list[dict[str, Any]], cache_dir: Path, workers: int
) -> None:
    with ThreadPoolExecutor(max_workers=max(1, workers)) as executor:
        futures = [
            executor.submit(download_source_image, product, cache_dir)
            for product in products
        ]
        for future in as_completed(futures):
            future.result()


def verify_images(
    products: list[dict[str, Any]],
    cache_dir: Path,
    asset_dir: Path,
    verify_sources: bool = True,
) -> None:
    expected_files = {
        f"{product['local_product_id']}-main.jpg" for product in products
    } | {"LICENSE-CC-BY-4.0.txt", "ATTRIBUTION.md"}
    actual_files = {
        path.name
        for path in asset_dir.iterdir()
        if path.is_file() and not path.name.startswith(".")
    }
    if actual_files != expected_files:
        missing = sorted(expected_files - actual_files)
        extra = sorted(actual_files - expected_files)
        raise CatalogError(f"Asset file set mismatch; missing={missing}, extra={extra}")

    for product in products:
        local_id = product["local_product_id"]
        target_path = asset_dir / f"{local_id}-main.jpg"
        image_data = product["image"]
        if not image_data.get("source_sha256") or not image_data.get("output_sha256"):
            raise CatalogError(f"{local_id}: image hashes are missing from manifest")
        if sha256_file(target_path) != image_data["output_sha256"]:
            raise CatalogError(f"{local_id}: output image SHA-256 mismatch")
        if verify_sources:
            source_path = cache_dir / "curated-v2-source" / image_data["source_path"]
            if not source_path.exists():
                raise CatalogError(f"{local_id}: cached source image is missing")
            if sha256_file(source_path) != image_data["source_sha256"]:
                raise CatalogError(f"{local_id}: source image SHA-256 mismatch")
        with Image.open(target_path) as image:
            if image.format != "JPEG" or image.mode != "RGB" or image.size != (800, 800):
                raise CatalogError(f"{local_id}: expected an RGB 800x800 JPEG")


def write_attribution(asset_dir: Path, cache_dir: Path) -> None:
    source_license = cache_dir / "LICENSE-CC-BY-4.0.txt"
    if not source_license.exists():
        raise CatalogError(f"Missing official ABO license: {source_license}")
    asset_dir.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source_license, asset_dir / "LICENSE-CC-BY-4.0.txt")
    (asset_dir / "ATTRIBUTION.md").write_text(
        ATTRIBUTION_TEXT, encoding="utf-8"
    )


def verify_attribution(
    asset_dir: Path, cache_dir: Path, verify_source_license: bool = True
) -> None:
    attribution_path = asset_dir / "ATTRIBUTION.md"
    license_path = asset_dir / "LICENSE-CC-BY-4.0.txt"
    if attribution_path.read_text(encoding="utf-8") != ATTRIBUTION_TEXT:
        raise CatalogError("ATTRIBUTION.md does not match the build tool")
    if license_path.stat().st_size < 1000:
        raise CatalogError("Committed ABO license is unexpectedly small")
    if verify_source_license:
        source_license = cache_dir / "LICENSE-CC-BY-4.0.txt"
        if sha256_file(license_path) != sha256_file(source_license):
            raise CatalogError("Committed license differs from the official ABO license")


def sql_quote(value: Any) -> str:
    if value is None:
        return "NULL"
    if isinstance(value, bool):
        return "1" if value else "0"
    if isinstance(value, (int, float)):
        return f"{value:.2f}" if isinstance(value, float) else str(value)
    return "'" + str(value).replace("'", "''") + "'"


def sql_values(rows: list[list[Any]]) -> str:
    return ",\n".join(
        "(" + ", ".join(sql_quote(value) for value in row) + ")" for row in rows
    )


def generate_sql_block(products: list[dict[str, Any]]) -> str:
    product_rows: list[list[Any]] = []
    sku_rows: list[list[Any]] = []
    for product in products:
        local_id = product["local_product_id"]
        catalog = product["catalog"]
        image = product["image"]
        source_marker = (
            f"abo-curated-v2:{product['item_id']}:{product['main_image_id']}"
        )
        product_rows.append(
            [
                local_id,
                product["item_id"],
                product["main_image_id"],
                catalog["title_zh"],
                catalog["subtitle_zh"],
                catalog["keywords"],
                str(catalog["category_id"]),
                image["local_path"],
                catalog["price"],
                catalog["ot_price"],
                catalog["cost"],
                catalog["stock"],
                catalog["sales"],
                catalog["sort"],
                catalog["unit_name"],
                catalog["weight"],
                source_marker,
            ]
        )
        offset = local_id - 8100
        sku_rows.append(
            [
                28100 + offset,
                local_id,
                18100 + offset,
                38100 + offset,
                catalog["attr_name"],
                catalog["attr_value"],
                f"D{offset:07d}",
                f"D{local_id}",
            ]
        )

    return f"""{BLOCK_START}
-- Generated by backend/sql/tools/build_abo_demo_catalog.py v{TOOL_VERSION}.
-- Source of truth: backend/sql/data/abo-curated-v2.json.
DROP TEMPORARY TABLE IF EXISTS tmp_demo_products;
CREATE TEMPORARY TABLE tmp_demo_products (
    id INT PRIMARY KEY,
    item_id VARCHAR(32) NOT NULL,
    main_image_id VARCHAR(64) NOT NULL,
    store_name VARCHAR(128) NOT NULL,
    store_info VARCHAR(256) NOT NULL,
    keyword VARCHAR(256) NOT NULL,
    cate_id VARCHAR(64) NOT NULL,
    image VARCHAR(256) NOT NULL,
    price DECIMAL(8, 2) NOT NULL,
    ot_price DECIMAL(8, 2) NOT NULL,
    cost DECIMAL(8, 2) NOT NULL,
    stock INT NOT NULL,
    sales INT NOT NULL,
    sort_num INT NOT NULL,
    unit_name VARCHAR(32) NOT NULL,
    weight DECIMAL(8, 2) NOT NULL,
    source_marker VARCHAR(255) NOT NULL
) ENGINE = MEMORY;

INSERT INTO tmp_demo_products VALUES
{sql_values(product_rows)};

DROP TEMPORARY TABLE IF EXISTS tmp_demo_skus;
CREATE TEMPORARY TABLE tmp_demo_skus (
    id INT PRIMARY KEY,
    product_id INT NOT NULL,
    attr_id INT NOT NULL,
    option_id INT NOT NULL,
    attr_name VARCHAR(32) NOT NULL,
    attr_value VARCHAR(32) NOT NULL,
    unique_key CHAR(8) NOT NULL,
    bar_code VARCHAR(50) NOT NULL,
    UNIQUE KEY uk_demo_sku_product (product_id)
) ENGINE = MEMORY;

INSERT INTO tmp_demo_skus VALUES
{sql_values(sku_rows)};

SET @demo_product_count = (SELECT COUNT(*) FROM tmp_demo_products);
{BLOCK_END}"""


def replace_generated_block(
    sql_text: str, generated_block: str, allow_legacy: bool
) -> str:
    if BLOCK_START in sql_text and BLOCK_END in sql_text:
        pattern = re.compile(
            re.escape(BLOCK_START) + r".*?" + re.escape(BLOCK_END),
            re.DOTALL,
        )
        replaced, count = pattern.subn(generated_block, sql_text, count=1)
        if count != 1:
            raise CatalogError("Unable to replace generated SQL block")
        return replaced
    if not allow_legacy:
        raise CatalogError("Generated SQL markers are missing")
    pattern = re.compile(
        r"-- Base product templates \(24\), extended below to 100 products\..*?"
        r"SET @demo_product_count = \(SELECT COUNT\(\*\) FROM tmp_demo_products\);",
        re.DOTALL,
    )
    replaced, count = pattern.subn(generated_block, sql_text, count=1)
    if count != 1:
        raise CatalogError("Unable to locate legacy product seed block")
    return replaced


def write_sql_block(sql_path: Path, products: list[dict[str, Any]]) -> None:
    sql_text = sql_path.read_text(encoding="utf-8")
    updated = replace_generated_block(
        sql_text, generate_sql_block(products), allow_legacy=True
    )
    sql_path.write_text(updated, encoding="utf-8")


def verify_sql_block(sql_path: Path, products: list[dict[str, Any]]) -> None:
    sql_text = sql_path.read_text(encoding="utf-8")
    expected = replace_generated_block(
        sql_text, generate_sql_block(products), allow_legacy=False
    )
    if expected != sql_text:
        raise CatalogError("Generated SQL product block is out of sync")


def contact_sheet_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = (
        "/System/Library/Fonts/STHeiti Medium.ttc",
        "/System/Library/Fonts/PingFang.ttc",
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
    )
    for candidate in candidates:
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size)
    return ImageFont.load_default()


def write_contact_sheets(
    products: list[dict[str, Any]], asset_dir: Path, output_dir: Path
) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    grouped: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for product in products:
        grouped[product["catalog"]["category_id"]].append(product)
    title_font = contact_sheet_font(28)
    label_font = contact_sheet_font(17)
    for category_id, category_products in grouped.items():
        canvas = Image.new("RGB", (1360, 510), "#f3f4f6")
        draw = ImageDraw.Draw(canvas)
        category_name = category_products[0]["catalog"]["category_name"]
        draw.text(
            (20, 15),
            f"{category_id} {category_name} ({len(category_products)})",
            font=title_font,
            fill="#111827",
        )
        for index, product in enumerate(category_products):
            x = index * 340 + 20
            with Image.open(
                asset_dir / f"{product['local_product_id']}-main.jpg"
            ) as source:
                preview = source.copy()
                preview.thumbnail((300, 300), Image.Resampling.LANCZOS)
            canvas.paste(preview, (x, 65))
            label = "\n".join(
                textwrap.wrap(
                    f"{product['local_product_id']} {product['item_id']} "
                    f"{product['catalog']['title_zh']}",
                    width=24,
                )
            )
            draw.multiline_text(
                (x, 375), label, font=label_font, fill="#111827", spacing=4
            )
        canvas.save(
            output_dir / f"{category_id}-{category_name}.jpg",
            "JPEG",
            quality=92,
        )


def main() -> int:
    args = parse_args()
    if args.offline and not args.check:
        raise CatalogError("--offline is only valid together with --check")
    manifest_path = args.manifest.resolve()
    sql_path = args.sql.resolve()
    asset_dir = args.asset_dir.resolve()
    cache_dir = args.cache_dir.resolve()

    manifest = load_manifest(manifest_path)
    products = validate_manifest_structure(manifest)
    if not args.offline:
        prepare_source_metadata(products, cache_dir)
        validate_source_mapping(products, cache_dir)

    if args.check:
        if not args.offline:
            ensure_source_images(products, cache_dir, args.workers)
        verify_attribution(
            asset_dir, cache_dir, verify_source_license=not args.offline
        )
        verify_images(
            products, cache_dir, asset_dir, verify_sources=not args.offline
        )
        verify_sql_block(sql_path, products)
        if args.contact_sheets:
            write_contact_sheets(
                products, asset_dir, args.contact_sheets.resolve()
            )
        print(
            "ABO curated catalog check passed: "
            "120 products, 34 categories, 120 verified images."
        )
        return 0

    build_images(products, cache_dir, asset_dir, args.workers)
    write_attribution(asset_dir, cache_dir)
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    write_sql_block(sql_path, products)
    verify_attribution(asset_dir, cache_dir)
    verify_images(products, cache_dir, asset_dir)
    verify_sql_block(sql_path, products)
    if args.contact_sheets:
        write_contact_sheets(products, asset_dir, args.contact_sheets.resolve())
    print(
        "ABO curated catalog built: "
        "120 products, 34 categories, SQL block synchronized."
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except CatalogError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(1)
