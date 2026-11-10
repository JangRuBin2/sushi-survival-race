--!strict
-- 공격 순수 로직 (m6-08, GDD 6). Roblox API 없이 숫자 표만 다뤄서 Lune으로 테스트해요 (tests/m6-08-attack.spec.luau).
-- 모든 플레이어가 같은 공격이에요 — 스킨은 연출(AttackFxLogic)만 바꾸고 여기 수치는 스킨과 무관해요 (GDD 9.1).
--   pickTargets(attacker, candidates, config) -> { userId }   반지름 안의 맞을 사람 (가까운 순)
--   knockFor(attacker, target, config) -> Vec3                  맞은 사람에게 줄 속도 (바깥쪽 수평 + 위)
--   newBook()                                                   쿨다운·면역 기록
--     canAttack / record / readyAt / isImmune / removePlayer
-- 시간(now)은 초 단위 숫자예요. 서버는 os.clock()을 넘겨요.

local AttackLogic = {}

export type Vec3 = { x: number, y: number, z: number }

export type Config = {
	Radius: number,
	KnockHorizontal: number,
	KnockUp: number,
	Cooldown: number,
	Immunity: number,
}

export type Attacker = {
	userId: number,
	position: Vec3, -- HumanoidRootPart 위치
	look: Vec3, -- 바라보는 방향 (같은 자리에 겹친 상대를 밀 방향, y는 무시)
}

export type Candidate = {
	userId: number,
	position: Vec3,
	alive: boolean,
	down: boolean, -- 넘어짐(PlatformStand)·젓가락(WalkSpeed 0)·Anchored
	immune: boolean?, -- 맞은 지 Immunity초 안
}

export type Book = {
	readyAt: { [number]: number }, -- 공격한 사람 userId → 다시 공격할 수 있는 시각
	immuneUntil: { [number]: number }, -- 맞은 사람 userId → 다시 맞을 수 있는 시각
}

local function distance(a: Vec3, b: Vec3): number
	local dx, dy, dz = b.x - a.x, b.y - a.y, b.z - a.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end
AttackLogic.distance = distance

local function flatUnit(v: Vec3): (number, number, number)
	local length = math.sqrt(v.x * v.x + v.z * v.z)
	if length < 1e-6 then
		return 0, 0, 0
	end
	return v.x / length, v.z / length, length
end

-- 맞을 사람: 같은 후보 목록(서버가 같은 방 레이서만 넣어요)에서 나·죽음·넘어짐·면역을 빼고 반지름 안. 가까운 순.
function AttackLogic.pickTargets(attacker: Attacker, candidates: { Candidate }, config: Config): { number }
	type Hit = { id: number, d: number }
	local hits: { Hit } = {}
	for _, candidate in candidates do
		if candidate.userId == attacker.userId or not candidate.alive or candidate.down or candidate.immune then
			continue
		end
		local d = distance(attacker.position, candidate.position)
		if d <= config.Radius then
			table.insert(hits, { id = candidate.userId, d = d })
		end
	end
	table.sort(hits, function(a: Hit, b: Hit): boolean
		if a.d == b.d then
			return a.id < b.id
		end
		return a.d < b.d
	end)
	local ids: { number } = {}
	for _, hit in hits do
		table.insert(ids, hit.id)
	end
	return ids
end

-- 맞은 사람 속도: 공격자 → 대상 수평 방향 × KnockHorizontal + 위 KnockUp.
-- 바로 위·아래로 겹쳐 있으면 공격자가 바라보는 방향, 그것도 없으면 -Z(코스 앞쪽)로 밀어요.
function AttackLogic.knockFor(attacker: Attacker, targetPosition: Vec3, config: Config): Vec3
	local ux, uz, length = flatUnit({
		x = targetPosition.x - attacker.position.x,
		y = 0,
		z = targetPosition.z - attacker.position.z,
	})
	if length == 0 then
		ux, uz, length = flatUnit(attacker.look)
		if length == 0 then
			ux, uz = 0, -1
		end
	end
	return { x = ux * config.KnockHorizontal, y = config.KnockUp, z = uz * config.KnockHorizontal }
end

function AttackLogic.newBook(): Book
	return { readyAt = {}, immuneUntil = {} }
end

-- 다시 공격할 수 있는 시각 (기록이 없으면 nil = 지금 됨)
function AttackLogic.readyAt(book: Book, userId: number): number?
	return book.readyAt[userId]
end

function AttackLogic.canAttack(book: Book, userId: number, now: number): boolean
	local untilTime = book.readyAt[userId]
	return untilTime == nil or now >= untilTime
end

function AttackLogic.isImmune(book: Book, userId: number, now: number): boolean
	local untilTime = book.immuneUntil[userId]
	return untilTime ~= nil and now < untilTime
end

-- 공격을 기록해요: 공격한 사람 쿨다운, 맞은 사람 면역. 쿨다운이 안 끝났으면 false(아무것도 안 바꿔요).
function AttackLogic.record(book: Book, attackerId: number, hits: { number }, now: number, config: Config): boolean
	if not AttackLogic.canAttack(book, attackerId, now) then
		return false
	end
	book.readyAt[attackerId] = now + config.Cooldown
	for _, id in hits do
		book.immuneUntil[id] = now + config.Immunity
	end
	return true
end

-- 라운드가 바뀌어도 쿨다운은 그대로 두고(시각이 지나면 저절로 풀려요), 나간 사람만 지워요.
function AttackLogic.removePlayer(book: Book, userId: number)
	book.readyAt[userId] = nil
	book.immuneUntil[userId] = nil
end

return AttackLogic
