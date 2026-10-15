--!strict
-- Survival 맵 "초대형 밥솥" (m5-36, GDD §5.3 3차 배치). 뚜껑을 연 업소용 밥솥 위, 고봉으로 솟은 5단 계단
-- 밥 언덕에서 버텨요. 바닥은 사라지지 않아요 — 발밑에 뜨는 주황 원(밥알 끓어오름, 1.5초 뒤 펑! 위로 튕김)을
-- 비키고, 양옆 증기 밸브가 휘파람과 함께 점선으로 알리는 증기 띠(2초 뒤 1.2초 분사, 옆으로 날림)를 읽고
-- 피해요. 반지름 40 밖으로 떨어져 루트 로컬 y < −20이면 탈락. 솥 앞 디지털 타이머가 남은 시간을 보여 줘요.
-- 통과자는 RoundService가 정해요 (남은 인원 ≤ 목표, 또는 timeLimit 75초 끝에 버틴 사람 전원).
--
-- 치수(단 표·조각·스폰·띠)는 RiceCookerLayout, 일정·곳 고르기·넉백·타이머 글자는 RiceCookerLogic — 둘 다 순수
-- 로직이고 tests/map-rice-cooker.spec.luau가 확인해요. 장식은 RiceCookerArt → MapKit.buildDecor.
-- 판정 바닥 조각은 태그 "RiceFloor", 증기 밸브 노즐·분배관은 "RiceSteamVent"(속성 VentSide·VentBand),
-- 끓어오름 경고 파츠는 "RiceBurst". start는 ctx.model 하위 태그 파츠만 찾아요 (M1 B10 (A)).
-- 넉백은 TempuraPot.launch와 같은 방식(LinearVelocity를 짧게 걸고 그 뒤는 포물선) + PlatformStand + MoveExempt.
-- 상태(쿨다운, 바로 전 띠)는 start 지역 변수에 둬서 여러 방이 섞이지 않아요.
-- Roblox API는 build/start 안에서만 써요 — require만 하는 것(Lune 테스트)은 안전해요.

local Art = require(script.Parent.RiceCookerArt)
local Layout = require(script.Parent.RiceCookerLayout)
local Logic = require(script.Parent.RiceCookerLogic)
local MapKit = require(script.Parent.MapKit)
local MapKitLogic = require(script.Parent.MapKitLogic)
local MapSfx = require(script.Parent.MapSfx)
local MapTypes = require(script.Parent.MapTypes)
local MoveExempt = require(script.Parent.Parent.MoveExempt)

local ID = "rice-cooker"
local FLOOR_TAG = "RiceFloor"
local VENT_TAG = "RiceSteamVent"
local BURST_TAG = "RiceBurst"
local TIMER_NAME = "CookerTimer"
local WARN_LIFT = 0.06 -- 경고 파츠를 윗면 위로 이만큼 (z-fighting 방지)
local DASH_SPACING = 5
local DASH_LENGTH = 2.8

local CX, CZ = Layout.CENTER_X, Layout.CENTER_Z

-- Color3는 Roblox API라 함수 안에서만 만들어요 (모듈 최상위에서 만들면 Lune require가 실패해요).
local function color3(rgb: MapKitLogic.RGB): Color3
	return Color3.fromRGB(rgb.r, rgb.g, rgb.b)
end

local function part(props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function ghost(p: BasePart)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
end

local UPRIGHT_Z = math.rad(90) -- 원기둥 축(로컬 X)을 Y로

-- 판정 밥 언덕: 단마다 반지름 방향 Block 조각 (Layout.segments)
local function buildHill(model: Model, origin: CFrame)
	local CollectionService = game:GetService("CollectionService")
	local folder = Instance.new("Folder")
	folder.Name = "RiceHill"
	for _, seg in Layout.segments() do
		local p = part({
			Name = seg.key,
			Size = Vector3.new(seg.length, seg.height, seg.width),
			CFrame = origin
				* CFrame.new(seg.x, seg.topY - seg.height / 2, seg.z)
				* CFrame.Angles(0, math.rad(seg.yaw), 0),
			Color = color3(Art.riceColor(seg.tier)),
			Material = Enum.Material.Sand, -- 고운 알갱이 질감 (물성은 아래에서 Plastic으로 고정)
			CanCollide = true,
		})
		p.CustomPhysicalProperties = PhysicalProperties.new(Enum.Material.Plastic) -- 재질이 물성을 바꾸지 않게
		p:SetAttribute("RiceTier", seg.tier)
		CollectionService:AddTag(p, FLOOR_TAG)
		p.Parent = folder
	end
	folder.Parent = model
end

-- 증기 밸브 분배관 + 띠마다 노즐 (보여 주기 + 분사 기준점, 충돌 없음). start가 경고 때 흔들어요.
local function buildVents(model: Model, origin: CFrame)
	local CollectionService = game:GetService("CollectionService")
	local folder = Instance.new("Folder")
	folder.Name = "SteamVents"
	for _, side in { 1, -1 } do
		local x = CX + side * Layout.VENT_X
		local manifold = part({
			Name = "VentManifold",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(36, 2.6, 2.6),
			CFrame = origin * CFrame.new(x, Layout.VENT_Y, CZ) * CFrame.Angles(0, math.rad(90), 0),
			Color = color3(Art.COLORS.brass),
			Material = Enum.Material.Metal,
			Reflectance = 0.25,
		})
		ghost(manifold)
		manifold:SetAttribute("VentSide", side)
		manifold:SetAttribute("VentBand", 0)
		CollectionService:AddTag(manifold, VENT_TAG)
		manifold.Parent = folder
		for band, bz in Layout.BANDS do
			-- 노즐: 분배관에서 언덕 쪽(−side X)으로 튀어나온 짧은 원기둥 + 입구 고리
			local nozzle = part({
				Name = "VentNozzle",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(3.2, 2, 2),
				CFrame = origin * CFrame.new(x - side * 2.2, Layout.VENT_Y, CZ + bz),
				Color = color3(Art.COLORS.brassDark),
				Material = Enum.Material.Metal,
				Reflectance = 0.2,
			})
			ghost(nozzle)
			nozzle:SetAttribute("VentSide", side)
			nozzle:SetAttribute("VentBand", band)
			CollectionService:AddTag(nozzle, VENT_TAG)
			nozzle.Parent = folder
			local mouth = part({
				Name = "VentMouth",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.5, 2.8, 2.8),
				CFrame = origin * CFrame.new(x - side * 3.9, Layout.VENT_Y, CZ + bz),
				Color = color3(Art.COLORS.brass),
				Material = Enum.Material.Metal,
				Reflectance = 0.25,
			})
			ghost(mouth)
			mouth:SetAttribute("VentSide", side)
			mouth:SetAttribute("VentBand", band)
			CollectionService:AddTag(mouth, VENT_TAG)
			mouth.Parent = folder
		end
	end
	folder.Parent = model
end

-- 솥 앞 디지털 타이머 (SurfaceGui 글자, 서버가 1초마다 바꿔요). 판정 없음.
local function buildTimer(model: Model, origin: CFrame)
	local t = Art.TIMER
	local display = part({
		Name = TIMER_NAME,
		Size = Vector3.new(t.size.x, t.size.y, t.size.z),
		CFrame = origin
			* CFrame.new(t.pos.x, t.pos.y, t.pos.z)
			* CFrame.Angles(0, math.rad(180), 0)
			* CFrame.Angles(math.rad(t.tilt), 0, 0),
		Color = color3(Art.COLORS.timerGlass),
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.1,
	})
	ghost(display)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "TimerGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Brightness = 2
	local label = Instance.new("TextLabel")
	label.Name = "Time"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Arcade
	label.TextScaled = true
	label.TextColor3 = color3(Art.COLORS.timerText)
	label.TextStrokeTransparency = 0.6
	label.TextStrokeColor3 = color3(Art.COLORS.timerTextGlow)
	label.Text = Logic.formatTimer(Logic.TIME_LIMIT)
	label.Parent = gui
	gui.Parent = display
	display.Parent = model
end

local function build(origin: CFrame): Model
	local model = Instance.new("Model")
	model.Name = ID

	buildHill(model, origin)
	buildVents(model, origin)
	buildTimer(model, origin)

	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	for i, offset in Layout.spawnOffsets() do
		local top = Layout.surfaceAtXZ(offset.x, offset.z) or 0
		part({
			Name = string.format("Spawn%02d", i),
			Size = Vector3.new(2, 0.2, 2),
			CFrame = origin * CFrame.new(offset.x, top + 0.1, offset.z),
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
			Transparency = 0.4,
			Color = Color3.fromRGB(246, 196, 70),
			Parent = spawns,
		})
	end
	spawns.Parent = model

	MapKit.buildDecor(Art.decor(), origin, MapKit.decorFolder(model))
	MapKit.introCamera(model, Art.introCamera(), origin)
	MapKit.attachStudioArt(model, ID, origin)
	return model
end

-- 서버가 root를 짧게(hold초) 강제 속도로 띄워요 (TempuraPot.launch와 같은 방식).
local function launch(ctx: MapTypes.RoundContext, root: BasePart, velocity: Vector3, hold: number)
	local attachment = root:FindFirstChild("RootAttachment") or root:FindFirstChildOfClass("Attachment")
	if attachment == nil then
		local created = Instance.new("Attachment")
		created.Name = "RiceCookerAttachment"
		created.Parent = root
		ctx.cleanup:add(created)
		attachment = created
	end
	local push = Instance.new("LinearVelocity")
	push.Name = "RiceCookerLaunch"
	push.Attachment0 = attachment :: Attachment
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	push.VectorVelocity = velocity
	push.MaxForce = math.huge
	push.Parent = root
	root.AssemblyLinearVelocity = velocity
	ctx.cleanup:add(push)
	ctx.cleanup:add(task.delay(hold, function()
		push:Destroy()
	end))
end

-- 윗면 높이 (x 범위의 가장 높은 단) — 경고 파츠가 윗단에 묻히지 않게
local function surfaceMax(x0: number, x1: number, z: number): number?
	local best: number? = nil
	for k = 0, 4 do
		local x = x0 + (x1 - x0) * k / 4
		local y = Layout.surfaceAtXZ(x, z)
		if y and (best == nil or y > best) then
			best = y
		end
	end
	return best
end

local function start(ctx: MapTypes.RoundContext)
	local CollectionService = game:GetService("CollectionService")
	local RunService = game:GetService("RunService")
	local origin = ctx.origin

	-- 이 방 Model 안의 밸브 파츠만 (다른 방의 같은 맵과 안 섞여요)
	local ventParts: { [number]: { { part: BasePart, base: CFrame, band: number } } } = { [1] = {}, [-1] = {} }
	for _, instance in CollectionService:GetTagged(VENT_TAG) do
		if instance:IsA("BasePart") and ctx.model:IsAncestorOf(instance) then
			local side = instance:GetAttribute("VentSide")
			local band = instance:GetAttribute("VentBand")
			local key = if side == 1 then 1 elseif side == -1 then -1 else nil
			if key and type(band) == "number" then
				table.insert(ventParts[key], { part = instance, base = instance.CFrame, band = band })
			end
		end
	end
	local timerLabel: TextLabel? = nil
	local display = ctx.model:FindFirstChild(TIMER_NAME)
	if display then
		local found = display:FindFirstChild("Time", true)
		if found and found:IsA("TextLabel") then
			timerLabel = found
		end
	end

	local startedAt = os.clock()
	local function elapsed(): number
		return os.clock() - startedAt
	end
	local function waitUntil(t: number)
		local remaining = t - elapsed()
		if remaining > 0 then
			task.wait(remaining)
		end
	end

	local lastBurstHit: { [Player]: number } = {}

	local function rootOf(player: Player): (BasePart?, Humanoid?)
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

	local function isRacer(player: Player): boolean
		return table.find(ctx.getRacers(), player) ~= nil
	end

	-- 발 높이가 그 자리 윗면 + range 아래인지 (언덕 밖이면 false)
	local function nearSurface(rel: Vector3, range: number): boolean
		local surface = Layout.surfaceAtXZ(rel.X, rel.Z)
		if surface == nil then
			return false
		end
		local foot = rel.Y - Layout.FOOT_OFFSET
		return foot > surface - 2 and foot < surface + range
	end

	local function knock(
		player: Player,
		root: BasePart,
		humanoid: Humanoid?,
		velocity: Logic.Velocity,
		hold: number,
		knockdown: number,
		exempt: number
	)
		MoveExempt.mark(player.Character, exempt)
		if humanoid then
			humanoid.PlatformStand = true
			ctx.cleanup:add(task.delay(knockdown, function()
				-- 그 사이 탈락했으면(EliminationService가 고정함) 손대지 않아요
				if ctx.isActive() and humanoid.Parent and isRacer(player) then
					humanoid.PlatformStand = false
				end
			end))
		end
		local world = origin:VectorToWorldSpace(Vector3.new(velocity.x, 0, velocity.z)) + Vector3.new(0, velocity.y, 0)
		launch(ctx, root, world, hold)
	end

	-- 낙하 탈락 (CHECK_INTERVAL마다)
	local sinceCheck = math.huge
	ctx.cleanup:add(RunService.Heartbeat:Connect(function(dt: number)
		if not ctx.isActive() then
			return
		end
		sinceCheck += dt
		if sinceCheck < Logic.CHECK_INTERVAL then
			return
		end
		sinceCheck = 0
		for _, player in ctx.getRacers() do
			local root = rootOf(player)
			if root and origin:PointToObjectSpace(root.Position).Y < Layout.FALL_ELIMINATION_Y then
				ctx.eliminate(player)
				if not ctx.isActive() then
					return -- 이 탈락으로 라운드가 끝났어요
				end
			end
		end
	end))

	-- 디지털 타이머: 1초마다 남은 시간
	ctx.cleanup:add(task.spawn(function()
		local label = timerLabel
		while ctx.isActive() do
			if label then
				label.Text = Logic.formatTimer(Logic.TIME_LIMIT - elapsed())
			end
			task.wait(1 - (elapsed() % 1))
		end
	end))

	---------------------------------------------------------------- 밥알 끓어오름

	local function warnPart(name: string, props: { [string]: any }): BasePart
		local p = part(props)
		p.Name = name
		ghost(p)
		CollectionService:AddTag(p, BURST_TAG)
		p.Parent = ctx.model
		ctx.cleanup:add(p)
		return p
	end

	-- 곳 하나 (origin 로컬 x, z): 경고 1.5초(깜빡임) → 펑 → 원 안 레이서 넉백
	local function burst(sx: number, sz: number)
		local warnings: { BasePart } = {}
		local r = Logic.BURST_RADIUS
		local centerTop = Layout.surfaceAtXZ(sx, sz) or 0
		-- 안쪽 옅은 주황 (원판)
		table.insert(
			warnings,
			warnPart("BurstFill", {
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.12, r * 2 - 0.6, r * 2 - 0.6),
				CFrame = origin * CFrame.new(sx, centerTop + WARN_LIFT, sz) * CFrame.Angles(0, 0, UPRIGHT_Z),
				Color = color3(Art.COLORS.warnFill),
				Material = Enum.Material.Neon,
				Transparency = 0.45,
			})
		)
		-- 진한 주황 테두리: 조각마다 그 자리 윗면에 (계단을 따라가요)
		local ringSegments = 18
		for k = 0, ringSegments - 1 do
			local a = 2 * math.pi * k / ringSegments
			local px, pz = sx + (r - 0.4) * math.cos(a), sz + (r - 0.4) * math.sin(a)
			local top = Layout.surfaceAtXZ(px, pz)
			if top then
				table.insert(
					warnings,
					warnPart("BurstRing", {
						Size = Vector3.new(2 * r * math.sin(math.pi / ringSegments) + 0.3, 0.16, 0.8),
						CFrame = origin
							* CFrame.new(px, top + WARN_LIFT + 0.03, pz)
							* CFrame.Angles(0, -a - math.pi / 2, 0),
						Color = color3(Art.COLORS.warn),
						Material = Enum.Material.Neon,
						Transparency = 0.05,
					})
				)
			end
		end
		-- 흰 김 (경고 동안)
		local steamHolder = warnPart("BurstSteam", {
			Size = Vector3.new(r * 1.4, 0.2, r * 1.4),
			CFrame = origin * CFrame.new(sx, centerTop + 0.2, sz),
			Transparency = 1,
		})
		local steam = MapKit.makeEmitter("Steam", 8)
		steam.Parent = steamHolder

		local waited = 0
		local blink = false
		while waited < Logic.BURST_WARN_TIME do
			waited += task.wait(0.15)
			if not ctx.isActive() then
				return
			end
			blink = not blink
			for _, w in warnings do
				if w.Name == "BurstFill" then
					w.Transparency = if blink then 0.25 else 0.55
				else
					w.Transparency = if blink then 0 else 0.35
				end
			end
		end
		for _, w in warnings do
			w:Destroy()
		end
		steam.Enabled = false
		ctx.cleanup:add(task.delay(2, function()
			steamHolder:Destroy()
		end))

		-- 펑! 밥알 튐 + 김 한 번
		local puff = part({
			Name = "RiceBurstPuff",
			Size = Vector3.new(2, 1, 2),
			CFrame = origin * CFrame.new(sx, centerTop + 0.6, sz),
			Transparency = 1,
		})
		ghost(puff)
		local grains = Instance.new("ParticleEmitter")
		grains.Name = "RiceGrains"
		grains.Color = ColorSequence.new(color3(Art.COLORS.riceGrain))
		grains.LightEmission = 0.1
		grains.Rate = 0
		grains.Lifetime = NumberRange.new(0.7, 1.1)
		grains.Speed = NumberRange.new(18, 30)
		grains.SpreadAngle = Vector2.new(40, 40)
		grains.Acceleration = Vector3.new(0, -50, 0)
		grains.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.45),
			NumberSequenceKeypoint.new(1, 0.3),
		})
		grains.Rotation = NumberRange.new(0, 360)
		grains.RotSpeed = NumberRange.new(-180, 180)
		grains.EmissionDirection = Enum.NormalId.Top
		grains.Parent = puff
		local cloud = MapKit.makeEmitter("SteamThick", 0)
		cloud.Speed = NumberRange.new(8, 14)
		cloud.EmissionDirection = Enum.NormalId.Top
		cloud.Parent = puff
		puff.Parent = ctx.model
		ctx.cleanup:add(puff)
		grains:Emit(45)
		cloud:Emit(8)
		MapSfx.play(puff, "RiceBubble")
		ctx.cleanup:add(task.delay(2.5, function()
			puff:Destroy()
		end))

		local now = os.clock()
		for _, player in ctx.getRacers() do
			local root, humanoid = rootOf(player)
			if root == nil then
				continue
			end
			local last = lastBurstHit[player]
			if last and now - last < Logic.BURST_COOLDOWN then
				continue
			end
			local rel = origin:PointToObjectSpace(root.Position)
			if not nearSurface(rel, Logic.BURST_HEIGHT_RANGE) then
				continue
			end
			local velocity = Logic.burstKnockback(rel.X - sx, rel.Z - sz, ctx.rng)
			if velocity then
				lastBurstHit[player] = now
				knock(
					player,
					root,
					humanoid,
					velocity,
					Logic.BURST_HOLD,
					Logic.BURST_KNOCKDOWN_TIME,
					Logic.BURST_MOVE_EXEMPT
				)
			end
		end
	end

	ctx.cleanup:add(task.spawn(function()
		waitUntil(Logic.BURST_SCHEDULE[1].from)
		while ctx.isActive() do
			local wave = Logic.burstWave(elapsed())
			if wave == nil then
				break
			end
			local feet: { Logic.Point } = {}
			for _, player in ctx.getRacers() do
				local root = rootOf(player)
				if root then
					local rel = origin:PointToObjectSpace(root.Position)
					if Layout.surfaceAtXZ(rel.X, rel.Z) then
						table.insert(feet, { x = rel.X - CX, z = rel.Z - CZ })
					end
				end
			end
			for _, spot in Logic.pickBurstSpots(ctx.rng, feet, wave.count) do
				ctx.cleanup:add(task.spawn(burst, CX + spot.x, CZ + spot.z))
			end
			task.wait(wave.interval)
		end
	end))

	---------------------------------------------------------------- 증기 분사

	-- 띠 가장자리 점선 (흰 속 + 주황 테두리, 계단 윗면을 따라가요)
	local function bandDashes(band: number): { BasePart }
		local list: { BasePart } = {}
		local bz = CZ + Layout.BANDS[band]
		for _, edge in { -1, 1 } do
			local z = bz + edge * (Layout.BAND_HALF_WIDTH - 0.5)
			local x = CX - Layout.HILL_RADIUS + DASH_SPACING / 2
			while x < CX + Layout.HILL_RADIUS do
				local top = surfaceMax(x - DASH_LENGTH / 2, x + DASH_LENGTH / 2, z)
				if top then
					local border = part({
						Name = "SteamDash",
						Size = Vector3.new(DASH_LENGTH, 0.14, 1),
						CFrame = origin * CFrame.new(x, top + WARN_LIFT + 0.07, z),
						Color = color3(Art.COLORS.warn),
						Material = Enum.Material.Neon,
					})
					ghost(border)
					border.Parent = ctx.model
					ctx.cleanup:add(border)
					table.insert(list, border)
					local core = part({
						Name = "SteamDashCore",
						Size = Vector3.new(DASH_LENGTH - 0.8, 0.16, 0.45),
						CFrame = origin * CFrame.new(x, top + WARN_LIFT + 0.09, z),
						Color = color3(Art.COLORS.steamWhite),
						Material = Enum.Material.SmoothPlastic,
					})
					ghost(core)
					core.Parent = ctx.model
					ctx.cleanup:add(core)
					table.insert(list, core)
				end
				x += DASH_SPACING
			end
		end
		return list
	end

	-- 띠를 따라 낮게 깔리는 김(경고) / 뿜어지는 짙은 김(분사)을 붙일 투명 파츠
	local function bandHolder(band: number, side: number): BasePart
		local bz = CZ + Layout.BANDS[band]
		local holder = part({
			Name = "SteamBand",
			Size = Vector3.new(Layout.BAND_HALF_LENGTH * 2, 1, Layout.BAND_HALF_WIDTH * 2 - 2),
			CFrame = origin * CFrame.new(CX, (surfaceMax(CX - 40, CX + 40, bz) or 0) + 1.2, bz),
			Transparency = 1,
		})
		ghost(holder)
		holder:SetAttribute("VentSide", side)
		holder.Parent = ctx.model
		ctx.cleanup:add(holder)
		return holder
	end

	local function nozzleOf(side: number, band: number): BasePart?
		for _, entry in ventParts[side] do
			if entry.band == band and entry.part.Name == "VentMouth" then
				return entry.part
			end
		end
		return nil
	end

	local function steam(jets: { Logic.Jet })
		local warnings: { BasePart } = {}
		local holders: { BasePart } = {}
		for _, jet in jets do
			for _, d in bandDashes(jet.band) do
				table.insert(warnings, d)
			end
			local holder = bandHolder(jet.band, jet.side)
			local low = MapKit.makeEmitter("Steam", 10)
			low.EmissionDirection = Enum.NormalId.Top
			low.Speed = NumberRange.new(0.5, 1.5)
			low.Parent = holder
			table.insert(holders, holder)
			local mouth = nozzleOf(jet.side, jet.band)
			if mouth then
				MapSfx.play(mouth, "SteamWhistle")
			end
		end

		-- 경고 2초: 밸브 덜컹 + 점선 깜빡임
		local waited = 0
		local blink = false
		while waited < Logic.STEAM_WARN_TIME do
			waited += task.wait(0.1)
			if not ctx.isActive() then
				return
			end
			blink = not blink
			for _, d in warnings do
				if d.Name == "SteamDash" then
					d.Transparency = if blink then 0 else 0.4
				end
			end
			for _, jet in jets do
				for _, entry in ventParts[jet.side] do
					local shake = if blink then 0.22 else -0.22
					entry.part.CFrame = entry.base * CFrame.new(0, shake, shake * 0.5)
				end
			end
		end
		for _, jet in jets do
			for _, entry in ventParts[jet.side] do
				entry.part.CFrame = entry.base
			end
		end
		for _, d in warnings do
			d:Destroy()
		end

		-- 분사 1.2초: 띠를 따라 짙은 김, 띠 안 레이서를 분사마다 한 번
		for i, jet in jets do
			local holder = holders[i]
			for _, emitter in holder:GetChildren() do
				if emitter:IsA("ParticleEmitter") then
					emitter.Enabled = false
				end
			end
			local thick = MapKit.makeEmitter("SteamThick", 20)
			thick.EmissionDirection = if jet.side == 1 then Enum.NormalId.Left else Enum.NormalId.Right
			thick.Speed = NumberRange.new(10, 18)
			thick.Acceleration = Vector3.new(0, 3, 0)
			thick.Parent = holder
			thick:Emit(16)
			local mouth = nozzleOf(jet.side, jet.band)
			if mouth then
				MapSfx.play(mouth, "SteamBlast")
			end
		end
		local hit: { [number]: { [Player]: boolean } } = {}
		for i = 1, #jets do
			hit[i] = {}
		end
		local blasted = 0
		while blasted < Logic.STEAM_BLAST_TIME and ctx.isActive() do
			for i, jet in jets do
				for _, player in ctx.getRacers() do
					if hit[i][player] then
						continue
					end
					local root, humanoid = rootOf(player)
					if root == nil then
						continue
					end
					local rel = origin:PointToObjectSpace(root.Position)
					if
						Logic.inBand(rel.Z - CZ, jet.band)
						and math.abs(rel.X - CX) <= Layout.BAND_HALF_LENGTH
						and nearSurface(rel, Logic.STEAM_HEIGHT_RANGE)
					then
						hit[i][player] = true
						knock(
							player,
							root,
							humanoid,
							Logic.steamKnockback(jet.side),
							Logic.STEAM_HOLD,
							Logic.STEAM_KNOCKDOWN_TIME,
							Logic.STEAM_MOVE_EXEMPT
						)
					end
				end
			end
			blasted += task.wait(Logic.CHECK_INTERVAL)
		end
		for _, holder in holders do
			for _, emitter in holder:GetChildren() do
				if emitter:IsA("ParticleEmitter") then
					emitter.Enabled = false
				end
			end
			ctx.cleanup:add(task.delay(4, function()
				holder:Destroy()
			end))
		end
	end

	ctx.cleanup:add(task.spawn(function()
		local last: { number } = {}
		for _, at in Logic.steamTimes(Logic.TIME_LIMIT) do
			waitUntil(at)
			if not ctx.isActive() then
				return
			end
			local jets = Logic.steamBands(at, ctx.rng, last)
			last = {}
			for _, jet in jets do
				table.insert(last, jet.band)
			end
			ctx.cleanup:add(task.spawn(steam, jets))
		end
	end))
end

local map: MapTypes.MapModule = {
	id = ID,
	kind = "Survival",
	displayName = "초대형 밥솥",
	rule = "끓어오르는 밥알과 뜨거운 증기를 피해 밥 위에서 버텨요!",
	timeLimit = Logic.TIME_LIMIT, -- 75초 (스펙 D5 — Config.TimeLimit.Survival은 그대로)
	lighting = Art.LIGHTING, -- 아침 햇살 드는 주방
	build = build,
	start = start,
}

return map
