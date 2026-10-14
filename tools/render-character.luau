--!strict
-- 캐릭터(초밥 몸·스킨) 미리보기 렌더러 (m5-25). Studio 없이 게임과 같은 코드로 캐릭터를 만들어 PNG로 그려요.
--   lune run tools/render-character [skinId|all] [--view lineup|turntable|face|gameplay|all]
--        [--light studio|lobby|both] [--quality fast|high] [--out build/renders/characters]
-- 결과: <out>/<light>/
--   lineup.png + lineup.txt   모든 스킨 격자 (앞 3/4, 칸 아래 스킨 id 글자, txt는 칸 번호 → id·등급)
--   turntable/<id>.png        한 스킨의 앞 · 3/4 · 옆 · 뒤 · 위(비스듬히) 다섯 장을 한 줄로
--   face.png                  기본 계란초밥 얼굴 가까이
--   gameplay-back.png         Roblox 기본 3인칭 카메라(머리 뒤 12.5 studs, 70° 시야)로 본 내 캐릭터 + 앞의 두 명
--   gameplay-front.png        세 명이 카메라를 보고 12.5~16 studs에 서 있는 모습 (다가오는 상대·로비)
--   mobile-back.png / mobile-front.png   위 두 장을 480×270으로 (휴대폰 크기에서 읽히는지)
--   stats.txt                 스킨별 파츠 수·효과·외곽·재질·색 수·삼각형 수
-- 캐릭터는 게임과 같은 SushiBody.build(id)로 만들어요. 서버 캐릭터(AppearanceService.applyAppearance)는
-- 같은 Model을 HumanoidRootPart에 Motor6D로 붙이고 원래 아바타를 투명하게 숨길 뿐이고, 연출 인형(탈락·우승·단상·
-- 탈의실)도 같은 build라 모양이 같아요. 발바닥이 땅(y = 0)에 닿게 Body 중심을 GROUND_OFFSET 위에 둬요.
-- 조명: studio = 중립 회색 스튜디오(정오 무렵 해, 약한 대기, 색 보정 없음), lobby = 로비 조명(MapLighting.LOBBY).
-- 해가 캐릭터 앞쪽 왼편 30°에서 오도록 캐릭터를 돌려 세워요(어느 조명이든 얼굴에 빛). 같은 입력이면 같은 PNG 바이트.
-- 콘셉트 견본 (m5-27): --sample concept 이면 스킨 대신 SushiConceptSample(사용자 콘셉트 시트를 따른 연어초밥 견본,
-- 게임에서는 안 써요)을 그려요 → <out>/<light>/concept/ 에 turntable(서기)·turntable-run(달리기)·expressions(표정 4종)·
-- gameplay-back/front·mobile-back/front·compare(지금 게임 연어 ↔ 견본, 3/4·뒤). 배우 id "concept:<표정>:<자세>[:<스킨 id>]".
-- m5-28: --sample concept-tuna 처럼 콘셉트 몸 스킨 id를 주면 같은 그림 묶음을 그 토핑으로 <out>/<light>/<스킨 id>/에 그려요
-- (compare는 같은 음식의 지금 게임 스킨 ↔ 콘셉트, 예: tuna ↔ concept-tuna). --sample concept = concept-salmon 견본(예전 그대로).
-- m5-32 콘셉트 몸 게임 스킨 (SushiBody.CONCEPT_BODY에 있는 판매 스킨, 예 fresh-mackerel): 스킨 id를 주면 게임 레이아웃
-- (관절 포함)으로 <out>/<light>/<skinId>/에 turntable·expressions(표정 6종)·gameplay-back/front·mobile-back/front·
-- compare(golden-otoro·concept-salmon과)·poses(대표 자세 8칸)·flop-strip(착지 팔딱 8프레임)·sheet-compare(사용자 시트
-- 정면·3/4·후면 ↔ 같은 각도 렌더)를 그려요.
--   --pose <이름|all>  CharacterAnimLogic.fishTestPoses의 자세(Rest·TailLeft·TailRight·JumpArch·LandPeak·Knocked·Hurt·
--                      Splash)를 관절에 적용해 그려요 (SushiPose.posed — 테스트 AC4와 같은 계산). turntable에 붙어요
--   closeup.png       앞·3/4·뒤 큰 칸 (비평용)
--   --sheet <png>      sheet-compare에 붙일 시트 (기본 docs/고등어 초밥 캐릭터 시트.png)
-- 한계: tools/render-map과 같아요 (Sparkles·Decal·SurfaceGui·이름표는 안 그려요, 파티클은 한 순간의 점 구름).
-- gameplay 뷰의 이름표는 렌더 뒤에 5×7 픽셀 글자로 흉내만 내요 (진짜는 GothamBold 18px).

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Png = require("./render/Png")
local Raster = require("./render/Raster")
local Scene = require("./render/Scene")
local LayoutCheck = require("./render/LayoutCheck")
local Sheet = require("./render/Sheet")
local Shims = require("./render/Shims")

type V3 = { x: number, y: number, z: number }

local function v3(x: number, y: number, z: number): V3
	return { x = x, y = y, z = z }
end

-- ── 인자 ────────────────────────────────────────────────────────────
local args = process.args
local skinArg = "all"
local outDir = "build/renders/characters"
local quality = "high"
local viewArg = "all"
local lightArg = "both"
local sampleArg: string? = nil
local poseArg: string? = nil
local sheetArg = "docs/고등어 초밥 캐릭터 시트.png"

local i = 1
while i <= #args do
	local a = args[i]
	if a == "--pose" then
		poseArg = args[i + 1]
		i += 1
	elseif a == "--sheet" then
		sheetArg = args[i + 1]
		i += 1
	elseif a == "--out" then
		outDir = args[i + 1]
		i += 1
	elseif a == "--quality" then
		quality = args[i + 1]
		assert(quality == "fast" or quality == "high", "--quality must be fast or high")
		i += 1
	elseif a == "--view" then
		viewArg = args[i + 1] or "all"
		i += 1
	elseif a == "--light" then
		lightArg = args[i + 1] or "both"
		assert(
			lightArg == "studio" or lightArg == "lobby" or lightArg == "both",
			"--light must be studio, lobby or both"
		)
		i += 1
	elseif a == "--sample" then
		sampleArg = args[i + 1]
		assert(
			sampleArg == "concept" or string.match(sampleArg or "", "^concept%-") ~= nil,
			"--sample must be concept or a concept skin id (concept-tuna ...)"
		)
		i += 1
	elseif a == "--help" or a == "-h" then
		print(
			"usage: lune run tools/render-character [skinId|all] [--view lineup|turntable|face|gameplay|all]"
				.. " [--light studio|lobby|both] [--quality fast|high] [--out build/renders/characters]"
		)
		process.exit(0)
	elseif string.sub(a, 1, 2) == "--" then
		error(`unknown option {a}`)
	else
		skinArg = a
	end
	i += 1
end

local supersample = if quality == "high" then 2 else 1
local shadowSize = if quality == "high" then 2048 else 1024

local Shared = Shims.root("src/shared")
local SushiBody = Shims.require(Shared.SushiBody)
local SushiPose = Shims.require(Shared.SushiPose)
local Skins = Shims.require(Shared.Skins)
local MapLighting = Shims.require(Shared.maps.MapLighting)
local ConceptSample = Shims.require(Shared.SushiConceptSample)
local CharacterAnimLogic = Shims.require(Shared.CharacterAnimLogic)

-- 대표 자세 (m5-32): 이름 → FishPose
local FISH_POSES: { [string]: any } = {}
local FISH_POSE_ORDER: { string } = {}
for _, item in CharacterAnimLogic.fishTestPoses() do
	FISH_POSES[item.name] = item.pose
	table.insert(FISH_POSE_ORDER, item.name)
end
if poseArg ~= nil and poseArg ~= "all" then
	assert(FISH_POSES[poseArg] ~= nil, `unknown --pose {poseArg} (poses: {table.concat(FISH_POSE_ORDER, ", ")})`)
end

local skinIds: { string } = {}
for _, skin in Skins.LIST do
	table.insert(skinIds, skin.id)
end
if skinArg ~= "all" and sampleArg == nil then
	assert(Skins.get(skinArg) ~= nil, `unknown skin {skinArg} (skins: {table.concat(skinIds, ", ")})`)
end

-- 중립 스튜디오 조명: 회색 환경광, 거의 없는 대기, 색 보정·블룸 약하게
local STUDIO = MapLighting.resolve({
	ClockTime = 13.2,
	Brightness = 2.4,
	Ambient = { r = 105, g = 105, b = 110 },
	OutdoorAmbient = { r = 135, g = 135, b = 140 },
	ShadowSoftness = 0.4,
	ExposureCompensation = 0,
	Atmosphere = {
		Density = 0.05,
		Offset = 0,
		Color = { r = 200, g = 205, b = 215 },
		Decay = { r = 170, g = 175, b = 185 },
		Glare = 0,
		Haze = 0,
	},
	ColorCorrection = { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = { r = 255, g = 255, b = 255 } },
	Bloom = { Intensity = 0.3, Size = 18, Threshold = 2 },
})

local LIGHTS: { { name: string, lighting: any } } = {}
if lightArg == "studio" or lightArg == "both" then
	table.insert(LIGHTS, { name = "studio", lighting = STUDIO })
end
if lightArg == "lobby" or lightArg == "both" then
	table.insert(LIGHTS, { name = "lobby", lighting = MapLighting.LOBBY })
end

local function wants(view: string): boolean
	return viewArg == "all" or viewArg == view
end

-- ── 장면 도우미 ──────────────────────────────────────────────────────
local FLOOR_COLOR = { 0.62, 0.63, 0.66 }

-- 해의 수평 방향에서 30° 돌린 쪽을 캐릭터 정면으로 (yaw, 라디안). 정면 벡터 = (-sin yaw, 0, -cos yaw)
local function keyYaw(lighting: any): number
	local sx, _, sz = Raster.sunDirection(lighting.ClockTime, lighting.GeographicLatitude)
	local sunYaw = math.atan2(-sx, -sz) -- 정면이 해를 바로 볼 때의 yaw
	return sunYaw + math.rad(30)
end

local function frontOf(yaw: number): (number, number)
	return -math.sin(yaw), -math.cos(yaw)
end

local function newScene(): Scene.Scene
	local scene = Scene.new()
	Scene.addBox(
		scene,
		roblox.CFrame.new(0, -0.5, 0),
		roblox.Vector3.new(240, 1, 240),
		FLOOR_COLOR,
		"Fabric",
		{ name = "Floor" }
	)
	return scene
end

-- 게임과 같은 build로 만든 캐릭터를 (x, z)에 yaw로 세워요. 돌려주는 값: Model
-- 배우 id: 스킨 id, 또는 "concept:<표정>:<자세>[:<콘셉트 스킨 id>]" (콘셉트 견본, m5-27·m5-28)
local function conceptArgs(id: string): (string?, string?, string?)
	local expression, pose, rest = string.match(id, "^concept:(%a+):(%a+)(.*)$")
	local skinId = if rest and rest ~= "" then string.sub(rest, 2) else nil
	return expression, pose, skinId
end

-- 게임 스킨 배우 (m5-32): "<스킨 id>#<표정>#<자세>" — 표정·자세는 비워도 돼요 (예 "fresh-mackerel##LandPeak").
-- 자세 "land<i>/<n>" = 착지 팔딱 n칸 중 i번째 (flop-strip)
local function gameArgs(id: string): (string?, string?, string?)
	local skinId, expression, pose = string.match(id, "^([^#]+)#([^#]*)#([^#]*)$")
	if skinId == nil then
		return nil, nil, nil
	end
	return skinId, if expression == "" then nil else expression, if pose == "" then nil else pose
end

local function fishPoseOf(name: string): any
	local index, count = string.match(name, "^land(%d+)/(%d+)$")
	if index then
		return CharacterAnimLogic.fishLandStrip(tonumber(count) :: number)[tonumber(index) :: number].pose
	end
	return assert(FISH_POSES[name], `unknown pose {name}`)
end

local function layoutOf(id: string): { any }
	local expression, pose, skinId = conceptArgs(id)
	if expression then
		return ConceptSample.layout(expression, pose, skinId)
	end
	local gameSkin, gameExpression, gamePose = gameArgs(id)
	if gameSkin then
		local layout = SushiBody.layout(gameSkin, gameExpression)
		if gamePose then
			layout = SushiPose.posed(layout, CharacterAnimLogic.fishMotion(fishPoseOf(gamePose)))
		end
		return layout
	end
	if poseArg ~= nil and poseArg ~= "all" and SushiBody.CONCEPT_BODY[id] then
		return SushiPose.posed(SushiBody.layout(id), CharacterAnimLogic.fishMotion(FISH_POSES[poseArg]))
	end
	return SushiBody.layout(id)
end

local function groundOffsetOf(id: string): number
	return if conceptArgs(id) then ConceptSample.GROUND_OFFSET else SushiBody.GROUND_OFFSET
end

local function placeCharacter(scene: Scene.Scene, id: string, x: number, z: number, yaw: number): any
	local expression, pose, skinId = conceptArgs(id)
	local model = if expression
		then ConceptSample.build(expression, pose, skinId)
		else SushiBody.buildLayout(layoutOf(id), `SushiBody_{id}`)
	model:PivotTo(roblox.CFrame.new(x, groundOffsetOf(id), z) * roblox.CFrame.Angles(0, yaw, 0))
	Scene.addModel(scene, model)
	return model
end

-- 대상(cx, cy, cz)을 정면 기준 방위각(도, 오른쪽 +)·고도(도)·거리에서 보는 원근 카메라
local function orbit(
	cx: number,
	cy: number,
	cz: number,
	yaw: number,
	azimuthDeg: number,
	elevationDeg: number,
	distance: number,
	fov: number,
	aspect: number
): Raster.Camera
	local a = yaw + math.rad(azimuthDeg)
	local fx, fz = frontOf(a)
	local e = math.rad(elevationDeg)
	local pos = v3(cx + fx * math.cos(e) * distance, cy + math.sin(e) * distance, cz + fz * math.cos(e) * distance)
	return Raster.perspective(pos, v3(cx, cy, cz), fov, aspect)
end

local function render(scene: Scene.Scene, cam: Raster.Camera, lighting: any, w: number, h: number): Sheet.Image
	local bounds = { -40, -1, -40, 40, 12, 40 }
	local image = Raster.render(scene, cam, lighting, bounds, {
		width = w,
		height = h,
		supersample = supersample,
		shadowSize = shadowSize,
	})
	return { width = image.width, height = image.height, rgb = image.rgb }
end

local function save(path: string, image: Sheet.Image)
	fs.writeFile(path, Png.encode(image.width, image.height, image.rgb))
end

local BODY_CENTER_Y = SushiBody.GROUND_OFFSET
local PORTRAIT_FOV = 30
local INK = { 30, 30, 34 }
local PAPER = { 236, 236, 238 }

local function tierOf(id: string): string
	local skin = Skins.get(id)
	return if skin then skin.tier else "?"
end

-- 칸 하나: 캐릭터 1명을 정해진 방위각에서
local function portrait(
	id: string,
	lighting: any,
	azimuth: number,
	elevation: number,
	w: number,
	h: number
): Sheet.Image
	local yaw = keyYaw(lighting)
	local scene = newScene()
	placeCharacter(scene, id, 0, 0, yaw)
	local layout = layoutOf(id)
	local b = SushiBody.bounds(layout)
	local topY = groundOffsetOf(id) + b.max[2]
	local cy = topY / 2
	local half = math.max(topY / 2, (b.max[1] - b.min[1]) / 2 * h / w) * 1.22
	local distance = half / math.tan(math.rad(PORTRAIT_FOV) / 2)
	return render(scene, orbit(0, cy, 0, yaw, azimuth, elevation, distance, PORTRAIT_FOV, w / h), lighting, w, h)
end

local LABEL_SCALE = 2
local LABEL_H = 7 * LABEL_SCALE + 10

local function labelled(image: Sheet.Image, text: string): Sheet.Image
	local out = Sheet.new(image.width, image.height + LABEL_H, PAPER)
	Sheet.blit(out, image, 0, 0)
	local tw = Sheet.textWidth(text, LABEL_SCALE)
	Sheet.text(out, math.floor((image.width - tw) / 2), image.height + 5, text, LABEL_SCALE, INK)
	return out
end

-- (a) 전체 스킨 격자
local function renderLineup(dir: string, lighting: any, ids: { string })
	local cellW, cellH, pad = 200, 240, 6
	local cols = Sheet.grid(#ids, 8)
	local _, rows = Sheet.grid(#ids, cols)
	local sheet = Sheet.new(pad + cols * (cellW + pad), pad + rows * (cellH + LABEL_H + pad), { 200, 200, 204 })
	local lines = { "# cell -> skin id (tier), 행 우선, 왼쪽 위가 1" }
	for index, id in ids do
		local cell = labelled(portrait(id, lighting, 30, 10, cellW, cellH), id)
		local x, y = Sheet.cellOrigin(index, cols, cellW, cellH + LABEL_H, pad)
		Sheet.blit(sheet, cell, x, y)
		table.insert(lines, `{index}\t{id}\t{tierOf(id)}`)
	end
	save(`{dir}/lineup.png`, sheet)
	fs.writeFile(`{dir}/lineup.txt`, table.concat(lines, "\n") .. "\n")
end

-- (b) 한 스킨 돌려 보기
local TURN_VIEWS = {
	{ name = "front", azimuth = 0, elevation = 6 },
	{ name = "3/4", azimuth = 40, elevation = 10 },
	{ name = "side", azimuth = 90, elevation = 6 },
	{ name = "back", azimuth = 180, elevation = 10 },
	{ name = "top", azimuth = 25, elevation = 62 },
}

local function renderTurntable(dir: string, lighting: any, id: string, fileName: string?, label: string?)
	local w, h, pad = 300, 340, 6
	local strip = Sheet.new(pad + #TURN_VIEWS * (w + pad), pad * 2 + h + LABEL_H, { 200, 200, 204 })
	for index, view in TURN_VIEWS do
		local cell = labelled(portrait(id, lighting, view.azimuth, view.elevation, w, h), `{label or id} {view.name}`)
		local x, y = Sheet.cellOrigin(index, #TURN_VIEWS, w, h + LABEL_H, pad)
		Sheet.blit(strip, cell, x, y)
	end
	if fileName then
		save(`{dir}/{fileName}.png`, strip)
	else
		fs.writeDir(`{dir}/turntable`)
		save(`{dir}/turntable/{id}.png`, strip)
	end
end

-- (c) 기본 계란초밥 얼굴 가까이 (눈·입 높이, 살짝 오른쪽에서)
local function renderFace(dir: string, lighting: any)
	local yaw = keyYaw(lighting)
	local scene = newScene()
	placeCharacter(scene, Skins.DEFAULT_ID, 0, 0, yaw)
	local faceY = BODY_CENTER_Y + 0.45
	local w, h = 800, 800
	save(`{dir}/face.png`, render(scene, orbit(0, faceY, 0, yaw, 15, 6, 8.5, PORTRAIT_FOV, w / h), lighting, w, h))
end

-- (d) 게임 거리: Roblox 기본 카메라 = 머리(루트 위 ~1.5) 뒤 12.5 studs, 시야 70°, 약 18° 내려다봐요
local CAMERA_DISTANCE = 12.5
local CAMERA_PITCH = 18
local FOCUS_Y = 4.5 -- 땅에서 휴머노이드 머리 높이 (R15 기본 HipHeight 2 + 루트 반 1 + 머리 1.5)

-- 세계 점 → 화면 픽셀 (원근 카메라)
local function toScreen(
	cam: Raster.Camera,
	w: number,
	h: number,
	x: number,
	y: number,
	z: number
): (number, number, boolean)
	local dx, dy, dz = x - cam.px, y - cam.py, z - cam.pz
	local fz = dx * cam.fx + dy * cam.fy + dz * cam.fz
	if fz <= 0.1 then
		return 0, 0, false
	end
	local rx = dx * cam.rx + dy * cam.ry + dz * cam.rz
	local uy = dx * cam.ux + dy * cam.uy + dz * cam.uz
	return (rx / (fz * cam.sx) * 0.5 + 0.5) * w, (0.5 - uy / (fz * cam.sy) * 0.5) * h, true
end

type Actor = { id: string, x: number, z: number, turn: number, tag: string? }

local function renderGameplay(dir: string, lighting: any, name: string, actors: { Actor }, w: number, h: number)
	local yaw = keyYaw(lighting)
	local fx, fz = frontOf(yaw)
	-- 플레이어(첫 배우)는 원점에서 yaw 쪽을 봐요. 다른 배우 좌표는 플레이어 기준 (오른쪽 +x, 앞 +z)
	local rx, rz = -fz, fx -- 오른쪽
	local scene = newScene()
	local world: { { tag: string?, x: number, z: number, top: number } } = {}
	for _, actor in actors do
		local wx, wz = rx * actor.x + fx * actor.z, rz * actor.x + fz * actor.z
		placeCharacter(scene, actor.id, wx, wz, yaw + math.rad(actor.turn))
		-- 이름표 높이는 스킨마다 (m5-32 고등어만 높아요 — SushiBody.nameTagHeight)
		local tagSkin = gameArgs(actor.id) or (if conceptArgs(actor.id) then nil else actor.id)
		local top = groundOffsetOf(actor.id) + SushiBody.nameTagHeight(tagSkin)
		table.insert(world, { tag = actor.tag, x = wx, z = wz, top = top })
	end
	local pitch = math.rad(CAMERA_PITCH)
	local eye = v3(
		-fx * math.cos(pitch) * CAMERA_DISTANCE,
		FOCUS_Y + math.sin(pitch) * CAMERA_DISTANCE,
		-fz * math.cos(pitch) * CAMERA_DISTANCE
	)
	local cam = Raster.perspective(eye, v3(0, FOCUS_Y, 0), 70, w / h)
	local image = render(scene, cam, lighting, w, h)
	-- 이름표 흉내 (다른 사람만, 게임처럼 Body 중심 위 SushiBody.nameTagHeight)
	local scale = if w >= 900 then 2 else 1
	for _, item in world do
		local tag = item.tag
		if tag then
			local sx, sy, visible = toScreen(cam, w, h, item.x, item.top, item.z)
			if visible then
				local tw = Sheet.textWidth(tag, scale)
				local x0, y0 = math.floor(sx - tw / 2), math.floor(sy - 7 * scale / 2)
				for _, o in { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } } do
					Sheet.text(image, x0 + o[1], y0 + o[2], tag, scale, { 40, 40, 40 })
				end
				Sheet.text(image, x0, y0, tag, scale, { 255, 255, 255 })
			end
		end
	end
	save(`{dir}/{name}.png`, image)
end

-- 뒤에서: 나(계란초밥) + 앞 8 studs 왼쪽(연어, 나를 봄) + 앞 16 studs 오른쪽(용 롤, 옆으로)
local BACK_ACTORS: { Actor } = {
	{ id = "tamago", x = 0, z = 0, turn = 0 },
	{ id = "salmon", x = -4, z = 8, turn = 160, tag = "Player2" },
	{ id = "dragon-roll", x = 5, z = 16, turn = 100, tag = "Player3" },
}
-- 앞에서: 세 명이 카메라 쪽을 봐요 (카메라는 원점 뒤라 앞 0~4 studs에 서면 12.5~16 거리)
local FRONT_ACTORS: { Actor } = {
	{ id = "tamago", x = -3.2, z = 1, turn = 180, tag = "Player1" },
	{ id = "tuna", x = 0, z = 3, turn = 175, tag = "Player2" },
	{ id = "cat-sushi", x = 3.2, z = 1, turn = 185, tag = "Player3" },
}

-- ── 콘셉트 견본 (m5-27) ──────────────────────────────────────────────
local CONCEPT = "concept:Default:Stand"
local CONCEPT_BACK_ACTORS: { Actor } = {
	{ id = "concept:Default:Run", x = 0, z = 0, turn = 0 },
	{ id = "concept:Happy:Run", x = -4, z = 8, turn = 160, tag = "Player2" },
	{ id = "concept:Flustered:Run", x = 5, z = 16, turn = 100, tag = "Player3" },
}
local CONCEPT_FRONT_ACTORS: { Actor } = {
	{ id = "concept:Happy:Stand", x = -3.2, z = 1, turn = 180, tag = "Player1" },
	{ id = "concept:Default:Run", x = 0, z = 3, turn = 175, tag = "Player2" },
	{ id = "concept:Flustered:Stand", x = 3.2, z = 1, turn = 185, tag = "Player3" },
}

-- m5-28 콘셉트 스킨 하나 (skinId): 그 스킨이 나(뒤 카메라)·가운데이고, 다른 콘셉트 스킨 둘이 옆에 서요 (서로 구분되는지)
local function conceptId(expression: string, pose: string, skinId: string?): string
	return if skinId then `concept:{expression}:{pose}:{skinId}` else `concept:{expression}:{pose}`
end

local function otherConcepts(skinId: string): (string, string)
	local others = {}
	for _, id in ConceptSample.SKIN_IDS do
		if id ~= skinId then
			table.insert(others, id)
		end
	end
	return others[1], others[#others]
end

local function conceptActors(skinId: string?): ({ Actor }, { Actor })
	if skinId == nil then
		return CONCEPT_BACK_ACTORS, CONCEPT_FRONT_ACTORS
	end
	local a, b = otherConcepts(skinId)
	return {
		{ id = conceptId("Default", "Run", skinId), x = 0, z = 0, turn = 0 },
		{ id = conceptId("Happy", "Run", a), x = -4, z = 8, turn = 160, tag = "Player2" },
		{ id = conceptId("Flustered", "Run", b), x = 5, z = 16, turn = 100, tag = "Player3" },
	}, {
		{ id = conceptId("Happy", "Stand", a), x = -3.2, z = 1, turn = 180, tag = "Player1" },
		{ id = conceptId("Default", "Run", skinId), x = 0, z = 3, turn = 175, tag = "Player2" },
		{ id = conceptId("Flustered", "Stand", b), x = 3.2, z = 1, turn = 185, tag = "Player3" },
	}
end

-- 표정 4종: 얼굴 가까이 (밥 앞면 높이, 살짝 오른쪽에서)
local function renderExpressions(dir: string, lighting: any, skinId: string?)
	local w, h, pad = 360, 300, 6
	local list = ConceptSample.EXPRESSIONS
	local sheet = Sheet.new(pad + #list * (w + pad), pad * 2 + h + LABEL_H, { 200, 200, 204 })
	local yaw = keyYaw(lighting)
	for index, expression in list do
		local id = conceptId(expression, "Stand", skinId)
		local scene = newScene()
		placeCharacter(scene, id, 0, 0, yaw)
		local cy = groundOffsetOf(id) + 0.2
		local image = render(scene, orbit(0, cy, 0, yaw, 12, 8, 10, PORTRAIT_FOV, w / h), lighting, w, h)
		local x, y = Sheet.cellOrigin(index, #list, w, h + LABEL_H, pad)
		Sheet.blit(sheet, labelled(image, string.upper(expression)), x, y)
	end
	save(`{dir}/expressions.png`, sheet)
end

local COMPARE_WITH: { [string]: string } = { unagi = "eel", tako = "octopus" }

-- 지금 게임 스킨 ↔ 콘셉트 (3/4 앞, 뒤). 견본은 연어, 스킨 id면 같은 음식 (concept-tuna ↔ tuna, concept-ikura ↔ ikura)
local function renderCompare(dir: string, lighting: any, skinId: string?)
	local w, h, pad = 300, 340, 6
	local now = if skinId then string.sub(skinId, #"concept-" + 1) else "salmon"
	now = COMPARE_WITH[now] or now -- m5-29: 이름이 다른 같은 음식 (unagi ↔ eel, tako ↔ octopus)
	if Skins.get(now) == nil then
		now = "salmon"
	end
	local concept = conceptId("Default", "Stand", skinId)
	local cells = {
		{ id = now, az = 30, label = "NOW 3/4" },
		{ id = now, az = 180, label = "NOW BACK" },
		{ id = concept, az = 30, label = "CONCEPT 3/4" },
		{ id = concept, az = 180, label = "CONCEPT BACK" },
	}
	local sheet = Sheet.new(pad + #cells * (w + pad), pad * 2 + h + LABEL_H, { 200, 200, 204 })
	for index, cell in cells do
		local image = labelled(portrait(cell.id, lighting, cell.az, 10, w, h), cell.label)
		local x, y = Sheet.cellOrigin(index, #cells, w, h + LABEL_H, pad)
		Sheet.blit(sheet, image, x, y)
	end
	save(`{dir}/compare.png`, sheet)
end

-- skinId 없음 = 견본(concept-salmon, <root>/concept), 있으면 <root>/<skinId>
local function renderConcept(root: string, lighting: any, skinId: string?)
	local dir = `{root}/{skinId or "concept"}`
	fs.writeDir(dir)
	local back, front = conceptActors(skinId)
	if wants("turntable") then
		renderTurntable(dir, lighting, conceptId("Default", "Stand", skinId), "turntable", skinId or "concept")
		renderTurntable(dir, lighting, conceptId("Happy", "Run", skinId), "turntable-run", "run")
	end
	if wants("face") then
		renderExpressions(dir, lighting, skinId)
	end
	if wants("gameplay") then
		renderGameplay(dir, lighting, "gameplay-back", back, 960, 540)
		renderGameplay(dir, lighting, "gameplay-front", front, 960, 540)
		renderGameplay(dir, lighting, "mobile-back", back, 480, 270)
		renderGameplay(dir, lighting, "mobile-front", front, 480, 270)
	end
	if wants("compare") then
		renderCompare(dir, lighting, skinId)
	end
end

-- ── 콘셉트 몸 게임 스킨 (m5-32) ───────────────────────────────────────
local function gameId(skinId: string, expression: string?, pose: string?): string
	return `{skinId}#{expression or ""}#{pose or ""}`
end

-- 칸 여러 개를 한 줄로 (cells = { { id, azimuth, elevation, label } })
local function renderRow(path: string, lighting: any, cells: { any }, w: number, h: number)
	local pad = 6
	local sheet = Sheet.new(pad + #cells * (w + pad), pad * 2 + h + LABEL_H, { 200, 200, 204 })
	for index, cell in cells do
		local image = labelled(portrait(cell[1], lighting, cell[2], cell[3], w, h), cell[4])
		local x, y = Sheet.cellOrigin(index, #cells, w, h + LABEL_H, pad)
		Sheet.blit(sheet, image, x, y)
	end
	save(path, sheet)
end

-- 사용자 시트의 정면·3/4·후면 (1536×1024 시트 기준 칸, 크기가 다르면 비율로)
local SHEET_CROPS = {
	{ label = "SHEET FRONT", x = 20, y = 170, w = 500, h = 420, azimuth = 0, elevation = 6 },
	{ label = "SHEET 3/4", x = 520, y = 170, w = 500, h = 420, azimuth = 40, elevation = 10 },
	{ label = "SHEET BACK", x = 1030, y = 170, w = 500, h = 420, azimuth = 180, elevation = 10 },
}

local function renderSheetCompare(path: string, lighting: any, skinId: string)
	local w, h, pad = 360, 300, 6
	local cols = #SHEET_CROPS
	local sheet = Sheet.new(pad + cols * (w + pad), pad * 3 + 2 * (h + LABEL_H), { 200, 200, 204 })
	local okSheet, bytes = pcall(fs.readFile, sheetArg)
	local sw, sh, rgb = 0, 0, buffer.create(0)
	if okSheet then
		sw, sh, rgb = Png.decode(bytes)
	end
	for index, crop in SHEET_CROPS do
		local x, y = Sheet.cellOrigin(index, cols, w, h + LABEL_H, pad)
		if okSheet then
			local fx, fy = sw / 1536, sh / 1024
			local image = Sheet.cropResize(
				{ width = sw, height = sh, rgb = rgb },
				crop.x * fx,
				crop.y * fy,
				crop.w * fx,
				crop.h * fy,
				w,
				h
			)
			Sheet.blit(sheet, labelled(image, crop.label), x, y)
		end
		local render = portrait(gameId(skinId, nil, nil), lighting, crop.azimuth, crop.elevation, w, h)
		Sheet.blit(sheet, labelled(render, `RENDER {string.sub(crop.label, 7)}`), x, y + h + LABEL_H + pad)
	end
	save(path, sheet)
end

local function renderConceptSkin(root: string, lighting: any, skinId: string)
	local dir = `{root}/{skinId}`
	fs.writeDir(dir)
	if wants("turntable") then
		local poseName = if poseArg and poseArg ~= "all" then poseArg else nil
		renderTurntable(
			dir,
			lighting,
			gameId(skinId, nil, poseName),
			if poseName then `turntable-{poseName}` else "turntable",
			if poseName then `{skinId} {poseName}` else skinId
		)
	end
	if wants("face") or wants("expressions") then
		local cells = {}
		for _, expression in ConceptSample.EXPRESSIONS do
			table.insert(cells, { gameId(skinId, expression, nil), 18, 8, string.upper(expression) })
		end
		renderRow(`{dir}/expressions.png`, lighting, cells, 260, 260)
	end
	if wants("poses") then
		local cells = {}
		for _, name in FISH_POSE_ORDER do
			table.insert(
				cells,
				{ gameId(skinId, if name == "Hurt" then "Hurt" else nil, name), 30, 10, string.upper(name) }
			)
		end
		renderRow(`{dir}/poses.png`, lighting, cells, 240, 260)
	end
	if wants("flop") then
		local frames = 8
		local strip = CharacterAnimLogic.fishLandStrip(frames)
		local cells = {}
		for index, frame in strip do
			table.insert(cells, {
				gameId(skinId, nil, `land{index}/{frames}`),
				30, -- 3/4: 꼬리 좌우 파닥(Y축)도 보이게
				8,
				string.format("T %.2fS", frame.time),
			})
		end
		renderRow(`{dir}/flop-strip.png`, lighting, cells, 220, 240)
	end
	if wants("compare") then
		local cells = {}
		for _, other in { skinId, "golden-otoro", "concept-salmon" } do
			local id = if other == skinId then gameId(skinId, nil, nil) else other
			table.insert(cells, { id, 30, 10, `{string.upper(other)} 3/4` })
			table.insert(cells, { id, 180, 10, `{string.upper(other)} BACK` })
		end
		renderRow(`{dir}/compare.png`, lighting, cells, 240, 280)
	end
	if wants("sheet") then
		renderSheetCompare(`{dir}/sheet-compare.png`, lighting, skinId)
	end
	if wants("closeup") then
		-- 크게 두 장 (앞·3/4) — 줄무늬·윤기·입·지느러미를 글로 비평할 때 (m5-32)
		renderRow(`{dir}/closeup.png`, lighting, {
			{ gameId(skinId, nil, nil), 0, 6, "FRONT" },
			{ gameId(skinId, nil, nil), 35, 12, "3/4" },
			{ gameId(skinId, nil, nil), 180, 14, "BACK" },
		}, 560, 480)
	end
	if wants("gameplay") then
		-- 뒤 카메라: 나 = 이 스킨(달리며 꼬리를 흔드는 순간), 앞에 장어(특)·판매 장어 / 앞 카메라: 연어(특)·이 스킨·판매 장어
		local back: { Actor } = {
			{ id = gameId(skinId, nil, "TailLeft"), x = 0, z = 0, turn = 0 },
			{ id = "concept-unagi", x = -4, z = 8, turn = 160, tag = "Player2" },
			{ id = "eel", x = 5, z = 16, turn = 100, tag = "Player3" },
		}
		local front: { Actor } = {
			{ id = "concept-salmon", x = -3.4, z = 1, turn = 180, tag = "Player1" },
			{ id = gameId(skinId, nil, "Splash"), x = 0, z = 3, turn = 175, tag = "Player2" },
			{ id = "eel", x = 3.4, z = 1, turn = 185, tag = "Player3" },
		}
		renderGameplay(dir, lighting, "gameplay-back", back, 960, 540)
		renderGameplay(dir, lighting, "gameplay-front", front, 960, 540)
		renderGameplay(dir, lighting, "mobile-back", back, 480, 270)
		renderGameplay(dir, lighting, "mobile-front", front, 480, 270)
	end
end

-- ── 통계 ────────────────────────────────────────────────────────────
local function skinStats(id: string): string
	local layout = SushiBody.layout(id)
	local b = SushiBody.bounds(layout)
	local materials: { [string]: boolean } = {}
	local colors: { [string]: boolean } = {}
	local shapes: { [string]: number } = {}
	local effects = {}
	local thin = 0
	for _, spec in layout do
		materials[spec.material] = true
		colors[table.concat(spec.color, ",")] = true
		local shape = spec.shape or "Block"
		shapes[shape] = (shapes[shape] or 0) + 1
		if spec.effect then
			table.insert(effects, spec.effect)
		end
		if math.min(spec.size[1], spec.size[2], spec.size[3]) < 0.1 then
			thin += 1
		end
	end
	local function keys(t: { [string]: any }): string
		local list = {}
		for k, v in t do
			table.insert(list, if type(v) == "number" then `{k}x{v}` else k)
		end
		table.sort(list)
		return table.concat(list, "+")
	end
	local scene = Scene.new()
	Scene.addModel(scene, SushiBody.build(id))
	local zf = LayoutCheck.zFight(layout)
	local fl = LayoutCheck.floating(layout)
	local ncolors = 0
	for _ in colors do
		ncolors += 1
	end
	return string.format(
		"%-18s %-9s parts=%2d shapes=%s thin<0.1=%d effects=%s materials=%s colors=%d size=%.2fx%.2fx%.2f tris=%d zfight=%s floating=%s",
		id,
		tierOf(id),
		#layout,
		keys(shapes),
		thin,
		if #effects > 0 then table.concat(effects, "+") else "-",
		keys(materials),
		ncolors,
		b.max[1] - b.min[1],
		b.max[2] - b.min[2],
		b.max[3] - b.min[3],
		#scene.p,
		if #zf > 0 then table.concat(zf, ";") else "-",
		if #fl > 0 then table.concat(fl, ";") else "-"
	)
end

-- ── 실행 ────────────────────────────────────────────────────────────
if sampleArg ~= nil then
	local skinId: string? = if sampleArg == "concept" then nil else sampleArg
	if skinId then
		assert(
			table.find(ConceptSample.SKIN_IDS, skinId) ~= nil,
			`unknown concept skin {skinId} (concept skins: {table.concat(ConceptSample.SKIN_IDS, ", ")})`
		)
	end
	for _, light in LIGHTS do
		local t0 = os.clock()
		renderConcept(`{outDir}/{light.name}`, light.lighting, skinId)
		print(
			string.format(
				"[render-character] %s %s: %s/%s/%s (%.1fs)",
				skinId or "concept",
				light.name,
				outDir,
				light.name,
				skinId or "concept",
				os.clock() - t0
			)
		)
	end
	local layout = ConceptSample.layout(nil, nil, skinId)
	print(
		`[render-character] {skinId or "concept"} parts {#layout} (Default·Stand), zfight {table.concat(
			LayoutCheck.zFight(layout),
			";"
		)}, floating {table.concat(LayoutCheck.floating(layout), ";")}`
	)
	for _, expression in ConceptSample.EXPRESSIONS do
		print(`  {expression}: {#ConceptSample.layout(expression, nil, skinId)} parts`)
	end
	process.exit(0)
end

if skinArg ~= "all" and SushiBody.CONCEPT_BODY[skinArg] ~= nil then
	for _, light in LIGHTS do
		local t0 = os.clock()
		renderConceptSkin(`{outDir}/{light.name}`, light.lighting, skinArg)
		print(
			string.format(
				"[render-character] %s %s: %s/%s/%s (%.1fs)",
				skinArg,
				light.name,
				outDir,
				light.name,
				skinArg,
				os.clock() - t0
			)
		)
	end
	fs.writeDir(outDir)
	local lines = {}
	for _, expression in ConceptSample.EXPRESSIONS do
		table.insert(lines, `{expression}: {#SushiBody.layout(skinArg, expression)} parts`)
	end
	table.insert(lines, skinStats(skinArg))
	fs.writeFile(`{outDir}/stats.txt`, table.concat(lines, "\n") .. "\n")
	print(table.concat(lines, "\n"))
	process.exit(0)
end

local ids = if skinArg == "all" then skinIds else { skinArg }
for _, light in LIGHTS do
	local dir = `{outDir}/{light.name}`
	fs.writeDir(dir)
	local t0 = os.clock()
	if wants("lineup") then
		renderLineup(dir, light.lighting, ids)
	end
	if wants("turntable") then
		for _, id in ids do
			renderTurntable(dir, light.lighting, id)
		end
	end
	if wants("face") then
		renderFace(dir, light.lighting)
	end
	if wants("gameplay") then
		renderGameplay(dir, light.lighting, "gameplay-back", BACK_ACTORS, 960, 540)
		renderGameplay(dir, light.lighting, "gameplay-front", FRONT_ACTORS, 960, 540)
		renderGameplay(dir, light.lighting, "mobile-back", BACK_ACTORS, 480, 270)
		renderGameplay(dir, light.lighting, "mobile-front", FRONT_ACTORS, 480, 270)
	end
	print(string.format("[render-character] %s: %d skin(s), out %s/ (%.1fs)", light.name, #ids, dir, os.clock() - t0))
end

local lines = {}
for _, id in ids do
	table.insert(lines, skinStats(id))
end
fs.writeDir(outDir)
fs.writeFile(`{outDir}/stats.txt`, table.concat(lines, "\n") .. "\n")
print(`[render-character] stats: {outDir}/stats.txt`)
