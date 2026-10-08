--!strict
-- 서버 이동 감시: 순간이동·속도 위반 되돌리기, 결승선 통과 막기 (m4-10).
--   감시 대상: RoundService.activeRoomOf(player) ~= nil (출발한 라운드에서 달리는 레이서)만.
--   Heartbeat마다 샘플 차례가 된 플레이어만(Config.MovementGuard.SampleInterval 간격, 사람마다 흩어서)
--   HumanoidRootPart 위치를 MovementGuardLogic.check로 직전 정상 위치와 비교해요.
--   - 캐릭터 Attributes.MoveExemptUntil이 지금보다 뒤면(MoveExempt.mark, 서버가 옮기거나 튕긴 직후) 검사하지 않아요.
--   - 위반: 마지막 정상 위치로 되돌리고(PivotTo, 속도 0) 위반 시각·횟수를 기록해요. StrikesToLog번째에
--     서버 Output에 경고 한 줄 (라운드당 한 번). 킥·탈락은 하지 않아요.
--   - 결승선 통과: RoundService.setPassValidator — 통과 순간에도 바로 한 번 검사해요(결승선으로 순간이동한
--     그 프레임에 통과되지 않게). 위반 직후 PassBlockAfterViolation 안이면 그 통과는 무시돼요.
--   달리지 않게 되면(통과·탈락·라운드 끝) 그 사람 기록을 지워요 → 횟수는 라운드마다 새로 세요.

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
	strikes: number,
	logged: boolean,
}

local MovementGuardService = {}

local cfg = Config.MovementGuard
local tracks: { [Player]: Track } = {}
-- 달리지 않는 사람은 activeRoomOf도 SampleInterval마다만 물어요 (프레임당 비용).
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

local function sampleOf(root: BasePart, t: number): Logic.Sample
	local p = root.Position
	return { x = p.X, y = p.Y, z = p.Z, t = t }
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
	track.lastViolationAt = t
	track.strikes += 1
	if Logic.strikeLog(track.strikes, track.logged, cfg) then
		track.logged = true
		warn(`[MovementGuard] userId {player.UserId} ({player.Name}) strikes {track.strikes} in this round`)
	end
end

-- 지금 위치를 한 번 검사해요. 위반이면 되돌리고 true.
local function inspect(player: Player, track: Track, root: BasePart, t: number): boolean
	local cur = sampleOf(root, t)
	local verdict = Logic.check(track.baseline, cur, exemptUntilOf(track.character), cfg)
	if verdict == "violation" then
		revert(track.character, root, track.baseline)
		recordViolation(player, track, t)
	end
	track.baseline = Logic.advance(track.baseline, cur, verdict)
	return verdict == "violation"
end

-- 달리는 레이서면 지금 캐릭터 기준의 Track을 돌려줘요 (처음 보거나 캐릭터가 바뀌면 지금 위치로 새로 시작).
-- 달리지 않으면 기록을 지우고 nil.
local function trackFor(player: Player, t: number): (Track?, BasePart?)
	if RoundService.activeRoomOf(player) == nil then
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
		-- 첫 샘플 시각을 사람마다 흩어서 한 프레임에 몰리지 않게 해요.
		tracks[player] = {
			character = character,
			baseline = sampleOf(root, t),
			nextSampleAt = t + cfg.SampleInterval * (0.5 + math.random() * 0.5),
			lastViolationAt = nil,
			strikes = 0,
			logged = false,
		}
		return nil, nil
	end
	if track.character ~= character then
		-- 같은 라운드에서 캐릭터가 바뀌면(드묾) 위치 기준만 새로 잡아요. 위반 기록은 유지.
		track.character = character
		track.baseline = sampleOf(root, t)
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
	if track then
		local root = rootOf(track.character)
		if root and player.Character == track.character then
			inspect(player, track, root, t)
		end
	end
	local lastViolationAt = if track then track.lastViolationAt else nil
	return Logic.allowPass(lastViolationAt, t, cfg)
end

function MovementGuardService.init() end

function MovementGuardService.start()
	RoundService.setPassValidator(validatePass)
	RunService.Heartbeat:Connect(step)
	Players.PlayerRemoving:Connect(function(player: Player)
		tracks[player] = nil
		idleCheckAt[player] = nil
	end)
end

return MovementGuardService
