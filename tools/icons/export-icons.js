#!/usr/bin/env node
// 터치 조작 버튼 아이콘 내보내기 (m6-14 C2).
//   assets/icons/<이름>.svg  →  assets/icons/png/<이름>.png (256px, 투명 배경)
//   + 확인용 시트 docs/renders/icons/touch-icons-sheet.png (버튼 바탕 위 256px·48px·44px, 쿨다운 덮개 예시)
// 실행: 저장소 맨 위에서 `node tools/icons/export-icons.js`
//   필요: Node 18+, playwright + Chromium (`npm i -g playwright && npx playwright install chromium`).
//   옵션: --size 256 (PNG 한 변 px), --only dive,grab (일부만), --sheet-only (PNG는 그대로 두고 시트만)
// PNG를 Roblox에 올리는 법은 docs/DEV-SETUP.md 3-22. 올린 id는 src/shared/IconAssets.luau에 적어요.

const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright");

const ROOT = path.resolve(__dirname, "..", "..");
const ICON_DIR = path.join(ROOT, "assets", "icons");
const PNG_DIR = path.join(ICON_DIR, "png");
const SHEET_PATH = path.join(ROOT, "docs", "renders", "icons", "touch-icons-sheet.png");

// 버튼 순서·이름 = src/shared/IconAssets.luau NAMES
const ICONS = [
	{ name: "dive", label: "dive (🤸 다이브)" },
	{ name: "grab", label: "grab (✊ 잡기)" },
	{ name: "attack", label: "attack (💥 공격)" },
	{ name: "dynamite", label: "dynamite (🧨 점화)" },
];

// 버튼 바탕 = TouchButtonFace (RoomUiKit Kit.Color.Row + Wood 테두리, 아이콘 = 지름 × ICON_SCALE)
const PLATE = "#FCF2E0";
const PLATE_SHADE = "#E2D6C6";
const WOOD = "#7A4A2A";
const ICON_SCALE = 0.78;

function parseArgs(argv) {
	const args = { size: 256, only: null, sheetOnly: false };
	for (let i = 0; i < argv.length; i++) {
		if (argv[i] === "--size") args.size = Number(argv[++i]);
		else if (argv[i] === "--only") args.only = argv[++i].split(",");
		else if (argv[i] === "--sheet-only") args.sheetOnly = true;
	}
	return args;
}

function readSvg(name) {
	return fs.readFileSync(path.join(ICON_DIR, `${name}.svg`), "utf8");
}

function dataUrl(svg) {
	return "data:image/svg+xml;base64," + Buffer.from(svg).toString("base64");
}

async function exportPng(page, name, size) {
	const svg = readSvg(name);
	await page.setViewportSize({ width: size, height: size });
	await page.setContent(
		`<html><body style="margin:0;background:transparent">` +
			`<img src="${dataUrl(svg)}" width="${size}" height="${size}" style="display:block"></body></html>`,
	);
	await page.waitForFunction(() => document.images[0] && document.images[0].complete);
	const out = path.join(PNG_DIR, `${name}.png`);
	await page.screenshot({ path: out, omitBackground: true, clip: { x: 0, y: 0, width: size, height: size } });
	return out;
}

// 버튼 하나 (지름 d, 아이콘 = d × ICON_SCALE). cooldown이 있으면 아래에서 차오른 덮개 + 숫자
function buttonHtml(name, d, cooldown) {
	const stroke = Math.max(2, Math.min(6, Math.round(d * 0.06)));
	const icon = Math.round(d * ICON_SCALE);
	const cover = cooldown
		? `<div style="position:absolute;inset:0;border-radius:50%;background:linear-gradient(to bottom,` +
			`rgba(0,0,0,0) ${100 - cooldown.fraction * 100}%,rgba(0,0,0,0.6) ${100 - cooldown.fraction * 100}%)"></div>` +
			`<div style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center;` +
			`font:700 ${Math.round(d * 0.36)}px 'Fredoka One','Arial Rounded MT Bold',Arial,sans-serif;color:#fff;` +
			`-webkit-text-stroke:${Math.max(1, d * 0.02)}px #1F2E4D">${cooldown.text || ""}</div>`
		: "";
	return (
		`<div style="position:relative;width:${d}px;height:${d}px;border-radius:50%;box-sizing:border-box;` +
		`background:linear-gradient(${PLATE},${PLATE_SHADE});border:${stroke}px solid ${WOOD};` +
		`display:flex;align-items:center;justify-content:center;flex:none">` +
		`<img src="${dataUrl(readSvg(name))}" width="${icon}" height="${icon}">${cover}</div>`
	);
}

// 게임 화면 흉내 바탕 (밝은 주방·어두운 아레나 둘 다 확인)
const SCENES = [
	{ id: "kitchen", css: "linear-gradient(160deg,#cfe3ea,#e9d7bd 55%,#b98a5e)" },
	{ id: "arena", css: "linear-gradient(160deg,#2b3550,#4a3a33 60%,#1d1a22)" },
];

function sheetHtml(names) {
	const rows = names
		.map((name) => {
			const label = ICONS.find((icon) => icon.name === name).label;
			const smalls = SCENES.map(
				(scene) =>
					`<div style="background:${scene.css};padding:14px;border-radius:10px;display:flex;gap:14px;align-items:center">` +
					buttonHtml(name, 48) +
					buttonHtml(name, 44) +
					(name === "attack" ? buttonHtml(name, 48, { fraction: 0.6, text: "5" }) : "") +
					(name === "dive" ? buttonHtml(name, 48, { fraction: 0.5 }) : "") +
					`</div>`,
			).join("");
			return (
				`<div style="display:flex;align-items:center;gap:28px;padding:18px 0;border-bottom:2px dashed #d9c6a8">` +
				`<div style="width:170px;font:700 20px Arial,sans-serif;color:#2B211C">${label}</div>` +
				buttonHtml(name, 256) +
				`<div style="display:flex;flex-direction:column;gap:12px">${smalls}` +
				`<div style="font:14px Arial,sans-serif;color:#78604E">48px · 44px${
					name === "attack" ? " · cooldown 5s" : name === "dive" ? " · cooldown 50%" : ""
				}</div></div>` +
				`<div style="display:flex;gap:10px;align-items:flex-end">` +
				`<img src="${dataUrl(readSvg(name))}" width="96" height="96" style="background:#fff;border:1px solid #ddd">` +
				`<img src="${dataUrl(readSvg(name))}" width="32" height="32" style="background:#fff;border:1px solid #ddd">` +
				`</div></div>`
			);
		})
		.join("");
	// 휴대폰 실제 배치 흉내 (점프 70 → 버튼 60, UiLayout.touchButtons 기본 배치)
	const jumpX = 640 - 95;
	const jumpY = 220 - 90;
	const size = 60;
	const gap = 11;
	const inset = 5;
	const at = {
		dive: { x: jumpX - gap - size, y: jumpY + inset },
		grab: { x: jumpX + inset, y: jumpY - gap - size },
		attack: { x: jumpX - gap - size, y: jumpY - gap - size },
	};
	const layout =
		`<div style="margin-top:18px;font:700 18px Arial,sans-serif;color:#2B211C">phone layout (jump 70px → buttons 60px)</div>` +
		`<div style="position:relative;width:640px;height:220px;margin-top:8px;border-radius:12px;background:${SCENES[0].css}">` +
		Object.entries(at)
			.map(([name, p]) => `<div style="position:absolute;left:${p.x}px;top:${p.y}px">${buttonHtml(name, size)}</div>`)
			.join("") +
		`<div style="position:absolute;left:${jumpX}px;top:${jumpY}px;width:70px;height:70px;border-radius:50%;` +
		`background:rgba(255,255,255,0.35);border:3px solid rgba(255,255,255,0.8);box-sizing:border-box"></div>` +
		`</div>`;
	return (
		`<html><head></head>` +
		`<body style="margin:0;background:#F4E2C4;padding:24px;width:1100px">` +
		`<div style="font:700 26px Arial,sans-serif;color:#2B211C;margin-bottom:6px">Touch button icons (m6-14)</div>` +
		`<div style="font:15px Arial,sans-serif;color:#78604E">assets/icons/*.svg → png 256px · plate = Kit.Color.Row + Wood stroke · icon = 78% of button</div>` +
		rows +
		layout +
		`</body></html>`
	);
}

async function main() {
	const args = parseArgs(process.argv.slice(2));
	const names = ICONS.map((icon) => icon.name).filter((name) => !args.only || args.only.includes(name));
	fs.mkdirSync(PNG_DIR, { recursive: true });
	fs.mkdirSync(path.dirname(SHEET_PATH), { recursive: true });
	const browser = await chromium.launch();
	try {
		const page = await browser.newPage();
		if (!args.sheetOnly) {
			for (const name of names) {
				console.log("png", path.relative(ROOT, await exportPng(page, name, args.size)));
			}
		}
		const sheet = await browser.newPage({ viewport: { width: 1148, height: 800 } });
		await sheet.setContent(sheetHtml(names), { waitUntil: "load" });
		await sheet.screenshot({ path: SHEET_PATH, fullPage: true });
		console.log("sheet", path.relative(ROOT, SHEET_PATH));
	} finally {
		await browser.close();
	}
}

main().catch((err) => {
	console.error(err);
	process.exit(1);
});
