--!strict
-- 다이브 순수 로직 (m3-06). Roblox API 없이 숫자만 다뤄서 lune으로 테스트해요.
--   canDive(input)            지금 다이브할 수 있는지
--   launch(input)             발사 속도 { vx, vy, vz }
--   begin(state, now)         Ready → Flying (발사 순간)
--   step(state, now, grounded, interrupted)   Flying → Stunned → Ready
--   groundFlightTime(up, g)   땅에서 위로 up만큼 튀었을 때 체공 시간
-- 상태: Ready → (발사) → Flying → (착지) → Stunned → Ready.
--       Flying이 MaxFlightTime 동안 착지하지 않으면 경직 없이 Ready. 끊기면(넘어짐 등) 어디서든 즉시 Ready.

local Config = require(script.Parent.Config)

local DiveLogic = {}

export type Phase = "Ready" | "Flying" | "Stunned"

export type State = {
	phase: Phase,
	phaseStart: number, -- 지금 상태에 들어간 시각
	lastDiveAt: number?, -- 마지막 다이브 시작 시각 (쿨다운 기준)
}

export type CanDiveInput = {
	hasCharacter: boolean,
	health: number,
	anchored: boolean,
	sitting: boolean,
	walkSpeed: number,
	platformStand: boolean,
	spectating: boolean, -- 카메라가 내 캐릭터를 보고 있지 않음 (관전·연출)
	state: State,
	now: number,
}

export type LaunchInput = {
	moveX: number, -- Humanoid.MoveDirection 수평 성분
	moveZ: number,
	lookX: number, -- 캐릭터가 바라보는 방향 수평 성분
	lookZ: number,
	walkSpeed: number,
	grounded: boolean,
	jumpPower: number,
	vy: number, -- 지금 수직 속도
}

export type Velocity = { vx: number, vy: number, vz: number }

-- 0.1초 같은 경계값이 부동소수점 오차로 어긋나지 않게
local EPSILON = 1e-6

-- 발사 직후에는 아직 땅에 붙어 있으니 착지로 치지 않아요
DiveLogic.LandingGrace = 0.1

-- 이동 입력이 이보다 짧으면 바라보는 방향으로 날아가요
DiveLogic.MoveDeadZone = 0.1

function DiveLogic.newState(): State
	return { phase = "Ready", phaseStart = 0, lastDiveAt = nil }
end

local function elapsed(since: number, now: number, duration: number): boolean
	return now - since + EPSILON >= duration
end

function DiveLogic.cooldownLeft(state: State, now: number): number
	if state.lastDiveAt == nil then
		return 0
	end
	return math.max(0, Config.Dive.Cooldown - (now - state.lastDiveAt))
end

function DiveLogic.canDive(input: CanDiveInput): boolean
	if not input.hasCharacter or input.health <= 0 then
		return false
	end
	if input.anchored or input.sitting or input.platformStand or input.spectating then
		return false
	end
	if input.walkSpeed <= 0 then
		return false
	end
	local state = input.state
	if state.phase ~= "Ready" then
		return false
	end
	if state.lastDiveAt ~= nil and not elapsed(state.lastDiveAt, input.now, Config.Dive.Cooldown) then
		return false
	end
	return true
end

function DiveLogic.launch(input: LaunchInput): Velocity
	local dx, dz = input.moveX, input.moveZ
	local length = math.sqrt(dx * dx + dz * dz)
	if length <= DiveLogic.MoveDeadZone then
		dx, dz = input.lookX, input.lookZ
		length = math.sqrt(dx * dx + dz * dz)
	end
	if length <= EPSILON then
		-- 바라보는 방향도 수평 성분이 없으면 (거의 없음) 앞(-Z)으로
		dx, dz, length = 0, -1, 1
	end
	dx, dz = dx / length, dz / length

	local speedScale = math.clamp(input.walkSpeed / Config.Character.WalkSpeed, 0, 1)
	local speed = Config.Dive.ForwardSpeed * speedScale

	local vy
	if input.grounded then
		vy = if input.jumpPower > 0 then Config.Dive.UpSpeed else 0
	else
		vy = input.vy
	end

	return { vx = dx * speed, vy = vy, vz = dz * speed }
end

-- 발사 순간. 이전 상태와 관계없이 Flying으로 (canDive로 먼저 확인해요)
function DiveLogic.begin(_state: State, now: number): State
	return { phase = "Flying", phaseStart = now, lastDiveAt = now }
end

function DiveLogic.step(state: State, now: number, grounded: boolean, interrupted: boolean): State
	if state.phase == "Ready" then
		return state
	end
	if interrupted then
		return { phase = "Ready", phaseStart = now, lastDiveAt = state.lastDiveAt }
	end
	if state.phase == "Flying" then
		if grounded and elapsed(state.phaseStart, now, DiveLogic.LandingGrace) then
			return { phase = "Stunned", phaseStart = now, lastDiveAt = state.lastDiveAt }
		end
		if elapsed(state.phaseStart, now, Config.Dive.MaxFlightTime) then
			return { phase = "Ready", phaseStart = now, lastDiveAt = state.lastDiveAt }
		end
		return state
	end
	-- Stunned
	if elapsed(state.phaseStart, now, Config.Dive.LandingStun) then
		return { phase = "Ready", phaseStart = now, lastDiveAt = state.lastDiveAt }
	end
	return state
end

function DiveLogic.groundFlightTime(upSpeed: number, gravity: number): number
	if upSpeed <= 0 or gravity <= 0 then
		return 0
	end
	return 2 * upSpeed / gravity
end

return DiveLogic
