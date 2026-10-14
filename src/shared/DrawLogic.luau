--!strict
-- 🎫 우승자 뽑기 티켓 (m5-31, GDD 9.6). 순수 로직이라 Roblox API를 쓰지 않아요 (tests/m5-31-draw-logic.spec.luau).
-- 티켓은 우승(Won)으로만 받아요 — Robux·코인·이벤트 재화·코드·상품으로 팔거나 주지 않아요 (GDD 9.1 v0.7).
-- 값은 Config.Draw, 뽑기 풀은 Skins.LIST 중 draw = true(특 스킨 9종).
--   pool(ownedSkins) -> { string }            아직 없는 특 스킨 id, order 순 (결정적)
--   odds(ownedSkins) -> { Odd }               결과마다 확률 (합 = 1). 남은 N > 0이면 스킨마다 SkinChance / N,
--                                             N = 0이면 Duplicate(코인 DuplicateCoins) SkinChance. 꽝 1 − SkinChance
--   canDraw(wallet, locked?, canSave?) -> (ok, reason?)   NoTickets / Locked / CannotSave
--   roll(ownedSkins, rng) -> Outcome          rng:NextNumber() 한 번 → < SkinChance면 스킨(남은 게 있으면
--                                             rng:NextInteger(1, N)으로 pool에서) 또는 Duplicate, 아니면 Consolation
--   apply(wallet, outcome) -> Types.DrawResult   티켓 −1 + 보상 (DataService.update 안에서). 장착은 안 바꿔요
--   addTickets(current, n) -> (newValue, added)  0 ~ MaxTickets로 잘라요 (우승 지급·관리자 명령)
--   sanitizeTickets(value) -> (number, note?)   저장 값 정리 (ProfileLogic.migrate): 잘못되면 0, 넘치면 MaxTickets
--   oddsText(odds) -> { string }              뽑기 화면 확률 줄 ("스킨 10% — 아직 없는 9종 중 하나(각 1.1%)", "꽝 90% — 🍚 +20")
--   percentText(chance) -> string             0.0111 → "1.1%", 0.1 → "10%"
--   message(reason) -> string                 거절 이유 한 줄 · resultText(result, skinName?) -> string  결과 한 줄

local Config = require(script.Parent.Config)
local Skins = require(script.Parent.Skins)
local Types = require(script.Parent.Types)

export type Reason = "NoTickets" | "Locked" | "CannotSave" | "TooFast" | "NoProfile"

export type OutcomeKind = "Skin" | "Consolation" | "Duplicate"

export type Outcome = {
	kind: OutcomeKind,
	skinId: string?, -- Skin
	coins: number, -- Consolation·Duplicate (Skin이면 0)
}

export type Odd = {
	kind: OutcomeKind,
	skinId: string?,
	chance: number,
	coins: number?,
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

local function validCount(value: unknown): number
	if type(value) ~= "number" or value ~= value or value < 0 or value == math.huge then
		return 0
	end
	return math.floor(value)
end

function DrawLogic.pool(ownedSkins: { [string]: boolean }): { string }
	local list: { string } = {}
	for _, skin in Skins.LIST do -- LIST는 order 순
		if Skins.isDraw(skin.id) and ownedSkins[skin.id] ~= true then
			table.insert(list, skin.id)
		end
	end
	return list
end

-- 전체 특 스킨 수 (9)
function DrawLogic.totalSkins(): number
	local count = 0
	for _, skin in Skins.LIST do
		if Skins.isDraw(skin.id) then
			count += 1
		end
	end
	return count
end

function DrawLogic.odds(ownedSkins: { [string]: boolean }): { Odd }
	local draw = Config.Draw
	local pool = DrawLogic.pool(ownedSkins)
	local list: { Odd } = {}
	if #pool > 0 then
		local each = draw.SkinChance / #pool
		for _, skinId in pool do
			table.insert(list, { kind = "Skin", skinId = skinId, chance = each })
		end
	else
		table.insert(list, { kind = "Duplicate", chance = draw.SkinChance, coins = draw.DuplicateCoins })
	end
	table.insert(list, { kind = "Consolation", chance = 1 - draw.SkinChance, coins = draw.ConsolationCoins })
	return list
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

function DrawLogic.roll(ownedSkins: { [string]: boolean }, rng: Rng): Outcome
	local draw = Config.Draw
	local value = rng:NextNumber()
	if value < draw.SkinChance then
		local pool = DrawLogic.pool(ownedSkins)
		if #pool == 0 then
			return { kind = "Duplicate", coins = draw.DuplicateCoins }
		end
		local index = math.clamp(math.floor(rng:NextInteger(1, #pool)), 1, #pool)
		return { kind = "Skin", skinId = pool[index], coins = 0 }
	end
	return { kind = "Consolation", coins = draw.ConsolationCoins }
end

-- 프로필을 바로 바꿔요. DataService.update 안에서 canDraw를 다시 확인한 뒤에 불러요.
function DrawLogic.apply(wallet: Wallet, outcome: Outcome): Types.DrawResult
	wallet.drawTickets = math.max(0, validCount(wallet.drawTickets) - 1)
	local coins = 0
	local skinId = outcome.skinId
	if outcome.kind == "Skin" and skinId ~= nil and Skins.isDraw(skinId) then
		wallet.ownedSkins[skinId] = true
	else
		coins = validCount(outcome.coins)
		wallet.coins = validCount(wallet.coins) + coins
	end
	return {
		kind = outcome.kind,
		skinId = if outcome.kind == "Skin" then skinId else nil,
		coins = coins,
		ticketsLeft = wallet.drawTickets,
		skinsLeft = #DrawLogic.pool(wallet.ownedSkins),
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

-- 확률 글씨: 소수 1자리, 끝의 .0은 떼요 (0.1 → "10%", 0.0111 → "1.1%", 0.9 → "90%")
function DrawLogic.percentText(chance: number): string
	local tenths = math.floor(chance * 1000 + 0.5)
	if tenths % 10 == 0 then
		return `{tenths // 10}%`
	end
	return `{tenths // 10}.{tenths % 10}%`
end

function DrawLogic.oddsText(odds: { Odd }): { string }
	local lines: { string } = {}
	local skinCount = 0
	local skinTotal = 0
	local each = 0
	for _, odd in odds do
		if odd.kind == "Skin" then
			skinCount += 1
			skinTotal += odd.chance
			each = odd.chance
		end
	end
	if skinCount > 0 then
		table.insert(
			lines,
			`스킨 {DrawLogic.percentText(skinTotal)} — 아직 없는 {skinCount}종 중 하나(각 {DrawLogic.percentText(
				each
			)})`
		)
	end
	for _, odd in odds do
		if odd.kind == "Duplicate" then
			table.insert(
				lines,
				`스킨 {DrawLogic.percentText(odd.chance)} — 특 스킨을 다 모아서 🍚 +{odd.coins or 0}`
			)
		end
	end
	for _, odd in odds do
		if odd.kind == "Consolation" then
			table.insert(lines, `꽝 {DrawLogic.percentText(odd.chance)} — 🍚 +{odd.coins or 0}`)
		end
	end
	return lines
end

local MESSAGES: { [Reason]: string } = {
	NoTickets = "우승하면 🎫 티켓을 받아요",
	Locked = "매치가 끝나면 뽑을 수 있어요",
	CannotSave = "저장이 안 되는 상태예요",
	TooFast = "잠시 뒤에 다시 해 주세요",
	NoProfile = "프로필을 불러오는 중이에요",
}

function DrawLogic.message(reason: Reason?): string
	if reason == nil then
		return ""
	end
	return MESSAGES[reason] or "다시 해 주세요"
end

-- 결과 한 줄 (결과 연출 아래 글씨)
function DrawLogic.resultText(result: Types.DrawResult, skinName: string?): string
	if result.kind == "Skin" then
		return `🎉 {skinName or result.skinId or "특 스킨"} 획득!`
	elseif result.kind == "Duplicate" then
		return `🎉 당첨! 특 스킨을 다 모아서 🍚 +{result.coins}`
	end
	return `꽝! 🍚 +{result.coins}`
end

-- 티켓 수 글씨 ("🎫 3장")
function DrawLogic.ticketText(tickets: number): string
	return `🎫 {validCount(tickets)}장`
end

return DrawLogic
