#!/usr/bin/env python3
"""Extract a flat field table from raw/ capture bundles.

One row per capture. Field availability per site is the point: this answers the
extraction half of spike 2 without a WKWebView.
"""
import csv, json, re, sys, glob, os

FIELDS = ["id","site","listing_id","url","captured_at",
          "plate","make","model","variant","trim_input","body",
          "first_reg","year","mileage_km","price_eur","fuel","transmission",
          "power_hp","color","upholstery","doors","owners","seller_name",
          "seller_type","seller_city","seller_zip","warranty_field",
          "warranty_exists","warranty_in_text","image_count","first_image","source"]

# The verdicts in listings.csv turn on warranty more than on any other single
# criterion, so we record the structured claim and the free-text claim
# separately -- they disagree often enough to matter (see FINDINGS.md).
WARRANTY_TEXT = re.compile(r"garantie", re.I)

def num(s):
    if s is None: return None
    m = re.sub(r"[^\d]", "", str(s))
    return int(m) if m else None

def from_autoscout(d):
    nd = json.loads(d["nextData"])
    L = nd["props"]["pageProps"]["listingDetails"]
    v, s, loc = L["vehicle"], L.get("seller") or {}, L.get("location") or {}
    warranty = L.get("warranty")
    return dict(
        site="autoscout24.nl",
        listing_id=L.get("id"),
        plate=v.get("licensePlate") or (L.get("identifier") or {}).get("offerReference"),
        make=v.get("make"), model=v.get("model"), variant=v.get("variant"),
        trim_input=v.get("modelVersionInput"), body=v.get("bodyType"),
        first_reg=v.get("firstRegistrationDateRaw"),
        year=(v.get("firstRegistrationDateRaw") or "")[:4] or None,
        mileage_km=v.get("mileageInKmRaw"),
        price_eur=((L.get("prices") or {}).get("public") or {}).get("priceRaw"),
        fuel=(v.get("fuelCategory") or {}).get("formatted"),
        transmission=v.get("transmissionType"), power_hp=v.get("rawPowerInHp"),
        color=v.get("bodyColor"), upholstery=v.get("upholstery"),
        doors=v.get("numberOfDoors"), owners=v.get("noOfPreviousOwners"),
        seller_name=s.get("companyName"), seller_type=s.get("type"),
        seller_city=loc.get("city"), seller_zip=loc.get("zip"),
        warranty_field=warranty if isinstance(warranty, str) else None,
        warranty_exists=L.get("warrantyExists"),
        warranty_in_text=bool(WARRANTY_TEXT.search(L.get("description") or "")),
        image_count=len(L.get("images") or []),
        first_image=(L.get("images") or [None])[0],
        source="__NEXT_DATA__",
    )

def from_autotrack(d):
    car = next((json.loads(b) for b in d["jsonLd"]
                if json.loads(b).get("@type") == "Car"), {})
    html = d["outerHtml"]
    def dom(label):
        m = re.search(r">\s*%s\s*<[^>]*>\s*(?:<[^>]*>\s*)*([^<]{1,60}?)\s*<" % re.escape(label),
                      html, re.I)
        return m.group(1).strip() if m else None
    name = car.get("name") or d.get("title") or ""
    plate = (re.search(r"\[([A-Z0-9]{1,3}-[A-Z0-9]{1,3}-[A-Z0-9]{1,3})\]", name)
             or re.search(r"", ""))
    engine = car.get("vehicleEngine") or {}
    if isinstance(engine, list): engine = engine[0] if engine else {}
    return dict(
        site="autotrack.nl",
        listing_id=(re.search(r"/a/[^?#]*?(\d{6,})", d.get("url") or "") or [None, None])[1],
        plate=plate.group(1) if plate else (d.get("plateCandidates") or [None])[0],
        make=(car.get("brand") or {}).get("name") if isinstance(car.get("brand"), dict) else car.get("brand"),
        model=car.get("model"), variant=None,
        trim_input=dom("Uitvoering") or None, body=car.get("bodyType"),
        first_reg=None, year=car.get("vehicleModelDate"),
        mileage_km=num((car.get("mileageFromOdometer") or {}).get("value")
                       if isinstance(car.get("mileageFromOdometer"), dict)
                       else car.get("mileageFromOdometer")),
        price_eur=num((car.get("offers") or {}).get("price")
                      if isinstance(car.get("offers"), dict) else None),
        fuel=(engine.get("fuelType") if isinstance(engine, dict) else None),
        transmission=car.get("vehicleTransmission"),
        power_hp=num((engine.get("enginePower") or {}).get("value")
                     if isinstance(engine.get("enginePower"), dict) else None),
        color=car.get("color"), upholstery=None,
        doors=num(car.get("numberOfDoors")), owners=None,
        seller_name=dom("Verkoper") or dom("Dealer"), seller_type=None,
        seller_city=dom("Plaats") or dom("Vestiging"), seller_zip=None,
        warranty_field=None, warranty_exists=None,
        warranty_in_text=bool(WARRANTY_TEXT.search(html)),
        image_count=len(car.get("image") or []),
        first_image=(car.get("image") or [None])[0],
        source="json-ld:Car + og:title",
    )

def main(rawdir, out):
    rows = []
    for f in sorted(glob.glob(os.path.join(rawdir, "*.json"))):
        d = json.load(open(f))
        cid = os.path.basename(f)[:-5]
        if cid.startswith("favorites") or cid.startswith("favourites"):
            continue
        host = d.get("host", "")
        try:
            r = from_autoscout(d) if "autoscout24" in host else from_autotrack(d)
        except Exception as e:
            print(f"!! {cid}: {e}", file=sys.stderr); continue
        r["id"] = cid
        r["url"] = (d.get("url") or "").split("?")[0]
        r["captured_at"] = d.get("capturedAt")
        rows.append({k: r.get(k) for k in FIELDS})
    w = csv.DictWriter(open(out, "w", newline=""), fieldnames=FIELDS)
    w.writeheader(); w.writerows(rows)
    print(f"wrote {len(rows)} rows -> {out}")

if __name__ == "__main__":
    base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    main(os.path.join(base, "raw"), os.path.join(base, "extracted.csv"))
