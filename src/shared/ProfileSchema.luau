--!strict
-- 플레이어 프로필 모양과 기본값 (GDD 9.4, 9.5, 8). 순수 로직이라 Roblox API를 쓰지 않아요.
--   ProfileSchema.new()                    새 프로필 (부를 때마다 새 표)
--   ProfileSchema.titleFor(wins)           승수로 정해지는 칭호 (Config.Titles), 0승이면 nil
--   ProfileSchema.toView(profile, persistent, extra?)  클라이언트에 보낼 ProfileView (ProfileUpdated).
--       extra = 저장하지 않는 화면용 값 { vip = boolean } (m5-03, DataService.setViewExtra). 없으면 vip = false
-- 저장(m4-07)은 이 모양 그대로 DataStore에 넣어요. 필드를 바꾸면 VERSION을 올리고 m4-07의 마이그레이션에 추가해요.

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

export type Profile = {
	version: number,
	coins: number,
	wins: number,
	matchesPlayed: number,
	lastDailyBonusDay: number?, -- UTC 날짜 번호 (os.time() // 86400)
	ownedSkins: { [string]: boolean },
	equippedSkin: string,
	settings: Types.Settings,
	-- 처리한 로벅스 결제 id (m4-14, 최근 Config.Shop.ReceiptHistoryMax개만). 같은 결제를 두 번 지급하지 않게
	receipts: { { id: string, at: number } },
	-- v2 (m5-03)
	redeemedCodes: { [string]: number }, -- 정규화한 코드 → 쓴 시각(os.time), 최근 MAX_REDEEMED_CODES개 (m5-10)
	eventTokens: { [string]: number }, -- 이벤트 id(Shared.Seasons) → 모은 이벤트 재화 (m5-07)
	ownedFx: { [string]: boolean }, -- 가진 연출 id (Shared.FxCatalog, m5-08)
	equippedFx: EquippedFx, -- 입은 연출 (가진 것만, 칸이 맞는 것만)
	boughtOffers: { [string]: number }, -- 한 번만 사는 상품 id → 산 시각 (m5-08)
}

export type EquippedFx = { Elimination: string?, Victory: string? }

-- 저장하지 않는 화면용 값 (m5-03). VIP는 게임 패스라 Roblox가 소유를 기억해요
export type ViewExtra = { vip: boolean }

local ProfileSchema = {}

ProfileSchema.VERSION = 2 -- v2 (m5-03): redeemedCodes, eventTokens, ownedFx, equippedFx, boughtOffers
ProfileSchema.MAX_REDEEMED_CODES = 200 -- 기억하는 쓴 코드 수 (오래된 것부터 지워요)

function ProfileSchema.new(): Profile
	local default = Config.Appearance.Default
	return {
		version = ProfileSchema.VERSION,
		coins = 0,
		wins = 0,
		matchesPlayed = 0,
		lastDailyBonusDay = nil,
		ownedSkins = { [default] = true },
		equippedSkin = default,
		settings = { muteLevel = 1 },
		receipts = {},
		redeemedCodes = {},
		eventTokens = {},
		ownedFx = {},
		equippedFx = {},
		boughtOffers = {},
	}
end

-- wins 이하인 칭호 중 가장 높은 것. Config.Titles는 wins 오름차순이에요.
function ProfileSchema.titleFor(wins: number): string?
	local title: string? = nil
	for _, entry in Config.Titles do
		if wins >= entry.wins then
			title = entry.name
		end
	end
	return title
end

ProfileSchema.MUTE_LEVELS = 3 -- 1 소리 켬, 2 음악 끔, 3 모두 끔

-- 클라이언트가 보낸 SaveSettings 인자 검사. 올바르면 새 Settings 표, 아니면 nil.
function ProfileSchema.sanitizeSettings(value: unknown): Types.Settings?
	if type(value) ~= "table" then
		return nil
	end
	local level = (value :: any).muteLevel
	if type(level) ~= "number" or level ~= level or level % 1 ~= 0 then
		return nil
	end
	if level < 1 or level > ProfileSchema.MUTE_LEVELS then
		return nil
	end
	return { muteLevel = level }
end

local function sortedKeys(map: { [string]: any }, keep: (value: any) -> boolean): { string }
	local list = {}
	for key, value in map do
		if keep(value) then
			table.insert(list, key)
		end
	end
	table.sort(list)
	return list
end

local function isTrue(value: any): boolean
	return value == true
end

local function always(_value: any): boolean
	return true
end

function ProfileSchema.toView(profile: Profile, persistent: boolean, extra: ViewExtra?): Types.ProfileView
	local owned = sortedKeys(profile.ownedSkins, isTrue)
	local tokens: { [string]: number } = table.clone(profile.eventTokens or {})
	local equippedFx: EquippedFx = profile.equippedFx or {} :: EquippedFx
	return {
		coins = profile.coins,
		wins = profile.wins,
		title = ProfileSchema.titleFor(profile.wins),
		equippedSkin = profile.equippedSkin,
		ownedSkins = owned,
		settings = { muteLevel = profile.settings.muteLevel },
		persistent = persistent,
		eventTokens = tokens,
		ownedFx = sortedKeys(profile.ownedFx or {}, isTrue),
		equippedFx = { Elimination = equippedFx.Elimination, Victory = equippedFx.Victory },
		boughtOffers = sortedKeys(profile.boughtOffers or {}, always),
		vip = extra ~= nil and extra.vip == true,
	}
end

return ProfileSchema
