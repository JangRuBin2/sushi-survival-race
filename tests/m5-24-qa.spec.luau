--!strict
-- m5-24 QA (docs/qa/m5-24-map-art-pass-v2.md): 아트 패스 v2 12맵을 렌더러 가짜 Roblox 환경(tools/render/Shims —
-- 진짜 @lune/roblox 인스턴스)으로 실제로 지어서, 그룹 테스트가 Art 데이터로만 본 것을 build 결과로 다시 확인해요.
--   판정 지문: Decor·IntroCamera 밖의 "판정에 쓰이는" 파츠(충돌·터치·쿼리 중 하나라도 켜짐, 또는 Spawns)의
--       개수·크기 합·origin 기준 위치 합·충돌 수·태그 수가 main(481eea0, m5-24 전)과 같아요.
--   판정 Model 하위에 새로 붙은 장식(도마 칸 EdgeTrim, 줄다리기 발판 Weights 장식)은 충돌·터치·쿼리가 모두 꺼져 있어요.
--   Decor 폴더의 모든 파츠는 충돌·터치·쿼리 꺼짐, anim/Wobble/EyeBlink 태그 파츠는 전부 Decor 하위.
--   실제 인스턴스 기준 조명 범위(SurfaceLight ≤ 16, Point·Spot ≤ 60), 그림자 조명 ≤ 2이고 움직이는 파츠에 없음.
--   소개 카메라 경로가 불투명(투명도 < 0.5) 파츠를 지나가지 않아요 — 판정 파츠 포함(그룹 테스트는 장식만 봤어요).
--   큰 반투명 장식 판(두 변 ≥ 40, 투명도 ≥ 0.5) 수가 main보다 늘지 않았어요.

local RobloxRequire = require("./lib/RobloxRequire")
local Test = require("./lib/Test")

local Shims = require("../tools/render/Shims")
local roblox = require("@lune/roblox")

local Shared = RobloxRequire.root("src/shared")
local Config = RobloxRequire.require(Shared.Config)
local IntroCameraLogic = RobloxRequire.require(Shared.IntroCameraLogic)

local RShared = Shims.root("src/shared")
local RMaps = Shims.require(RShared.maps)

local IDS = {
	"rotating-belt",
	"hot-plate",
	"skewer-showdown",
	"soy-swamp",
	"chef-board",
	"tug-of-war-platform",
	"ramen-rapids",
	"giant-jenga",
	"claw-machine-prize",
	"bouncy-castle-maze",
	"lantern-bridge",
	"cat-cafe-shelves",
}

type Fingerprint = { n: number, size: number, x: number, y: number, z: number, collide: number, tags: number }

-- main(481eea0, m5-24 병합 전)에서 같은 계산으로 잰 값. 판정 지오메트리를 바꾸면 이 값이 달라져요.
local MAIN_FINGERPRINT: { [string]: Fingerprint } = {
	-- m5-40 L1 길이 늘리기로 판정 지오메트리가 의도해서 바뀜 (옛 n = 57, size = 982.30, x = 239.50, y = 91.82, z = -2496.25, collide = 22, tags = 4)
	["rotating-belt"] = { n = 203, size = 3922.20, x = 867.00, y = 871.90, z = -42000.25, collide = 151, tags = 12 },
	["hot-plate"] = { n = 267, size = 3259.80, x = 3564.00, y = -4979.10, z = -7209.00, collide = 243, tags = 243 },
	["skewer-showdown"] = { n = 89, size = 934.22, x = 632.14, y = -42.60, z = 73.03, collide = 65, tags = 0 },
	-- m5-40 L1 (옛 n = 40, size = 1429.33, x = 174.10, y = 167.35, z = -1700.10, collide = 12, tags = 4)
	["soy-swamp"] = { n = 69, size = 3234.56, x = 268.80, y = 739.30, z = -9538.09, collide = 39, tags = 9 },
	["chef-board"] = { n = 85, size = 1259.80, x = 1136.00, y = -89.10, z = 0.00, collide = 61, tags = 61 },
	["tug-of-war-platform"] = { n = 25, size = 194.80, x = 420.00, y = 1.40, z = -1000.00, collide = 1, tags = 1 },
	-- m5-40 L2: 젓가락 다리·렌게 계단·두 번째 급류를 끼우고 결승을 -446으로 옮긴 뒤 다시 잰 값 (옛 값 n 57, size 1353.67,
	-- x 272.10, y -721.56, z -5197.64, collide 33, tags 10)
	["ramen-rapids"] = { n = 72, size = 1826.36, x = 304.60, y = -1124.20, z = -11017.37, collide = 48, tags = 11 },
	["giant-jenga"] = { n = 49, size = 610.80, x = 600.00, y = -2.60, z = 0.00, collide = 25, tags = 25 },
	["claw-machine-prize"] = { n = 88, size = 996.80, x = 912.00, y = -53.98, z = -3520.00, collide = 64, tags = 64 },
	-- m5-40 L3 길이 늘리기로 판정 지오메트리가 의도해서 바뀐 두 맵 (전: bouncy n 37·size 1205.80·x 286.50·y 61.40·
	-- z -1105.60·collide 13·tags 1 / lantern n 33·size 358.80·x 84.00·y -6.60·z -820.00·collide 9·tags 4)
	["bouncy-castle-maze"] = { n = 72, size = 2469.80, x = 555.10, y = 282.40, z = -8230.60, collide = 48, tags = 3 },
	["lantern-bridge"] = { n = 51, size = 727.80, x = 106.50, y = -24.60, z = -5925.00, collide = 27, tags = 7 },
	["cat-cafe-shelves"] = { n = 33, size = 430.80, x = 433.60, y = 155.40, z = -1320.00, collide = 9, tags = 9 },
}

-- main에서 잰 큰 반투명 장식 판 수 (m5-20 안개 패널 · 인형뽑기 유리 천장). 늘면 안 돼요 (스펙 D3·AC11).
local MAIN_BIG_TRANSLUCENT: { [string]: number } = {
	["soy-swamp"] = 4,
	["chef-board"] = 4,
	["ramen-rapids"] = 3,
	["claw-machine-prize"] = 1,
}

-- 소개 카메라 경로가 지나가는 불투명 파츠 중 main에도 있던 것(이번 패스와 무관). 고치면 지우세요.
--   soy-swamp·ramen-rapids StartWall: 출발 뒤 반투명(0.6) 판정 벽 — 0.5 기준이라 걸리지만 반투명이라 화면이 막히지 않아요.
local KNOWN_INTRO_THROUGH: { [string]: boolean } = {
	["soy-swamp/StartWall"] = true,
	["ramen-rapids/StartWall"] = true,
}

-- QA B1 (docs/qa/m5-24-map-art-pass-v2.md, P2)은 고쳤어요(젠가 ②와 ③ 사이에 탑 모서리 바깥 경유점 추가).
-- 새로 알려진 버그가 생기면 여기에 맵 id를 넣어 "아직 뚫는다"를 고정해요.
local KNOWN_INTRO_BUG: { [string]: boolean } = {}

local origin = roblox.CFrame.new(Config.Arena.SlotSpacing, Config.Arena.BaseHeight, 0)

local built: { [string]: any } = {}
local function build(id: string): any
	if built[id] == nil then
		built[id] = RMaps.get(id).build(origin)
	end
	return built[id]
end

local function under(inst: any, root: any, name: string): boolean
	local node = inst.Parent
	while node and node ~= root do
		if node.Name == name then
			return true
		end
		node = node.Parent
	end
	return false
end

local function pathOf(inst: any, root: any): string
	local names = {}
	local node = inst
	while node and node ~= root do
		table.insert(names, 1, node.Name)
		node = node.Parent
	end
	return table.concat(names, "/")
end

local function fingerprint(model: any): Fingerprint
	local fp: Fingerprint = { n = 0, size = 0, x = 0, y = 0, z = 0, collide = 0, tags = 0 }
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and not under(d, model, "Decor") and not under(d, model, "IntroCamera") then
			if d.CanCollide or d.CanTouch or d.CanQuery or under(d, model, "Spawns") then
				fp.n += 1
				fp.size += d.Size.X + d.Size.Y + d.Size.Z
				local p = origin:PointToObjectSpace(d.CFrame.Position)
				fp.x += math.abs(p.X)
				fp.y += p.Y
				fp.z += p.Z
				if d.CanCollide then
					fp.collide += 1
				end
				fp.tags += #d:GetTags()
			end
		end
	end
	return fp
end

local function near(a: number, b: number): boolean
	return math.abs(a - b) <= 0.02
end

return function(t: Test.Test)
	t.test(
		"QA AC1: 12맵 판정 지문(개수·크기·위치·충돌·태그)이 main(m5-24 전)과 같아요",
		function()
			for _, id in IDS do
				local got = fingerprint(build(id))
				local want = MAIN_FINGERPRINT[id]
				t.eq(got.n, want.n, `{id}: judgment part count`)
				t.eq(got.collide, want.collide, `{id}: CanCollide count`)
				t.eq(got.tags, want.tags, `{id}: tag count`)
				for _, key in { "size", "x", "y", "z" } do
					local g, w = (got :: any)[key], (want :: any)[key]
					t.ok(near(g, w), `{id}: {key} sum {g} ~= main {w}`)
				end
			end
		end
	)

	t.test(
		"QA AC1: 판정 Model 하위 새 장식(도마 칸 EdgeTrim·줄다리기 Weights)은 충돌·터치·쿼리 꺼짐",
		function()
			local chef = build("chef-board")
			local trims = 0
			for _, d in chef:GetDescendants() do
				if d:IsA("BasePart") and d.Name == "EdgeTrim" then
					trims += 1
					t.ok(not d.CanCollide and not d.CanTouch and not d.CanQuery, `chef {pathOf(d, chef)}`)
				end
			end
			t.ok(trims > 0, "chef-board EdgeTrim exists")
			local tug = build("tug-of-war-platform")
			local weights = tug:FindFirstChild("PlatformGroup"):FindFirstChild("Weights")
			t.ok(weights ~= nil, "Weights folder")
			for _, d in weights:GetDescendants() do
				if d:IsA("BasePart") then
					t.ok(not d.CanCollide and not d.CanTouch and not d.CanQuery, `tug {pathOf(d, tug)}`)
				end
			end
		end
	)

	t.test(
		"QA AC13: Decor 폴더의 모든 파츠는 충돌·터치·쿼리 꺼짐 (결승 3맵 포함 12맵)",
		function()
			for _, id in IDS do
				local model = build(id)
				local bad = 0
				local first = nil
				for _, d in model:GetDescendants() do
					if d:IsA("BasePart") and under(d, model, "Decor") then
						if d.CanCollide or d.CanTouch or d.CanQuery then
							bad += 1
							first = first or pathOf(d, model)
						end
					end
				end
				t.eq(bad, 0, `{id}: collidable/queryable decor (first {tostring(first)})`)
			end
		end
	)

	t.test(
		"QA AC5: 움직임 태그(Anim·Wobble·EyeBlink) 파츠는 전부 맨 위 Decor 폴더 하위예요",
		function()
			for _, id in IDS do
				local model = build(id)
				for _, d in model:GetDescendants() do
					if
						d:IsA("BasePart")
						and (d:HasTag("MapDecorAnim") or d:HasTag("MapDecorWobble") or d:HasTag("MapDecorEyeBlink"))
					then
						local p = pathOf(d, model)
						t.ok(string.sub(p, 1, 6) == "Decor/", `{id}: animated part outside Decor: {p}`)
						-- 꼬치 음식(Decor/<꼬치>Food)은 꼬치와 같이 움직여요 → anim 금지
						t.ok(string.find(p, "Food/", 1, true) == nil, `{id}: animated skewer food {p}`)
					end
				end
			end
		end
	)

	t.test(
		"QA AC5: 인형뽑기는 연장전에 모델 전체가 기울어요 — Decor의 anim은 CFrame을 안 건드리는 Pulse만",
		function()
			local model = build("claw-machine-prize")
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") and d:HasTag("MapDecorAnim") then
					t.eq(d:GetAttribute("AnimKind"), "Pulse", `claw {pathOf(d, model)}`)
				end
			end
		end
	)

	t.test(
		"QA 가이드 6절: 실제 조명 범위(Surface ≤ 16, Point·Spot ≤ 60), 그림자 ≤ 2이고 고정 파츠에만",
		function()
			for _, id in IDS do
				local model = build(id)
				local shadowed = 0
				for _, d in model:GetDescendants() do
					if d:IsA("SurfaceLight") then
						t.ok(d.Range <= 16, `{id}: SurfaceLight range {d.Range} on {pathOf(d.Parent, model)}`)
					elseif d:IsA("PointLight") or d:IsA("SpotLight") then
						t.ok(d.Range <= 60, `{id}: {d.ClassName} range {d.Range} on {pathOf(d.Parent, model)}`)
					end
					if (d:IsA("SurfaceLight") or d:IsA("PointLight") or d:IsA("SpotLight")) and d.Shadows then
						shadowed += 1
						local host = d.Parent
						t.ok(
							not (host:HasTag("MapDecorAnim") or host:HasTag("MapDecorWobble")),
							`{id}: shadowed light on animated part {pathOf(host, model)}`
						)
						t.ok(under(host, model, "Decor"), `{id}: shadowed light outside Decor {pathOf(host, model)}`)
					end
				end
				t.ok(shadowed >= 1 and shadowed <= 2, `{id}: shadowed lights {shadowed}`)
			end
		end
	)

	t.test(
		"QA AC11: 큰 반투명 장식 판(두 변 ≥ 40, 투명도 ≥ 0.5) 수가 main보다 늘지 않아요",
		function()
			for _, id in IDS do
				local model = build(id)
				local count = 0
				for _, d in model:GetDescendants() do
					if
						d:IsA("BasePart")
						and under(d, model, "Decor")
						and d.Transparency >= 0.5
						and d.Transparency < 0.99
					then
						local dims = { d.Size.X, d.Size.Y, d.Size.Z }
						table.sort(dims)
						if dims[2] >= 40 then
							count += 1
						end
					end
				end
				t.ok(count <= (MAIN_BIG_TRANSLUCENT[id] or 0), `{id}: big translucent decor panels {count}`)
			end
		end
	)

	t.test(
		"QA AC14: 소개 카메라 경로(실제 IntroCamera 점)가 불투명 파츠 속을 지나가지 않아요",
		function()
			for _, id in IDS do
				local model = build(id)
				local intro = model:FindFirstChild("IntroCamera")
				t.ok(intro ~= nil, `{id}: IntroCamera`)
				local points = intro:GetChildren()
				table.sort(points, function(a: any, b: any)
					return a.Name < b.Name
				end)
				local path = {}
				for _, p in points do
					local pos = p.CFrame.Position
					local look = pos + p.CFrame.LookVector * 10
					table.insert(path, {
						position = { x = pos.X, y = pos.Y, z = pos.Z },
						lookAt = { x = look.X, y = look.Y, z = look.Z },
					})
				end
				local solids = {}
				for _, d in model:GetDescendants() do
					if d:IsA("BasePart") and not under(d, model, "IntroCamera") and d.Transparency < 0.5 then
						table.insert(solids, d)
					end
				end
				local hits: { [string]: boolean } = {}
				for step = 0, 600 do
					local w = IntroCameraLogic.sample(path, step / 600).position
					local wp = roblox.Vector3.new(w.x, w.y, w.z)
					for _, part in solids do
						local rel = part.CFrame:PointToObjectSpace(wp)
						local h = part.Size / 2
						if math.abs(rel.X) < h.X and math.abs(rel.Y) < h.Y and math.abs(rel.Z) < h.Z then
							hits[part.Name] = true
						end
					end
				end
				local unexpected = {}
				for name in hits do
					if not KNOWN_INTRO_THROUGH[`{id}/{name}`] then
						table.insert(unexpected, name)
					end
				end
				table.sort(unexpected)
				if KNOWN_INTRO_BUG[id] then
					t.ok(
						#unexpected > 0,
						`{id}: intro path no longer passes through parts — remove it from KNOWN_INTRO_BUG`
					)
				else
					t.eq(unexpected, {}, `{id}: intro camera path passes through opaque parts`)
				end
			end
		end
	)
end
