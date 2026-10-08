--!strict
-- 밥알 코인 지급·승수·우승 칭호 (GDD 9.4, 8, m4-08). MatchEvents·DataService 공개 API만 써요.
--   라운드 통과 +10 (결승 제외), 결승 출발 +30 (레이서 전원), 우승 +100 (+ wins), 매치 끝 하루 첫 판 +50
--   (+ matchesPlayed, 끝까지 방에 남은 참가자만). 규칙은 RewardLogic, 값은 Config.Rewards.
--   지급은 그 순간 바로 DataService.update로 반영하고 본인에게 RewardGranted({ reason, amount, total })를 보내요.
--   프로필이 아직 없으면 waitForProfile로 최대 10초 기다리고, 그래도 없으면 버려요(경고).
--   칭호: 캐릭터가 생길 때·프로필이 로드될 때·승수가 바뀔 때 캐릭터 Model에 Attributes.Title을 달아요 (0승이면 지움).
-- 코인은 서버만 지급해요 — 클라이언트 요청으로 지급하는 리모트는 없어요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local ProfileSchema = require(ReplicatedStorage.Shared.ProfileSchema)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RewardLogic = require(ReplicatedStorage.Shared.RewardLogic)
local Types = require(ReplicatedStorage.Shared.Types)
local DataService = require(script.Parent.DataService)
local MatchEvents = require(script.Parent.MatchEvents)
local RoomService = require(script.Parent.RoomService)

type Profile = ProfileSchema.Profile
type Mutate = (profile: Profile) -> number? -- 지급할 코인 (nil이면 지급 없음)

local RewardService = {}

local PROFILE_WAIT = 10

local trackers: { [string]: RewardLogic.Tracker } = {}
local rewardGrantedEvent: RemoteEvent

local function applyTitle(player: Player, wins: number?)
	local character = player.Character
	if character == nil then
		return
	end
	local title = if wins then ProfileSchema.titleFor(wins) else nil
	if character:GetAttribute(Attributes.Title) ~= title then
		character:SetAttribute(Attributes.Title, title)
	end
end

local function refreshTitle(player: Player)
	local profile = DataService.get(player)
	applyTitle(player, if profile then profile.wins else nil)
end

-- 프로필을 (필요하면 기다려서) 바꾸고, 코인을 줬으면 RewardGranted를 보내요. 호출한 스레드를 기다리게 할 수 있어요.
local function grantWith(player: Player, reason: Types.RewardReason, mutate: Mutate)
	local profile = DataService.get(player) or DataService.waitForProfile(player, PROFILE_WAIT)
	if profile == nil then
		if player.Parent ~= nil then
			warn(`[RewardService] no profile for {player.Name}, dropped {reason}`)
		end
		return
	end
	local amount: number? = nil
	local total = 0
	local ok = DataService.update(player, function(p)
		amount = mutate(p)
		if amount then
			p.coins += amount :: number
		end
		total = p.coins
	end)
	if not ok then
		warn(`[RewardService] profile update failed for {player.Name}, dropped {reason}`)
		return
	end
	if amount and player.Parent ~= nil then
		local grant: Types.RewardGrant = { reason = reason, amount = amount :: number, total = total }
		rewardGrantedEvent:FireClient(player, grant)
	end
end

local function grant(grantInfo: RewardLogic.Grant)
	local player = Players:GetPlayerByUserId(grantInfo.userId)
	if player == nil then
		return -- 나간 사람: 이미 받은 건 그대로, 이후 지급은 없어요
	end
	task.spawn(function()
		grantWith(player, grantInfo.reason, function(profile)
			if grantInfo.reason == "Win" then
				profile.wins += 1
			end
			return grantInfo.amount
		end)
		if grantInfo.reason == "Win" then
			refreshTitle(player)
		end
	end)
end

local function grantAll(grants: { RewardLogic.Grant })
	for _, grantInfo in grants do
		grant(grantInfo)
	end
end

local function onMatchStart(roomId: string, _userIds: { number })
	trackers[roomId] = RewardLogic.newTracker()
end

local function onRoundStart(roomId: string, roundIndex: number, roundCount: number, userIds: { number })
	local tracker = trackers[roomId]
	if tracker == nil then
		tracker = RewardLogic.newTracker()
		trackers[roomId] = tracker
	end
	grantAll(RewardLogic.onRoundStart(tracker, roundIndex, roundCount, userIds))
end

local function onResult(roomId: string, result: Types.PlayerResult)
	-- 매치가 끝난 뒤(tracker 없음) 늦게 온 결과는 Won만 지급해요 — 결승 여부를 모르니 Passed +10은 주지 않아요
	local tracker = trackers[roomId]
	if tracker == nil and result.result ~= "Won" then
		return
	end
	grantAll(RewardLogic.onResult(tracker or RewardLogic.newTracker(), result.userId, result.result))
end

local function onMatchEnd(roomId: string, info: MatchEvents.MatchEndInfo)
	trackers[roomId] = nil
	-- 끝까지 방에 남은 참가자만 (방만 나가고 서버에 남은 사람 제외, m4-08 QA B1). 이 훅은 RoomService.endMatch
	-- 전에 불리고 여기까지 기다림 없이 와서, 지금 방 멤버 = 매치 끝 시점 멤버(관전 중인 탈락자 포함)예요.
	local memberIds = {}
	for _, member in RoomService.getPlayers(roomId) do
		table.insert(memberIds, member.UserId)
	end
	local today = RewardLogic.dayNumber(os.time())
	for _, userId in RewardLogic.matchEndRecipients(info.participants, memberIds) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			task.spawn(grantWith, player, "DailyFirstMatch", function(profile): number?
				profile.matchesPlayed += 1
				local amount = RewardLogic.dailyBonus(profile.lastDailyBonusDay, today)
				if amount then
					profile.lastDailyBonusDay = today
				end
				return amount
			end)
		end
	end
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(function()
		refreshTitle(player)
	end)
	if player.Character then
		refreshTitle(player)
	end
end

function RewardService.init()
	rewardGrantedEvent = Remotes.event("RewardGranted")
end

function RewardService.start()
	MatchEvents.onMatchStart(onMatchStart)
	MatchEvents.onRoundStart(onRoundStart)
	MatchEvents.onResult(onResult)
	MatchEvents.onMatchEnd(onMatchEnd)
	DataService.onLoaded(function(player: Player, _profile: Profile)
		refreshTitle(player)
	end)
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
end

return RewardService
