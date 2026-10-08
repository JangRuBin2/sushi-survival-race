--!strict
-- 플레이어 프로필 모양과 기본값 (GDD 9.4, 9.5, 8). 순수 로직이라 Roblox API를 쓰지 않아요.
--   ProfileSchema.new()                    새 프로필 (부를 때마다 새 표)
--   ProfileSchema.titleFor(wins)           승수로 정해지는 칭호 (Config.Titles), 0승이면 nil
--   ProfileSchema.toView(profile, persistent)  클라이언트에 보낼 ProfileView (ProfileUpdated)
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
}

local ProfileSchema = {}

ProfileSchema.VERSION = 1

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

function ProfileSchema.toView(profile: Profile, persistent: boolean): Types.ProfileView
	local owned = {}
	for skinId, has in profile.ownedSkins do
		if has then
			table.insert(owned, skinId)
		end
	end
	table.sort(owned)
	return {
		coins = profile.coins,
		wins = profile.wins,
		title = ProfileSchema.titleFor(profile.wins),
		equippedSkin = profile.equippedSkin,
		ownedSkins = owned,
		settings = { muteLevel = profile.settings.muteLevel },
		persistent = persistent,
	}
end

return ProfileSchema
