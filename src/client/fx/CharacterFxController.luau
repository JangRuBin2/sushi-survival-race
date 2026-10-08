--!strict
-- 캐릭터 움직임 연출 (클라이언트 로컬, 판정과 무관): 걷기 통통, 넘어짐 버둥.
-- 보이는 모든 초밥 캐릭터(AppearanceService가 붙인 `SushiBody` Model)의 `SushiJoint`(Motor6D).Transform만 바꿔요.
--   걷기: 땅 위에서 움직이면 위아래로 튀고 좌우로 기우뚱 (속도에 비례, 서 있으면 멈춤)
--   넘어짐: Humanoid.PlatformStand인 동안 옆으로 누워 떨고 머리 위에 "@_@". 시작할 때 Sfx "Knockdown" 한 번.
--   탈락 고정(서버가 HumanoidRootPart를 Anchored + PlatformStand)은 넘어짐이 아니에요 — 연출·소리 없음 (m3-02 QA B1).
--   이름표: 다른 사람의 초밥 Body 위에 이름(DisplayName)을 직접 띄워요. Head가 투명해도 보이게 기본 이름표 대신 (m3-02 QA B2).
--   탈락 연출로 숨겨진 캐릭터(LocalTransparencyModifier = 1, m3-03)에는 아무것도 하지 않고 이름표도 숨겨요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SushiBody = require(ReplicatedStorage.Shared.SushiBody)
local Sfx = require(script.Parent.Parent.Sfx)

local CharacterFxController = {}

local MODEL_NAME = SushiBody.MODEL_NAME
local JOINT_NAME = SushiBody.JOINT_NAME

local WALK_SPEED_REF = 16 -- 이 속도에서 흔들림 1배
local MAX_WALK_FACTOR = 1.3
local MIN_MOVE_SPEED = 1 -- 이보다 느리면 서 있는 것
local MAX_AIR_SPEED_Y = 4 -- 위아래로 이보다 빠르면 공중(점프·낙하) — 튀지 않아요
local TELEPORT_SPEED = 120 -- 한 프레임 이동이 이보다 빠르면 순간이동으로 보고 무시
local BOUNCE_HEIGHT = 0.45
local BOUNCE_TILT = math.rad(10)
local BOUNCE_RATE_MIN = 9 -- rad/s (|sin|이라 튀는 횟수는 두 배)
local BOUNCE_RATE_PER_FACTOR = 5
local WALK_BLEND = 10
local LIE_BLEND = 14
local LIE_HEIGHT = 1.4 -- 누웠을 때 Body 중심 높이 (계란 폭 2.8의 절반)
local SHAKE_RATE = 45
local SHAKE_ANGLE = math.rad(7)
local GROUND_RAY = 8
local DEFAULT_GROUND_BELOW_ROOT = 3
local DIZZY_TEXT = "@_@"
local DIZZY_SPIN = 360 -- 도/초
local HIDDEN_THRESHOLD = 0.99
local NAME_TAG_HEIGHT = 3.6 -- Body 중심에서 이름표까지 (초밥 꼭대기 2.4 + 여유)
local NAME_TAG_DISTANCE = 100 -- Roblox 기본 이름표 거리와 같아요

type State = {
	lastPos: Vector3?,
	walk: number, -- 0~MAX_WALK_FACTOR, 부드럽게 따라가요
	phase: number,
	lie: number, -- 0(서 있음) ~ 1(누움)
	knocked: boolean,
	knockTime: number,
	dizzy: BillboardGui?,
	nameTag: BillboardGui?,
}

local states: { [Model]: State } = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function newState(): State
	return {
		lastPos = nil,
		walk = 0,
		phase = 0,
		lie = 0,
		knocked = false,
		knockTime = 0,
		dizzy = nil,
		nameTag = nil,
	}
end

local function removeDizzy(state: State)
	if state.dizzy then
		state.dizzy:Destroy()
		state.dizzy = nil
	end
end

local function removeNameTag(state: State)
	if state.nameTag then
		state.nameTag:Destroy()
		state.nameTag = nil
	end
end

local function makeNameTag(body: BasePart, displayName: string): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "SushiNameTag"
	gui.Adornee = body
	gui.Size = UDim2.fromOffset(200, 24)
	gui.StudsOffsetWorldSpace = Vector3.new(0, NAME_TAG_HEIGHT, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = NAME_TAG_DISTANCE
	local label = Instance.new("TextLabel")
	label.Name = "Name"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = displayName
	label.TextSize = 18
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
	gui.Parent = body
	return gui
end

-- 다른 사람 캐릭터의 이름표: 기본 휴머노이드 이름표는 끄고(로컬) 우리 이름표를 Body에 붙여요.
local function updateNameTag(character: Model, state: State, body: BasePart, humanoid: Humanoid, player: Player)
	if humanoid.DisplayDistanceType ~= Enum.HumanoidDisplayDistanceType.None then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local hidden = body.LocalTransparencyModifier >= HIDDEN_THRESHOLD
	if state.nameTag == nil or state.nameTag.Parent ~= body then
		removeNameTag(state)
		state.nameTag = makeNameTag(body, player.DisplayName)
	end
	local tag = state.nameTag :: BillboardGui
	tag.Enabled = not hidden and character.Parent ~= nil
end

local function makeDizzy(body: BasePart): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "Dizzy"
	gui.Adornee = body
	gui.Size = UDim2.fromOffset(90, 44)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = DIZZY_TEXT
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	gui.Parent = body
	return gui
end

local function approach(current: number, target: number, rate: number, dt: number): number
	return current + (target - current) * math.min(1, rate * dt)
end

-- 땅 높이 (못 찾으면 서 있는 휴머노이드 기준)
local function groundY(character: Model, root: BasePart): number
	rayParams.FilterDescendantsInstances = { character }
	local hit = Workspace:Raycast(root.Position, Vector3.new(0, -GROUND_RAY, 0), rayParams)
	if hit then
		return hit.Position.Y
	end
	return root.Position.Y - DEFAULT_GROUND_BELOW_ROOT
end

-- root의 방향에서 좌우 회전(yaw)만 남겨요 (넘어져서 root가 기울어도 바닥에 눕게)
local function yawOnly(cf: CFrame): CFrame
	local look = cf.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(cf.UpVector.X, 0, cf.UpVector.Z)
		if flat.Magnitude < 1e-3 then
			return CFrame.identity
		end
	end
	flat = flat.Unit
	return CFrame.lookAt(Vector3.zero, flat)
end

local function update(character: Model, state: State, dt: number, localCharacter: Model?, player: Player)
	local sushi = character:FindFirstChild(MODEL_NAME)
	local body = sushi and (sushi :: Model).PrimaryPart
	local joint = body and body:FindFirstChild(JOINT_NAME)
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if body == nil or joint == nil or not joint:IsA("Motor6D") or root == nil or not root:IsA("BasePart") then
		return
	end
	if humanoid == nil then
		return
	end
	if character ~= localCharacter then
		updateNameTag(character, state, body, humanoid, player)
	end

	-- 탈락 연출이 숨긴 캐릭터는 건드리지 않아요 (내 캐릭터의 1인칭 숨김은 소리만 계속)
	local hidden = body.LocalTransparencyModifier >= HIDDEN_THRESHOLD
	if hidden and character ~= localCharacter then
		joint.Transform = CFrame.identity
		removeDizzy(state)
		state.knocked = humanoid.PlatformStand and not root.Anchored
		state.lastPos = nil
		state.walk = 0
		state.lie = 0
		return
	end

	-- 속도 (다른 사람 캐릭터도 같은 방식으로: 위치 변화)
	local pos = root.Position
	local speed, speedY = 0, 0
	if state.lastPos and dt > 0 then
		local delta = (pos - (state.lastPos :: Vector3)) / dt
		if delta.Magnitude < TELEPORT_SPEED then
			speed = Vector3.new(delta.X, 0, delta.Z).Magnitude
			speedY = math.abs(delta.Y)
		end
	end
	state.lastPos = pos

	-- 넘어짐 (탈락 고정 = Anchored는 넘어짐이 아니에요)
	local knocked = humanoid.PlatformStand and humanoid.Health > 0 and not root.Anchored
	if knocked and not state.knocked then
		state.knockTime = 0
		Sfx.play("Knockdown", root)
	end
	state.knocked = knocked
	if knocked then
		state.knockTime += dt
	end

	-- 걷기
	local walkTarget = 0
	if not knocked and speed > MIN_MOVE_SPEED and speedY < MAX_AIR_SPEED_Y then
		walkTarget = math.min(speed / WALK_SPEED_REF, MAX_WALK_FACTOR)
	end
	state.walk = approach(state.walk, walkTarget, WALK_BLEND, dt)
	if state.walk < 0.01 then
		state.walk = 0
		state.phase = 0
	else
		state.phase = (state.phase + dt * (BOUNCE_RATE_MIN + BOUNCE_RATE_PER_FACTOR * state.walk)) % (2 * math.pi)
	end
	local walkCf = CFrame.new(0, math.abs(math.sin(state.phase)) * BOUNCE_HEIGHT * state.walk, 0)
		* CFrame.Angles(0, 0, math.sin(state.phase) * BOUNCE_TILT * state.walk)

	state.lie = approach(state.lie, if knocked then 1 else 0, LIE_BLEND, dt)
	if state.lie < 0.01 then
		state.lie = 0
	end

	if hidden then
		-- 내 캐릭터 1인칭: 보이지 않으니 자세는 그대로 두고 표시만 정리
		joint.Transform = CFrame.identity
		removeDizzy(state)
		return
	end

	local transform = walkCf
	if state.lie > 0 then
		-- 바닥에 옆으로 누워 바르르: 월드 기준 목표 자세를 관절 공간으로 바꿔요
		local shake = math.sin(state.knockTime * SHAKE_RATE) * SHAKE_ANGLE
		local wobble = math.sin(state.knockTime * SHAKE_RATE * 0.7) * SHAKE_ANGLE * 0.5
		local worldTarget = CFrame.new(pos.X, groundY(character, root) + LIE_HEIGHT, pos.Z)
			* yawOnly(root.CFrame)
			* CFrame.Angles(wobble, 0, math.rad(90) + shake)
		local base = root.CFrame * joint.C0
		local lieCf = base:Inverse() * worldTarget
		transform = walkCf:Lerp(lieCf, state.lie)
	end
	joint.Transform = transform

	if knocked then
		if state.dizzy == nil or state.dizzy.Parent == nil then
			state.dizzy = makeDizzy(body)
		end
		local label = (state.dizzy :: BillboardGui):FindFirstChild("Text")
		if label and label:IsA("TextLabel") then
			label.Rotation = (state.knockTime * DIZZY_SPIN) % 360
		end
	else
		removeDizzy(state)
	end
end

local function step(dt: number)
	local localCharacter = Players.LocalPlayer and Players.LocalPlayer.Character
	local seen: { [Model]: boolean } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and character.Parent then
			seen[character] = true
			local state = states[character]
			if state == nil then
				state = newState()
				states[character] = state
			end
			update(character, state, dt, localCharacter, player)
		end
	end
	for character, state in states do
		if not seen[character] then
			removeDizzy(state)
			removeNameTag(state)
			states[character] = nil
		end
	end
end

function CharacterFxController.start(_gui: Instance)
	RunService.RenderStepped:Connect(step)
end

return CharacterFxController
