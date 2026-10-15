--!strict
-- 밥알 코인 지급·승수·우승 칭호 (GDD 9.4, 8, m4-08). MatchEvents·DataService 공개 API만 써요.
--   라운드 통과 +10 (결승 제외), 결승 출발 +30 (레이서 전원), 우승 +100 (+ wins), 매치 끝 하루 첫 판 +50
--   (+ matchesPlayed, 끝까지 방에 남은 참가자만). 규칙은 RewardLogic, 값은 Config.Rewards.
--   지급은 그 순간 바로 DataService.update로 반영하고 본인에게 RewardGranted({ reason, amount, total })를 보내요.
--   이벤트 재화 (m5-07): 시즌 이벤트가 진행 중이면 같은 지급에 재화도 얹어 eventTokens[eventId]에 더하고
--   RewardGranted에 tokens·tokenTotal·eventId를 채워요. 매치 끝은 한 번에: 하루 첫 판이면 DailyFirstMatch(코인 50 +
--   재화 4), 아니면 이벤트 중 MatchPlayed(코인 0 + 재화 1). 코인도 재화도 0이면 보내지 않아요.
--   "지금 시각" = Seasons.now(Studio, Config.DEBUG.eventNow, os.time()).
--   🎫 우승자 뽑기 티켓 (m5-31): Won 지급과 같은 DataService.update 안에서 DrawLogic.addTickets(+TicketsPerWin, 상한
--   MaxTickets). RewardGranted에 tickets(받은 장수, 가득이면 0)·ticketsFull을 채워요. 이벤트·VIP여도 1장.
--   프로필이 아직 없으면 waitForProfile로 최대 45초 기다리고, 그래도 없으면 버려요(경고).
--   칭호: 캐릭터가 생길 때·프로필이 로드될 때·승수가 바뀔 때 캐릭터 Model에 Attributes.Title을 달아요 (0승이면 지움).
-- 코인은 서버만 지급해요 — 클라이언트 요청으로 지급하는 리모트는 없어요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local DrawLogic = require(ReplicatedStorage.Shared.DrawLogic)
local ProfileSchema = require(ReplicatedStorage.Shared.ProfileSchema)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RewardLogic = require(ReplicatedStorage.Shared.RewardLogic)
local Seasons = require(ReplicatedStorage.Shared.Seasons)
local Types = require(ReplicatedStorage.Shared.Types)
local DataService = require(script.Parent.DataService)
local MatchEvents = require(script.Parent.MatchEvents)
local RoomService = require(script.Parent.RoomService)

type Profile = ProfileSchema.Profile
-- 이번 지급 (nil이면 지급 없음). reason이 있으면 처음 넘긴 이유 대신 그걸 써요 (매치 끝 DailyFirstMatch/MatchPlayed)
-- tickets: 🎫 뽑기 티켓 (m5-31, Win만)
type Payout = { amount: number, tokens: number?, eventId: string?, reason: Types.RewardReason?, tickets: number? }
type Mutate = (profile: Profile) -> Payout?

local RewardService = {}

-- 최악의 로드(같은 서버 옛 세션 대기 30초 + 재시도)보다 길게 (m4-07 QA D7)
local PROFILE_WAIT = 45

local trackers: { [string]: RewardLogic.Tracker } = {}
local rewardGrantedEvent: RemoteEvent

local function applyTitle(player: Player, wins: number?)
	local character = player.Character
	if character == nil then
		return
	end
	-- 칭호 문장이 아니라 기준 승수(1/10/100)만 달아요 — 클라이언트가 Loc.titleName으로 (m5-26)
	local title = if wins then ProfileSchema.titleWinsFor(wins) else nil
	if character:GetAttribute(Attributes.Title) ~= title then
		character:SetAttribute(Attributes.Title, title)
	end
end

-- 이벤트 재화 판단 시각 (Studio면 Config.DEBUG.eventNow 우선)
local function eventNow(): number
	return Seasons.now(RunService:IsStudio(), Config.DEBUG.eventNow, os.time())
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
	local payout: Payout? = nil
	local total = 0
	local tokenTotal: number? = nil
	local ticketsAdded: number? = nil -- 티켓을 줄 지급이면 실제로 늘어난 장수 (가득이면 0)
	local ok = DataService.update(player, function(p)
		payout = mutate(p)
		local current = payout
		if current then
			p.coins += current.amount
			local tokens, eventId = current.tokens, current.eventId
			if tokens and tokens > 0 and eventId then
				p.eventTokens[eventId] = (p.eventTokens[eventId] or 0) + tokens
				tokenTotal = p.eventTokens[eventId]
			end
			local tickets = current.tickets
			if tickets and tickets > 0 then
				local after, added = DrawLogic.addTickets(p.drawTickets, tickets)
				p.drawTickets = after
				ticketsAdded = added
			end
		end
		total = p.coins
	end)
	if not ok then
		warn(`[RewardService] profile update failed for {player.Name}, dropped {reason}`)
		return
	end
	local current = payout
	if current == nil or player.Parent == nil then
		return
	end
	local tokens = if tokenTotal ~= nil then current.tokens else nil
	if current.amount <= 0 and tokens == nil and ticketsAdded == nil then
		return -- 코인도 재화도 티켓도 없어요
	end
	local grant: Types.RewardGrant = {
		reason = current.reason or reason,
		amount = current.amount,
		total = total,
		tokens = tokens,
		tokenTotal = tokenTotal,
		eventId = if tokens then current.eventId else nil,
		tickets = ticketsAdded,
		ticketsFull = if ticketsAdded ~= nil and ticketsAdded <= 0 then true else nil,
	}
	rewardGrantedEvent:FireClient(player, grant)
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
			return {
				amount = grantInfo.amount,
				tokens = grantInfo.tokens,
				eventId = grantInfo.eventId,
				tickets = grantInfo.tickets,
			}
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
	grantAll(RewardLogic.onRoundStart(tracker, roundIndex, roundCount, userIds, eventNow()))
end

local function onResult(roomId: string, result: Types.PlayerResult)
	-- 매치가 끝난 뒤(tracker 없음) 늦게 온 결과는 Won만 지급해요 — 결승 여부를 모르니 Passed +10은 주지 않아요
	local tracker = trackers[roomId]
	if tracker == nil and result.result ~= "Won" then
		return
	end
	grantAll(RewardLogic.onResult(tracker or RewardLogic.newTracker(), result.userId, result.result, eventNow()))
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
	local now = eventNow()
	for _, userId in RewardLogic.matchEndRecipients(info.participants, memberIds) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			task.spawn(grantWith, player, "DailyFirstMatch", function(profile: Profile): Payout?
				profile.matchesPlayed += 1
				local payout = RewardLogic.matchEndPayout(profile.lastDailyBonusDay, today, now)
				if payout == nil then
					return nil
				end
				if payout.daily then
					profile.lastDailyBonusDay = today
				end
				return {
					amount = payout.amount,
					tokens = payout.tokens,
					eventId = payout.eventId,
					reason = payout.reason,
				}
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
