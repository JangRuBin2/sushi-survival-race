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

export type Reason = "NotAdmin" | "TooFast" | "BadArgument" | "UnknownSkin" | "Locked"

export type StoreEntry = {
	skinId: string | boolean, -- 끄면 false
	at: number,
}

local AdminLogic = {}

AdminLogic.STORE_NAME = "AdminPreview_v1"
AdminLogic.STORE_TTL = 3600 -- 초 (1시간)

local MESSAGES: { [Reason]: string } = {
	NotAdmin = "권한이 없어요",
	TooFast = "잠시 뒤에 다시 해 주세요",
	BadArgument = "없는 스킨이에요",
	UnknownSkin = "없는 스킨이에요",
	Locked = "라운드 중에는 바꿀 수 없어요",
}

function AdminLogic.message(reason: Reason): string
	return MESSAGES[reason] or "다시 해 주세요"
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

return AdminLogic
