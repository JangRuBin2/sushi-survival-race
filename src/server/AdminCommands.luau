--!strict
-- 관리자 명령 실행 (m5-11). AdminService.onCommand가 관리자 표 → 요청 간격 → AdminLogic.parse →
-- AdminLogic.canRun(Studio 확인)을 모두 통과한 명령만 여기로 넘겨요. 여기서는 권한을 다시 판단하지 않아요.
-- 모든 명령은 부른 관리자 **본인**에게만 해요 (다른 사람 대상 명령 없음, 결정 기록 D2).
--   info          결과 한 줄 (역할·JobId·방 수·플레이어 수·내 방·코인·이벤트 재화). 겉모습·기록 변화 없음
--   fx            연출 미리보기: Player 속성 EliminationFx/VictoryFx만 잠깐 바꿔요 (프로필·소유 그대로)
--   start         내 방을 인원 조건 없이 바로 시작 (RoomService.forceStart)
--   plan          내 방 다음 매치 한 번만 맵 순서 (MatchService.setNextPlan, 한 플레이스 모드만)
--   coins/tokens  내 코인·진행 중 이벤트 재화 +n (DataService.update, 0 아래로 안 감) + 저장 요청
--   tickets       내 🎫 뽑기 티켓 +n (m5-31, DrawLogic.addTickets로 0~MaxTickets) + 저장 요청
--   resetprofile  내 프로필을 새 프로필로 (메모리 프로필만 — 저장을 켠 Studio는 canRun·canPersist가 거절)
-- 이 파일은 AdminService가 명령을 처음 실행할 때 require해요 (미리보기 경로는 경제 모듈을 모르게 — m5-02).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AdminLogic = require(ReplicatedStorage.Shared.AdminLogic)
local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Config = require(ReplicatedStorage.Shared.Config)
local DrawLogic = require(ReplicatedStorage.Shared.DrawLogic)
local FxCatalog = require(ReplicatedStorage.Shared.FxCatalog)
local ProfileSchema = require(ReplicatedStorage.Shared.ProfileSchema)
local Seasons = require(ReplicatedStorage.Shared.Seasons)
local Maps = require(ReplicatedStorage.Shared.maps)

local DataService = require(script.Parent.DataService)
local MatchService = require(script.Parent.MatchService)
local PlaceService = require(script.Parent.PlaceService)
local RoomService = require(script.Parent.RoomService)
local ShopService = require(script.Parent.ShopService)

local AdminCommands = {}

local function fail(reason: AdminLogic.Reason): (boolean, string?)
	return false, AdminLogic.message(reason)
end

local function currentEvent(): Seasons.Event?
	local now = Seasons.now(RunService:IsStudio(), Config.DEBUG.eventNow, os.time())
	return Seasons.current(now)
end

local function fxAttribute(slot: FxCatalog.Slot): string
	return if slot == "Elimination" then Attributes.EliminationFx else Attributes.VictoryFx
end

local function runInfo(player: Player): (boolean, string?)
	local roomId = RoomService.getRoomIdOf(player)
	local room = if roomId then RoomService.getRoom(roomId) else nil
	local profile = DataService.get(player)
	local event = currentEvent()
	local info: AdminLogic.Info = {
		role = PlaceService.role(),
		jobId = game.JobId,
		rooms = #RoomService.listRooms(),
		players = #Players:GetPlayers(),
		roomId = roomId,
		roomState = if room then room.state else nil,
		coins = if profile then profile.coins else nil,
		eventName = if event then event.name else nil,
		tokenIcon = if event then event.token.icon else nil,
		tokens = if event and profile then (profile.eventTokens or {})[event.id] or 0 else nil,
		tickets = if profile then profile.drawTickets or 0 else nil,
	}
	return true, AdminLogic.infoLine(info)
end

local function runFx(player: Player, parsed: AdminLogic.Parsed): (boolean, string?)
	local slot = parsed.slot :: FxCatalog.Slot
	if ShopService.isLocked(player) then
		return fail("Locked") -- 장착 잠금과 같게: 달리는 중·탈락/우승 연출 중
	end
	local value: string? = parsed.fxId
	if value == nil then
		local profile = DataService.get(player)
		value = AdminLogic.equippedFx(
			if profile then profile.equippedFx :: any else nil,
			if profile then profile.ownedFx else nil,
			slot
		)
	end
	player:SetAttribute(fxAttribute(slot), value)
	if parsed.fxId then
		local fx = FxCatalog.get(parsed.fxId) :: FxCatalog.Fx
		return true, `연출 미리보기: {fx.displayName} (저장 안 됨)`
	end
	return true, `연출 미리보기 끔 ({value or "기본"})`
end

local function runStart(player: Player): (boolean, string?)
	local roomId = RoomService.getRoomIdOf(player)
	if roomId == nil then
		return fail("NotInRoom")
	end
	local ok, err = RoomService.forceStart(roomId)
	if not ok then
		return false, err
	end
	return true, `방 {roomId} 시작!`
end

local function runPlan(player: Player, parsed: AdminLogic.Parsed): (boolean, string?)
	if PlaceService.role() ~= "Single" then
		return fail("SingleOnly") -- 매치 서버로 넘기는 건 범위 밖 (결정 기록 D3)
	end
	local roomId = RoomService.getRoomIdOf(player)
	if roomId == nil then
		return fail("NotInRoom")
	end
	local plan, text = AdminLogic.resolvePlan(parsed.ids :: { string }, Maps.allInfos())
	if plan == nil then
		return false, text
	end
	MatchService.setNextPlan(roomId, plan)
	return true, text
end

local function runCoins(player: Player, parsed: AdminLogic.Parsed): (boolean, string?)
	local n = parsed.amount :: number
	local after = 0
	local updated = DataService.update(player, function(profile)
		profile.coins = AdminLogic.applyCoins(profile.coins, n)
		after = profile.coins
	end)
	if not updated then
		return fail("NoProfile")
	end
	task.spawn(DataService.saveNow, player) -- 저장 요청 (Studio 메모리 프로필이면 아무것도 안 해요)
	return true, `코인 {if n >= 0 then "+" else ""}{n} → {after}`
end

local function runTokens(player: Player, parsed: AdminLogic.Parsed): (boolean, string?)
	local event = currentEvent()
	if event == nil then
		return fail("NoEvent")
	end
	local n = parsed.amount :: number
	local after = 0
	local updated = DataService.update(player, function(profile)
		local tokens = profile.eventTokens or {}
		profile.eventTokens = tokens
		tokens[event.id] = AdminLogic.applyTokens(tokens[event.id], n)
		after = tokens[event.id]
	end)
	if not updated then
		return fail("NoProfile")
	end
	task.spawn(DataService.saveNow, player)
	return true, `{event.token.name} {if n >= 0 then "+" else ""}{n} → {event.token.icon}{after}`
end

local function runTickets(player: Player, parsed: AdminLogic.Parsed): (boolean, string?)
	local n = parsed.amount :: number
	local after = 0
	local updated = DataService.update(player, function(profile)
		local value = DrawLogic.addTickets(profile.drawTickets, n)
		profile.drawTickets = value
		after = value
	end)
	if not updated then
		return fail("NoProfile")
	end
	task.spawn(DataService.saveNow, player)
	return true, `🎫 티켓 {if n >= 0 then "+" else ""}{n} → {after}`
end

local function runResetProfile(player: Player): (boolean, string?)
	-- canRun이 저장을 켠 Studio를 이미 거절했어요. 한 번 더: 이 프로필이 실제 저장소에 묶여 있으면 거절
	if DataService.canPersist(player) then
		return fail("PersistOn")
	end
	if ShopService.isLocked(player) then
		return fail("Locked")
	end
	local updated = DataService.update(player, function(profile)
		local fresh = ProfileSchema.new() :: any
		local target = profile :: any
		for key in table.clone(target) do
			target[key] = nil
		end
		for key, value in fresh do
			target[key] = value
		end
	end)
	if not updated then
		return fail("NoProfile")
	end
	player:SetAttribute(Attributes.EliminationFx, nil)
	player:SetAttribute(Attributes.VictoryFx, nil)
	-- 스킨 미리보기도 끄고 다시 입혀요 (장착 스킨이 기본으로 돌아갔어요)
	ShopService.setPreview(player, nil)
	return true, "새 프로필로 돌아갔어요 (메모리 프로필)"
end

function AdminCommands.run(player: Player, parsed: AdminLogic.Parsed): (boolean, string?)
	local command = parsed.command
	if command == "info" then
		return runInfo(player)
	elseif command == "fx" then
		return runFx(player, parsed)
	elseif command == "start" then
		return runStart(player)
	elseif command == "plan" then
		return runPlan(player, parsed)
	elseif command == "coins" then
		return runCoins(player, parsed)
	elseif command == "tokens" then
		return runTokens(player, parsed)
	elseif command == "tickets" then
		return runTickets(player, parsed)
	elseif command == "resetprofile" then
		return runResetProfile(player)
	end
	return fail("UnknownCommand")
end

return AdminCommands
