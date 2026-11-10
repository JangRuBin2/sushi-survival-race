--!strict
-- 다이너마이트 맵 아이템 순수 로직 (m6-12, GDD 6). Roblox API 없이 숫자 표만 다뤄요 (tests/m6-12-dynamite.spec.luau).
-- 누구나 줍는 아이템이에요 — 스킨과 무관하고(다이너마이트 스시는 폭발 연출만 화려해져요, GDD 9.1), 판정은 전부 서버.
--   shouldSpawn(room, now, activeCount, racerCount, config)  이 방에 지금 하나 떨어뜨릴까
--   dropSpot(racers, pick, config)        떨어뜨릴 자리: 땅에 선 레이서 하나 근처 (pick = 0~1 난수 두 개를 주는 함수)
--   pickupBy(item, racers, config)        이 아이템을 줍는 레이서 userId (가장 가까운, 손 빈 사람만)
--   blastTargets(center, carrierId, racers, config)  폭발에 휘말리는 userId (들고 있던 사람 포함, 가까운 순)
--   effectFor(kind, respawns)             "Home"(Race 부활: 출발점으로) | "Knock"(Survival·결승: 크게 튕김)
--   knockFor(center, target, config)      Knock 속도 (바깥 수평 + 위)
--   fuseLeft(litAt, now, config)          남은 초 (0이면 터질 때)
--   rollUnique(kind, isFinal, roll, config)  이 라운드가 "다이너마이트 라운드"인가 (결승 아닌 Race, roll < UniqueChance)

local DynamiteLogic = {}

export type Vec3 = { x: number, y: number, z: number }

export type Config = {
	FirstDelay: number,
	Interval: number,
	MaxPerRoom: number,
	MinRacers: number,
	PickupRadius: number,
	DropMinDist: number,
	DropMaxDist: number,
	Fuse: number,
	Radius: number,
	KnockHorizontal: number,
	KnockUp: number,
	UniqueChance: number,
}

export type RoomState = {
	startedAt: number, -- 이 방 라운드에서 레이서를 처음 본 시각
	lastSpawnAt: number?, -- 마지막으로 떨어뜨린 시각
}

export type Racer = {
	userId: number,
	position: Vec3,
	grounded: boolean, -- 땅을 밟고 있나 (허공 위에 떨어뜨리지 않게)
	holding: boolean, -- 이미 들고 있나 (하나만)
	down: boolean?, -- 넘어짐·고정·부활 대기 등
}

export type Item = { position: Vec3 }

local function distance(a: Vec3, b: Vec3): number
	local dx, dy, dz = b.x - a.x, b.y - a.y, b.z - a.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end
DynamiteLogic.distance = distance

function DynamiteLogic.newRoom(now: number): RoomState
	return { startedAt = now, lastSpawnAt = nil }
end

-- 라운드 시작 FirstDelay초 뒤 첫 개, 그 뒤 Interval초마다. 방에 MaxPerRoom개(바닥 + 들고 있는 것 + 불붙은 것)까지,
-- 레이서가 MinRacers명 아래면 안 떨어뜨려요 (혼자 남은 결승 등).
function DynamiteLogic.shouldSpawn(
	room: RoomState,
	now: number,
	activeCount: number,
	racerCount: number,
	config: Config
): boolean
	if racerCount < config.MinRacers or activeCount >= config.MaxPerRoom then
		return false
	end
	if now - room.startedAt < config.FirstDelay then
		return false
	end
	return room.lastSpawnAt == nil or now - room.lastSpawnAt >= config.Interval
end

-- 땅에 선(넘어지지 않은) 레이서 하나를 고르고 그 둘레 DropMinDist~DropMaxDist 거리, 같은 높이에. 없으면 nil.
-- 맵 바닥 모양을 몰라서 사람이 선 자리 근처에만 떨어뜨려요(가까울수록 바닥일 확률이 높아요).
function DynamiteLogic.dropSpot(racers: { Racer }, pick: () -> number, config: Config): Vec3?
	local pool: { Racer } = {}
	for _, racer in racers do
		if racer.grounded and not racer.down then
			table.insert(pool, racer)
		end
	end
	if #pool == 0 then
		return nil
	end
	local index = math.clamp(math.floor(pick() * #pool) + 1, 1, #pool)
	local base = pool[index].position
	local angle = pick() * math.pi * 2
	local dist = config.DropMinDist + (config.DropMaxDist - config.DropMinDist) * pick()
	return { x = base.x + math.cos(angle) * dist, y = base.y, z = base.z + math.sin(angle) * dist }
end

-- 아이템 PickupRadius 안의 손 빈 레이서 중 가장 가까운 사람. 같은 거리면 userId 작은 사람.
function DynamiteLogic.pickupBy(item: Item, racers: { Racer }, config: Config): number?
	local bestId: number? = nil
	local best = math.huge
	for _, racer in racers do
		if racer.holding or racer.down then
			continue
		end
		local d = distance(item.position, racer.position)
		if d <= config.PickupRadius and (d < best or (d == best and racer.userId < (bestId :: number))) then
			best = d
			bestId = racer.userId
		end
	end
	return bestId
end

-- 폭발에 휘말리는 사람: 들고 있던 사람(어디 있든) + 폭발 지점 Radius 안의 레이서. 들고 있던 사람이 맨 앞, 나머지 가까운 순.
function DynamiteLogic.blastTargets(center: Vec3, carrierId: number?, racers: { Racer }, config: Config): { number }
	type Hit = { id: number, d: number }
	local hits: { Hit } = {}
	local out: { number } = {}
	local carrierRacing = false
	for _, racer in racers do
		if racer.userId == carrierId then
			carrierRacing = true
			continue
		end
		if racer.down then
			continue
		end
		local d = distance(center, racer.position)
		if d <= config.Radius then
			table.insert(hits, { id = racer.userId, d = d })
		end
	end
	table.sort(hits, function(a: Hit, b: Hit): boolean
		if a.d == b.d then
			return a.id < b.id
		end
		return a.d < b.d
	end)
	if carrierId ~= nil and carrierRacing then
		table.insert(out, carrierId)
	end
	for _, hit in hits do
		table.insert(out, hit.id)
	end
	return out
end

-- Race(정원 전 부활이 되는 라운드)면 출발점으로, 아니면(Survival·결승) 크게 튕겨 내기 (사용자 결정 2026-11-10)
function DynamiteLogic.effectFor(respawns: boolean): "Home" | "Knock"
	return if respawns then "Home" else "Knock"
end

function DynamiteLogic.knockFor(center: Vec3, target: Vec3, config: Config): Vec3
	local dx, dz = target.x - center.x, target.z - center.z
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 1e-6 then
		dx, dz, length = 0, -1, 1 -- 한가운데(들고 있던 사람)는 코스 앞쪽이 아니라 그냥 -Z로
	end
	return {
		x = dx / length * config.KnockHorizontal,
		y = config.KnockUp,
		z = dz / length * config.KnockHorizontal,
	}
end

-- 유니크 라운드 뽑기 (사용자 결정 2026-11-10): 결승이 아닌 Race 라운드에서만, roll(0~1) < UniqueChance
function DynamiteLogic.rollUnique(kind: string, isFinal: boolean, roll: number, config: Config): boolean
	if kind ~= "Race" or isFinal then
		return false
	end
	return roll < config.UniqueChance
end

function DynamiteLogic.fuseLeft(litAt: number, now: number, config: Config): number
	return math.max(0, litAt + config.Fuse - now)
end

return DynamiteLogic
