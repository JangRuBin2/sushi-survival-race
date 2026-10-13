--!strict
-- 테스트용 관리자 판단 (m5-02). 순수 함수라 Roblox API를 쓰지 않아요 (tests/admin-logic.spec.luau).
-- 비밀번호·키는 쓰지 않아요: 서버가 UserId·Studio 여부·게임 소유자로만 판단해요 (스펙 결정 기록 D1).
--   AdminLogic.isAdmin(input)            관리자인가. 이름(Name·DisplayName)으로는 절대 판단하지 않아요.
--   AdminLogic.checkPreview(isAdmin, skinId, isKnownSkin, locked) -> (ok, reason?, normalizedSkinId?)
--                                        AdminPreviewSkin 요청 판단. nil·""는 미리보기 끄기 (normalized nil).
--   AdminLogic.pickAppearance(preview, equipped, owned, isKnownSkin) -> string?
--                                        입을 스킨: 미리보기 > 보유한 장착 스킨 > nil(기본 계란초밥)
--   AdminLogic.storeKey(userId) / encodeEntry(skinId?, now) / decodeEntry(value, isKnownSkin)
--                                        서버 간 유지 MemoryStore(AdminPreview_v1) 키와 값 (m4-11 로비↔매치)
--   AdminLogic.message(reason)           클라이언트에 돌려줄 한 줄
--   AdminLogic.commandTier(command) -> CommandTier?   AdminCommand 명령의 등급 (m5-03 틀, 명령 실행은 m5-11)
--   AdminLogic.canRun(tier, isStudio, persistInStudio) -> (ok, reason?)
--                                        사용자 결정(2026-10-08): 실서버에서는 Info 명령만. Test·StudioOnly 명령은
--                                        Studio에서만 되고, 실서버에서 켜는 설정은 없어요 (설정으로도 못 켜요).
--   AdminLogic.parse(command, args) -> (Parsed?, Reason?)   AdminCommand 인자 모양 검사 (m5-11)
--   AdminLogic.applyCoins(current, n) / applyTokens(current, n)   0 아래로 내려가지 않는 더하기
--   AdminLogic.resolvePlan(ids, pool) -> (plan?, text)   다음 판 맵 순서: 결과 문구(결승이 Final이 아니면 경고 포함)
--   AdminLogic.equippedFx(equipped, owned, slot) -> string?   fx 미리보기를 끌 때 돌아갈 프로필 장착값
--   AdminLogic.infoLine(info) -> string      info 명령 결과 한 줄
--   AdminLogic.describe(parsed) -> string    서버 로그용 인자 요약
-- 관리자 목록은 서버 전용 src/server/AdminConfig.luau에 있어요 (클라이언트에 복제되지 않음).

export type CreatorType = "User" | "Group"

export type AdminInput = {
	isStudio: boolean,
	userId: number,
	allowList: { number },
	includeOwner: boolean,
	creatorType: CreatorType,
	creatorId: number,
	studioAllAdmins: boolean,
	liveEnabled: boolean?, -- false면 실서버에서는 아무도 관리자가 아니에요 (nil이면 켜짐)
}

export type Reason =
	"NotAdmin"
	| "TooFast"
	| "BadArgument"
	| "UnknownSkin"
	| "Locked"
	| "UnknownCommand"
	| "StudioOnly"
	| "PersistOn"
	| "NotReady"
	| "BadCommandArgs"
	| "NotInRoom"
	| "NoProfile"
	| "NoEvent"
	| "SingleOnly"

-- AdminCommand 등급 (m5-03, m5-11 스펙 표). Info = 보기만·겉모습만, Test = 경제·판정에 영향, StudioOnly = 되돌리기 어려움
export type CommandTier = "Info" | "Test" | "StudioOnly"

export type StoreEntry = {
	skinId: string | boolean, -- 끄면 false
	at: number,
}

local FxCatalog = require(script.Parent.FxCatalog)
local Rules = require(script.Parent.Rules)

local AdminLogic = {}

AdminLogic.STORE_NAME = "AdminPreview_v1"
AdminLogic.STORE_TTL = 3600 -- 초 (1시간)

local MESSAGES: { [Reason]: string } = {
	NotAdmin = "권한이 없어요",
	TooFast = "잠시 뒤에 다시 해 주세요",
	BadArgument = "없는 스킨이에요",
	UnknownSkin = "없는 스킨이에요",
	Locked = "라운드 중에는 바꿀 수 없어요",
	UnknownCommand = "모르는 명령이에요",
	StudioOnly = "Studio에서만 쓸 수 있는 명령이에요",
	PersistOn = "저장을 켠 Studio에서는 쓸 수 없어요",
	NotReady = "준비 중이에요",
	BadCommandArgs = "명령 값이 잘못됐어요",
	NotInRoom = "방에 들어가 있지 않아요",
	NoProfile = "프로필을 아직 불러오지 못했어요",
	NoEvent = "진행 중인 이벤트가 없어요",
	SingleOnly = "한 플레이스 모드에서만 돼요",
}

function AdminLogic.message(reason: Reason): string
	return MESSAGES[reason] or "다시 해 주세요"
end

AdminLogic.COMMAND_TIERS = {
	info = "Info",
	fx = "Info",
	start = "Test",
	plan = "Test",
	coins = "Test",
	tokens = "Test",
	resetprofile = "StudioOnly",
} :: { [string]: CommandTier }

function AdminLogic.commandTier(command: unknown): CommandTier?
	if type(command) ~= "string" then
		return nil
	end
	return AdminLogic.COMMAND_TIERS[command]
end

-- 이 환경에서 그 등급을 실행할 수 있는가. 실서버(isStudio = false)는 Info만 — 켜는 설정이 없어요 (사용자 결정 2026-10-08).
-- StudioOnly는 Studio여도 저장을 켜면(persistInStudio) 거절해요 (운영 저장소를 건드리지 않게).
function AdminLogic.canRun(tier: CommandTier, isStudio: boolean, persistInStudio: boolean?): (boolean, Reason?)
	if tier == "Info" then
		return true, nil
	end
	if not isStudio then
		return false, "StudioOnly"
	end
	if tier == "StudioOnly" and persistInStudio == true then
		return false, "PersistOn"
	end
	return true, nil
end

function AdminLogic.isAdmin(input: AdminInput): boolean
	if input.isStudio and input.studioAllAdmins then
		return true -- Studio 테스트 계정(음수 UserId)도
	end
	local userId = input.userId
	if type(userId) ~= "number" or userId <= 0 or userId ~= math.floor(userId) then
		return false
	end
	if not input.isStudio and input.liveEnabled == false then
		return false
	end
	if table.find(input.allowList, userId) ~= nil then
		return true
	end
	return input.includeOwner == true and input.creatorType == "User" and input.creatorId == userId
end

function AdminLogic.checkPreview(
	isAdmin: boolean,
	skinId: unknown,
	isKnownSkin: (string) -> boolean,
	locked: boolean
): (boolean, Reason?, string?)
	if isAdmin ~= true then
		return false, "NotAdmin", nil
	end
	local normalized: string? = nil
	if skinId == nil or skinId == "" then
		normalized = nil
	elseif type(skinId) == "string" then
		if not isKnownSkin(skinId) then
			return false, "UnknownSkin", nil
		end
		normalized = skinId
	else
		return false, "BadArgument", nil
	end
	if locked then
		return false, "Locked", nil
	end
	return true, nil, normalized
end

function AdminLogic.pickAppearance(
	preview: string?,
	equipped: string?,
	owned: { [string]: boolean },
	isKnownSkin: (string) -> boolean
): string?
	if type(preview) == "string" and isKnownSkin(preview) then
		return preview
	end
	if type(equipped) == "string" and isKnownSkin(equipped) and owned[equipped] == true then
		return equipped
	end
	return nil
end

function AdminLogic.storeKey(userId: number): string
	return `u_{userId}`
end

function AdminLogic.encodeEntry(skinId: string?, now: number): StoreEntry
	return { skinId = if skinId ~= nil then skinId else false, at = now }
end

-- MemoryStore에서 읽은 값 → 미리보기 스킨 (끔·잘못된 값·모르는 스킨이면 nil)
function AdminLogic.decodeEntry(value: unknown, isKnownSkin: (string) -> boolean): string?
	if type(value) ~= "table" then
		return nil
	end
	local skinId = (value :: any).skinId
	if type(skinId) ~= "string" or not isKnownSkin(skinId) then
		return nil
	end
	return skinId
end

---------------------------------------------------------------- AdminCommand 인자·결과 (m5-11)

-- 검사를 통과한 명령. command마다 쓰는 칸만 채워요
export type Parsed = {
	command: string,
	amount: number?, -- coins·tokens
	ids: { string }?, -- plan
	slot: FxCatalog.Slot?, -- fx
	fxId: string?, -- fx (nil = 끄기)
}

AdminLogic.COINS_LIMIT = 10000 -- coins n: -10,000 ~ 10,000
AdminLogic.TOKENS_LIMIT = 500 -- tokens n: -500 ~ 500
AdminLogic.MAP_ID_MAX_LENGTH = 64

local function isIntegerIn(value: unknown, limit: number): boolean
	if type(value) ~= "number" or value ~= value or value % 1 ~= 0 then
		return false
	end
	return value >= -limit and value <= limit
end

local function parsePlan(args: unknown): { string }?
	if type(args) ~= "table" then
		return nil
	end
	local list = args :: { [any]: any }
	local count = 0
	for _ in list do
		count += 1
	end
	if count ~= 3 and count ~= 4 then
		return nil
	end
	local ids: { string } = {}
	for i = 1, count do
		local id = list[i]
		if type(id) ~= "string" or id == "" or #id > AdminLogic.MAP_ID_MAX_LENGTH then
			return nil -- 문자열이 아니거나, 1..n 순서 목록이 아니에요
		end
		table.insert(ids, id)
	end
	return ids
end

-- fx 인자: { slot, fxId? }. fxId가 nil·"off"면 끄기, 아니면 그 칸의 FxCatalog id
local function parseFx(args: unknown): (FxCatalog.Slot?, string?, boolean)
	if type(args) ~= "table" then
		return nil, nil, false
	end
	local list = args :: { [any]: any }
	local slot = list[1]
	local fxId = list[2]
	if not FxCatalog.isSlot(slot) then
		return nil, nil, false
	end
	if fxId == nil or fxId == "off" then
		return slot :: FxCatalog.Slot, nil, true
	end
	if type(fxId) ~= "string" then
		return nil, nil, false
	end
	local fx = FxCatalog.get(fxId)
	if fx == nil or fx.slot ~= slot then
		return nil, nil, false
	end
	return slot :: FxCatalog.Slot, fxId, true
end

-- command는 commandTier로 이미 아는 명령이어야 해요. 모르는 명령이면 UnknownCommand
function AdminLogic.parse(command: unknown, args: unknown): (Parsed?, Reason?)
	if AdminLogic.commandTier(command) == nil then
		return nil, "UnknownCommand"
	end
	local name = command :: string
	if name == "coins" or name == "tokens" then
		local limit = if name == "coins" then AdminLogic.COINS_LIMIT else AdminLogic.TOKENS_LIMIT
		if not isIntegerIn(args, limit) then
			return nil, "BadCommandArgs"
		end
		return { command = name, amount = args :: number }, nil
	elseif name == "plan" then
		local ids = parsePlan(args)
		if ids == nil then
			return nil, "BadCommandArgs"
		end
		return { command = name, ids = ids }, nil
	elseif name == "fx" then
		local slot, fxId, ok = parseFx(args)
		if not ok then
			return nil, "BadCommandArgs"
		end
		return { command = name, slot = slot, fxId = fxId }, nil
	end
	-- info·start·resetprofile: 인자 없음 (보내도 무시)
	return { command = name }, nil
end

-- 코인 더하기: 0 아래로 내려가지 않아요 (100에서 -1000 → 0)
function AdminLogic.applyCoins(current: number, n: number): number
	return math.max(0, math.floor(current + n))
end

function AdminLogic.applyTokens(current: number?, n: number): number
	return math.max(0, math.floor((current or 0) + n))
end

-- 다음 판 맵 순서. 성공이면 (plan, 결과 문구), 실패면 (nil, 이유 문구). pool은 Maps.allInfos()
-- (inPool = false 맵도 돼요). 결승 자리가 Final이 아니면 Rules.forcedPlanWarning을 문구에 붙여요
function AdminLogic.resolvePlan(ids: { string }, pool: { Rules.MapInfo }): ({ Rules.MapInfo }?, string)
	local plan, problem = Rules.resolveForcedPlan(ids, pool)
	if plan == nil then
		return nil, `맵 순서를 쓸 수 없어요: {problem}`
	end
	local names = {}
	for _, map in plan do
		table.insert(names, map.id)
	end
	local text = `다음 판: {table.concat(names, " → ")}`
	local caution = Rules.forcedPlanWarning(plan)
	if caution then
		text ..= ` (주의: {caution})`
	end
	return plan, text
end

-- fx 미리보기를 끌 때 돌아갈 값: 프로필 장착값이 그 칸의 카탈로그 연출이고 가진 것일 때만, 아니면 nil(기본)
function AdminLogic.equippedFx(
	equipped: { [string]: string? }?,
	owned: { [string]: boolean }?,
	slot: FxCatalog.Slot
): string?
	local id = if equipped then equipped[slot] else nil
	if type(id) ~= "string" then
		return nil
	end
	local fx = FxCatalog.get(id)
	if fx == nil or fx.slot ~= slot or owned == nil or owned[id] ~= true then
		return nil
	end
	return id
end

export type Info = {
	role: string,
	jobId: string,
	rooms: number,
	players: number,
	roomId: string?,
	roomState: string?,
	coins: number?,
	eventName: string?,
	tokenIcon: string?,
	tokens: number?,
}

function AdminLogic.infoLine(info: Info): string
	local job = if info.jobId == "" then "-" else string.sub(info.jobId, 1, 8)
	local parts = {
		info.role,
		`서버 {job}`,
		`방 {info.rooms}`,
		`플레이어 {info.players}`,
		if info.roomId then `내 방 {info.roomId}({info.roomState or "?"})` else "내 방 없음",
		if info.coins then `코인 {info.coins}` else "코인 ?",
	}
	if info.eventName then
		table.insert(parts, `{info.eventName} {info.tokenIcon or ""}{info.tokens or 0}`)
	end
	return table.concat(parts, " · ")
end

function AdminLogic.describe(parsed: Parsed): string
	if parsed.amount ~= nil then
		return tostring(parsed.amount)
	elseif parsed.ids ~= nil then
		return table.concat(parsed.ids, ",")
	elseif parsed.slot ~= nil then
		return `{parsed.slot} {parsed.fxId or "off"}`
	end
	return "-"
end

return AdminLogic
