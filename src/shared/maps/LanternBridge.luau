--!strict
-- Race 맵 "등불 다리 건너기" (m5-15, GDD §5.3 v0.6). 일본 축제 분위기의 흔들리는 외나무다리 4개를 건너요.
-- 다른 Race 맵은 "개인 대 지형" 싸움이지만, 이 맵은 다리 위에 몰린 사람이 많을수록 그 다리가 더 심하게
-- 흔들리는 유일한 맵이에요(군중 압박감). 치수는 LanternBridgeLayout, 흔들림·미는 속도·낙하선 계산은
-- LanternBridgeLogic, 장식은 LanternBridgeArt.
-- 다리 파츠는 태그(LanternBridgePlank)를 달고 start에서 ctx.model 하위의 태그 파츠만 흔들어요(CFrame 직접
-- 갱신, 결정 기록 참고 — TweenService는 진폭이 매 틱 바뀌어야 해서 안 써요). 상태는 전부 start 안의 지역
-- 변수에 둬서 여러 방이 같은 맵을 동시에 돌려도 섞이지 않아요.
-- 미는 힘은 ChefBoard 기울기와 같은 분류(연속 밀기)라 MoveExempt를 달지 않아요.
-- id·kind·displayName·rule은 m5-13에서 확정이에요 (바꾸지 않아요).
-- Roblox API는 build/start 안에서만 써요 — require만 하는 것(Lune 테스트)은 안전해요.

local Art = require(script.Parent.LanternBridgeArt)
local Config = require(script.Parent.Parent.Config)
local Layout = require(script.Parent.LanternBridgeLayout)
local Logic = require(script.Parent.LanternBridgeLogic)
local MapKit = require(script.Parent.MapKit)
local MapTypes = require(script.Parent.MapTypes)

local ID = "lantern-bridge"
local MAX_PLAYERS = Config.Room.MaxPlayerOptions[#Config.Room.MaxPlayerOptions]
local TAG_PLANK = "LanternBridgePlank"

local function palette()
	return {
		start = Color3.fromRGB(210, 182, 140),
		rest = Color3.fromRGB(196, 164, 120),
		plank = Color3.fromRGB(168, 124, 78),
		finish = Color3.fromRGB(214, 188, 150),
		finishLine = Color3.fromRGB(255, 196, 40),
	}
end

local function makePart(props: { [string]: any }): BasePart
	local parent = props.Parent
	props.Parent = nil
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = true
	p.Material = Enum.Material.WoodPlanks
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	if parent then
		p.Parent = parent
	end
	return p
end

local function build(origin: CFrame): Model
	local CollectionService = game:GetService("CollectionService")
	local COLORS = palette()
	local model = Instance.new("Model")
	model.Name = ID

	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end

	local function flatFloor(name: string, front: number, back: number, width: number, color: Color3)
		local depth = front - back
		local center = front - depth / 2
		makePart({
			Name = name,
			Size = Vector3.new(width, Layout.FLOOR_THICKNESS, depth),
			CFrame = at(0, -Layout.FLOOR_THICKNESS / 2, center),
			Color = color,
			Parent = model,
		})
	end

	-- 출발 평지
	flatFloor("StartFloor", Layout.START.front, Layout.START.back, Layout.START_WIDTH, COLORS.start)

	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = model
	local positions = Layout.spawnPositions()
	assert(#positions == MAX_PLAYERS, "spawn count must cover the largest room size")
	for i, pos in positions do
		makePart({
			Name = string.format("Spawn%02d", i),
			Size = Vector3.new(2, 0.2, 2),
			CFrame = at(pos.x, 0.1, pos.z),
			Color = Color3.fromRGB(246, 196, 70),
			Transparency = 0.4,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
			Parent = spawns,
		})
	end

	-- 다리 4개: 흔들리는 외나무다리(태그, start에서 CFrame 갱신)
	for _, bridge in Layout.BRIDGES do
		local center = (bridge.front + bridge.back) / 2
		local plank = makePart({
			Name = string.format("Plank%d", bridge.index),
			Size = Vector3.new(bridge.width, Layout.FLOOR_THICKNESS, bridge.length),
			CFrame = at(0, -Layout.FLOOR_THICKNESS / 2, center),
			Color = COLORS.plank,
			Parent = model,
		})
		plank:SetAttribute("BridgeIndex", bridge.index)
		CollectionService:AddTag(plank, TAG_PLANK)
	end

	-- 쉼터 3곳 (안전 평지, 흔들리지 않아요)
	for _, rest in Layout.RESTS do
		flatFloor(rest.name .. "Floor", rest.front, rest.back, rest.width, COLORS.rest)
	end

	-- 결승 평지 + FinishLine
	flatFloor("FinishFloor", Layout.FINISH.front, Layout.FINISH.back, Layout.FINISH_WIDTH, COLORS.finish)
	makePart({
		Name = "FinishLine",
		Size = Vector3.new(Layout.FINISH_WIDTH, 0.4, 1),
		CFrame = at(0, 0.2, Layout.finishLineZ()),
		Color = COLORS.finishLine,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Parent = model,
	})

	-- 장식(충돌 없음) + 등불 조명 + 소개 카메라 + 사용자 Studio 아트 자리
	local decor = MapKit.decorFolder(model)
	for _, part in MapKit.buildDecor(Art.decor(), origin, decor) do
		if part.Name == Art.LANTERN then
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 190, 140)
			light.Brightness = 1.1
			light.Range = 14
			light.Parent = part
		end
	end
	MapKit.introCamera(model, Art.introCamera(), origin)
	MapKit.attachStudioArt(model, ID, origin)

	return model
end

-- ctx.model 하위에 있는 태그 파츠만 (여러 방 동시 진행)
local function taggedParts(ctx: MapTypes.RoundContext): { BasePart }
	local CollectionService = game:GetService("CollectionService")
	local parts = {}
	for _, instance in CollectionService:GetTagged(TAG_PLANK) do
		if instance:IsA("BasePart") and ctx.model:IsAncestorOf(instance) then
			table.insert(parts, instance)
		end
	end
	return parts
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function start(ctx: MapTypes.RoundContext)
	local RunService = game:GetService("RunService")
	local origin = ctx.origin
	local startedAt = os.clock()
	local right = origin.RightVector

	local finishProgress = Logic.finishProgress()
	local finishLine = ctx.model:FindFirstChild("FinishLine")
	if finishLine and finishLine:IsA("BasePart") then
		finishProgress = Logic.progress(origin:PointToObjectSpace(finishLine.Position).Z)
	end

	local planks: { { part: BasePart, bridge: Layout.Bridge, base: CFrame } } = {}
	for _, part in taggedParts(ctx) do
		local index = part:GetAttribute("BridgeIndex")
		if type(index) == "number" and Layout.BRIDGES[index] then
			local bridge = Layout.BRIDGES[index]
			local center = (bridge.front + bridge.back) / 2
			table.insert(planks, {
				part = part,
				bridge = bridge,
				base = origin * CFrame.new(0, -Layout.FLOOR_THICKNESS / 2, center),
			})
		end
	end

	ctx.cleanup:add(RunService.Heartbeat:Connect(function(dt: number)
		if not ctx.isActive() then
			return
		end
		local elapsed = os.clock() - startedAt

		-- 1. 다리 위 인원 집계 (이번 프레임 시작 위치 기준)
		local riderCounts: { [number]: number } = {}
		for _, player in ctx.getRacers() do
			local root = rootOf(player)
			if root then
				local rel = origin:PointToObjectSpace(root.Position)
				local bridge = Logic.bridgeAt(rel.Z)
				if bridge then
					riderCounts[bridge.index] = (riderCounts[bridge.index] or 0) + 1
				end
			end
		end

		-- 2. 다리 CFrame 갱신 (흔들림 진폭은 이번 프레임 인원수 기준)
		local angleByIndex: { [number]: number } = {}
		for _, plank in planks do
			local riders = riderCounts[plank.bridge.index] or 0
			local amplitude = Logic.swayAmplitudeDeg(riders, plank.bridge.maxSwayDeg)
			local angle = Logic.swayAngle(elapsed, amplitude, Layout.SWAY_PERIOD, plank.bridge.phase)
			angleByIndex[plank.bridge.index] = angle
			plank.part.CFrame = plank.base * CFrame.Angles(0, 0, angle)
		end

		-- 3. 판정: 결승선 통과 / 낙하
		for _, player in ctx.getRacers() do
			local root = rootOf(player)
			if root then
				local rel = origin:PointToObjectSpace(root.Position)
				if Logic.progress(rel.Z) >= finishProgress then
					ctx.pass(player)
				elseif rel.Y < Logic.fallLineAt(rel.Z) then
					ctx.eliminate(player)
				end
				if not ctx.isActive() then
					return -- 이 통과/탈락으로 라운드가 끝났어요
				end
			end
		end

		-- 4. 남은 레이서에게 다리가 기운 쪽으로 미는 힘
		for _, player in ctx.getRacers() do
			local root = rootOf(player)
			if root == nil then
				continue
			end
			local rel = origin:PointToObjectSpace(root.Position)
			local bridge = Logic.bridgeAt(rel.Z)
			if bridge then
				local angle = angleByIndex[bridge.index] or 0
				local target = Logic.pushSpeedFor(angle, bridge.maxSwayDeg)
				local velocity = root.AssemblyLinearVelocity
				local addSide = Logic.pushDelta(velocity:Dot(right), target, Layout.PLANK_PUSH_ACCEL, dt)
				if addSide ~= 0 then
					root.AssemblyLinearVelocity = velocity + right * addSide
				end
			end
		end
	end))
end

local map: MapTypes.MapModule = {
	id = ID,
	kind = "Race",
	displayName = "등불 다리 건너기",
	rule = "흔들리는 다리와 종이 등불 사이를 건너요.",
	inPool = true, -- m5-15: 랜덤 판 풀에 포함
	build = build,
	start = start,
}

return map
