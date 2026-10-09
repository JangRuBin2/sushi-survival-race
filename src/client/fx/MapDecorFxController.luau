--!strict
-- 맵 장식 로컬 애니메이션 (m5-20): 서버가 만든 장식 파츠를 클라이언트에서만 움직여요 — 복제 없음.
-- LobbyFxController와 같은 "서버는 고정, 클라이언트가 로컬로 움직인다" 패턴이지만, 맵은 한 플레이스 모드에서
-- 방마다 다른 좌표에 아레나가 뜨므로(Config.Arena) 고정 workspace 경로를 못 써요 → CollectionService 태그로 찾아요.
-- 서버 CFrame·Transparency는 절대 바꾸지 않아요 — 처음 본 값을 "원래 값"으로 기억해 두고 로컬 오프셋만 얹어요.
--   MapDecorTags.EyeBlink — rotating-belt 손님 얼굴 눈. 2~4초마다 한 번 0.15초간 Transparency를 1로.
--   MapDecorTags.Wobble   — hot-plate 선반 간장병. ±3도 안팎으로 천천히 좌우 회전(사인파).
-- 카메라가 멀면(다른 방 관전 등) 그 파츠는 매 프레임 갱신을 건너뛰어요 (로비와 같은 거리 컬링).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MapDecorTags = require(ReplicatedStorage.Shared.maps.MapDecorTags)

local MapDecorFxController = {}

local FAR_DISTANCE = 250 -- 카메라가 파츠에서 이보다 멀면 갱신을 건너뛰어요
local BLINK_GAP_MIN = 2
local BLINK_GAP_MAX = 4
local BLINK_DURATION = 0.15
local WOBBLE_PERIOD_MIN = 2.2
local WOBBLE_PERIOD_MAX = 3.6
local WOBBLE_MAX_DEG = 3

type EyeEntry = {
	baseTransparency: number,
	phase: number, -- 0~1, 파츠마다 달라서 전부 같이 깜빡이지 않아요
	blinking: boolean,
	nextAt: number, -- 다음 상태 전환 시각 (os.clock())
}

type WobbleEntry = {
	base: CFrame, -- 처음 본 CFrame (원래 값)
	period: number,
	phase: number,
}

local eyes: { [BasePart]: EyeEntry } = {}
local wobbles: { [BasePart]: WobbleEntry } = {}

-- 파츠마다 다른 0~1 난수 위상 (처음 본 순간 한 번만 뽑아서 전부 같이 움직이지 않게 해요)
local function randomPhase(): number
	return math.random()
end

local function near(camera: Camera?, position: Vector3): boolean
	if camera == nil then
		return false
	end
	return (camera.CFrame.Position - position).Magnitude <= FAR_DISTANCE
end

local function trackTag(tag: string, onAdd: (BasePart) -> (), onRemove: (Instance) -> ())
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsA("BasePart") then
			onAdd(inst)
		end
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst)
		if inst:IsA("BasePart") then
			onAdd(inst)
		end
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(onRemove)
end

local function addEye(part: BasePart)
	if eyes[part] then
		return
	end
	local phase = randomPhase()
	eyes[part] = {
		baseTransparency = part.Transparency,
		phase = phase,
		blinking = false,
		nextAt = os.clock() + BLINK_GAP_MIN + phase * (BLINK_GAP_MAX - BLINK_GAP_MIN),
	}
end

local function addWobble(part: BasePart)
	if wobbles[part] then
		return
	end
	local phase = randomPhase()
	wobbles[part] = {
		base = part.CFrame,
		period = WOBBLE_PERIOD_MIN + phase * (WOBBLE_PERIOD_MAX - WOBBLE_PERIOD_MIN),
		phase = phase * 2 * math.pi,
	}
end

local function stepEyes(camera: Camera?, now: number)
	for part, entry in eyes do
		if part.Parent == nil then
			eyes[part] = nil
			continue
		end
		if not near(camera, part.Position) then
			continue
		end
		if now < entry.nextAt then
			continue
		end
		if entry.blinking then
			part.Transparency = entry.baseTransparency
			entry.blinking = false
			entry.nextAt = now + BLINK_GAP_MIN + math.random() * (BLINK_GAP_MAX - BLINK_GAP_MIN)
		else
			part.Transparency = 1
			entry.blinking = true
			entry.nextAt = now + BLINK_DURATION
		end
	end
end

local function stepWobbles(camera: Camera?, now: number)
	for part, entry in wobbles do
		if part.Parent == nil then
			wobbles[part] = nil
			continue
		end
		if not near(camera, part.Position) then
			continue
		end
		local angleDeg = math.sin(now * (2 * math.pi / entry.period) + entry.phase) * WOBBLE_MAX_DEG
		part.CFrame = entry.base * CFrame.Angles(0, 0, math.rad(angleDeg))
	end
end

function MapDecorFxController.start(_gui: Instance)
	trackTag(MapDecorTags.EyeBlink, addEye, function(inst: Instance)
		if inst:IsA("BasePart") then
			eyes[inst] = nil
		end
	end)
	trackTag(MapDecorTags.Wobble, addWobble, function(inst: Instance)
		if inst:IsA("BasePart") then
			wobbles[inst] = nil
		end
	end)

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		local now = os.clock()
		stepEyes(camera, now)
		stepWobbles(camera, now)
	end)
end

return MapDecorFxController
