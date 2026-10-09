--!strict
-- Survival 맵 "와르르 나무 블록"(giant-jenga, m5-16). GDD §5.3(v0.6), 결정 기록은 스펙 참고.
--
-- 공중에 뜬 5×5 나무 블록탑(25칸, 한 칸 3단) 위에서 버텨요. 가운데 3×3은 뽑히지 않는 받침대(보호 칸)고,
-- 바깥 테두리 16칸 아래에서는 셰프가 주기적으로(갈수록 빨라져요) 블록을 하나씩 뽑아 가요. 블록이 뽑힌 칸은
-- 그 칸만(그리고 그 칸에 맞닿은 칸들의 "낮은 쪽" 계산에) 영향을 줘요 — 셰프의 도마(전체가 같이 기움)와 달리
-- "탑의 어느 부분이 약해졌는지" 계속 눈으로 읽고 무게중심을 옮겨야 해요.
--
-- 판정은 ctx.eliminate만 불러요 (탑 꼭대기보다 30 아래로 떨어지면). Survival 종료(목표 인원 이하, 60초 종료 시
-- 전원 통과)와 점수(높이)는 RoundService/RoundLogic이 해요.
-- 칸(GiantJengaColumn)은 CollectionService 태그를 달고, start에서 ctx.model 하위의 태그만 동작시켜요.
-- 상태(보드 레벨, 애니메이션 중인지)는 전부 start 안의 지역 변수에 둬요 (여러 방이 같은 맵을 동시에 돌려도 안전).
-- 국소 기울기 밀기는 연속 밀기(기준 안)라 MoveExempt를 달지 않아요 (ChefBoardLogic과 같은 판례).
-- 순수 로직은 GiantJengaLayout(격자 치수)·GiantJengaLogic(보드 상태·제거 일정·기울기), 아트 데이터는 GiantJengaArt.
-- Roblox API는 build/start 안에서만 써요 — require만 하는 것(Lune 테스트)은 안전해요.

local Art = require(script.Parent.GiantJengaArt)
local Config = require(script.Parent.Parent.Config)
local Layout = require(script.Parent.GiantJengaLayout)
local Logic = require(script.Parent.GiantJengaLogic)
local MapKit = require(script.Parent.MapKit)
local MapSfx = require(script.Parent.MapSfx)
local MapTypes = require(script.Parent.MapTypes)

local ID = "giant-jenga"
local TAG_COLUMN = "GiantJengaColumn"

local TOP_THICKNESS = 0.4
local BLOCK_GAP = 1 -- 바깥 블록 테두리가 살짝 안쪽 (칸 사이 틈처럼 보이게, 판정은 Top만 해요)
local PEDESTAL_GAP = 0.6

type RGB = { r: number, g: number, b: number }

local function color3(c: RGB): Color3
	return Color3.fromRGB(c.r, c.g, c.b)
end

local function makePart(props: { [string]: any }): BasePart
	local parent = props.Parent
	props.Parent = nil
	local p = Instance.new("Part")
	p.Anchored = true
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

local function ghost(part: BasePart)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
end

local function build(origin: CFrame): Model
	local CollectionService = game:GetService("CollectionService")

	local model = Instance.new("Model")
	model.Name = ID

	local columnsFolder = Instance.new("Folder")
	columnsFolder.Name = "Columns"
	local size = Layout.CELL_SIZE
	local towerHeight = Layout.LEVEL_MAX * Layout.LEVEL_DROP

	for _, column in Layout.columns() do
		local protected = Layout.isProtected(column.i, column.j)
		local top = makePart({
			Name = `Column_{column.i}_{column.j}`,
			Size = Vector3.new(size, TOP_THICKNESS, size),
			CFrame = origin * CFrame.new(column.x, -TOP_THICKNESS / 2, column.z),
			Color = if protected
				then color3(Art.PEDESTAL_COLOR)
				else color3(Art.blockColor(column.i, column.j, Layout.LEVEL_MAX)),
		})
		top:SetAttribute("ColumnI", column.i)
		top:SetAttribute("ColumnJ", column.j)
		CollectionService:AddTag(top, TAG_COLUMN)

		local blocks = Instance.new("Folder")
		blocks.Name = "Blocks"
		if protected then
			local pedestal = makePart({
				Name = "Pedestal",
				Size = Vector3.new(size - PEDESTAL_GAP, towerHeight, size - PEDESTAL_GAP),
				CFrame = origin * CFrame.new(column.x, -towerHeight / 2, column.z),
				Color = color3(Art.PEDESTAL_COLOR),
				Material = Enum.Material.Wood,
			})
			ghost(pedestal)
			pedestal.Parent = blocks
		else
			for level = 1, Layout.LEVEL_MAX do
				local centerY = -(level - 1) * Layout.LEVEL_DROP - Layout.LEVEL_DROP / 2
				local block = makePart({
					Name = `Block{level}`,
					Size = Vector3.new(size - BLOCK_GAP, Layout.LEVEL_DROP - 0.2, size - BLOCK_GAP),
					CFrame = origin * CFrame.new(column.x, centerY, column.z),
					Color = color3(Art.blockColor(column.i, column.j, level)),
				})
				ghost(block)
				block.Parent = blocks
			end
		end
		blocks.Parent = top
		top.Parent = columnsFolder
	end
	columnsFolder.Parent = model

	-- 스폰 24개: 정중앙 (0,0)을 뺀 나머지 칸 위 (RoundService가 조금 띄워서 배치해요)
	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	for i, offset in Layout.spawnOffsets() do
		local spawn = makePart({
			Name = string.format("Spawn%02d", i),
			Size = Vector3.new(2, 0.2, 2),
			CFrame = origin * CFrame.new(offset.x, 0.1, offset.z),
			Color = Color3.fromRGB(246, 196, 70),
			Transparency = 0.4,
		})
		ghost(spawn)
		spawn.Parent = spawns
	end
	spawns.Parent = model

	for _, part in MapKit.buildDecor(Art.decor(), origin, MapKit.decorFolder(model)) do
		if part.Name == Art.LAMP_BULB then
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 235, 180)
			light.Brightness = 1
			light.Range = 24
			light.Parent = part
		end
	end
	MapKit.introCamera(model, Art.introCamera(), origin)
	MapKit.attachStudioArt(model, ID, origin)

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

type ColumnEntry = {
	part: BasePart,
	i: number,
	j: number,
	key: string,
	blocks: { [number]: BasePart },
	busy: boolean, -- 삐걱이거나·가라앉거나·사라지는 중 (그동안 기울기 갱신을 건너뛰어요)
	vanished: boolean,
	tilt: Logic.TiltParams?, -- 이번 프레임 기울기 (밀기 계산용)
}

local function start(ctx: MapTypes.RoundContext)
	local RunService = game:GetService("RunService")

	local origin = ctx.origin
	local startedAt = os.clock()
	local board = Logic.newBoard()

	local columns: { [string]: ColumnEntry } = {}
	for _, instance in taggedInModel(ctx.model, TAG_COLUMN) do
		if instance:IsA("BasePart") then
			local i = instance:GetAttribute("ColumnI")
			local j = instance:GetAttribute("ColumnJ")
			if type(i) == "number" and type(j) == "number" then
				local blocks: { [number]: BasePart } = {}
				local blocksFolder = instance:FindFirstChild("Blocks")
				if blocksFolder then
					for level = 1, Layout.LEVEL_MAX do
						local block = blocksFolder:FindFirstChild(`Block{level}`)
						if block and block:IsA("BasePart") then
							blocks[level] = block
						end
					end
				end
				local key = Layout.key(i, j)
				columns[key] = {
					part = instance,
					i = i,
					j = j,
					key = key,
					blocks = blocks,
					busy = false,
					vanished = false,
					tilt = nil,
				}
			end
		end
	end

	local function flatCFrame(entry: ColumnEntry): CFrame
		local y = Logic.heightOf(board, entry.i, entry.j)
		return origin * CFrame.new(entry.i * Layout.CELL_SIZE, y, entry.j * Layout.CELL_SIZE)
	end

	-- 매 프레임: 기울어진 칸을 다시 계산해 돌리고, 낙하 탈락·기운 쪽으로 밀기
	ctx.cleanup:add(RunService.Heartbeat:Connect(function(dt: number)
		if not ctx.isActive() then
			return
		end

		for _, entry in columns do
			if entry.busy or entry.vanished then
				continue
			end
			local tilt = Logic.tiltFor(board, entry.i, entry.j)
			entry.tilt = tilt
			local rotation = if tilt
				then CFrame.fromAxisAngle(Vector3.new(tilt.axisX, 0, tilt.axisZ), tilt.angle)
				else CFrame.identity
			entry.part.CFrame = flatCFrame(entry) * rotation
		end

		for _, player in ctx.getRacers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not (root and root:IsA("BasePart")) then
				continue
			end
			local relative = origin:PointToObjectSpace(root.Position)
			if relative.Y < -Layout.FALL_DEPTH then
				ctx.eliminate(player)
				if not ctx.isActive() then
					return -- 이 탈락으로 라운드가 끝났어요
				end
				continue
			end

			local ci = math.round(relative.X / Layout.CELL_SIZE)
			local cj = math.round(relative.Z / Layout.CELL_SIZE)
			if not Layout.inGrid(ci, cj) then
				continue
			end
			local entry = columns[Layout.key(ci, cj)]
			if not entry or entry.busy or entry.vanished or entry.tilt == nil then
				continue
			end
			local dx = math.abs(relative.X - ci * Layout.CELL_SIZE)
			local dz = math.abs(relative.Z - cj * Layout.CELL_SIZE)
			local columnY = Logic.heightOf(board, ci, cj)
			if dx > Layout.CELL_SIZE / 2 + 1 or dz > Layout.CELL_SIZE / 2 + 1 then
				continue
			end
			if relative.Y < columnY - 6 or relative.Y > columnY + 8 then
				continue
			end
			local tilt = entry.tilt :: Logic.TiltParams
			local pushDirection = origin:VectorToWorldSpace(Vector3.new(tilt.downX, 0, tilt.downZ))
			local pushSpeed = Logic.TILT_PUSH_SPEED * tilt.strength
			local current = root.AssemblyLinearVelocity
			local along = current:Dot(pushDirection)
			if along < pushSpeed then
				local delta = math.min(Logic.TILT_PUSH_ACCEL * dt, pushSpeed - along)
				root.AssemblyLinearVelocity = current + pushDirection * delta
			end
			-- 기울기 밀기(최고 6)는 연속 밀기라 MoveExempt를 달지 않아요 (ChefBoardLogic 판례).
		end
	end))

	-- 칸 하나 뽑기: 삐걱임(0.8초, 그 칸만 흔들림) → 레벨 -1 →
	--   레벨 > 0이면 부드럽게 가라앉고 안정 / 레벨 0이면 추가로 0.5초 흔들린 뒤 사라져 구멍이 돼요.
	local function removeColumn(column: Layout.Column)
		local entry = columns[column.key]
		if not entry or entry.busy or entry.vanished then
			return
		end
		entry.busy = true
		MapSfx.play(entry.part, "BlockCreak")

		local home = flatCFrame(entry) -- 흔들리는 동안은 평평한 자리를 기준으로 떨려요
		local shakeAmt = 0.18
		local shaken = 0
		while shaken < Logic.CREAK_TIME do
			shaken += task.wait()
			entry.part.CFrame = home
				* CFrame.new(ctx.rng:NextNumber(-shakeAmt, shakeAmt), 0, ctx.rng:NextNumber(-shakeAmt, shakeAmt))
		end
		entry.part.CFrame = home
		if not ctx.isActive() then
			entry.busy = false
			return
		end

		Logic.applyRemoval(board, { column })
		local newLevel = board.levels[column.key] or 0
		local poppedBlock = entry.blocks[newLevel + 1]
		if poppedBlock then
			poppedBlock.Transparency = 1
			poppedBlock.CanCollide = false
		end

		if newLevel > 0 then
			local fromCFrame = entry.part.CFrame
			local toCFrame = flatCFrame(entry)
			local elapsed = 0
			while elapsed < Logic.SINK_TIME do
				elapsed += RunService.Heartbeat:Wait()
				entry.part.CFrame = fromCFrame:Lerp(toCFrame, math.min(elapsed / Logic.SINK_TIME, 1))
			end
			entry.part.CFrame = toCFrame
			entry.busy = false
			return
		end

		local shaken2 = 0
		while shaken2 < Logic.VANISH_SHAKE_TIME do
			shaken2 += task.wait()
			entry.part.CFrame = home
				* CFrame.new(ctx.rng:NextNumber(-shakeAmt, shakeAmt), 0, ctx.rng:NextNumber(-shakeAmt, shakeAmt))
		end
		entry.part.CFrame = home
		entry.part.CanCollide = false
		entry.part.CanQuery = false
		MapSfx.play(entry.part, "TileVanish")
		entry.part.Transparency = 1
		for _, block in entry.blocks do
			block.CanCollide = false
			block.Transparency = 1
		end
		entry.vanished = true
		entry.busy = false
	end

	-- 제거 일정: 시간이 갈수록 간격이 좁아지고 한 번에 뽑는 개수가 늘어요
	ctx.cleanup:add(task.spawn(function()
		local previousKeys: { string }? = nil
		for _, removeAt in Logic.removalTimes(Config.TimeLimit.Survival) do
			local untilThen = removeAt - (os.clock() - startedAt)
			if untilThen > 0 then
				task.wait(untilThen)
			end
			if not ctx.isActive() then
				break
			end
			local wave = Logic.removalWave(removeAt)
			if wave == nil then
				break
			end
			local picks = Logic.pickColumns(board, previousKeys, wave.count, ctx.rng)
			if #picks > 0 then
				local keys = {}
				for _, column in picks do
					table.insert(keys, column.key)
					ctx.cleanup:add(task.spawn(removeColumn, column))
				end
				previousKeys = keys
			end
		end
	end))
end

local GiantJenga: MapTypes.MapModule = {
	id = ID,
	kind = "Survival",
	displayName = "와르르 나무 블록",
	rule = "국소적으로 흔들리는 블록탑 위에서 안 떨어지게 버티세요!",
	build = build,
	start = start,
}

return GiantJenga
