--!strict
-- 회전 벨트 Race 맵의 젓가락 장애물 (GDD 5.2 ①, 11.4).
-- CollectionService 태그 "Chopstick"을 영역 파츠에 달아 동작시켜요: 빨간 경고 1초 → 젓가락이 내려와
-- 3초간 그 자리의 선수를 묶어두고(시간 손해) → 다시 올라가요.
-- 여러 방이 같은 맵을 동시에 돌릴 수 있어서 상태는 station Model 하나에만 둬요 (모듈 전역 금지).
-- Chopstick.run은 Roblox API(game, Instance, CollectionService 등)를 함수 안에서만 불러요 — 이 모듈을
-- require만 하는 것(Lune 테스트 포함)은 Roblox 런타임이 없어도 안전해요.

local MoveExempt = require(script.Parent.Parent.MoveExempt)
local Art = require(script.Parent.RotatingBeltArt)
local MapSfx = require(script.Parent.MapSfx)
local MapTypes = require(script.Parent.MapTypes)

local TAG = "Chopstick" -- 포획 영역 Zone에 다는 태그
local TIP_LENGTH = 1.6 -- 젓가락 끝 나무색 부분

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

Chopstick.TAG = TAG

-- GetTagged만 쓰는 최소 모양 (테스트가 가짜를 넘길 수 있게)
type TagSource = { GetTagged: (self: any, tag: string) -> { Instance } }

-- container 하위에 있는 tag 파츠만 (여러 방이 같은 맵을 돌려도 자기 맵 것만, M1 B10).
-- 폴더 구조와 상관없이 태그로 찾아요. tags를 안 넘기면 CollectionService를 써요.
function Chopstick.taggedIn(container: Instance, tag: string, tags: TagSource?): { BasePart }
	local source: TagSource = tags or (game:GetService("CollectionService") :: any)
	local parts: { BasePart } = {}
	for _, instance in source:GetTagged(tag) do
		if instance:IsA("BasePart") and instance:IsDescendantOf(container) then
			table.insert(parts, instance)
		end
	end
	return parts
end

-- container 하위의 젓가락 station Model (태그 달린 Zone의 부모). 같은 station은 한 번만.
function Chopstick.stationsIn(container: Instance, tags: TagSource?): { Model }
	local stations: { Model } = {}
	for _, zone in Chopstick.taggedIn(container, TAG, tags) do
		local station = zone.Parent
		if station and station:IsA("Model") and not table.find(stations, station) then
			table.insert(stations, station)
		end
	end
	return stations
end

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
	CollectionService:AddTag(zone, TAG)

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
		-- 아트 (m4-02): 옻칠 빨강/검정 몸통 + 나무색 끝. 크기·위치·충돌은 M3 그대로.
		local body = if offsetX < 0 then Art.COLORS.stickRed else Art.COLORS.stickBlack
		stick.Material = Enum.Material.SmoothPlastic
		stick.Reflectance = 0.1
		stick.Color = Color3.fromRGB(body.r, body.g, body.b)
		stick.Size = Vector3.new(0.6, 0.6, ZONE_DEPTH * 0.8)
		stick.CFrame = stationCFrame * CFrame.new(offsetX * (ZONE_WIDTH / 4), REST_HEIGHT, 0)
		stick.Parent = sticks

		-- 끝(코스 앞쪽 -Z)은 장식: 젓가락에 용접해서 트윈으로 같이 움직여요. 충돌·쿼리·터치 없음.
		local tipColor = Art.COLORS.stickTip
		local tip = Instance.new("Part")
		tip.Name = "Tip"
		tip.Anchored = false
		tip.CanCollide = false
		tip.CanQuery = false
		tip.CanTouch = false
		tip.Massless = true
		tip.Material = Enum.Material.Wood
		tip.Color = Color3.fromRGB(tipColor.r, tipColor.g, tipColor.b)
		tip.Size = Vector3.new(0.62, 0.62, TIP_LENGTH)
		tip.CFrame = stick.CFrame * CFrame.new(0, 0, -(stick.Size.Z - TIP_LENGTH) / 2)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = stick
		weld.Part1 = tip
		weld.Parent = tip
		tip.Parent = stick
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
			-- 서버가 붙잡아요: 잡힌 동안 + 1초는 이동 감시(m4-10)에서 빼요
			MoveExempt.mark(character, GRAB_DURATION + 1)
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
			-- 놓아준 직후(벨트에 밀려 떨어지는 순간)도 면제
			local character = entry.humanoid.Parent
			if character:IsA("Model") then
				MoveExempt.mark(character)
			end
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
		MapSfx.play(warning, "ChopstickWarn")
		task.wait(WARN_DURATION)
		setWarningVisible(warning, false)
		if not ctx.isActive() then
			break
		end

		moveSticks(station, zone, DEPLOY_HEIGHT, DEPLOY_TWEEN)
		task.wait(DEPLOY_TWEEN)
		-- 젓가락이 내려온 순간 영역 안에 있는 선수만 붙잡는다 (GDD: 내려와 3초간 들어 올렸다 떨어뜨림)
		local grabbed = grab(overlappingRacers(zone, ctx.getRacers()))
		-- 잡고 있는 사이 라운드가 끝나면 이 스레드는 task.cancel로 멈춰서 아래 release까지 못 가요.
		-- 그래서 풀어주는 일을 ctx.cleanup에도 걸어 두고, 어느 쪽이 먼저 불러도 한 번만 돌려줘요.
		local released = false
		local function releaseOnce()
			if not released then
				released = true
				release(grabbed)
			end
		end
		ctx.cleanup:add(releaseOnce)
		task.wait(GRAB_DURATION)
		releaseOnce()
		moveSticks(station, zone, REST_HEIGHT, RETRACT_TWEEN)
	end
end

return Chopstick
