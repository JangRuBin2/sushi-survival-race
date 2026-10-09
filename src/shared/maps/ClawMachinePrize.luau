--!strict
-- Final 맵 "인형뽑기 기계 속" (m5-19, GDD §5.3 v0.6). 오락실 인형뽑기 기계 속 투명한 유리 상자, 바닥은
-- 8x8=64칸 격자(칸마다 인형 더미, 높이가 조금씩 달라요 — 시각 정보일 뿐 판정에는 안 써요). 거대한 집게가
-- 주기적으로(시간이 갈수록 빨라지고 구역도 커져요) 구역을 예고한 뒤 그 칸들을 통째로 들어 올려 치워요.
-- 치운 칸은 그 라운드 동안 돌아오지 않아요. 연장전은 상자 전체를 한쪽으로 기울여 낮은 쪽 줄부터 없애요.
--
-- 집게는 "바닥(칸)만" 들어 올려요 — 사람을 직접 붙잡지 않아요(결정 기록 D3). 칸이 사라진 순간 그 위에
-- 있던 사람은 바닥이 없어져 자연스럽게 떨어지고(ctx.eliminate는 낙하 깊이로만 판정), 탈락 연출은 결승
-- 공통 셰프 손 그대로예요. 집게 발톱·레일·레일 기둥의 "들어 올리는" 움직임은 전부 연출(충돌 없음)이에요.
--
-- 이 맵은 ctx.pass를 부르지 않아요(결승선 없음). 우승 판정(1명 남음, 동시 낙하, 시간 종료)은 RoundService가
-- 해요. 장애물(칸·집게)은 CollectionService 태그를 달고, start/overtime에서 ctx.model 하위 태그만 동작시켜요.
-- 상태는 전부 start 지역 변수(roundStates[ctx])에 둬요 (여러 방이 같은 맵을 동시에 돌려도 안 섞여요).
-- Roblox API는 build/start/overtime 안에서만 써서 Lune에서 require해도 안전해요.
--
-- 아트(m4-02 공통 규칙): 장식은 ClawMachinePrizeArt(순수 데이터) → MapKit.buildDecor. 칸 위 인형 더미 장식은
-- 칸 파츠의 자식으로 넣어서(ClawMachinePrizeArt.tileDecor) 칸이 사라질 때(Destroy) 같이 사라져요.

local Art = require(script.Parent.ClawMachinePrizeArt)
local Layout = require(script.Parent.ClawMachinePrizeLayout)
local Logic = require(script.Parent.ClawMachinePrizeLogic)
local MapKit = require(script.Parent.MapKit)
local MapSfx = require(script.Parent.MapSfx)
local MapTypes = require(script.Parent.MapTypes)

local ID = "claw-machine-prize"

local TAG_TILE = "ClawMachineTile"
local TAG_CLAW = "ClawMachinePrizeClaw"

local GRID_SIZE = Layout.GRID_SIZE

-- 집게 연출 시간 (studs/초). 판정(바닥 사라짐)과는 무관해요.
local CLAW_HOVER_TIME = 0.6 -- 경고 시작 때 집게가 과녁 중심으로 이동하는 시간
local CLAW_DESCEND_LEAD = 0.3 -- 경고 끝나기 이만큼 전부터 발톱이 내려오는 모습
local CLAW_DESCEND_DROP = 4 -- 내려오는 높이
local CLAW_LIFT_HEIGHT = 20 -- 들어 올리는 높이
local CLAW_LIFT_TIME = 1.2 -- 들어 올리는 시간
local WARN_BLINK = 0.2 -- 노란 깜빡임 간격
local OVERTIME_WARN_TIME = 1 -- 연장전 줄 경고 시간 (Logic.overtimeTilt warnTime)

local WARN_RGB = { 235, 205, 40 }

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function makePart(props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

-- 칸 하나(태그 ClawMachineTile, 속성 Row·Col·Index)를 만들어요. 위에 저예산 인형 더미 장식을 자식으로 넣어요
-- (칸이 사라질 때 Destroy 한 번으로 같이 사라져요).
local function buildTile(model: Model, origin: CFrame, row: number, col: number): BasePart
	local CollectionService = game:GetService("CollectionService")
	local topY = Layout.tileHeight(row, col)
	local cframe = origin
		* CFrame.new(Layout.tileLocalX(col), topY - Layout.THICKNESS / 2, Layout.CENTER_Z + Layout.tileLocalZGrid(row))
	local checker = (row + col) % 2 == 0
	local tile = makePart({
		Name = string.format("Tile_%d_%d", row, col),
		Size = Vector3.new(Layout.TILE_SIZE, Layout.THICKNESS, Layout.TILE_SIZE),
		CFrame = cframe,
		Color = if checker then rgb(232, 224, 208) else rgb(242, 236, 224),
		Parent = model,
	})
	tile:SetAttribute("Row", row)
	tile:SetAttribute("Col", col)
	tile:SetAttribute("Index", Layout.tileIndex(row, col))
	CollectionService:AddTag(tile, TAG_TILE)
	MapKit.buildDecor(Art.tileDecor(row, col), tile.CFrame, tile)
	return tile
end

-- 집게(태그 ClawMachinePrizeClaw): 중앙 허브 + 세 갈래 발톱. 연출 전용(충돌 없음), start/liftWindow가 PivotTo로 움직여요.
local function buildClaw(model: Model, origin: CFrame)
	local CollectionService = game:GetService("CollectionService")
	local claw = Instance.new("Model")
	claw.Name = "Claw"
	local restCFrame = origin * CFrame.new(0, Art.RAIL_HEIGHT - 2, Layout.CENTER_Z)
	local hub = makePart({
		Name = "Hub",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.6, 2.6, 2.6),
		CFrame = restCFrame,
		Color = rgb(196, 200, 208),
		Material = Enum.Material.Metal,
		Parent = claw,
	})
	for i = 1, 3 do
		local angle = math.rad((i - 1) * 120)
		makePart({
			Name = "Prong",
			Size = Vector3.new(0.6, 3.2, 0.6),
			CFrame = restCFrame * CFrame.new(math.cos(angle) * 1.1, -2, math.sin(angle) * 1.1),
			Color = rgb(220, 50, 60),
			Material = Enum.Material.Metal,
			Parent = claw,
		})
	end
	for _, part in claw:GetChildren() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end
	claw.PrimaryPart = hub
	CollectionService:AddTag(claw, TAG_CLAW)
	claw.Parent = model
end

local function build(origin: CFrame): Model
	local model = Instance.new("Model")
	model.Name = ID

	-- 모델 전체를 origin 기준으로 정확히 회전시키려고(연장전 기울기), 피벗을 origin에 고정해요.
	local anchor = makePart({
		Name = "PivotAnchor",
		Size = Vector3.new(1, 1, 1),
		CFrame = origin,
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Parent = model,
	})

	for row = 0, GRID_SIZE - 1 do
		for col = 0, GRID_SIZE - 1 do
			buildTile(model, origin, row, col)
		end
	end

	buildClaw(model, origin)

	for _, part in MapKit.buildDecor(Art.decor(), origin, MapKit.decorFolder(model)) do
		if part.Name == Art.NEON then
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 150, 210)
			light.Brightness = 1.4
			light.Range = 20
			light.Parent = part
		end
	end
	MapKit.introCamera(model, Art.introCamera(), origin)
	MapKit.attachStudioArt(model, ID, origin)

	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	for i, tile in Layout.spawnTiles() do
		makePart({
			Name = string.format("Spawn%02d", i),
			Size = Vector3.new(2, 0.2, 2),
			CFrame = origin * CFrame.new(tile.x, tile.y, tile.z),
			Color = Color3.fromRGB(246, 196, 70),
			Transparency = 0.4,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
			Parent = spawns,
		})
	end
	spawns.Parent = model

	model.PrimaryPart = anchor
	return model
end

-- 태그가 붙은 것 중 이 라운드의 맵(ctx.model) 안에 있는 것만
local function taggedInModel(model: Model, tag: string): { Instance }
	local CollectionService = game:GetService("CollectionService")
	local found = {}
	for _, instance in CollectionService:GetTagged(tag) do
		if model:IsAncestorOf(instance) then
			table.insert(found, instance)
		end
	end
	return found
end

-- Model을 duration 동안 to로 옮겨요 (Anchored 파츠라 Heartbeat마다 PivotTo).
local function movePivot(target: Model, to: CFrame, duration: number)
	local RunService = game:GetService("RunService")
	local from = target:GetPivot()
	local elapsed = 0
	while elapsed < duration do
		elapsed += RunService.Heartbeat:Wait()
		local alpha = math.min(elapsed / duration, 1)
		target:PivotTo(from:Lerp(to, 1 - (1 - alpha) * (1 - alpha))) -- ease-out
	end
end

-- 라운드(ctx)마다 start와 overtime이 같이 보는 상태 (m5-01). 키가 ctx라 여러 방이 섞이지 않고,
-- 라운드가 끝나면 ctx.cleanup이 지워요.
type RoundState = {
	startedAt: number,
	overtimeAt: number?, -- 연장전 시작(출발 기준 초). nil이면 아직 연장전 전
	tiles: { [number]: BasePart }, -- tileIndex -> 아직 살아 있는 칸 파츠
	pending: { [number]: boolean }, -- tileIndex -> 지금 경고·들어 올리는 중이면 true (새 과녁에서 빠져요)
}
local roundStates: { [MapTypes.RoundContext]: RoundState } = {}

local function aliveIndices(state: RoundState): { Logic.Tile }
	local list: { Logic.Tile } = {}
	for row = 0, GRID_SIZE - 1 do
		for col = 0, GRID_SIZE - 1 do
			local index = Layout.tileIndex(row, col) :: number
			if state.tiles[index] and not state.pending[index] then
				table.insert(list, { row = row, col = col })
			end
		end
	end
	return list
end

local function setPending(state: RoundState, tiles: { Logic.Tile }, value: boolean?)
	for _, t in tiles do
		local index = Layout.tileIndex(t.row, t.col)
		if index then
			state.pending[index] = value
		end
	end
end

-- 레이서들이 지금 서 있는 칸 (격자 밖이면 제외 — 낙하 중이거나 스폰 전)
local function racerTiles(ctx: MapTypes.RoundContext): { Logic.Tile }
	local origin = ctx.origin
	local list: { Logic.Tile } = {}
	for _, player in ctx.getRacers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local relative = origin:PointToObjectSpace(root.Position)
			local col = Layout.colOf(relative.X)
			local row = Layout.rowOf(relative.Z - Layout.CENTER_Z)
			if row >= 0 and row < GRID_SIZE and col >= 0 and col < GRID_SIZE then
				table.insert(list, { row = row, col = col })
			end
		end
	end
	return list
end

-- 경고(노란 깜빡임, warnTime초) → 바닥 없앰(CanCollide/Touch/Query = false, 그 순간 위에 있던 사람은 떨어져요)
-- → 들어 올리는 연출(보너스) → Destroy. 집게 발톱도 과녁 쪽으로 움직였다가(경고 0.3초 전부터 내려옴) 다시 올라가요.
local function liftWindow(
	ctx: MapTypes.RoundContext,
	state: RoundState,
	window: { Logic.Tile },
	warnTime: number,
	claw: Model?
)
	local parts: { BasePart } = {}
	for _, t in window do
		local index = Layout.tileIndex(t.row, t.col)
		local part = index and state.tiles[index]
		if part and part.Parent then
			table.insert(parts, part)
		end
	end
	if #parts == 0 then
		setPending(state, window, nil)
		return
	end

	local sum = Vector3.zero
	for _, part in parts do
		sum += part.Position
	end
	local center = sum / #parts

	if claw then
		task.spawn(
			movePivot,
			claw,
			CFrame.new(center + Vector3.new(0, Art.RAIL_HEIGHT - 2, 0)),
			math.min(CLAW_HOVER_TIME, warnTime)
		)
	end

	local baseColors: { [BasePart]: Color3 } = {}
	for _, part in parts do
		baseColors[part] = part.Color
	end
	local warnColor = rgb(WARN_RGB[1], WARN_RGB[2], WARN_RGB[3])
	local blinkOn = true
	local descending = false
	local warned = 0
	while warned < warnTime do
		if not ctx.isActive() then
			setPending(state, window, nil)
			return
		end
		for _, part in parts do
			if part.Parent then
				part.Color = if blinkOn then warnColor else baseColors[part]
			end
		end
		blinkOn = not blinkOn
		if claw and not descending and warnTime - warned <= CLAW_DESCEND_LEAD then
			descending = true
			task.spawn(
				movePivot,
				claw,
				CFrame.new(center + Vector3.new(0, Art.RAIL_HEIGHT - 2 - CLAW_DESCEND_DROP, 0)),
				CLAW_DESCEND_LEAD
			)
		end
		warned += task.wait(WARN_BLINK)
	end
	if not ctx.isActive() then
		setPending(state, window, nil)
		return
	end

	MapSfx.play(parts[1], "ClawLift")
	for _, part in parts do
		if part.Parent then
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Transparency = 0.3
		end
	end

	local liftThread: thread? = nil
	if claw then
		liftThread = task.spawn(movePivot, claw, claw:GetPivot() + Vector3.new(0, CLAW_LIFT_HEIGHT, 0), CLAW_LIFT_TIME)
		ctx.cleanup:add(liftThread :: thread)
	end
	local RunService = game:GetService("RunService")
	local starts: { [BasePart]: Vector3 } = {}
	for _, part in parts do
		starts[part] = part.Position
	end
	local elapsed = 0
	while elapsed < CLAW_LIFT_TIME do
		elapsed += RunService.Heartbeat:Wait()
		local alpha = math.min(elapsed / CLAW_LIFT_TIME, 1)
		for _, part in parts do
			if part.Parent then
				part.Position = starts[part] + Vector3.new(0, CLAW_LIFT_HEIGHT * alpha, 0)
			end
		end
	end
	for _, part in parts do
		if part.Parent then
			local index = part:GetAttribute("Index")
			if type(index) == "number" then
				state.tiles[index] = nil
			end
			part:Destroy()
		end
	end
	setPending(state, window, nil)
end

local function start(ctx: MapTypes.RoundContext)
	local RunService = game:GetService("RunService")
	local origin = ctx.origin
	local startedAt = os.clock()

	local tiles: { [number]: BasePart } = {}
	for _, instance in taggedInModel(ctx.model, TAG_TILE) do
		if instance:IsA("BasePart") then
			local index = instance:GetAttribute("Index")
			if type(index) == "number" then
				tiles[index] = instance
			end
		end
	end
	local state: RoundState = { startedAt = startedAt, overtimeAt = nil, tiles = tiles, pending = {} }
	roundStates[ctx] = state
	ctx.cleanup:add(function()
		roundStates[ctx] = nil
	end)

	local claw: Model? = nil
	for _, instance in taggedInModel(ctx.model, TAG_CLAW) do
		if instance:IsA("Model") then
			claw = instance
		end
	end

	-- 낙하 판정: 칸 윗면(원래 origin 기준, 기울어도 안 바뀌어요)보다 FALL_DEPTH 아래로 내려가면 탈락
	ctx.cleanup:add(RunService.Heartbeat:Connect(function()
		if not ctx.isActive() then
			return
		end
		for _, player in ctx.getRacers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") and origin:PointToObjectSpace(root.Position).Y < -Layout.FALL_DEPTH then
				ctx.eliminate(player)
				if not ctx.isActive() then
					break
				end
			end
		end
	end))

	-- 집게 일정: Logic.clawWave대로 주기적으로 과녁을 고르고 들어 올려요. 연장전이 시작되면 새 과녁은 멈춰요.
	ctx.cleanup:add(task.spawn(function()
		while ctx.isActive() do
			if state.overtimeAt ~= nil then
				break
			end
			local elapsed = os.clock() - startedAt
			local wave = Logic.clawWave(elapsed, nil)
			if wave == nil then
				task.wait(math.max(0.2, Logic.START_GRACE - elapsed))
				continue
			end
			local alive = aliveIndices(state)
			if #alive > 0 then
				local chosen = Logic.pickClawTarget(ctx.rng, racerTiles(ctx), alive, wave.size, GRID_SIZE)
				setPending(state, chosen, true)
				ctx.cleanup:add(task.spawn(liftWindow, ctx, state, chosen, wave.warnTime, claw))
			end
			task.wait(wave.interval)
		end
	end))
end

-- 연장전(기운 쪽) 줄 하나: warnTime 동안 노랗게 깜빡인 뒤 사라져요 (SkewerShowdown.collapseStrip과 같은 패턴).
local function collapseLine(
	ctx: MapTypes.RoundContext,
	state: RoundState?,
	dim: string,
	gridIndex: number,
	dropAt: number
)
	local parts: { BasePart } = {}
	if state then
		for row = 0, GRID_SIZE - 1 do
			for col = 0, GRID_SIZE - 1 do
				local matches = if dim == "row" then row == gridIndex else col == gridIndex
				if matches then
					local index = Layout.tileIndex(row, col) :: number
					local part = state.tiles[index]
					if part and part.Parent then
						table.insert(parts, part)
					end
				end
			end
		end
	else
		-- start가 실패했어도 바닥은 없애요 (안전 상한까지 기다리지 않게)
		for _, instance in taggedInModel(ctx.model, TAG_TILE) do
			if instance:IsA("BasePart") then
				local r, c = instance:GetAttribute("Row"), instance:GetAttribute("Col")
				local matches = if dim == "row" then r == gridIndex else c == gridIndex
				if type(r) == "number" and type(c) == "number" and matches then
					table.insert(parts, instance)
				end
			end
		end
	end
	if #parts == 0 then
		return
	end
	local baseColors: { [BasePart]: Color3 } = {}
	for _, part in parts do
		baseColors[part] = part.Color
	end
	local warnColor = rgb(WARN_RGB[1], WARN_RGB[2], WARN_RGB[3])
	local blinkOn = true
	while os.clock() < dropAt do
		if not ctx.isActive() then
			return
		end
		for _, part in parts do
			if part.Parent then
				part.Color = if blinkOn then warnColor else baseColors[part]
			end
		end
		blinkOn = not blinkOn
		task.wait(math.min(WARN_BLINK, math.max(dropAt - os.clock(), 0)))
	end
	if not ctx.isActive() then
		return
	end
	for _, part in parts do
		if part.Parent then
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Transparency = 1
			if state then
				local index = part:GetAttribute("Index")
				if type(index) == "number" then
					state.tiles[index] = nil
				end
			end
		end
	end
	MapSfx.play(parts[1], "TileVanish")
end

-- 결승 연장전 (m5-01): 새 집게 과녁 선정은 멈추고(start의 루프가 state.overtimeAt을 보고 멈춰요, 이미 진행 중인
-- 경고·들어 올리기는 끝까지), 유리 상자 전체가 collapseDuration초에 걸쳐 0→35도로 기울며 낮은 쪽 줄부터
-- 한 줄씩(8줄) 사라져요. 집게 레일·발톱·유리벽·천장은 처음부터 충돌이 없어서 매달려 버틸 곳이 없어요.
local function overtime(ctx: MapTypes.RoundContext, info: MapTypes.OvertimeInfo)
	local now = os.clock()
	local state = roundStates[ctx]
	if state then
		state.overtimeAt = now - state.startedAt
	end

	-- 기우는 방향: 4가지(행/열 x 낮은 쪽 방향) 중 무작위 (결정 기록 D4)
	local DIRS = {
		{ dim = "row", sign = 1 },
		{ dim = "row", sign = -1 },
		{ dim = "col", sign = 1 },
		{ dim = "col", sign = -1 },
	}
	local dir = DIRS[ctx.rng:NextInteger(1, #DIRS)]
	local origin = ctx.origin

	ctx.cleanup:add(task.spawn(function()
		local RunService = game:GetService("RunService")
		local elapsed = 0
		while ctx.isActive() and elapsed < info.collapseDuration do
			elapsed += RunService.Heartbeat:Wait()
			local angle = math.rad(Logic.OVERTIME_MAX_TILT) * math.clamp(elapsed / info.collapseDuration, 0, 1)
			local rx = if dir.dim == "row" then dir.sign * angle else 0
			local rz = if dir.dim == "col" then dir.sign * angle else 0
			ctx.model:PivotTo(origin * CFrame.Angles(rx, 0, rz))
		end
	end))

	for _, step in Logic.overtimeTilt(info.collapseDuration, OVERTIME_WARN_TIME, GRID_SIZE) do
		-- step.row(1..GRID_SIZE, 낮은 쪽부터) → 실제 격자 row/col 번호
		local gridIndex = if dir.sign == 1 then step.row - 1 else GRID_SIZE - step.row
		ctx.cleanup:add(task.delay(step.warnAt, collapseLine, ctx, state, dir.dim, gridIndex, now + step.dropAt))
	end
end

local ClawMachinePrize: MapTypes.MapModule = {
	id = ID,
	kind = "Final",
	displayName = "인형뽑기 기계 속",
	rule = "집게가 훑고 지나가는 유리 상자 안에서 버텨요.",
	build = build,
	start = start,
	overtime = overtime,
}

return ClawMachinePrize
