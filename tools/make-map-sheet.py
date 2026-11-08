# Builds docs/overview/maps-all.jpg (one hero render per map) for docs/GAME-GUIDE.md.
# Usage: python3 tools/make-map-sheet.py . /tmp/out   (run from the repo root; needs Pillow + Noto Sans CJK)
import csv, os, sys, json
from PIL import Image, ImageDraw, ImageFont
root = sys.argv[1]
os.chdir(root)
MAPS = [
 ("Race", ["rotating-belt","soy-swamp","ramen-rapids","dessert-fridge","bouncy-castle-maze","lantern-bridge","dish-sink","space-conveyor"]),
 ("대형 Race", ["sushi-counter-crossing","bento-door-dash","pantry-shelf-dash"]),
 ("Survival", ["hot-plate","chef-board","tempura-pot","giant-jenga","cat-cafe-shelves","rice-cooker","fish-market"]),
 ("대형 Survival", ["lazy-susan","banquet-sweep"]),
 ("Final", ["skewer-showdown","ikura-bombs","tug-of-war-platform","claw-machine-prize","tea-garden","onsen-claw"]),
]
names = {}
with open("src/shared/Localization/Strings.csv", encoding="utf-8") as f:
    for row in csv.DictReader(f):
        k = row["Key"]
        if k.startswith("map.") and k.endswith(".name"):
            names[k[4:-5]] = row["Source"]
def pick(mid, prefs):
    d = f"docs/renders/{mid}"
    for p in prefs:
        if os.path.exists(f"{d}/{p}"): return f"{d}/{p}"
    return None
HERO = ["after-length-intro-01.png","after-intro-01.png","after-intro.png","after-length-intro-04.png","after-intro-03.png"]
EYE = ["after-length-eye.png","after-eye.png"]
TOP = ["after-length-overview.png","after-overview.png","after-length-top.png","after-top.png"]
chosen = {}
for kind, ids in MAPS:
    for mid in ids:
        chosen[mid] = {"kind": kind, "name": names[mid], "hero": pick(mid, HERO), "eye": pick(mid, EYE), "top": pick(mid, TOP)}
json.dump(chosen, open(sys.argv[2] + "/chosen.json", "w"), ensure_ascii=False, indent=1)
font_path = "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc"
def font(sz):
    return ImageFont.truetype(font_path, sz, index=1)  # KR
TW, TH, BAR, COLS, PAD = 480, 270, 46, 4, 10
COLOR = {"Race": (232,96,64), "대형 Race": (200,60,40), "Survival": (60,140,220), "대형 Survival": (40,90,190), "Final": (220,170,40)}
rows = []
for kind, ids in MAPS:
    rows.append(("header", kind, len(ids)))
    for i in range(0, len(ids), COLS):
        rows.append(("maps", ids[i:i+COLS]))
H = 90
for r in rows: H += 54 if r[0] == "header" else TH + BAR + PAD
W = COLS * (TW + PAD) + PAD
img = Image.new("RGB", (W, H), (28, 24, 30))
d = ImageDraw.Draw(img)
d.text((PAD+6, 20), "Sushi Survival Race — 맵 26개", font=font(40), fill=(250,240,230))
y = 90
for r in rows:
    if r[0] == "header":
        _, kind, n = r
        d.rectangle([PAD, y+8, PAD+10, y+44], fill=COLOR[kind])
        d.text((PAD+22, y+6), f"{kind}  ·  {n}개", font=font(30), fill=(250,240,230))
        y += 54; continue
    for c, mid in enumerate(r[1]):
        x = PAD + c * (TW + PAD)
        th = Image.open(chosen[mid]["hero"]).convert("RGB").resize((TW, TH), Image.LANCZOS)
        img.paste(th, (x, y))
        d.rectangle([x, y+TH, x+TW, y+TH+BAR], fill=(44, 38, 46))
        d.rectangle([x, y+TH, x+6, y+TH+BAR], fill=COLOR[chosen[mid]["kind"]])
        d.text((x+16, y+TH+6), chosen[mid]["name"], font=font(24), fill=(250,240,230))
        tw = d.textlength(mid, font=font(16))
        d.text((x+TW-tw-10, y+TH+14), mid, font=font(16), fill=(170,160,170))
    y += TH + BAR + PAD
os.makedirs("docs/overview", exist_ok=True)
img.save("docs/overview/maps-all.jpg", quality=86)
print(img.size, os.path.getsize("docs/overview/maps-all.jpg"))
for m,v in chosen.items():
    print(m, v["hero"], v["eye"], v["top"])
