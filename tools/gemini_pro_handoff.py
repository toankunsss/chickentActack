#!/usr/bin/env python3
"""Human-in-the-loop Gemini Pro asset handoff for this Godot project.

This tool intentionally never calls an image API. It writes clear generation
tickets for Gemini Pro web, then imports a downloaded image into Godot at the
correct display resolution.
"""

from __future__ import annotations

import argparse
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image


PROJECT_ROOT = Path(__file__).resolve().parents[1]
REQUESTS_ROOT = PROJECT_ROOT / "asset_requests"
PENDING_DIR = REQUESTS_ROOT / "pending"
DONE_DIR = REQUESTS_ROOT / "done"
INBOX_DIR = PROJECT_ROOT / "assets" / "inbox"
GENERATED_DIR = PROJECT_ROOT / "assets" / "generated" / "ui"
MANIFEST_PATH = REQUESTS_ROOT / "manifest.json"
STYLE_REFERENCE = "../mutation-farm/assets/icons/cozy/Icon9.png"


SHOP_ITEMS = {
    "shop_chest": "a single closed treasure chest",
    "shop_coin_pouch": "a single tied coin pouch with a tiny mint-green coin glint",
    "shop_refresh": "a single circular refresh symbol made from two chunky curved arrows",
    "shop_daily_gift": "a single small wrapped daily reward gift box with ribbon and a tiny mint-green sparkle",
}


def ensure_dirs() -> None:
    for directory in (PENDING_DIR, DONE_DIR, INBOX_DIR, GENERATED_DIR):
        directory.mkdir(parents=True, exist_ok=True)


def ticket_path(asset_id: str, directory: Path = PENDING_DIR) -> Path:
    return directory / f"{asset_id}.json"


def build_prompt(description: str) -> str:
    return (
        "Create one mobile-game UI icon. "
        f"Subject: {description}. "
        "Match the attached style reference: cozy hand-painted cartoon, bold dark outline, "
        "soft rounded forms, compact silhouette, warm cream and honey palette with restrained "
        "mint-green accents. Center the icon with 10% padding, keep it readable at 128x128 pixels. "
        "Use a uniform pale warm-cream background (#F7F0E6). No text, letters, numbers, logos, "
        "watermarks, characters, or extra objects. Output a square 1024x1024 PNG."
    )


def write_ticket(asset_id: str, description: str) -> Path:
    ensure_dirs()
    path = ticket_path(asset_id)
    if path.exists() or ticket_path(asset_id, DONE_DIR).exists():
        raise FileExistsError(f"Ticket already exists for {asset_id}")

    ticket = {
        "id": asset_id,
        "status": "pending_manual_generation",
        "kind": "ui_icon",
        "description": description,
        "style_reference": STYLE_REFERENCE,
        "source_size_px": [1024, 1024],
        "display_size_px": [128, 128],
        "inbox_path": f"assets/inbox/{asset_id}.png",
        "output_path": f"assets/generated/ui/{asset_id}.png",
        "gemini_prompt": build_prompt(description),
    }
    path.write_text(json.dumps(ticket, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return path


def make_shop_pack(_: argparse.Namespace) -> None:
    created = [write_ticket(asset_id, description) for asset_id, description in SHOP_ITEMS.items()]
    for path in created:
        print(path.relative_to(PROJECT_ROOT))


def create_ticket(args: argparse.Namespace) -> None:
    print(write_ticket(args.id, args.description).relative_to(PROJECT_ROOT))


def load_ticket(asset_id: str) -> tuple[Path, dict]:
    path = ticket_path(asset_id)
    if not path.exists():
        raise FileNotFoundError(f"No pending ticket: {path.relative_to(PROJECT_ROOT)}")
    return path, json.loads(path.read_text(encoding="utf-8"))


def update_manifest(ticket: dict, image_size: tuple[int, int]) -> None:
    manifest = []
    if MANIFEST_PATH.exists():
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    manifest = [entry for entry in manifest if entry["id"] != ticket["id"]]
    manifest.append({
        "id": ticket["id"],
        "kind": ticket["kind"],
        "path": ticket["output_path"],
        "display_size_px": ticket["display_size_px"],
        "source_size_px": list(image_size),
        "source": "Gemini Pro manual handoff",
        "imported_at": datetime.now(timezone.utc).isoformat(),
    })
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def ingest(args: argparse.Namespace) -> None:
    ensure_dirs()
    ticket_file, ticket = load_ticket(args.id)
    incoming = INBOX_DIR / f"{args.id}.png"
    if not incoming.exists():
        raise FileNotFoundError(
            f"Put the downloaded Gemini image at {incoming.relative_to(PROJECT_ROOT)} first."
        )

    output = PROJECT_ROOT / ticket["output_path"]
    if output.exists() and not args.replace:
        raise FileExistsError(f"Output already exists: {output}. Use --replace to update it.")

    with Image.open(incoming) as image:
        source_size = image.size
        if image.mode not in ("RGB", "RGBA"):
            image = image.convert("RGBA")
        target_size = tuple(ticket["display_size_px"])
        image.resize(target_size, Image.Resampling.LANCZOS).save(output, format="PNG")

    update_manifest(ticket, source_size)
    ticket["status"] = "imported"
    ticket["imported_source"] = str(incoming.relative_to(PROJECT_ROOT)).replace("\\", "/")
    done_file = ticket_path(args.id, DONE_DIR)
    done_file.write_text(json.dumps(ticket, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    ticket_file.unlink()
    print(output.relative_to(PROJECT_ROOT))


def main() -> None:
    parser = argparse.ArgumentParser(description="Gemini Pro web-to-Godot asset handoff")
    sub = parser.add_subparsers(dest="command", required=True)

    pack = sub.add_parser("make-shop-pack", help="Create the four planned Shop icon tickets")
    pack.set_defaults(func=make_shop_pack)

    create = sub.add_parser("create", help="Create one manual Gemini Pro generation ticket")
    create.add_argument("--id", required=True, help="Stable asset id, e.g. shop_egg")
    create.add_argument("--description", required=True, help="Single icon subject")
    create.set_defaults(func=create_ticket)

    ingest_parser = sub.add_parser("ingest", help="Resize a downloaded PNG and add it to the game")
    ingest_parser.add_argument("--id", required=True, help="Ticket id and inbox PNG name")
    ingest_parser.add_argument("--replace", action="store_true", help="Replace an existing generated icon")
    ingest_parser.set_defaults(func=ingest)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
