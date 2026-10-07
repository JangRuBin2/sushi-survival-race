--!strict
-- 회전 벨트 Race 맵의 젓가락 장애물 (GDD 5.2 ①, 11.4).
-- CollectionService 태그 "Chopstick"을 영역 파츠에 달아 동작시켜요: 빨간 경고 1초 → 젓가락이 내려와
-- 3초간 그 자리의 선수를 묶어두고(시간 손해) → 다시 올라가요.
-- 여러 방이 같은 맵을 동시에 돌릴 수 있어서 상태는 station Model 하나에만 둬요 (모듈 전역 금지).
-- Chopstick.run은 Roblox API(game, Instance, CollectionService 등)를 함수 안에서만 불러요 — 이 모듈을
-- require만 하는 것(Lune 테스트 포함)은 Roblox 런타임이 없어도 안전해요.

local MapTypes = require(script.Parent.MapTypes)

local WARN_DURATION = 1 -- 빨간 경고가 뜨는 시간
local GRAB_DURATION = 3 -- 젓가락이 붙잡고 있는 시간 (시간 손해)
local COOLDOWN_MIN = 2.5 -- 다음 사이클까지 최소 대기
local COOLDOWN_MAX = 4.5 -- 다음 사이클까지 최대 대기
local DEPLOY_TWEEN = 0.2 -- 젓가락이 내려오는 연출 시간
local RETRACT_TWEEN = 0.3 -- 젓가락이 올라가는 연출 시간
local ZONE_WIDTH = 8 -- 포획 영역 가로폭 (벨트 전체 폭 16의 절반 — 반대쪽 레인으로 피할 수 있게)
local ZONE_HEIGHT = 6
local ZONE_DEPTH = 10
local REST_HEIGHT = 10 -- 평소 젓가락이 숨어있는 높이 (바닥 기준)
local DEPLOY_HEIGHT = 1.5 -- 내려왔을 때 높이

local Chopstick = {}

-- station 하나를 짓는다. stationCFrame은 바닥 위(y=0)를 기준으로 하는 월드 CFrame.
-- 포획 판정용 Zone에 CollectionService 태그 "Chopstick"을 붙인다.
function Chopstick.build(stationCFrame: CFrame): Model
	local CollectionService = game:GetService("CollectionService")

	local station = Instance.new("Model")
	station.Name = "ChopstickStation"

	local zone = Instance.new("Part")
	zone.Name = "Zone"
	zone.Anchored = true
	zone.CanCollide = false
	zone.CanTouch = false
	zone.Transparency = 1
	zone.Size = Vector3.new(ZONE_WIDTH, ZONE_HEIGHT, ZONE_DEPTH)
	zone.CFrame = stationCFrame * CFrame.new(0, ZONE_HEIGHT / 2, 0)
	zone.Parent = station
	CollectionService:AddTag(zone, "Chopstick")

	local warning = Instance.new("Part")
	warning.Name = "Warning"
	warning.Shape = Enum.PartType.Block
	warning.Anchored = true
	warning.CanCollide = false
	warning.Material = Enum.Material.Neon
	warning.Color = Color3.fromRGB(220, 40, 40)
	warning.Transparency = 1
	warning.Size = Vector3.new(ZONE_WIDTH * 0.9, 0.2, ZONE_DEPTH * 0.9)
	warning.CFrame = stationCFrame * CFrame.new(0, 0.11, 0)
	warning.Parent = station

	local sticks = Instance.new("Model")
	sticks.Name = "Sticks"
	sticks.Parent = station
	for _, offsetX in { -1, 1 } do
		local stick = Instance.new("Part")
		stick.Name = if offsetX < 0 then "StickLeft" else "StickRight"
		stick.Anchored = true
		stick.CanCollide = false
		stick.Material = Enum.Material.Wood
		stick.Color = Color3.fromRGB(200, 170, 120)
		stick.Size = Vector3.new(0.6, 0.6, ZONE_DEPTH * 0.8)
		stick.CFrame = stationCFrame * CFrame.new(offsetX * (ZONE_WIDTH / 4), REST_HEIGHT, 0)
		stick.Parent = sticks
	end

	return station
end

-- zone 영역 안에 있는 레이서(아직 통과/탈락하지 않은 선수)만 찾는다.
local function overlappingRacers(zone: BasePart, racers: { Player }): { Player }
	local caught = {}
	local half = zone.Size / 2
	for _, player in racers do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local relative = zone.CFrame:PointToObjectSpace(root.Position)
			if math.abs(relative.X) <= half.X and math.abs(relative.Y) <= half.Y and math.abs(relative.Z) <= half.Z then
				table.insert(caught, player)
			end
		end
	end
	return caught
end

type Grabbed = { humanoid: Humanoid, walkSpeed: number, jumpPower: number }

-- 이동을 멈춰서 "들어 올려짐"을 표현한다. 원래 속도는 돌려줄 수 있게 들고 있는다.
local function grab(players: { Player }): { Grabbed }
	local grabbed = {}
	for _, player in players do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			table.insert(
				grabbed,
				{ humanoid = humanoid, walkSpeed = humanoid.WalkSpeed, jumpPower = humanoid.JumpPower }
			)
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
		end
	end
	return grabbed
end

local function release(grabbed: { Grabbed })
	for _, entry in grabbed do
		-- 그 사이 캐릭터가 사라졌을 수 있어서(탈락·퇴장) Parent를 확인하고 돌려준다.
		if entry.humanoid.Parent then
			entry.humanoid.WalkSpeed = entry.walkSpeed
			entry.humanoid.JumpPower = entry.jumpPower
		end
	end
end

local function moveSticks(station: Model, zone: BasePart, height: number, duration: number)
	local TweenService = game:GetService("TweenService")
	local sticks = station:FindFirstChild("Sticks")
	if not sticks then
		return
	end
	for _, stick in sticks:GetChildren() do
		if stick:IsA("BasePart") then
			local offsetX = if stick.Name == "StickLeft" then -(ZONE_WIDTH / 4) else ZONE_WIDTH / 4
			local target = zone.CFrame * CFrame.new(offsetX, height, 0)
			TweenService:Create(stick, TweenInfo.new(duration, Enum.EasingStyle.Quad), { CFrame = target }):Play()
		end
	end
end

local function setWarningVisible(warning: BasePart, visible: boolean)
	warning.Transparency = if visible then 0.2 else 1
end

-- station 하나의 경고 → 포획 → 해제 사이클을 ctx가 활성인 동안 계속 돌린다.
-- 호출하는 쪽(RotatingBelt.start)이 task.spawn으로 띄우고 그 스레드를 ctx.cleanup에 넣어야 한다.
function Chopstick.run(station: Model, ctx: MapTypes.RoundContext)
	local zone = station:FindFirstChild("Zone") :: BasePart
	local warning = station:FindFirstChild("Warning") :: BasePart
	assert(zone and warning, "chopstick station missing Zone/Warning parts")

	while ctx.isActive() do
		task.wait(ctx.rng:NextNumber(COOLDOWN_MIN, COOLDOWN_MAX))
		if not ctx.isActive() then
			break
		end

		setWarningVisible(warning, true)
		task.wait(WARN_DURATION)
		setWarningVisible(warning, false)
		if not ctx.isActive() then
			break
		end

		moveSticks(station, zone, DEPLOY_HEIGHT, DEPLOY_TWEEN)
		task.wait(DEPLOY_TWEEN)
		-- 젓가락이 내려온 순간 영역 안에 있는 선수만 붙잡는다 (GDD: 내려와 3초간 들어 올렸다 떨어뜨림)
		local grabbed = grab(overlappingRacers(zone, ctx.getRacers()))
		task.wait(GRAB_DURATION)
		release(grabbed)
		moveSticks(station, zone, REST_HEIGHT, RETRACT_TWEEN)
	end
end

return Chopstick
