--!strict
-- Race 대형 맵 "초밥집 카운터 대횡단" (m6-03, GDD v0.9 5.2, 제안서 large-maps ①). 폭 72·스폰 40·12~40명.
--   B 갈림길: 왼 회전 레일(RailSegment 태그, 서버가 구간 방향으로 연속 밀기 — MoveExempt 없음, 방향이 바뀌면 색도 바뀜)
--             가운데 접시 징검다리(고정 원판), 오른 간장병(CounterBottle 태그, 충돌 없음 — 서버가 옮기고 숫자로 맞음 판정)
--   D 젓가락 들판: 서버가 빨간 원(StrikeDisc)을 띄우고 1.5초 뒤 젓가락(StrikeStick)을 내려 원 안 사람을 바깥으로 넉백
--   E 계산대 오르막: 바깥 두 줄 영수증이 뒤로 연속 밀기, 안쪽 두 줄 동전(CounterCoin 태그)이 굴러옴
-- 치수는 SushiCounterCrossingLayout, 계산은 SushiCounterCrossingLogic, 장식은 SushiCounterCrossingArt.
-- 태그 파츠는 ctx.model 하위의 것만 쓰고, 상태는 전부 start 안 지역 변수에 둬요(여러 방 동시 진행).
-- Roblox API는 build/start 안에서만 써요 — require만 하는 것(Lune 테스트)은 안전해요.

local Art = require(script.Parent.SushiCounterCrossingArt)
local Layout = require(script.Parent.SushiCounterCrossingLayout)
local Logic = require(script.Parent.SushiCounterCrossingLogic)
local MapKit = require(script.Parent.MapKit)
local MapSfx = require(script.Parent.MapSfx)
local MapTypes = require(script.Parent.MapTypes)
local MoveExempt = require(script.Parent.Parent.MoveExempt)

local ID = "sushi-counter-crossing"
local TAG_RAIL = "RailSegment"
local TAG_BOTTLE = "CounterBottle"
local TAG_COIN = "CounterCoin"
local TAG_STRIKE = "ChopstickStrike"
local PARK_Y = -85 -- 쉬는 굴림·젓가락을 숨겨 두는 높이 (origin 기준, 가게 바닥 -70 아래)

local function rgb(c: { r: number, g: number, b: number }): Color3
	return Color3.fromRGB(c.r, c.g, c.b)
end

local function makePart(props: { [string]: any }, class: string?): BasePart
	local parent = props.Parent
	props.Parent = nil
	local p = Instance.new(class or "Part") :: BasePart
	p.Anchored = true
	p.CanCollide = true
	p.Material = Enum.Material.SmoothPlastic
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

local function ghost(props: { [string]: any }, class: string?): BasePart
	props.CanCollide = false
	props.CanTouch = false
	props.CanQuery = false
	return makePart(props, class)
end

local function build(origin: CFrame): Model
	local CollectionService = game:GetService("CollectionService")
	local C = Art.JUDGE_COLORS
	local model = Instance.new("Model")
	model.Name = ID
	local thickness = Layout.FLOOR_THICKNESS

	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end

	-- 바닥 (광장·들판·결승·레일 구간·간장병 줄·오르막 위 평지)
	for _, rect in Layout.floorRects() do
		local color = C.counter
		local material = Enum.Material.WoodPlanks
		if string.sub(rect.name, 1, 4) == "Rail" then
			color = C.railForward
			material = Enum.Material.SmoothPlastic
		elseif rect.name == "ChopstickField" then
			color = C.field
		elseif rect.name == "FinishPlaza" or string.sub(rect.name, 1, 7) == "RampTop" then
			color = C.register
			material = Enum.Material.SmoothPlastic
		end
		local part = makePart({
			Name = rect.name,
			Size = Vector3.new(rect.maxX - rect.minX, thickness, rect.maxZ - rect.minZ),
			CFrame = at((rect.minX + rect.maxX) / 2, rect.top - thickness / 2, (rect.minZ + rect.maxZ) / 2),
			Color = rgb(color),
			Material = material,
			CustomPhysicalProperties = PhysicalProperties.new(Enum.Material.SmoothPlastic),
			Parent = model,
		})
		local segment = tonumber(string.match(rect.name, "^Rail(%d)$"))
		if segment then
			part:SetAttribute("RailSegment", segment)
			CollectionService:AddTag(part, TAG_RAIL)
		end
	end

	-- 들판 양옆 낮은 벽 (떨어지지 않게)
	for _, side in { -1, 1 } do
		local field = Layout.FIELD
		makePart({
			Name = "FieldWall",
			Size = Vector3.new(Layout.FIELD_WALL_THICKNESS, Layout.FIELD_WALL_HEIGHT, field.front - field.back),
			CFrame = at(
				side * (Layout.HALF + Layout.FIELD_WALL_THICKNESS / 2),
				Layout.LOW_Y + Layout.FIELD_WALL_HEIGHT / 2,
				(field.front + field.back) / 2
			),
			Color = rgb(C.wall),
			Material = Enum.Material.Wood,
			Parent = model,
		})
	end

	-- 접시 징검다리 (고정 원판)
	for _, plate in Layout.PLATES do
		local d = plate.radius * 2
		makePart({
			Name = string.format("StepPlate%02d", plate.index),
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(Layout.PLATE_THICKNESS, d, d),
			CFrame = at(plate.x, plate.top - Layout.PLATE_THICKNESS / 2, plate.z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = rgb(C.plate),
			Reflectance = 0.05,
			Parent = model,
		})
	end

	-- 계산대 오르막 쐐기 4줄 (높은 쪽이 결승 쪽 -Z)
	local slope = Layout.RAMP_SLOPE
	for _, ramp in Layout.RAMP_LIST do
		makePart({
			Name = string.format("Ramp%d", ramp.index),
			Size = Vector3.new(Layout.RAMP_WIDTH, Layout.HIGH_Y - Layout.LOW_Y, slope.front - slope.back),
			CFrame = at(ramp.x, (Layout.LOW_Y + Layout.HIGH_Y) / 2, (slope.front + slope.back) / 2)
				* CFrame.Angles(0, math.pi, 0),
			Color = rgb(if ramp.kind == "Receipt" then C.receipt else C.register),
			Parent = model,
		}, "WedgePart")
		if ramp.kind == "Receipt" then
			-- 영수증 종이 띠 (평지 구간까지, 밟는 면 바로 위 얇은 장식 — 충돌 없음)
			ghost({
				Name = "ReceiptStrip",
				Size = Vector3.new(Layout.RAMP_WIDTH - 4, 0.1, Layout.RAMP_SLOPE.back - Layout.RAMPS.back),
				CFrame = at(ramp.x, Layout.HIGH_Y + 0.05, (Layout.RAMP_SLOPE.back + Layout.RAMPS.back) / 2),
				Color = rgb(C.receiptPaper),
				Parent = model,
			})
		end
	end

	-- 출발 스폰 40개
	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = model
	local positions = Layout.spawnPositions()
	assert(#positions == Layout.CAPACITY, "spawn count must equal capacity")
	for i, pos in positions do
		ghost({
			Name = string.format("Spawn%02d", i),
			Size = Vector3.new(2, 0.2, 2),
			CFrame = at(pos.x, Layout.LOW_Y + 0.1, pos.z),
			Color = Color3.fromRGB(246, 196, 70),
			Transparency = 0.4,
			Parent = spawns,
		})
	end

	-- 결승선
	ghost({
		Name = "FinishLine",
		Size = Vector3.new(Layout.WIDTH, 0.4, 1),
		CFrame = at(0, Layout.HIGH_Y + 0.2, Layout.FINISH_LINE_Z),
		Color = Color3.fromRGB(255, 196, 40),
		Material = Enum.Material.Neon,
		Parent = model,
	})

	-- 굴러오는 것 (충돌 없음, 서버가 옮겨요). 처음엔 아래에 숨겨 둬요.
	local rollers = Instance.new("Folder")
	rollers.Name = "Rollers"
	rollers.Parent = model
	local park = at(0, PARK_Y, 0)
	for slot = 1, Layout.BOTTLE_SLOTS do
		local bottle = ghost({
			Name = string.format("Bottle%d", slot),
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(Layout.BOTTLE_LENGTH, Layout.BOTTLE_DIAMETER, Layout.BOTTLE_DIAMETER),
			CFrame = park,
			Color = rgb(C.bottle),
			Material = Enum.Material.Glass,
			Transparency = 0.15,
			Parent = rollers,
		})
		bottle:SetAttribute("Slot", slot)
		CollectionService:AddTag(bottle, TAG_BOTTLE)
	end
	for _, ramp in Layout.RAMP_LIST do
		if ramp.kind ~= "Coin" then
			continue
		end
		for slot = 1, Layout.COIN_SLOTS do
			local coin = ghost({
				Name = string.format("Coin%d_%d", ramp.index, slot),
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(Layout.COIN_LENGTH, Layout.COIN_DIAMETER, Layout.COIN_DIAMETER),
				CFrame = park,
				Color = rgb(C.coin),
				Material = Enum.Material.Metal,
				Reflectance = 0.2,
				Parent = rollers,
			})
			coin:SetAttribute("Slot", slot)
			coin:SetAttribute("Lane", ramp.index)
			CollectionService:AddTag(coin, TAG_COIN)
		end
	end

	-- 젓가락 들판 묶음: 경고 원(StrikeDisc) + 젓가락 두 짝(StrikeStick). 서버가 띄우고 숨겨요.
	local strikes = Instance.new("Folder")
	strikes.Name = "Strikes"
	strikes.Parent = model
	for slot = 1, Layout.STRIKE_SLOTS do
		local disc = ghost({
			Name = "StrikeDisc",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, Layout.STRIKE_RADIUS * 2, Layout.STRIKE_RADIUS * 2),
			CFrame = park,
			Color = rgb(C.warn),
			Material = Enum.Material.Neon,
			Transparency = 1,
			Parent = strikes,
		})
		disc:SetAttribute("Slot", slot)
		CollectionService:AddTag(disc, TAG_STRIKE)
		for k = 1, 2 do
			local stick = ghost({
				Name = "StrikeStick",
				Size = Vector3.new(1.4, Art.STICK_LENGTH, 1.4),
				CFrame = park,
				Color = rgb(C.stick),
				Material = Enum.Material.Wood,
				Parent = strikes,
			})
			stick:SetAttribute("Slot", slot)
			stick:SetAttribute("Side", k)
		end
	end

	-- 장식(충돌 없음) + 소개 카메라 + 사용자 Studio 아트 자리
	MapKit.buildDecor(Art.decor(), origin, MapKit.decorFolder(model))
	MapKit.introCamera(model, Art.introCamera(), origin)
	MapKit.attachStudioArt(model, ID, origin)

	return model
end

local function taggedParts(ctx: MapTypes.RoundContext, tag: string): { BasePart }
	local CollectionService = game:GetService("CollectionService")
	local parts = {}
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("BasePart") and ctx.model:IsAncestorOf(instance) then
			table.insert(parts, instance)
		end
	end
	return parts
end

local function rootAndHumanoid(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if character == nil then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") then
		return root, humanoid
	end
	return nil, humanoid
end

-- 넉백: 캐릭터 물리는 그 클라이언트가 맡아서 서버가 LinearVelocity를 잠깐 걸어요 (설거지통 수세미와 같은 방식)
local function knock(
	ctx: MapTypes.RoundContext,
	player: Player,
	root: BasePart,
	humanoid: Humanoid?,
	velocity: Vector3,
	exempt: number,
	down: number
)
	MoveExempt.mark(player.Character, exempt)
	local attachment = root:FindFirstChild("RootAttachment") or root:FindFirstChildOfClass("Attachment")
	if attachment == nil then
		local created = Instance.new("Attachment")
		created.Name = "CounterAttachment"
		created.Parent = root
		ctx.cleanup:add(created)
		attachment = created
	end
	local push = Instance.new("LinearVelocity")
	push.Name = "CounterKnock"
	push.Attachment0 = attachment :: Attachment
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	push.VectorVelocity = velocity
	push.MaxForce = math.huge
	push.Parent = root
	root.AssemblyLinearVelocity = velocity
	ctx.cleanup:add(push)
	ctx.cleanup:add(task.delay(0.15, function()
		push:Destroy()
	end))
	if humanoid then
		humanoid.PlatformStand = true
		ctx.cleanup:add(task.delay(down, function()
			-- 그 사이 통과·탈락(·부활 대기)했으면 손대지 않아요
			if humanoid.Parent == nil or player.Character ~= humanoid.Parent then
				return
			end
			if table.find(ctx.getRacers(), player) then
				humanoid.PlatformStand = false
			end
		end))
	end
end

type StrikeState = { slot: number, x: number, z: number, impactAt: number, endAt: number, struck: boolean }

local function start(ctx: MapTypes.RoundContext)
	local RunService = game:GetService("RunService")
	local origin = ctx.origin
	local C = Art.JUDGE_COLORS
	local startedAt = os.clock()
	local finishProgress = Logic.finishProgress()

	-- 태그 파츠 모으기 (이 방 맵 것만)
	local rails: { [number]: BasePart } = {}
	for _, part in taggedParts(ctx, TAG_RAIL) do
		local segment = part:GetAttribute("RailSegment")
		if type(segment) == "number" then
			rails[segment] = part
		end
	end
	local bottleParts: { [number]: BasePart } = {}
	for _, part in taggedParts(ctx, TAG_BOTTLE) do
		local slot = part:GetAttribute("Slot")
		if type(slot) == "number" then
			bottleParts[slot] = part
		end
	end
	local coinParts: { [string]: BasePart } = {}
	for _, part in taggedParts(ctx, TAG_COIN) do
		local slot, lane = part:GetAttribute("Slot"), part:GetAttribute("Lane")
		if type(slot) == "number" and type(lane) == "number" then
			coinParts[`{lane}:{slot}`] = part
		end
	end
	local discs: { [number]: BasePart } = {}
	local sticks: { [number]: { BasePart } } = {}
	for _, disc in taggedParts(ctx, TAG_STRIKE) do
		local slot = disc:GetAttribute("Slot")
		if type(slot) ~= "number" then
			continue
		end
		discs[slot] = disc
		sticks[slot] = {}
		local folder = disc.Parent
		if folder then
			for _, child in folder:GetChildren() do
				if child:IsA("BasePart") and child.Name == "StrikeStick" and child:GetAttribute("Slot") == slot then
					table.insert(sticks[slot], child)
				end
			end
		end
	end

	local park = origin * CFrame.new(0, PARK_Y, 0)
	local railFlips = -1
	local warnedPeriod = -1
	local strikesActive: { StrikeState } = {}
	local nextStrikeAt = startedAt + Layout.STRIKE_START_DELAY
	local hitReadyAt: { [Player]: number } = {}
	local sideVector = origin.RightVector
	local backVector = origin.LookVector * -1 -- +z (출발 쪽)

	local function stickFrames(x: number, z: number, lifted: boolean): { CFrame }
		local half = Art.STICK_LENGTH / 2
		local baseY = if lifted then Layout.LOW_Y + Art.STICK_HOVER else Layout.LOW_Y
		return {
			origin * CFrame.new(x - 1.2, baseY + half, z) * CFrame.Angles(0, 0, math.rad(-4)),
			origin * CFrame.new(x + 1.2, baseY + half, z) * CFrame.Angles(0, 0, math.rad(4)),
		}
	end

	ctx.cleanup:add(RunService.Heartbeat:Connect(function(dt: number)
		if not ctx.isActive() then
			return
		end
		local now = os.clock()
		local elapsed = now - startedAt

		-- 1. 판정: 결승선 통과 / 낙하
		for _, player in ctx.getRacers() do
			local root = rootAndHumanoid(player)
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

		-- 2. 레일 방향이 바뀌면 색도 바꿔요 (앞으로 = 청록, 뒤로 = 연어색). 바뀌기 직전 경고 소리
		local flips = math.floor(elapsed / Layout.RAIL_PERIOD)
		if flips ~= railFlips then
			railFlips = flips
			for segment, part in rails do
				part.Color = rgb(if Logic.railDirection(segment, elapsed) > 0 then C.railForward else C.railBackward)
			end
		end
		if Logic.railSwitchSoon(elapsed) and warnedPeriod ~= flips then
			warnedPeriod = flips
			MapSfx.play(rails[1], "RailSwitch")
		end

		-- 3. 굴러오는 것·젓가락 옮기기 (한 번에)
		local moveParts: { BasePart } = {}
		local moveFrames: { CFrame } = {}
		local bottles = Logic.bottles(elapsed)
		local bottleBusy: { [number]: boolean } = {}
		for _, b in bottles do
			local part = bottleParts[b.slot]
			if part then
				bottleBusy[b.slot] = true
				table.insert(moveParts, part)
				-- 굴러가는 느낌: z 이동만큼 x축으로 돌려요
				local spin = (b.z - Layout.BOTTLE_FROM_Z) / (Layout.BOTTLE_DIAMETER / 2)
				table.insert(
					moveFrames,
					origin * CFrame.new(b.x, Layout.LOW_Y + Layout.BOTTLE_DIAMETER / 2, b.z) * CFrame.Angles(spin, 0, 0)
				)
			end
		end
		for slot, part in bottleParts do
			if not bottleBusy[slot] then
				table.insert(moveParts, part)
				table.insert(moveFrames, park)
			end
		end
		local coins = Logic.coins(elapsed)
		local coinBusy: { [string]: boolean } = {}
		for _, coin in coins do
			local key = `{coin.lane}:{coin.slot}`
			local part = coinParts[key]
			if part then
				coinBusy[key] = true
				local floorY = Logic.floorAt(coin.z)
				local spin = (coin.z - Layout.COIN_FROM_Z) / (Layout.COIN_DIAMETER / 2)
				table.insert(moveParts, part)
				table.insert(
					moveFrames,
					origin * CFrame.new(coin.x, floorY + Layout.COIN_DIAMETER / 2, coin.z) * CFrame.Angles(spin, 0, 0)
				)
			end
		end
		for key, part in coinParts do
			if not coinBusy[key] then
				table.insert(moveParts, part)
				table.insert(moveFrames, park)
			end
		end

		-- 젓가락: 새 원 띄우기 → 내려찍기 → 숨기기
		if now >= nextStrikeAt then
			nextStrikeAt = now + Layout.STRIKE_INTERVAL
			local used: { [number]: boolean } = {}
			for _, s in strikesActive do
				used[s.slot] = true
			end
			for slot = 1, Layout.STRIKE_SLOTS do
				if not used[slot] and discs[slot] then
					local spot = Logic.strikeAt(ctx.rng)
					table.insert(strikesActive, {
						slot = slot,
						x = spot.x,
						z = spot.z,
						impactAt = now + Layout.STRIKE_WARN,
						endAt = now + Layout.STRIKE_WARN + Layout.STRIKE_SHOW,
						struck = false,
					})
					local disc = discs[slot]
					disc.Transparency = 0.45
					table.insert(moveParts, disc)
					table.insert(
						moveFrames,
						origin * CFrame.new(spot.x, Layout.LOW_Y + 0.15, spot.z) * CFrame.Angles(0, 0, math.rad(90))
					)
					for k, stick in sticks[slot] do
						table.insert(moveParts, stick)
						table.insert(moveFrames, stickFrames(spot.x, spot.z, true)[k])
					end
					MapSfx.play(disc, "ChopstickWarn")
					break
				end
			end
		end
		local impacts: { StrikeState } = {}
		for i = #strikesActive, 1, -1 do
			local s = strikesActive[i]
			if now >= s.endAt then
				table.remove(strikesActive, i)
				local disc = discs[s.slot]
				disc.Transparency = 1
				table.insert(moveParts, disc)
				table.insert(moveFrames, park)
				for _, stick in sticks[s.slot] do
					table.insert(moveParts, stick)
					table.insert(moveFrames, park)
				end
			elseif not s.struck and now >= s.impactAt then
				s.struck = true
				table.insert(impacts, s)
				discs[s.slot].Transparency = 0.2
				for k, stick in sticks[s.slot] do
					table.insert(moveParts, stick)
					table.insert(moveFrames, stickFrames(s.x, s.z, false)[k])
				end
				MapSfx.play(discs[s.slot], "ChopstickClack")
			end
		end
		if #moveParts > 0 then
			workspace:BulkMoveTo(moveParts, moveFrames, Enum.BulkMoveMode.FireCFrameChanged)
		end

		-- 4. 남은 레이서: 젓가락·굴림 맞음, 레일·영수증 밀기
		for _, player in ctx.getRacers() do
			local root, humanoid = rootAndHumanoid(player)
			if root == nil then
				continue
			end
			local rel = origin:PointToObjectSpace(root.Position)
			local foot = rel.Y - Layout.FOOT_OFFSET
			local ready = (hitReadyAt[player] or 0) <= now

			local hit = false
			for _, s in impacts do
				local dx, dz = rel.X - s.x, rel.Z - s.z
				if Logic.strikeHit(dx, dz) and foot - Layout.LOW_Y < Layout.HIT_FOOT + 2 then
					local ux, uz = Logic.strikeKnock(dx, dz)
					local dir = origin:VectorToWorldSpace(Vector3.new(ux, 0, uz))
					knock(
						ctx,
						player,
						root,
						humanoid,
						dir * Layout.STRIKE_KNOCK_OUT + Vector3.new(0, Layout.STRIKE_KNOCK_UP, 0),
						Layout.STRIKE_EXEMPT,
						Layout.STRIKE_DOWN
					)
					hitReadyAt[player] = now + Layout.HIT_COOLDOWN
					hit = true
					break
				end
			end
			if not hit and ready then
				local function tryRoll(list: { Logic.Roller }, length: number, diameter: number, cue: string): boolean
					for _, r in list do
						local floorY = Logic.floorAt(r.z)
						if Logic.rollHit(rel.X - r.x, rel.Z - r.z, foot - floorY, length, diameter) then
							local side = if rel.X >= r.x then 1 else -1
							knock(
								ctx,
								player,
								root,
								humanoid,
								backVector * Layout.ROLL_KNOCK_BACK
									+ sideVector * (side * 6)
									+ Vector3.new(0, Layout.ROLL_KNOCK_UP, 0),
								Layout.ROLL_EXEMPT,
								Layout.ROLL_DOWN
							)
							hitReadyAt[player] = now + Layout.HIT_COOLDOWN
							MapSfx.play(root, cue)
							return true
						end
					end
					return false
				end
				hit = tryRoll(bottles, Layout.BOTTLE_LENGTH, Layout.BOTTLE_DIAMETER, "Knockdown")
					or tryRoll(coins, Layout.COIN_LENGTH, Layout.COIN_DIAMETER, "Knockdown")
			end
			if hit then
				continue
			end

			-- 연속 밀기 (회전 레일·영수증): 목표 속도까지 가속만, 이동 감시 면제 없음
			local targetZ = 0
			local segment = Logic.railAt(rel.X, rel.Y, rel.Z)
			if segment then
				targetZ = -Logic.railDirection(segment, elapsed) * Layout.RAIL_SPEED -- 1이면 -z
			else
				local ramp = Logic.rampAt(rel.X, rel.Y, rel.Z)
				if ramp and ramp.kind == "Receipt" then
					targetZ = Layout.RECEIPT_SPEED -- 뒤로(+z)
				end
			end
			if targetZ ~= 0 then
				local unit = origin:VectorToWorldSpace(Vector3.new(0, 0, if targetZ > 0 then 1 else -1))
				local velocity = root.AssemblyLinearVelocity
				local add = Logic.pushDelta(velocity:Dot(unit), math.abs(targetZ), Layout.PUSH_ACCEL, dt)
				if add ~= 0 then
					root.AssemblyLinearVelocity = velocity + unit * add
				end
			end
		end
	end))
end

local map: MapTypes.MapModule = {
	id = ID,
	kind = "Race",
	displayName = "초밥집 카운터 대횡단",
	rule = "세 갈래 길 중 하나를 골라 젓가락을 피해 계산대까지 달려요!",
	build = build,
	start = start,
	lighting = Art.LIGHTING, -- 저녁 초밥집 카운터, 따뜻한 등불
	capacity = Layout.CAPACITY,
	minPlayers = Layout.MIN_PLAYERS,
}

return map
