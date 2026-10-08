--!strict
-- 서버 이동 감시: 순간이동·속도 위반 되돌리기, 결승선 통과 막기 (m4-10).
--   감시 대상: RoundService.placedRoomOf(player) ~= nil — 스폰에 배치된 뒤(소개 중 포함) 아직 통과·탈락하지 않은 레이서.
--   기준점: RoundService.setPlacementListener로 스폰에 배치하는 순간 스폰 위치를 기준으로 잡아요 (m4-10 QA B2).
--     소개 중(이동 잠김)이나 출발 직후에 순간이동해도 스폰 기준으로 위반이에요.
--   Heartbeat마다 샘플 차례가 된 플레이어만(Config.MovementGuard.SampleInterval 간격, 사람마다 흩어서)
--   HumanoidRootPart 위치를 MovementGuardLogic.check로 직전 정상 위치와 비교해요.
--   - 캐릭터 Attributes.MoveExemptUntil이 지금보다 뒤면(MoveExempt.mark, 서버가 튕기거나 미는 중) 넉넉한 상한만 봐요.
--     면제 중이어도 그 상한을 넘으면 위반이에요 (m4-10 QA B1).
--   - 위반: 마지막 정상 위치로 되돌리고(PivotTo, 속도 0) 위반 시각·횟수를 기록해요. StrikesToLog번째에
--     서버 Output에 경고 한 줄 (라운드당 한 번). 킥·탈락은 하지 않아요.
--     되돌린(배치한) 뒤 RevertSettle 안의 위반은 되돌리기만 하고 세지 않아요 (지연으로 옛 위치가 계속 오는 것, B5).
--   - 결승선 통과: RoundService.setPassValidator — 통과 순간에도 바로 한 번 검사해요(결승선으로 순간이동한
--     그 프레임에 통과되지 않게). 감시 기록이 없거나, 지금 위반이거나, 위반 뒤 PassBlockAfterViolation 안이면 거부.
--   레이서가 아니게 되면(통과·탈락·라운드 끝) 그 사람 기록을 지워요. 배치될 때마다 새로 시작 → 횟수는 라운드마다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local Logic = require(ReplicatedStorage.Shared.MovementGuardLogic)
local RoundService = require(script.Parent.RoundService)

type Track = {
	character: Model,
	baseline: Logic.Sample,
	nextSampleAt: number,
	lastViolationAt: number?,
	settleUntil: number?,
	strikes: number,
	logged: boolean,
}

local MovementGuardService = {}

local cfg = Config.MovementGuard
local tracks: { [Player]: Track } = {}
-- 감시 대상이 아닌 사람은 placedRoomOf도 SampleInterval마다만 물어요 (프레임당 비용).
local idleCheckAt: { [Player]: number } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function rootOf(character: Model?): BasePart?
	if character == nil then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function sampleAt(position: Vector3, t: number): Logic.Sample
	return { x = position.X, y = position.Y, z = position.Z, t = t }
end

local function exemptUntilOf(character: Model): number?
	local value = character:GetAttribute(Attributes.MoveExemptUntil)
	return if type(value) == "number" then value else nil
end

-- 마지막 정상 위치로 되돌려요. 회전은 그대로 두고 위치 차이만큼 캐릭터 전체를 옮겨요.
local function revert(character: Model, root: BasePart, baseline: Logic.Sample)
	local delta = Vector3.new(baseline.x, baseline.y, baseline.z) - root.Position
	character:PivotTo(character:GetPivot() + delta)
	root.AssemblyLinearVelocity = Vector3.zero
end

local function recordViolation(player: Player, track: Track, t: number)
	track.settleUntil = t + Logic.RevertSettle
	track.lastViolationAt = t
	track.strikes += 1
	if Logic.strikeLog(track.strikes, track.logged, cfg) then
		track.logged = true
		warn(`[MovementGuard] userId {player.UserId} ({player.Name}) strikes {track.strikes} in this round`)
	end
end

-- 지금 위치를 한 번 검사해요. 위반이면 되돌리고 true.
local function inspect(player: Player, track: Track, root: BasePart, t: number): boolean
	local cur = sampleAt(root.Position, t)
	local verdict = Logic.check(track.baseline, cur, exemptUntilOf(track.character), cfg)
	if verdict == "violation" then
		revert(track.character, root, track.baseline)
		-- 되돌린(배치한) 직후 RevertSettle 안이면 지연으로 도착한 옛 위치일 수 있어 되돌리기만 해요.
		-- 세는 위반만 settleUntil을 늘려요 (계속 빠르게 달리면 0.5초마다 한 번씩은 세요).
		if Logic.countsStrike(t, track.settleUntil) then
			recordViolation(player, track, t)
		end
	end
	track.baseline = Logic.advance(track.baseline, cur, verdict)
	return verdict == "violation"
end

local function newTrack(character: Model, position: Vector3, t: number): Track
	return {
		character = character,
		baseline = sampleAt(position, t),
		-- 첫 샘플 시각을 사람마다 흩어서 한 프레임에 몰리지 않게 해요.
		nextSampleAt = t + cfg.SampleInterval * (0.5 + math.random() * 0.5),
		lastViolationAt = nil,
		-- 배치 직후 클라이언트가 아직 옛(로비) 위치를 보내는 것은 세지 않아요 (되돌리기는 해요)
		settleUntil = t + Logic.RevertSettle,
		strikes = 0,
		logged = false,
	}
end

-- RoundService가 스폰에 배치한 순간: 기준점 = 스폰 위치, 이번 라운드 기록 새로 시작.
local function onPlaced(player: Player, character: Model, position: Vector3)
	tracks[player] = newTrack(character, position, now())
	idleCheckAt[player] = nil
end

-- 감시 대상이면 지금 캐릭터의 Track을 돌려줘요. 대상이 아니면 기록을 지우고 nil.
local function trackFor(player: Player, t: number): (Track?, BasePart?)
	if RoundService.placedRoomOf(player) == nil then
		tracks[player] = nil
		return nil, nil
	end
	local character = player.Character
	local root = rootOf(character)
	if character == nil or root == nil then
		return nil, nil
	end
	local track = tracks[player]
	if track == nil then
		-- 배치 알림을 못 받은 경우(있으면 안 됨): 지금 위치로 시작하되 통과는 기록이 생긴 뒤에도
		-- 검사를 거쳐요. 경고만 남겨요.
		warn(`[MovementGuard] {player.Name} is placed but had no track; starting from the current position`)
		tracks[player] = newTrack(character, root.Position, t)
		return nil, nil
	end
	if track.character ~= character then
		-- 같은 라운드에서 캐릭터가 바뀌면(드묾) 위치 기준만 새로 잡아요. 위반 기록은 유지.
		track.character = character
		track.baseline = sampleAt(root.Position, t)
		track.nextSampleAt = t + cfg.SampleInterval
		return nil, nil
	end
	return track, root
end

local function step()
	local t = now()
	for _, player in Players:GetPlayers() do
		local track = tracks[player]
		local due = if track then t >= track.nextSampleAt else t >= (idleCheckAt[player] or 0)
		if due then
			idleCheckAt[player] = t + cfg.SampleInterval
			local current, root = trackFor(player, t)
			if current and root then
				current.nextSampleAt = t + cfg.SampleInterval
				inspect(player, current, root, t)
			end
		end
	end
end

-- 결승선 통과 직전에 RoundService가 물어요. false면 그 통과는 무시돼요.
local function validatePass(player: Player): boolean
	local t = now()
	local track = tracks[player]
	local violatedNow = false
	if track then
		local root = rootOf(track.character)
		if root == nil or player.Character ~= track.character then
			return false -- 감시하던 캐릭터가 아니에요
		end
		violatedNow = inspect(player, track, root, t)
	end
	return Logic.passDecision(track ~= nil, violatedNow, if track then track.lastViolationAt else nil, t, cfg)
end

function MovementGuardService.init() end

function MovementGuardService.start()
	RoundService.setPassValidator(validatePass)
	RoundService.setPlacementListener(onPlaced)
	RunService.Heartbeat:Connect(step)
	Players.PlayerRemoving:Connect(function(player: Player)
		tracks[player] = nil
		idleCheckAt[player] = nil
	end)
end

return MovementGuardService
