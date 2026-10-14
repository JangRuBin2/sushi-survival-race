--!strict
-- 🎫 우승자 뽑기 (m5-31, GDD 9.6). 순수 로직이라 Roblox API를 쓰지 않아요 (tests/m5-31-draw-logic.spec.luau).
-- 뽑기권은 우승(Won)으로만 받아요 — Robux·코인·이벤트 재화·코드·상품으로 팔거나 주지 않아요 (GDD 9.1 v0.7).
-- 꽝 없음: 등급을 먼저 뽑고(Config.Draw.GradeWeights) 그 등급 스킨 중 하나를 균등하게. 이미 가진 스킨이 나오면
-- 그 등급의 밥알 코인(Config.Draw.DuplicateCoins). 뽑기 풀 = drawGrade가 있는 스킨 (카탈로그 데이터).
-- 스킨이 하나도 없는 등급(m5-31의 전설)은 확률 0, 그 몫은 남은 등급에 기본 비율대로 나눠요:
--   실제 = 기본 / (스킨이 있는 등급들의 기본 합). 확률은 보유와 무관해요 (사람마다 같은 표).
-- 화면 확률표(displayPercents·perSkinPercent)와 서버 판정(roll)은 같은 grades()에서 나와요 — 별도 상수 없음.
--   grades(list?) -> { GradeRow }              5줄 (전설 → 일반): grade, skinIds(order 순), chance, duplicateCoins
--   roll(ownedSkins, rng, list?) -> Outcome?   rng:NextNumber() 한 번(누적 구간 `<`) + rng:NextInteger(1, n) 한 번.
--                                              풀이 비면 nil (서버는 NoPool로 거절)
--   canDraw(wallet, locked?, canSave?) -> (ok, reason?)   NoTickets / Locked / CannotSave
--   apply(wallet, outcome) -> Types.DrawResult  티켓 −1 + 새 스킨 보유 또는 중복 코인 (DataService.update 안에서)
--   addTickets(current, n) -> (newValue, added) 0 ~ MaxTickets (우승 지급·관리자 명령)
--   sanitizeTickets(value) -> (number, note?)   저장 값 정리 (ProfileLogic.migrate)
--   displayPercents(grades) -> { [grade]: string }   소수 1자리, 최대 나머지 방식으로 표시 합 정확히 100.0%,
--                                              빈 등급은 "준비 중"
--   perSkinPercent(grades) -> { [skinId]: string }   ⓘ 상세: 스킨 하나의 확률, 소수 2자리 ("5.05%")
--   featured(ownedSkins, list?) -> string?      단상 대표 스킨: 아직 없는 스킨 중 가장 높은 등급(같으면 order 앞),
--                                              다 가졌으면 가장 높은 등급의 첫 스킨
--   pool(ownedSkins, list?) / totalSkins(list?) / ownedCount(ownedSkins, list?)   보유 목록 n/총수
--   message(reason) · resultText(result, skinName?) · ticketText(n)

local Config = require(script.Parent.Config)
local Skins = require(script.Parent.Skins)
local Types = require(script.Parent.Types)

export type Reason = "NoTickets" | "Locked" | "CannotSave" | "TooFast" | "NoProfile" | "NoPool"

export type Outcome = {
	kind: "Skin" | "Duplicate",
	skinId: string,
	grade: Skins.DrawGrade,
	coins: number, -- Duplicate: 그 등급 코인 (Skin이면 0)
}

export type GradeRow = {
	grade: Skins.DrawGrade,
	skinIds: { string }, -- 그 등급 스킨 (order 순)
	chance: number, -- 빈 등급 몫을 나눈 뒤 실제 확률 (빈 등급 0)
	duplicateCoins: number,
}

-- 뽑기에 쓰는 프로필 부분 (ProfileSchema.Profile이 이 모양을 가져요)
export type Wallet = {
	coins: number,
	ownedSkins: { [string]: boolean },
	drawTickets: number,
}

-- 가짜 rng도 받을 수 있게 (Random과 같은 메서드 두 개)
export type Rng = {
	NextNumber: (self: any) -> number,
	NextInteger: (self: any, min: number, max: number) -> number,
}

local DrawLogic = {}

DrawLogic.EMPTY_TEXT = "준비 중" -- 스킨이 없는 등급 줄
DrawLogic.ROUNDING_NOTE = "확률은 반올림한 값이라 합이 100%와 조금 다를 수 있어요."

local function validCount(value: unknown): number
	if type(value) ~= "number" or value ~= value or value < 0 or value == math.huge then
		return 0
	end
	return math.floor(value)
end

function DrawLogic.grades(list: { Skins.Skin }?): { GradeRow }
	local weights = Config.Draw.GradeWeights :: { [string]: number }
	local coins = Config.Draw.DuplicateCoins :: { [string]: number }
	local byGrade: { [string]: { string } } = {}
	for _, grade in Skins.DRAW_GRADES do
		byGrade[grade] = {}
	end
	for _, skin in list or Skins.LIST do -- order 순
		local grade = skin.drawGrade
		if grade ~= nil and byGrade[grade] ~= nil then
			table.insert(byGrade[grade], skin.id)
		end
	end
	local total = 0
	for _, grade in Skins.DRAW_GRADES do
		if #byGrade[grade] > 0 then
			total += math.max(0, weights[grade] or 0)
		end
	end
	local rows: { GradeRow } = {}
	for _, grade in Skins.DRAW_GRADES do
		local skinIds = byGrade[grade]
		local chance = if #skinIds > 0 and total > 0 then math.max(0, weights[grade] or 0) / total else 0
		table.insert(rows, {
			grade = grade,
			skinIds = skinIds,
			chance = chance,
			duplicateCoins = validCount(coins[grade]),
		})
	end
	return rows
end

function DrawLogic.roll(ownedSkins: { [string]: boolean }, rng: Rng, list: { Skins.Skin }?): Outcome?
	local rows = DrawLogic.grades(list)
	local last: GradeRow? = nil
	for _, row in rows do
		if row.chance > 0 and #row.skinIds > 0 then
			last = row
		end
	end
	if last == nil then
		return nil -- 풀이 비었어요
	end
	local value = rng:NextNumber()
	local picked: GradeRow = last -- 부동소수 오차로 끝까지 가면 마지막(가장 낮은) 등급
	local acc = 0
	for _, row in rows do
		if row.chance > 0 and #row.skinIds > 0 then
			acc += row.chance
			if value < acc then
				picked = row
				break
			end
		end
	end
	local count = #picked.skinIds
	local index = math.clamp(math.floor(rng:NextInteger(1, count)), 1, count)
	local skinId = picked.skinIds[index]
	if ownedSkins[skinId] == true then
		return { kind = "Duplicate", skinId = skinId, grade = picked.grade, coins = picked.duplicateCoins }
	end
	return { kind = "Skin", skinId = skinId, grade = picked.grade, coins = 0 }
end

function DrawLogic.canDraw(wallet: Wallet, locked: boolean?, canSave: boolean?): (boolean, Reason?)
	if validCount(wallet.drawTickets) < 1 then
		return false, "NoTickets"
	end
	if locked == true then
		return false, "Locked"
	end
	if canSave == false then
		return false, "CannotSave"
	end
	return true, nil
end

-- 프로필을 바로 바꿔요. DataService.update 안에서 canDraw를 다시 확인한 뒤에 불러요.
function DrawLogic.apply(wallet: Wallet, outcome: Outcome): Types.DrawResult
	wallet.drawTickets = math.max(0, validCount(wallet.drawTickets) - 1)
	local kind = outcome.kind
	local coins = 0
	if kind == "Skin" and wallet.ownedSkins[outcome.skinId] ~= true then
		wallet.ownedSkins[outcome.skinId] = true
	else
		-- 중복 (roll 뒤에 보유가 생긴 경우도): 그 등급 코인
		kind = "Duplicate"
		coins = if outcome.kind == "Duplicate"
			then validCount(outcome.coins)
			else validCount((Config.Draw.DuplicateCoins :: { [string]: number })[outcome.grade])
		wallet.coins = validCount(wallet.coins) + coins
	end
	return {
		kind = kind,
		skinId = outcome.skinId,
		grade = outcome.grade,
		coins = coins,
		ticketsLeft = wallet.drawTickets,
	}
end

function DrawLogic.addTickets(current: unknown, n: number): (number, number)
	local before = math.min(validCount(current), Config.Draw.MaxTickets)
	local after = math.clamp(math.floor(before + n), 0, Config.Draw.MaxTickets)
	return after, after - before
end

-- 저장된 티켓 수 정리: 숫자가 아니거나 음수·소수·NaN이면 0(노트), MaxTickets보다 크면 MaxTickets(노트)
function DrawLogic.sanitizeTickets(value: unknown): (number, string?)
	if value == nil then
		return 0, nil
	end
	if type(value) ~= "number" or value ~= value or value < 0 or value % 1 ~= 0 or value == math.huge then
		return 0, `drawTickets was invalid ({tostring(value)}), set to 0`
	end
	if value > Config.Draw.MaxTickets then
		return Config.Draw.MaxTickets, `drawTickets {value} above max, set to {Config.Draw.MaxTickets}`
	end
	return value, nil
end

-- 등급 줄 퍼센트: 0.1% 단위 정수로 내린 뒤, 남은 0.1%들을 나머지가 큰 등급부터 하나씩 (최대 나머지 방식).
-- 스킨이 있는 등급의 표시 합 = 정확히 100.0%. 빈 등급은 "준비 중"
function DrawLogic.displayPercents(grades: { GradeRow }): { [string]: string }
	local units: { [string]: number } = {}
	type Entry = { grade: string, rest: number, index: number }
	local order: { Entry } = {}
	local used = 0
	for index, row in grades do
		if row.chance > 0 then
			local exact = row.chance * 1000
			local base = math.floor(exact + 1e-9)
			units[row.grade] = base
			used += base
			table.insert(order, { grade = row.grade, rest = exact - base, index = index })
		end
	end
	if #order > 0 then
		table.sort(order, function(a: Entry, b: Entry): boolean
			if math.abs(a.rest - b.rest) > 1e-12 then
				return a.rest > b.rest
			end
			return a.index < b.index
		end)
		local left = 1000 - used
		local i = 1
		while left > 0 do
			local entry = order[((i - 1) % #order) + 1]
			units[entry.grade] += 1
			left -= 1
			i += 1
		end
	end
	local out: { [string]: string } = {}
	for _, row in grades do
		local unit = units[row.grade]
		out[row.grade] = if unit == nil then DrawLogic.EMPTY_TEXT else `{unit // 10}.{unit % 10}%`
	end
	return out
end

-- ⓘ 상세: 스킨 하나의 확률, 소수 2자리 반올림
function DrawLogic.perSkinPercent(grades: { GradeRow }): { [string]: string }
	local out: { [string]: string } = {}
	for _, row in grades do
		if row.chance > 0 then
			local hundredths = math.floor(row.chance / #row.skinIds * 10000 + 0.5)
			for _, skinId in row.skinIds do
				out[skinId] = `{hundredths // 100}.{string.format("%02d", hundredths % 100)}%`
			end
		end
	end
	return out
end

function DrawLogic.featured(ownedSkins: { [string]: boolean }, list: { Skins.Skin }?): string?
	local first: string? = nil
	for _, row in DrawLogic.grades(list) do
		for _, skinId in row.skinIds do
			first = first or skinId
			if ownedSkins[skinId] ~= true then
				return skinId
			end
		end
	end
	return first
end

function DrawLogic.pool(ownedSkins: { [string]: boolean }, list: { Skins.Skin }?): { string }
	local out: { string } = {}
	for _, row in DrawLogic.grades(list) do
		for _, skinId in row.skinIds do
			if ownedSkins[skinId] ~= true then
				table.insert(out, skinId)
			end
		end
	end
	return out
end

function DrawLogic.totalSkins(list: { Skins.Skin }?): number
	local count = 0
	for _, row in DrawLogic.grades(list) do
		count += #row.skinIds
	end
	return count
end

function DrawLogic.ownedCount(ownedSkins: { [string]: boolean }, list: { Skins.Skin }?): number
	return DrawLogic.totalSkins(list) - #DrawLogic.pool(ownedSkins, list)
end

local MESSAGES: { [Reason]: string } = {
	NoTickets = "우승하면 🎫 뽑기권을 받아요",
	Locked = "매치가 끝나면 뽑을 수 있어요",
	CannotSave = "저장이 안 되는 상태예요",
	TooFast = "잠시 뒤에 다시 해 주세요",
	NoProfile = "프로필을 불러오는 중이에요",
	NoPool = "뽑을 스킨이 없어요",
}

function DrawLogic.message(reason: Reason?): string
	if reason == nil then
		return ""
	end
	return MESSAGES[reason] or "다시 해 주세요"
end

function DrawLogic.resultText(result: Types.DrawResult, skinName: string?): string
	if result.kind == "Skin" then
		return `🎉 {skinName or result.skinId} 획득!`
	end
	return `이미 가진 스킨이에요 → 🍚 +{result.coins}`
end

-- 뽑기권 수 글씨 ("×3")
function DrawLogic.ticketText(tickets: number): string
	return `×{validCount(tickets)}`
end

return DrawLogic
