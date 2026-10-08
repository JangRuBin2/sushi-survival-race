--!strict
-- 잡기 순수 로직 (m3-07). Roblox API 없이 숫자 표만 다뤄서 Lune으로 테스트해요.
--   pickTarget(grabber, candidates, config) -> userId?   앞쪽·거리 안에서 가장 가까운 후보
--   shouldEnd(state, config) -> boolean                 지금 잡기를 끝내야 하나
--   newBook()                                            누가 누구를 잡았는지·쿨다운·면역 기록
--     canStart / isGrabbed / isImmune / begin / finish / grabOf / grabberOf / removePlayer
-- 시간(now)은 초 단위 숫자예요. 서버는 os.clock()을 넘겨요.

local GrabLogic = {}

export type Vec3 = { x: number, y: number, z: number }

export type Config = {
	Range: number,
	FrontDot: number,
	BreakRange: number,
	MaxHold: number,
	Cooldown: number,
	Immunity: number,
}

export type Grabber = {
	userId: number,
	position: Vec3, -- HumanoidRootPart 위치
	look: Vec3, -- 바라보는 방향 (y는 무시해요)
}

export type Candidate = {
	userId: number,
	position: Vec3,
	alive: boolean,
	down: boolean, -- 넘어짐(PlatformStand)·젓가락(WalkSpeed 0)·Anchored
	grabbed: boolean?, -- 이미 다른 사람에게 잡혀 있음
	grabbing: boolean?, -- 다른 사람을 잡고 있음 (잡고 있는 사람은 잡을 수 없어요 — 감속 중첩 방지, m3-09)
	immune: boolean?, -- 풀려난 지 Immunity초 안
}

export type EndState = {
	holding: boolean, -- 잡는 사람이 아직 버튼을 누르고 있나
	elapsed: number, -- 잡은 지 몇 초
	distance: number, -- 두 루트 사이 거리
	grabberRacing: boolean, -- activeRoomOf가 잡을 때 방과 같음
	targetRacing: boolean,
	grabberDown: boolean, -- 죽음·캐릭터 바뀜·넘어짐·WalkSpeed 0·Anchored
	targetDown: boolean,
}

export type Grab = {
	grabber: number,
	target: number,
	startedAt: number,
}

export type Book = {
	grabs: { [number]: Grab }, -- 잡는 사람 userId → 잡기
	grabbedBy: { [number]: number }, -- 대상 userId → 잡는 사람 userId
	cooldownUntil: { [number]: number },
	immuneUntil: { [number]: number },
}

local function horizontal(v: Vec3): (number, number, number)
	local length = math.sqrt(v.x * v.x + v.z * v.z)
	if length < 1e-6 then
		return 0, 0, 0
	end
	return v.x / length, v.z / length, length
end

local function distance(a: Vec3, b: Vec3): number
	local dx, dy, dz = b.x - a.x, b.y - a.y, b.z - a.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end
GrabLogic.distance = distance

-- 잡을 대상을 골라요. 후보가 없으면 nil.
function GrabLogic.pickTarget(grabber: Grabber, candidates: { Candidate }, config: Config): number?
	local lookX, lookZ, lookLength = horizontal(grabber.look)
	if lookLength == 0 then
		return nil
	end
	local bestId: number? = nil
	local bestDistance = math.huge
	for _, candidate in candidates do
		if
			candidate.userId == grabber.userId
			or not candidate.alive
			or candidate.down
			or candidate.grabbed
			or candidate.grabbing
			or candidate.immune
		then
			continue
		end
		local d = distance(grabber.position, candidate.position)
		if d > config.Range or d >= bestDistance then
			continue
		end
		local dirX, dirZ, flat = horizontal({
			x = candidate.position.x - grabber.position.x,
			y = 0,
			z = candidate.position.z - grabber.position.z,
		})
		if flat == 0 then
			continue -- 바로 위·아래는 앞쪽이 아니에요
		end
		if lookX * dirX + lookZ * dirZ < config.FrontDot then
			continue
		end
		bestId = candidate.userId
		bestDistance = d
	end
	return bestId
end

function GrabLogic.shouldEnd(state: EndState, config: Config): boolean
	return not state.holding
		or state.elapsed >= config.MaxHold
		or state.distance > config.BreakRange
		or not state.grabberRacing
		or not state.targetRacing
		or state.grabberDown
		or state.targetDown
end

function GrabLogic.newBook(): Book
	return { grabs = {}, grabbedBy = {}, cooldownUntil = {}, immuneUntil = {} }
end

function GrabLogic.grabOf(book: Book, grabberId: number): Grab?
	return book.grabs[grabberId]
end

function GrabLogic.grabberOf(book: Book, targetId: number): number?
	return book.grabbedBy[targetId]
end

function GrabLogic.isGrabbed(book: Book, userId: number): boolean
	return book.grabbedBy[userId] ~= nil
end

function GrabLogic.isImmune(book: Book, userId: number, now: number): boolean
	local untilTime = book.immuneUntil[userId]
	return untilTime ~= nil and now < untilTime
end

-- 이 사람이 지금 잡기를 시작할 수 있나 (잡고 있지 않음, 잡혀 있지 않음, 쿨다운 지남)
function GrabLogic.canStart(book: Book, grabberId: number, now: number): boolean
	if book.grabs[grabberId] ~= nil or book.grabbedBy[grabberId] ~= nil then
		return false
	end
	local untilTime = book.cooldownUntil[grabberId]
	return untilTime == nil or now >= untilTime
end

-- 잡기를 기록해요. 성립하지 않으면 false (먼저 시작한 잡기만 성립).
function GrabLogic.begin(book: Book, grabberId: number, targetId: number, now: number): boolean
	if grabberId == targetId or not GrabLogic.canStart(book, grabberId, now) then
		return false
	end
	if book.grabbedBy[targetId] ~= nil or book.grabs[targetId] ~= nil or GrabLogic.isImmune(book, targetId, now) then
		return false
	end
	book.grabs[grabberId] = { grabber = grabberId, target = targetId, startedAt = now }
	book.grabbedBy[targetId] = grabberId
	return true
end

-- 잡기를 끝내요. 잡던 사람에게 쿨다운, 잡혔던 사람에게 면역. 끝난 잡기를 돌려줘요.
function GrabLogic.finish(book: Book, grabberId: number, now: number, config: Config): Grab?
	local grab = book.grabs[grabberId]
	if grab == nil then
		return nil
	end
	book.grabs[grabberId] = nil
	if book.grabbedBy[grab.target] == grabberId then
		book.grabbedBy[grab.target] = nil
	end
	book.cooldownUntil[grabberId] = now + config.Cooldown
	book.immuneUntil[grab.target] = now + config.Immunity
	return grab
end

-- 플레이어가 나가면 그 사람과 관련된 잡기를 끝내고 기록을 지워요. 끝난 잡기 목록을 돌려줘요.
function GrabLogic.removePlayer(book: Book, userId: number, now: number, config: Config): { Grab }
	local ended: { Grab } = {}
	local own = GrabLogic.finish(book, userId, now, config)
	if own then
		table.insert(ended, own)
	end
	local grabberId = book.grabbedBy[userId]
	if grabberId ~= nil then
		local other = GrabLogic.finish(book, grabberId, now, config)
		if other then
			table.insert(ended, other)
		end
	end
	book.cooldownUntil[userId] = nil
	book.immuneUntil[userId] = nil
	return ended
end

return GrabLogic
