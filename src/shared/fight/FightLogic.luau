--!strict
-- 스시 파이트 핵심 순수 로직 (f1-01). Roblox API 없이 숫자 표만 다뤄서 lune으로 테스트해요.
--   게이지:   applyGauge · soyTint
--   넉백:     knockbackSpeed · knockbackVelocity · hitstun
--   장외:     isRingOut
--   타격 장부: newBook · setInvincible · isInvincible · canHit · hit · koCredit · removeFromBook
--   매치:     newMatch · ringOut · leave · aliveIds · winner · standings · timeUpLeaders · startSuddenDeath
--   아이템:   pickChopstickTarget
-- 시간(now)은 초 단위 숫자예요. 서버는 os.clock()을 넘겨요. 판정은 전부 서버가 이 모듈로 해요.

local FightConfig = require(script.Parent.FightConfig)

local FightLogic = {}

export type Vec3 = { x: number, y: number, z: number }
export type Move = FightConfig.Move

-- 0.1초 같은 경계값이 부동소수점 오차로 어긋나지 않게
local EPSILON = 1e-6

------------------------------------------------------------------------
-- 게이지
------------------------------------------------------------------------

-- 게이지에 delta를 더하고 0~Max로 자른 값. 회복은 음수 delta.
function FightLogic.applyGauge(gauge: number, delta: number): number
	return math.clamp(gauge + delta, 0, FightConfig.Gauge.Max)
end

-- 간장 색 진하기 0~1. 0%면 0, TintFull 이상이면 1.
function FightLogic.soyTint(gauge: number): number
	return math.clamp(gauge / FightConfig.Gauge.TintFull, 0, 1)
end

------------------------------------------------------------------------
-- 넉백
------------------------------------------------------------------------

-- 맞은 뒤 게이지(gaugeAfter) 기준 넉백 속도. 상한 MaxSpeed.
function FightLogic.knockbackSpeed(gaugeAfter: number, move: Move): number
	local speed = move.base + math.max(gaugeAfter, 0) * move.scale
	return math.min(speed, FightConfig.Knockback.MaxSpeed)
end

-- 넉백 속도 벡터. 수평 방향은 때린 사람 → 맞은 사람, 둘이 겹치면 facing(때린 사람이 보는 방향),
-- 그것도 없으면 -Z. y 성분은 speed × lift, 수평 크기는 speed × sqrt(1 - lift²).
function FightLogic.knockbackVelocity(
	attackerPos: Vec3,
	targetPos: Vec3,
	gaugeAfter: number,
	move: Move,
	facing: Vec3?
): Vec3
	local speed = FightLogic.knockbackSpeed(gaugeAfter, move)
	local dx, dz = targetPos.x - attackerPos.x, targetPos.z - attackerPos.z
	local length = math.sqrt(dx * dx + dz * dz)
	if length < EPSILON and facing then
		dx, dz = facing.x, facing.z
		length = math.sqrt(dx * dx + dz * dz)
	end
	if length < EPSILON then
		dx, dz, length = 0, -1, 1
	end
	local lift = math.clamp(move.lift, 0, 1)
	local horizontal = speed * math.sqrt(1 - lift * lift)
	return {
		x = dx / length * horizontal,
		y = speed * lift,
		z = dz / length * horizontal,
	}
end

-- 경직 시간(초). 넉백 속도에 비례, Min~Max로 자름.
function FightLogic.hitstun(speed: number): number
	local k = FightConfig.Knockback
	return math.clamp(speed * k.HitstunPerSpeed, k.HitstunMin, k.HitstunMax)
end

------------------------------------------------------------------------
-- 장외
------------------------------------------------------------------------

export type Arena = {
	center: Vec3, -- 아레나 중심 (y는 쓰지 않음)
	floorY: number, -- 판정 바닥 윗면 높이
	radius: number, -- 판정 바닥이 차지하는 수평 반지름
}

-- 바닥보다 BelowFloor 넘게 아래거나, 중심에서 radius + OutsideRadius 넘게 수평으로 나가면 장외.
-- 경계와 정확히 같으면 아직 장외가 아니에요.
function FightLogic.isRingOut(position: Vec3, arena: Arena): boolean
	local r = FightConfig.RingOut
	if position.y < arena.floorY - r.BelowFloor - EPSILON then
		return true
	end
	local dx, dz = position.x - arena.center.x, position.z - arena.center.z
	local limit = arena.radius + r.OutsideRadius
	return dx * dx + dz * dz > limit * limit + EPSILON
end

------------------------------------------------------------------------
-- 타격 장부 (누가 누구를 언제 때렸나, 무적, 같은 기술 잠금)
------------------------------------------------------------------------

export type LastHit = { attacker: number, at: number }

export type Book = {
	lastHit: { [number]: LastHit }, -- 맞은 사람 → 마지막으로 때린 사람
	invincibleUntil: { [number]: number },
	lockUntil: { [string]: number }, -- "attacker:target:move" → 잠금 끝
}

function FightLogic.newBook(): Book
	return { lastHit = {}, invincibleUntil = {}, lockUntil = {} }
end

local function lockKey(attacker: number, target: number, moveName: string): string
	return `{attacker}:{target}:{moveName}`
end

function FightLogic.setInvincible(book: Book, userId: number, untilTime: number)
	book.invincibleUntil[userId] = untilTime
end

function FightLogic.isInvincible(book: Book, userId: number, now: number): boolean
	local untilTime = book.invincibleUntil[userId]
	return untilTime ~= nil and now < untilTime - EPSILON
end

export type HitReason = "Self" | "Invincible" | "Lockout"

-- 지금 attacker가 target을 moveName으로 때릴 수 있나. 안 되면 (false, 이유).
function FightLogic.canHit(
	book: Book,
	attacker: number,
	target: number,
	moveName: string,
	now: number
): (boolean, HitReason?)
	if attacker == target then
		return false, "Self"
	end
	if FightLogic.isInvincible(book, target, now) then
		return false, "Invincible"
	end
	local lockedUntil = book.lockUntil[lockKey(attacker, target, moveName)]
	if lockedUntil ~= nil and now < lockedUntil - EPSILON then
		return false, "Lockout"
	end
	return true, nil
end

export type HitInput = {
	attacker: number,
	target: number,
	moveName: FightConfig.MoveName,
	attackerPos: Vec3,
	targetPos: Vec3,
	facing: Vec3?,
	gauge: number, -- 맞기 전 target 게이지
	now: number,
	guard: Guard?, -- target이 김 방패 같은 막기 상태면 (f1-02)
}

-- 맞는 쪽의 막기 배율. 게이지 증가와 넉백 속도에 곱해요.
export type Guard = { gaugeMul: number, knockbackMul: number }

export type HitResult = {
	applied: boolean,
	reason: HitReason?,
	gauge: number, -- 맞은 뒤 게이지 (안 맞았으면 그대로)
	velocity: Vec3?, -- 서버가 target에 줄 넉백 속도
	hitstun: number, -- 경직 초 (안 맞았으면 0)
}

-- 타격 한 번을 판정하고 장부에 기록해요. 맞으면 게이지·넉백·경직을 돌려줘요.
function FightLogic.hit(book: Book, input: HitInput): HitResult
	local ok, reason = FightLogic.canHit(book, input.attacker, input.target, input.moveName, input.now)
	if not ok then
		return { applied = false, reason = reason, gauge = input.gauge, velocity = nil, hitstun = 0 }
	end
	local move = FightConfig.Moves[input.moveName]
	assert(move, `unknown move {input.moveName}`)
	local guard = input.guard
	local gaugeMul = if guard then math.clamp(guard.gaugeMul, 0, 1) else 1
	local knockMul = if guard then math.clamp(guard.knockbackMul, 0, 1) else 1
	local gauge = FightLogic.applyGauge(input.gauge, move.gauge * gaugeMul)
	local velocity = FightLogic.knockbackVelocity(input.attackerPos, input.targetPos, gauge, move, input.facing)
	velocity = { x = velocity.x * knockMul, y = velocity.y * knockMul, z = velocity.z * knockMul }
	local speed = FightLogic.knockbackSpeed(gauge, move) * knockMul
	book.lastHit[input.target] = { attacker = input.attacker, at = input.now }
	book.lockUntil[lockKey(input.attacker, input.target, input.moveName)] = input.now
		+ FightConfig.Knockback.SameMoveLockout
	return { applied = true, reason = nil, gauge = gauge, velocity = velocity, hitstun = FightLogic.hitstun(speed) }
end

-- target이 지금 장외면 KO 점수를 받을 사람. CreditWindow 안에 맞은 적이 없으면 nil(자폭).
function FightLogic.koCredit(book: Book, target: number, now: number): number?
	local last = book.lastHit[target]
	if last == nil or last.attacker == target then
		return nil
	end
	if now - last.at > FightConfig.Ko.CreditWindow + EPSILON then
		return nil
	end
	return last.attacker
end

-- 장외·퇴장 뒤 그 사람이 맞은 기록을 지워요(다음 목숨에 KO 점수가 넘어가지 않게).
-- left = true(방을 나감)면 그 사람이 때린 기록·잠금도 지워요.
function FightLogic.removeFromBook(book: Book, userId: number, left: boolean?)
	book.lastHit[userId] = nil
	if left then
		book.invincibleUntil[userId] = nil
		for target, last in book.lastHit do
			if last.attacker == userId then
				book.lastHit[target] = nil
			end
		end
		local prefix = `{userId}:`
		local infix = `:{userId}:`
		for key in book.lockUntil do
			if string.sub(key, 1, #prefix) == prefix or string.find(key, infix, 1, true) then
				book.lockUntil[key] = nil
			end
		end
	end
end

------------------------------------------------------------------------
-- 매치 (목숨·탈락 순서·순위)
------------------------------------------------------------------------

export type Fighter = {
	userId: number,
	stocks: number,
	gauge: number,
	kos: number,
	outOrder: number?, -- 탈락한 순서 (1 = 처음 탈락). 살아 있으면 nil
	left: boolean, -- 방을 나감
}

export type Match = {
	fighters: { [number]: Fighter },
	order: { number }, -- 참가 순서 (동점 정렬을 안정적으로)
	outCount: number,
	suddenDeath: boolean,
}

function FightLogic.newMatch(userIds: { number }, stocks: number?): Match
	local fighters: { [number]: Fighter } = {}
	local order: { number } = {}
	for _, userId in userIds do
		if fighters[userId] == nil then
			fighters[userId] = {
				userId = userId,
				stocks = stocks or FightConfig.Match.Stocks,
				gauge = 0,
				kos = 0,
				outOrder = nil,
				left = false,
			}
			table.insert(order, userId)
		end
	end
	return { fighters = fighters, order = order, outCount = 0, suddenDeath = false }
end

local function isAlive(fighter: Fighter): boolean
	return fighter.outOrder == nil
end

local function markOut(match: Match, fighter: Fighter)
	match.outCount += 1
	fighter.outOrder = match.outCount
	fighter.stocks = 0
end

export type RingOutResult = {
	counted: boolean, -- 이미 탈락했거나 없는 사람이면 false
	eliminated: boolean, -- 이번에 목숨이 0이 됨
	stocksLeft: number,
	creditedTo: number?, -- KO 점수를 받은 사람
}

-- userId가 장외. 목숨 -1, 게이지 0, creditTo(살아 있는 다른 사람)에게 KO +1.
function FightLogic.ringOut(match: Match, userId: number, creditTo: number?): RingOutResult
	local fighter = match.fighters[userId]
	if fighter == nil or not isAlive(fighter) then
		return { counted = false, eliminated = false, stocksLeft = 0, creditedTo = nil }
	end
	fighter.stocks -= 1
	fighter.gauge = 0
	local credited: number? = nil
	if creditTo ~= nil and creditTo ~= userId then
		local scorer = match.fighters[creditTo]
		if scorer ~= nil and not scorer.left then
			scorer.kos += 1
			credited = creditTo
		end
	end
	local eliminated = fighter.stocks <= 0
	if eliminated then
		markOut(match, fighter)
	end
	return { counted = true, eliminated = eliminated, stocksLeft = fighter.stocks, creditedTo = credited }
end

-- 방을 나감 = 그 자리에서 탈락(같은 순간 장외보다 먼저 탈락한 것으로 쳐요 — 호출 순서대로).
function FightLogic.leave(match: Match, userId: number)
	local fighter = match.fighters[userId]
	if fighter == nil then
		return
	end
	fighter.left = true
	if isAlive(fighter) then
		markOut(match, fighter)
	end
end

function FightLogic.aliveIds(match: Match): { number }
	local ids = {}
	for _, userId in match.order do
		if isAlive(match.fighters[userId]) then
			table.insert(ids, userId)
		end
	end
	return ids
end

-- 살아 있는 사람이 정확히 1명이면 그 사람. 아니면 nil.
function FightLogic.winner(match: Match): number?
	local alive = FightLogic.aliveIds(match)
	if #alive == 1 then
		return alive[1]
	end
	return nil
end

-- 순위표 (1등부터). 살아 있는 사람: 목숨 많은 순 → 게이지 낮은 순 → KO 많은 순 → 참가 순.
-- 탈락한 사람: 늦게 탈락한 순. 나간 사람은 탈락 순서대로 같이 섞여요.
function FightLogic.standings(match: Match): { number }
	local position: { [number]: number } = {}
	for i, userId in match.order do
		position[userId] = i
	end
	local ids = table.clone(match.order)
	table.sort(ids, function(a: number, b: number): boolean
		local fa, fb = match.fighters[a], match.fighters[b]
		local aliveA, aliveB = isAlive(fa), isAlive(fb)
		if aliveA ~= aliveB then
			return aliveA
		end
		if not aliveA then
			return (fa.outOrder :: number) > (fb.outOrder :: number)
		end
		if fa.stocks ~= fb.stocks then
			return fa.stocks > fb.stocks
		end
		if fa.gauge ~= fb.gauge then
			return fa.gauge < fb.gauge
		end
		if fa.kos ~= fb.kos then
			return fa.kos > fb.kos
		end
		return position[a] < position[b]
	end)
	return ids
end

-- 시간이 끝났을 때 목숨이 가장 많은 살아 있는 사람들(참가 순). 1명이면 우승, 여럿이면 서든데스.
function FightLogic.timeUpLeaders(match: Match): { number }
	local best = 0
	for _, userId in match.order do
		local f = match.fighters[userId]
		if isAlive(f) and f.stocks > best then
			best = f.stocks
		end
	end
	local leaders = {}
	if best == 0 then
		return leaders
	end
	for _, userId in match.order do
		local f = match.fighters[userId]
		if isAlive(f) and f.stocks == best then
			table.insert(leaders, userId)
		end
	end
	return leaders
end

-- 서든데스: leaders만 남기고(목숨 1·게이지 SuddenDeathGauge), 나머지 살아 있는 사람은 탈락 처리.
-- 탈락 처리 순서는 지금 순위가 낮은 사람부터라서, 순위표가 시간 종료 순위를 그대로 유지해요.
function FightLogic.startSuddenDeath(match: Match, leaders: { number })
	local keep: { [number]: boolean } = {}
	for _, userId in leaders do
		keep[userId] = true
	end
	local ranked = FightLogic.standings(match)
	for i = #ranked, 1, -1 do
		local f = match.fighters[ranked[i]]
		if isAlive(f) and not keep[f.userId] then
			markOut(match, f)
		end
	end
	for _, userId in leaders do
		local f = match.fighters[userId]
		if f ~= nil and isAlive(f) then
			f.stocks = 1
			f.gauge = FightConfig.Match.SuddenDeathGauge
		end
	end
	match.suddenDeath = true
end

------------------------------------------------------------------------
-- 아이템
------------------------------------------------------------------------

-- 젓가락 소환: 나(userId)를 뺀 살아 있는 사람 중 게이지가 가장 높은 사람(ChopstickMinGauge 이상).
-- 같으면 참가 순으로 앞사람. 없으면 nil.
function FightLogic.pickChopstickTarget(match: Match, userId: number): number?
	local best: number? = nil
	local bestGauge = -math.huge
	for _, id in match.order do
		local f = match.fighters[id]
		if id ~= userId and isAlive(f) and f.gauge >= FightConfig.Items.ChopstickMinGauge and f.gauge > bestGauge then
			best = id
			bestGauge = f.gauge
		end
	end
	return best
end

return FightLogic
