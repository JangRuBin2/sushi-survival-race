#!/usr/bin/env python3
"""Top-down concept diagrams for the large-map proposal (our own drawings).

Writes SVG files to the output dir given as argv[1]. Units are studs; each
diagram picks a px-per-stud scale. Course "forward" (local -Z) points up.
"""
import math
import os
import sys

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)

FONT = "Noto Sans CJK KR, Noto Sans CJK SC, sans-serif"
BG = "#FBF6EE"
INK = "#3A2E2A"
SUB = "#7A6A60"
WOOD = "#D9A066"
WOOD_D = "#B97F45"
RICE = "#FFFDF7"
SALMON = "#F28C6B"
NORI = "#2F4A3A"
SOY = "#5A3A2A"
TEAL = "#4FB3A9"
ORANGE = "#F2A541"
RED = "#D9534F"
BLUE = "#6FA8DC"
STEEL = "#B8C2CC"
GREEN = "#8BC34A"
LILAC = "#B39DDB"


class Svg:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.items = []

    def add(self, s):
        self.items.append(s)

    def rect(self, x, y, w, h, fill, stroke=None, rx=0, sw=1.5, op=1.0, dash=None):
        st = f' stroke="{stroke}" stroke-width="{sw}"' if stroke else ""
        da = f' stroke-dasharray="{dash}"' if dash else ""
        self.add(f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" rx="{rx}" fill="{fill}"{st}{da} opacity="{op}"/>')

    def circle(self, cx, cy, r, fill, stroke=None, sw=1.5, op=1.0, dash=None):
        st = f' stroke="{stroke}" stroke-width="{sw}"' if stroke else ""
        da = f' stroke-dasharray="{dash}"' if dash else ""
        self.add(f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.1f}" fill="{fill}"{st}{da} opacity="{op}"/>')

    def line(self, x1, y1, x2, y2, stroke, sw=2, dash=None, arrow=False):
        da = f' stroke-dasharray="{dash}"' if dash else ""
        mk = ' marker-end="url(#arrow)"' if arrow else ""
        self.add(f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" stroke="{stroke}" stroke-width="{sw}"{da}{mk}/>')

    def path(self, d, fill="none", stroke=INK, sw=2, op=1.0, arrow=False):
        mk = ' marker-end="url(#arrow)"' if arrow else ""
        self.add(f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" opacity="{op}"{mk}/>')

    def text(self, x, y, s, size=14, fill=INK, anchor="middle", weight=400):
        s = s.replace("&", "&amp;").replace("<", "&lt;")
        self.add(f'<text x="{x:.1f}" y="{y:.1f}" font-family="{FONT}" font-size="{size}" font-weight="{weight}" fill="{fill}" text-anchor="{anchor}">{s}</text>')

    def save(self, name):
        head = (
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}" viewBox="0 0 {self.w} {self.h}">'
            '<defs><marker id="arrow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="11" markerHeight="11" markerUnits="userSpaceOnUse" orient="auto-start-reverse">'
            f'<path d="M0,0 L10,5 L0,10 z" fill="{INK}"/></marker></defs>'
            f'<rect width="100%" height="100%" fill="{BG}"/>'
        )
        with open(os.path.join(OUT, name + ".svg"), "w", encoding="utf-8") as f:
            f.write(head + "".join(self.items) + "</svg>")


def header(svg, title, sub):
    svg.text(svg.w / 2, 34, title, 22, INK, weight=700)
    svg.text(svg.w / 2, 58, sub, 13, SUB)


def scale_bar(svg, x, y, k, studs=50):
    svg.line(x, y, x + studs * k, y, INK, 3)
    svg.line(x, y - 5, x, y + 5, INK, 2)
    svg.line(x + studs * k, y - 5, x + studs * k, y + 5, INK, 2)
    svg.text(x + studs * k / 2, y - 9, f"{studs} studs", 11, INK)


def spawn_grid(svg, cx, cy, k, cols, rows, gap):
    for r in range(rows):
        for c in range(cols):
            x = cx + (c - (cols - 1) / 2) * gap * k
            y = cy + (r - (rows - 1) / 2) * gap * k
            svg.circle(x, y, 2.2, SALMON)


def callout(svg, x_from, y, x_text, label, size=12, color=INK):
    svg.line(x_from, y, x_text - 6, y, "#9C8B80", 1.2, dash="3 3")
    svg.text(x_text, y + 4, label, size, color, anchor="start")


def legend(svg, x, y, items):
    for i, (color, label) in enumerate(items):
        yy = y + i * 20
        svg.rect(x, yy - 10, 14, 12, color, INK, rx=2, sw=1)
        svg.text(x + 20, yy, label, 12, INK, anchor="start")


# ---------------------------------------------------------------- 1. counter
def counter():
    W, L, k = 72, 520, 1.5
    svg = Svg(620, 940)
    header(svg, "① 초밥집 카운터 대횡단 (Race · 40명)", "폭 72 × 길이 약 520 studs · 갈림길 3개 → 합류 → 젓가락 들판 → 계산대 오르막 4줄")
    ox, oy = 150, 80 + L * k  # course origin (start edge) in px; forward = up
    X = lambda x: ox + (x + W / 2) * k
    Z = lambda z: oy - z * k
    # start plaza
    svg.rect(X(-36), Z(40), 72 * k, 40 * k, RICE, INK, rx=6)
    spawn_grid(svg, X(0), Z(20), k, 8, 5, 7)
    callout(svg, X(36), Z(20), 330, "출발 광장 · 스폰 40 (8×5, 간격 7)")
    # three lanes 40..200
    lanes = [(-27, "왼쪽: 회전 레일", TEAL), (0, "가운데: 접시 징검다리", RICE), (27, "오른쪽: 간장병 굴러옴", WOOD)]
    for lx, label, col in lanes:
        svg.rect(X(lx - 9), Z(200), 18 * k, 160 * k, col, INK, rx=4)
    # lane details
    for z in range(55, 200, 18):
        svg.line(X(-35), Z(z), X(-19), Z(z + 6), "#2E7D74", 2, arrow=True)
    for i, z in enumerate(range(52, 196, 16)):
        svg.circle(X(-4 if i % 2 else 4), Z(z), 5 * k, "#FFFFFF", BLUE, 2)
    for z in range(60, 200, 30):
        svg.circle(X(27), Z(z), 3.2 * k, SOY)
    svg.line(X(27), Z(198), X(27), Z(150), SOY, 2, dash="4 3", arrow=True)
    callout(svg, X(36), Z(150), 330, "갈림길 A (폭 18 × 3줄)")
    svg.text(330, Z(150) + 22, "왼: 회전 레일(밀림)", 11, SUB, anchor="start")
    svg.text(330, Z(150) + 38, "가운데: 접시 징검다리", 11, SUB, anchor="start")
    svg.text(330, Z(150) + 54, "오른: 간장병 굴러옴", 11, SUB, anchor="start")
    # merge plaza
    svg.rect(X(-36), Z(240), 72 * k, 36 * k, RICE, INK, rx=6)
    callout(svg, X(36), Z(220), 330, "합류 광장 (숨 돌리기)")
    # chopstick field
    svg.rect(X(-36), Z(380), 72 * k, 140 * k, "#F6E7C8", INK, rx=4)
    for i, (x, z) in enumerate([(-20, 270), (10, 290), (-5, 320), (22, 335), (-25, 355), (8, 365)]):
        svg.circle(X(x), Z(z), 7 * k, RED, RED, 1, op=0.18, dash="3 3")
        svg.rect(X(x - 1), Z(z + 6), 2 * k, 12 * k, WOOD_D, rx=1)
    callout(svg, X(36), Z(310), 330, "젓가락 들판 (폭 72)")
    svg.text(330, Z(310) + 22, "그림자 1.5초 → 쿡! 넉백", 11, SUB, anchor="start")
    # register ramps
    for i in range(4):
        x = -27 + i * 18
        svg.rect(X(x - 7), Z(500), 14 * k, 120 * k, STEEL, INK, rx=3)
    callout(svg, X(36), Z(440), 330, "계산대 오르막 4줄 (폭 14)")
    svg.rect(X(-36), Z(520), 72 * k, 20 * k, GREEN, INK, rx=4)
    svg.text(X(0), Z(510) + 4, "결승: 계산대 아치", 12, INK, weight=700)
    scale_bar(svg, 20, 900, k)
    legend(svg, 20, 110, [(TEAL, "레일(밀림)"), (RICE, "밥/접시 바닥"), (WOOD, "나무 카운터"), (STEEL, "오르막"), (RED, "경고 원")])
    svg.text(330, 870, "가장 좁은 곳 폭 14 (출발~30%는 18 이상)", 11, RED, anchor="start")
    svg.save("01-sushi-counter-crossing")


# ---------------------------------------------------------------- 2. bento doors
def bento():
    W, L, k = 80, 460, 1.6
    svg = Svg(620, 860)
    header(svg, "② 도시락 뚜껑 대탈출 (Race · 40명)", "폭 80 × 길이 약 460 studs · 문 줄 5개(8칸씩, 진짜 문 5→3) · 줄 사이마다 다른 방해")
    ox, oy = 140, 80 + L * k
    X = lambda x: ox + (x + W / 2) * k
    Z = lambda z: oy - z * k
    svg.rect(X(-40), Z(L), W * k, L * k, "#F3E3C3", INK, rx=6)
    svg.rect(X(-40), Z(40), W * k, 40 * k, RICE, INK, rx=6)
    spawn_grid(svg, X(0), Z(20), k, 8, 5, 8)
    rows = [(80, 5), (150, 4), (220, 4), (290, 3), (360, 3)]
    import random
    rnd = random.Random(7)
    for z, real in rows:
        reals = set(rnd.sample(range(8), real))
        for d in range(8):
            x = -40 + d * 10
            col = "#FFF3D6" if d in reals else "#C9A27A"
            svg.rect(X(x) + 1, Z(z + 3), 10 * k - 2, 6 * k, col, INK, rx=2, sw=1.2)
        svg.text(X(40) + 8, Z(z) + 4, f"진짜 {real}/8", 11, INK, anchor="start")
    zones = [(115, "우메보시 굴러옴", RED), (185, "간장 웅덩이(감속)", SOY), (255, "회전 젓가락 막대", WOOD_D), (325, "와사비 튕김판", GREEN)]
    for z, label, col in zones:
        svg.rect(X(-30), Z(z + 12), 60 * k, 24 * k, col, None, rx=6, op=0.2)
        svg.text(X(0), Z(z) + 4, label, 11, INK)
    svg.rect(X(-40), Z(L), W * k, 40 * k, GREEN, INK, rx=6, op=0.8)
    svg.text(X(0), Z(440), "결승: 젓가락 받침 아치", 12, INK, weight=700)
    scale_bar(svg, 20, 830, k)
    legend(svg, 380, 120, [("#FFF3D6", "깨지는 문 (종이 뚜껑)"), ("#C9A27A", "가짜 문 (튕겨 나옴)")])
    svg.text(280, 845, "문 배치는 라운드마다 서버가 정함 — 앞사람이 길을 연다", 12, SUB)
    svg.save("02-bento-door-dash")


# ---------------------------------------------------------------- 3. pantry shelves
def pantry():
    W, L, k = 96, 500, 1.4
    svg = Svg(640, 880)
    header(svg, "③ 팬트리 선반 대질주 (Race · 40명)", "폭 96 × 길이 약 500 studs · 떠 있는 선반 섬 + 양옆 환풍기 바람 + 굴러오는 통조림")
    ox, oy = 145, 80 + L * k
    X = lambda x: ox + (x + W / 2) * k
    Z = lambda z: oy - z * k
    # fans on sides
    for z in range(70, 460, 80):
        svg.rect(X(-48) - 26, Z(z + 10), 20, 20 * k, STEEL, INK, rx=3)
        svg.rect(X(48) + 6, Z(z + 10), 20, 20 * k, STEEL, INK, rx=3)
    svg.rect(X(-48), Z(40), W * k, 40 * k, RICE, INK, rx=6)
    spawn_grid(svg, X(0), Z(20), k, 8, 5, 8)
    shelves = [
        (-30, 50, 30, 70), (0, 50, 26, 70), (30, 50, 30, 70),
        (-24, 128, 40, 60), (24, 128, 40, 60),
        (-34, 196, 24, 70), (0, 196, 30, 70), (34, 196, 24, 70),
        (-20, 274, 46, 66), (26, 274, 34, 66),
        (-30, 348, 30, 64), (6, 348, 30, 64), (36, 348, 20, 64),
        (0, 420, 90, 40),
    ]
    for x, z, w, l in shelves:
        svg.rect(X(x - w / 2), Z(z + l), w * k, l * k, WOOD, WOOD_D, rx=3, sw=2)
    for z in (90, 240, 380):
        svg.line(X(-46), Z(z), X(-14), Z(z), BLUE, 2, dash="6 4", arrow=True)
    for z in (165, 310):
        svg.line(X(46), Z(z), X(14), Z(z), BLUE, 2, dash="6 4", arrow=True)
    for x, z in [(-24, 150), (24, 140), (-20, 300), (26, 290)]:
        svg.circle(X(x), Z(z), 4 * k, "#C0392B", INK, 1.2)
    callout(svg, X(48) + 30, Z(90), 360, "환풍기 바람 (파란 점선, 줄마다 반대)")
    callout(svg, X(48) + 30, Z(150), 360, "빨간 점: 통조림이 굴러옴")
    callout(svg, X(48) + 30, Z(230), 360, "선반 섬 사이 틈 6~10")
    callout(svg, X(48) + 30, Z(20), 360, "출발 · 스폰 40")
    svg.rect(X(-45), Z(L), 90 * k, 40 * k, GREEN, INK, rx=6, op=0.8)
    svg.text(X(0), Z(480), "결승: 큰 병뚜껑 위", 12, INK, weight=700)
    scale_bar(svg, 20, 855, k)
    svg.text(280, 870, "선반 사이 틈 6~10 (점프·다이브), 떨어지면 부활(m6-01)", 12, SUB)
    svg.save("03-pantry-shelf-dash")


# ---------------------------------------------------------------- 4. lazy susan
def lazy():
    k = 4.0
    svg = Svg(700, 720)
    header(svg, "④ 중식당 회전 원판 (Survival · 40명)", "반지름 72 studs · 고리 4개가 번갈아 반대로 돎 · 고리마다 빈칸(구멍) · 75초")
    cx, cy = 350, 390
    rings = [(10, 26, "CW", "#F7D9B5"), (28, 44, "CCW", "#F3C99A"), (46, 60, "CW", "#EEB984"), (62, 72, "CCW", "#E8A96E")]
    for r_in, r_out, d, col in reversed(rings):
        svg.circle(cx, cy, r_out * k, col, INK, 2)
        svg.circle(cx, cy, r_in * k, BG, INK, 1)
    svg.circle(cx, cy, 10 * k, "#9CCFD8", INK, 2)
    svg.text(560, 160, "가운데: 유리 회전판(고정)", 12, INK)
    # holes: pie slices
    import math as m
    def slice_(r_in, r_out, a0, a1, fill):
        a0r, a1r = m.radians(a0), m.radians(a1)
        p = (f"M{cx + r_in * k * m.cos(a0r):.1f},{cy + r_in * k * m.sin(a0r):.1f} "
             f"L{cx + r_out * k * m.cos(a0r):.1f},{cy + r_out * k * m.sin(a0r):.1f} "
             f"A{r_out * k:.1f},{r_out * k:.1f} 0 0,1 {cx + r_out * k * m.cos(a1r):.1f},{cy + r_out * k * m.sin(a1r):.1f} "
             f"L{cx + r_in * k * m.cos(a1r):.1f},{cy + r_in * k * m.sin(a1r):.1f} "
             f"A{r_in * k:.1f},{r_in * k:.1f} 0 0,0 {cx + r_in * k * m.cos(a0r):.1f},{cy + r_in * k * m.sin(a0r):.1f} Z")
        svg.path(p, fill=fill, stroke=INK, sw=1)
    holes = {0: [(20, 50)], 1: [(110, 140), (290, 320)], 2: [(0, 25), (150, 175), (250, 275)], 3: [(60, 80), (200, 220), (320, 340)]}
    for i, (r_in, r_out, d, col) in enumerate(rings):
        for a0, a1 in holes[i]:
            slice_(r_in + 0.5, r_out - 0.5, a0, a1, "#4A3B35")
    # bowls (sweeping bumps)
    for i, (r_in, r_out, d, col) in enumerate(rings):
        rm = (r_in + r_out) / 2
        for a in (200 + i * 40, 80 + i * 30):
            ar = m.radians(a)
            svg.circle(cx + rm * k * m.cos(ar), cy + rm * k * m.sin(ar), 4 * k, "#FFFFFF", RED, 2)
    # direction arrows
    for i, (r_in, r_out, d, col) in enumerate(rings):
        rm = (r_in + r_out) / 2 * k
        a0, a1 = (m.radians(-60), m.radians(-30)) if d == "CW" else (m.radians(-30), m.radians(-60))
        sweep = 1 if d == "CW" else 0
        p = f"M{cx + rm * m.cos(a0):.1f},{cy + rm * m.sin(a0):.1f} A{rm:.1f},{rm:.1f} 0 0,{sweep} {cx + rm * m.cos(a1):.1f},{cy + rm * m.sin(a1):.1f}"
        svg.path(p, stroke=INK, sw=2.5, arrow=True)
    legend(svg, 24, 110, [("#4A3B35", "빈칸(구멍) — 빠지면 탈락"), ("#FFFFFF", "반찬 그릇 — 밀어냄")])
    svg.text(560, 120, "면적 ≈ 16,300 studs²", 12, INK)
    svg.text(560, 138, "40명 → 1명당 약 400", 12, INK)
    scale_bar(svg, 24, 700, k, 25)
    svg.save("04-lazy-susan")


# ---------------------------------------------------------------- 5. banquet
def banquet():
    k = 6.0
    svg = Svg(720, 820)
    header(svg, "⑤ 연회상 쟁반 쓸기 (Survival · 40명)", "96 × 96 studs 상 위 · 쟁반 벽이 사방에서 밀려옴(점프 벽·구멍 벽) · 45초부터 가장자리 무너짐")
    ox, oy = 72, 110
    S = 96
    svg.rect(ox, oy, S * k, S * k, "#E9D9B0", INK, rx=8, sw=2.5)
    # tatami grid
    for i in range(1, 6):
        svg.line(ox + i * 16 * k, oy, ox + i * 16 * k, oy + S * k, "#CDBB8E", 1.5)
        svg.line(ox, oy + i * 16 * k, ox + S * k, oy + i * 16 * k, "#CDBB8E", 1.5)
    # shrink ring
    svg.rect(ox + 12 * k, oy + 12 * k, 72 * k, 72 * k, "none", RED, rx=4, sw=2.5, dash="10 6")
    svg.text(ox + 30 * k, oy + 12 * k + 22, "45초: 바깥 12 studs 무너짐 → 72 × 72", 13, RED, weight=700)
    # walls
    # low wall from top moving down
    svg.rect(ox + 4, oy + 24 * k, S * k - 8, 3 * k, ORANGE, INK, rx=3)
    svg.text(ox + S * k / 2, oy + 24 * k - 6, "낮은 쟁반 벽 (점프)", 12, INK)
    svg.line(ox + S * k / 2, oy + 28 * k, ox + S * k / 2, oy + 40 * k, INK, 2.5, arrow=True)
    # gap wall from left moving right
    for z0, z1 in [(0, 30), (42, 96)]:
        svg.rect(ox + 60 * k, oy + z0 * k, 4 * k, (z1 - z0) * k, LILAC, INK, rx=3)
    svg.text(ox + 66 * k, oy + 36 * k + 4, "← 구멍 (지나갈 곳)", 12, INK, anchor="start")
    svg.line(ox + 58 * k, oy + 70 * k, ox + 46 * k, oy + 70 * k, INK, 2.5, arrow=True)
    svg.text(ox + 52 * k, oy + 66 * k, "높은 벽(구멍 벽)", 11, INK)
    spawn_grid(svg, ox + 30 * k, oy + 64 * k, k, 8, 5, 6)
    svg.text(ox + 30 * k, oy + 82 * k, "스폰 40", 11, SUB)
    timeline = ["0~15초: 한쪽에서 낮은 벽", "15~45초: 두 방향, 구멍 벽 섞임", "45초~: 가장자리 무너짐, 벽 간격 짧아짐", "60~75초: 서든데스(벽 2장 동시)"]
    for i, t in enumerate(timeline):
        svg.text(ox, oy + S * k + 30 + i * 18, t, 12, INK, anchor="start")
    scale_bar(svg, 470, oy + S * k + 40, k, 16)
    svg.save("05-banquet-sweep")


# ---------------------------------------------------------------- 6. size compare
def compare():
    k = 0.85
    svg = Svg(900, 640)
    header(svg, "크기 비교 — 지금 맵 vs 대형 맵 (위에서 본 바닥 크기, 같은 축척)", "지금 Race 코스 폭 16~40 · 결승·Survival 반지름 24~52  →  대형 Race 폭 72~96 · Survival 반지름 72 / 96×96")
    base_y = 590
    items = [
        ("간장 늪\n폭 24", 24, 400, RICE),
        ("방방 미로\n폭 40", 40, 400, RICE),
        ("① 카운터\n(폭 72)", 72, 520, ORANGE),
        ("② 도시락\n(폭 80)", 80, 460, ORANGE),
        ("③ 팬트리\n(폭 96)", 96, 500, ORANGE),
    ]
    x = 50
    for label, w, l, col in items:
        svg.rect(x, base_y - l * k, w * k, l * k, col, INK, rx=3)
        for j, part in enumerate(label.split("\n")):
            svg.text(x + w * k / 2, base_y - l * k - 22 + j * 14, part, 11, INK)
        x += max(w * k, 60) + 40
    # circles
    cx = 640
    for label, r, col, cy in [("찻잎 정원 (결승, r 47)", 47, RICE, 210), ("④ 회전 원판 (r 72)", 72, ORANGE, 420)]:
        svg.circle(cx, cy, r * k * 1.4, col, INK, 2)
        svg.text(cx, cy + 4, label, 12, INK)
    svg.text(640, 110, "오른쪽 도형은 1.4배 확대해 그림", 11, SUB)
    svg.text(330, base_y + 20, "Race 길이는 지금 240~470(그림은 400) → 대형 460~520", 11, SUB)
    svg.save("00-size-compare")


counter()
bento()
pantry()
lazy()
banquet()
compare()
print("ok")
