--!strict
-- "간장 늪 & 와사비 산"의 장애물 동작 (GDD 5.2 ②, 6, 11.4). 판정은 전부 서버에서 해요.
--   SoySauce 태그 웅덩이: 안에 있으면 이동 속도 50%, 점프 불가. 벗어나면 바로 기본값으로.
--   Wasabi 태그 패드: 밟으면 위·앞으로 크게 튕기고 머리 위에 "매워!!" 1초. 같은 플레이어 1초 쿨다운.
--   날치알 공: 내리막 위에서 2~3초마다 생겨 굴러 내려와요. 맞으면 1초 넘어져요 (PlatformStand).
-- 태그 파츠는 ctx.model 하위에 있는 것만 써요 (M1 B10 (A)). 상태는 전부 이 함수들의 지역 변수에 둬서
-- 여러 방이 같은 맵을 동시에 돌려도 섞이지 않아요. Roblox API는 함수 안에서만 불러요.

local Art = require(script.Parent.SoySwampArt)
local Config = require(script.Parent.Parent.Config)
local Layout = require(script.Parent.SoySwampLayout)
local MoveExempt = require(script.Parent.Parent.MoveExempt)
local MapSfx = require(script.Parent.MapSfx)
local MapTypes = require(script.Parent.MapTypes)

local Hazards = {}

local WASABI_EXEMPT = 2.5 -- 와사비 튕김 뒤 이동 감시 면제 (위 80·앞 30 studs/s 포물선이 착지할 때까지, 초)

-- ctx.model 하위에 있는 태그 파츠만
function Hazards.taggedParts(ctx: MapTypes.RoundContext, tag: string): { BasePart }
	local CollectionService = game:GetService("CollectionService")
	local parts = {}
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("BasePart") and ctx.model:IsAncestorOf(instance) then
			table.insert(parts, instance)
		end
	end
	return parts
end

local function isAbove(plate: BasePart, position: Vector3, above: number): boolean
	local rel = plate.CFrame:PointToObjectSpace(position)
	return Layout.isAbovePlate(rel.X, rel.Y, rel.Z, plate.Size.X, plate.Size.Z, 1, above)
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

-- 간장: 매 프레임 racers를 받아 감속을 걸거나 풀어요. 돌려주는 함수를 Heartbeat에서 불러요.
-- 통과·탈락해서 racers에서 빠진 사람은 손대지 않고 잊어요 (통과자는 로비로 갈 때, 탈락자는 연출 뒤
-- CharacterUtil이 기본값으로 돌려요. 여기서 되돌리면 탈락 고정을 풀어 버릴 수 있어요).
function Hazards.soyStepper(ctx: MapTypes.RoundContext): (racers: { Player }) -> ()
	local puddles = Hazards.taggedParts(ctx, "SoySauce")
	local soaked: { [Player]: Humanoid } = {}
	local slowSpeed = Layout.soyWalkSpeed(Config.Character.WalkSpeed)

	return function(racers: { Player })
		local current: { [Player]: boolean } = {}
		for _, player in racers do
			current[player] = true
			local root, humanoid = rootAndHumanoid(player)
			if root == nil or humanoid == nil then
				continue
			end
			local inSoy = false
			for _, puddle in puddles do
				if isAbove(puddle, root.Position, Layout.SOY_ZONE_HEIGHT) then
					inSoy = true
					break
				end
			end
			if inSoy then
				if soaked[player] ~= humanoid then
					soaked[player] = humanoid
					humanoid.WalkSpeed = slowSpeed
					humanoid.JumpPower = 0
					MoveExempt.mark(player.Character) -- 서버가 속도를 바꿨어요 (m4-10 이동 감시 오탐 방지)
					MapSfx.play(root, "SoySlow")
				end
			elseif soaked[player] ~= nil then
				if soaked[player] == humanoid then
					humanoid.WalkSpeed = Config.Character.WalkSpeed
					humanoid.JumpPower = Config.Character.JumpPower
					MoveExempt.mark(player.Character)
				end
				soaked[player] = nil
			end
		end
		for player in soaked do
			if not current[player] then
				soaked[player] = nil
			end
		end
	end
end

local function showSpicyText(ctx: MapTypes.RoundContext, character: Model)
	local head = character:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "WasabiSpicy"
	gui.Size = UDim2.fromOffset(140, 44)
	gui.StudsOffset = Vector3.new(0, 2.5, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "매워!!"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.fromRGB(120, 220, 60)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	gui.Parent = head
	ctx.cleanup:add(gui)
	ctx.cleanup:add(task.delay(Layout.WASABI_TEXT_DURATION, function()
		gui:Destroy()
	end))
end

-- 캐릭터는 그 클라이언트가 물리를 맡고 있어서 서버가 속도만 바꾸면 덮어써질 수 있어요.
-- 그래서 서버에서 LinearVelocity를 잠깐(WASABI_HOLD) 붙여 그 클라이언트 물리가 튕김을 직접 계산하게 해요.
local function launch(ctx: MapTypes.RoundContext, root: BasePart, velocity: Vector3)
	local attachment = root:FindFirstChild("RootAttachment") or root:FindFirstChildOfClass("Attachment")
	if attachment == nil then
		local created = Instance.new("Attachment")
		created.Name = "WasabiAttachment"
		created.Parent = root
		ctx.cleanup:add(created)
		attachment = created
	end
	local push = Instance.new("LinearVelocity")
	push.Name = "WasabiLaunch"
	push.Attachment0 = attachment :: Attachment
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	push.VectorVelocity = velocity
	push.MaxForce = math.huge
	push.Parent = root
	root.AssemblyLinearVelocity = velocity
	ctx.cleanup:add(push)
	ctx.cleanup:add(task.delay(Layout.WASABI_HOLD, function()
		push:Destroy()
	end))
end

-- 와사비: 패드 위에 서 있는 레이서를 튕겨요. 돌려주는 함수를 Heartbeat에서 불러요.
function Hazards.wasabiStepper(ctx: MapTypes.RoundContext): (racers: { Player }) -> ()
	local pads = Hazards.taggedParts(ctx, "Wasabi")
	local cooldown = Layout.newCooldown(Layout.WASABI_COOLDOWN)
	local velocity = Vector3.new(0, Layout.WASABI_UP, 0) + ctx.origin.LookVector * Layout.WASABI_FORWARD

	return function(racers: { Player })
		for _, player in racers do
			local root = rootAndHumanoid(player)
			if root == nil then
				continue
			end
			for _, pad in pads do
				if isAbove(pad, root.Position, Layout.WASABI_ZONE_HEIGHT) then
					if cooldown.tryUse(player, os.clock()) then
						local character = player.Character
						-- 큰 튕김: 날아가 착지할 때까지 이동 감시(m4-10)에서 빼요
						MoveExempt.mark(character, WASABI_EXEMPT)
						launch(ctx, root, velocity)
						MapSfx.play(pad, "WasabiBoing")
						if character then
							showSpicyText(ctx, character)
						end
					end
					break
				end
			end
		end
	end
end

type Ball = { part: BasePart, bornAt: number }

local function spawnBall(ctx: MapTypes.RoundContext, folder: Instance): BasePart
	local origin = ctx.origin
	local x = ctx.rng:NextNumber(-Layout.BALL_SPAWN_HALF_WIDTH, Layout.BALL_SPAWN_HALF_WIDTH)
	local radius = Layout.BALL_DIAMETER / 2
	local y = Layout.slopeHeightAt(Layout.BALL_SPAWN_Z) + radius + 0.5
	local ball = Instance.new("Part")
	ball.Name = "Tobiko"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * Layout.BALL_DIAMETER
	-- 아트 (m4-02): 날치알 오렌지 모래 질감. 구르는 물리는 M3의 SmoothPlastic 그대로.
	local tobiko = Art.COLORS.tobiko
	ball.Color = Color3.fromRGB(tobiko.r, tobiko.g, tobiko.b)
	ball.Material = Enum.Material.Sand
	ball.CustomPhysicalProperties = PhysicalProperties.new(Enum.Material.SmoothPlastic)
	ball.Anchored = false
	ball.CanCollide = true
	ball.CFrame = origin * CFrame.new(x, y, Layout.BALL_SPAWN_Z)
	ball.Parent = folder
	ctx.cleanup:add(ball)
	-- 공 물리는 서버가 맡아요 (클라이언트가 소유하면 위치가 사람마다 달라져서 판정이 어긋나요).
	pcall(function()
		ball:SetNetworkOwner(nil)
	end)
	-- 출발 쪽(로컬 +Z)으로 살짝 밀어서 굴리기 시작해요
	ball.AssemblyLinearVelocity = -origin.LookVector * Layout.BALL_START_SPEED
	return ball
end

local function knockDown(ctx: MapTypes.RoundContext, player: Player, humanoid: Humanoid)
	humanoid.PlatformStand = true
	-- 공에 맞아 튕겨 넘어져요: 일어날 때까지 이동 감시(m4-10)에서 빼요
	MoveExempt.mark(player.Character, Layout.KNOCKDOWN_DURATION + 1)
	ctx.cleanup:add(task.delay(Layout.KNOCKDOWN_DURATION, function()
		-- 그 사이 통과·탈락했으면 손대지 않아요 (탈락 고정은 PlatformStand를 켜 둬요).
		if humanoid.Parent == nil or player.Character ~= humanoid.Parent then
			return
		end
		if table.find(ctx.getRacers(), player) then
			humanoid.PlatformStand = false
		end
	end))
end

-- 날치알: 공 생성 스레드를 띄우고(ctx.cleanup에 넣어요), 공 수명·속도 제한·충돌 판정을 하는
-- 함수를 돌려줘요. 돌려주는 함수를 Heartbeat에서 불러요.
function Hazards.tobikoStepper(ctx: MapTypes.RoundContext): (racers: { Player }) -> ()
	local folder = Instance.new("Folder")
	folder.Name = "TobikoBalls"
	folder.Parent = ctx.model
	ctx.cleanup:add(folder)

	local balls: { Ball } = {}
	local hitCooldown = Layout.newCooldown(Layout.KNOCKDOWN_COOLDOWN)
	local hitRange = Layout.BALL_DIAMETER / 2 + Layout.BALL_HIT_EXTRA

	ctx.cleanup:add(task.spawn(function()
		while ctx.isActive() do
			task.wait(ctx.rng:NextNumber(Layout.BALL_INTERVAL_MIN, Layout.BALL_INTERVAL_MAX))
			if not ctx.isActive() then
				break
			end
			table.insert(balls, { part = spawnBall(ctx, folder), bornAt = os.clock() })
		end
	end))

	return function(racers: { Player })
		local now = os.clock()
		for i = #balls, 1, -1 do
			local ball = balls[i]
			local part = ball.part
			local rel = ctx.origin:PointToObjectSpace(part.Position)
			if part.Parent == nil or Layout.ballExpired(now - ball.bornAt, rel.Z, rel.Y) then
				part:Destroy()
				table.remove(balls, i)
				continue
			end
			local velocity = part.AssemblyLinearVelocity
			if velocity.Magnitude > Layout.BALL_MAX_SPEED then
				part.AssemblyLinearVelocity = velocity.Unit * Layout.BALL_MAX_SPEED
			end
		end

		for _, player in racers do
			local root, humanoid = rootAndHumanoid(player)
			if root == nil or humanoid == nil then
				continue
			end
			for _, ball in balls do
				if (ball.part.Position - root.Position).Magnitude <= hitRange then
					if hitCooldown.tryUse(player, now) then
						knockDown(ctx, player, humanoid)
					end
					break
				end
			end
		end
	end
end

return Hazards
