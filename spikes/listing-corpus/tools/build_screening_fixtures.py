#!/usr/bin/env python3
"""Build the screening spike's fixture set from raw/ capture bundles.

Emits ../listing-screening/fixtures/cases.json: for each listing, the seller's
free-text description plus the structured facts the same page carries. The
screening spike feeds one or the other (or both) to a model and grades the
answer against ../listing-screening/labels.csv.

Descriptions are marketing prose written by dealers. They routinely carry phone
numbers and email addresses, so those are redacted here rather than in the
consumer -- the fixture file is committed, the raw bundle it came from is the
thing to go back to if a redaction loses something.
"""
import html
import json
import os
import re
import sys

EMAIL = re.compile(r"\b[\w.+-]+@[\w-]+\.[\w.]+\b")
TAG = re.compile(r"<[^>]+>")
BLANKS = re.compile(r"\n\s*\n+")

# Phone numbers are matched loosely and then confirmed by counting digits, not by
# shape. Dealers write "0529-70 02 24", "+31 (0)527 - 728145" and "0345-688888",
# and a shape-based pattern that covers all three also eats dates like
# "01-08-2026". A Dutch number is 10 digits starting 0, or 31 + 9; a date is 8.
PHONE_CANDIDATE = re.compile(r"[+(]?\d[\d\s().\-]{7,18}\d")


def redact_phones(text: str) -> str:
    def replace(match: re.Match[str]) -> str:
        digits = re.sub(r"\D", "", match.group(0))
        is_phone = (len(digits) == 10 and digits.startswith("0")) or (
            len(digits) == 11 and digits.startswith("31")
        )
        return "[phone]" if is_phone else match.group(0)

    return PHONE_CANDIDATE.sub(replace, text)


def clean_description(raw: str | None) -> str:
    """HTML to readable lines. Tags become newlines: sellers use <br> and <li> as
    the only structure, and collapsing them to spaces destroys the package lists
    that the warranty question turns on."""
    if not raw:
        return ""
    text = html.unescape(TAG.sub("\n", raw))
    text = redact_phones(text)
    text = EMAIL.sub("[email]", text)
    lines = [line.strip() for line in text.split("\n")]
    return BLANKS.sub("\n", "\n".join(line for line in lines if line))


def equipment_ids(vehicle: dict) -> list[str]:
    equipment = vehicle.get("equipment") or {}
    if not isinstance(equipment, dict):
        return []
    return sorted(
        {
            item.get("id", "")
            for items in equipment.values()
            if isinstance(items, list)
            for item in items
            if isinstance(item, dict) and item.get("id")
        }
    )


def build_case(capture_id: str, bundle: dict) -> dict | None:
    if "autoscout24" not in bundle.get("host", ""):
        # Only AutoScout24 carries a seller description in structured form. The
        # AutoTrack captures have no __NEXT_DATA__ and no description block, so
        # they cannot pose the question at all.
        return None
    listing = json.loads(bundle["nextData"])["props"]["pageProps"]["listingDetails"]
    vehicle = listing["vehicle"]
    equipment = equipment_ids(vehicle)
    return {
        "id": capture_id,
        "site": "autoscout24.nl",
        "description": clean_description(listing.get("description")),
        # Everything the page states structurally about the three criteria. The
        # screening prompt gets these only in `full` mode; `text_only` withholds
        # them, which is what turns the criteria into abstention tests.
        "structured": {
            "warranty": listing.get("warranty"),
            "warrantyExists": listing.get("warrantyExists"),
            "equipment": equipment,
            "upholstery": vehicle.get("upholstery"),
            "make": vehicle.get("make"),
            "model": vehicle.get("model"),
            "trim": vehicle.get("modelVersionInput"),
            "mileageKm": vehicle.get("mileageInKmRaw"),
            "priceEur": ((listing.get("prices") or {}).get("public") or {}).get("priceRaw"),
            "firstRegistration": vehicle.get("firstRegistrationDateRaw"),
        },
    }


def main() -> int:
    base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    raw_dir = os.path.join(base, "raw")
    out_path = os.path.join(
        os.path.dirname(base), "listing-screening", "fixtures", "cases.json"
    )

    cases = []
    for name in sorted(os.listdir(raw_dir)):
        if not name.endswith(".json") or name.startswith(("favorites", "favourites")):
            continue
        with open(os.path.join(raw_dir, name), encoding="utf-8") as handle:
            bundle = json.load(handle)
        case = build_case(name[:-5], bundle)
        if case is not None:
            cases.append(case)

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as handle:
        json.dump(cases, handle, indent=2, ensure_ascii=False)
        handle.write("\n")

    lengths = sorted(len(case["description"]) for case in cases)
    print(f"wrote {len(cases)} cases -> {out_path}")
    print(
        f"description length: min {lengths[0]}  median {lengths[len(lengths) // 2]}  max {lengths[-1]} chars"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
