--!strict
-- 서버 이동 감시의 순수 판정 (m4-10). Roblox API 없이 lune으로 테스트해요.
--   check(prev, cur, exemptUntil, cfg)   직전 정상 위치(prev)에서 지금(cur)까지 움직임 → "ok" | "exempt" | "violation"
--       수평 거리 > MaxHorizontalSpeed × dt + Slack 이거나, 위로 > MaxRiseSpeed × dt + Slack 이면 위반.
--       아래로 떨어지는 건 보지 않아요 (낙하는 탈락 판정이 처리).
--       exemptUntil이 cur.t보다 뒤면(서버가 튕기거나 미는 중) 넉넉한 상한(ExemptMaxHorizontalSpeed·ExemptMaxRiseSpeed)만
--       보고 "exempt". 그것도 넘으면 면제 중이어도 "violation" (m4-10 QA B1: 면제 중 순간이동·속도 조작).
--       dt는 MaxGap까지만 써요 (오래 서 있다가 순간이동하면 허용 거리가 끝없이 커지지 않게).
--   advance(prev, cur, verdict)          다음 비교 기준(정상 위치)
--       ok·exempt → cur. 단 거의 안 움직였으면(복제가 잠깐 멈춤) prev 시각을 StallGrace까지 유지해요 —
--       멈췄던 복제가 한꺼번에 따라잡을 때 짧은 dt로 재서 오탐이 나지 않게.
--       violation → prev 위치로 되돌렸으니 prev 위치 + cur 시각.
--   allowPass(lastViolationAt, now, cfg)  마지막 위반이 PassBlockAfterViolation 안이면 false
--   strikeLog(strikes, alreadyLogged, cfg?)  이번 위반에서 서버 경고를 찍을지 (라운드당 한 번)
--   countsStrike(t, settleUntil)          되돌린 직후 RevertSettle 안의 위반은 세지 않아요 (지연 때문에 옛 위치가
--       계속 도착하는 것, m4-10 QA B5). 되돌리기는 계속 해요.

local Config = require(script.Parent.Config)

local MovementGuardLogic = {}

export type Sample = { x: number, y: number, z: number, t: number }
export type Verdict = "ok" | "exempt" | "violation"
export type GuardConfig = {
	MaxHorizontalSpeed: number,
	MaxRiseSpeed: number,
	Slack: number,
	PassBlockAfterViolation: number,
	StrikesToLog: number,
}

-- check에서 쓰는 dt의 상한(초). 그보다 오래 걸린 샘플도 이 시간만큼만 허용해요.
MovementGuardLogic.MaxGap = 1.0
-- 이 거리(studs) 안이면 "안 움직임"으로 보고 기준 시각을 유지해요.
MovementGuardLogic.StillDistance = 0.05
-- 안 움직이는 동안 기준 시각을 유지하는 최대 시간(초). 넘으면 시각을 새로 잡아요.
MovementGuardLogic.StallGrace = 0.5
-- 면제(MoveExemptUntil) 중에도 넘으면 위반인 상한 (studs/s). 서버가 주는 가장 큰 충격은 칼 넉백 수평 45,
-- 와사비 위 80이에요. 0.2초 샘플이면 수평 32 / 위 46 studs.
MovementGuardLogic.ExemptMaxHorizontalSpeed = 130
MovementGuardLogic.ExemptMaxRiseSpeed = 200
-- 되돌린(또는 스폰에 배치한) 뒤 이 시간(초) 안의 위반은 횟수·통과 막기에 세지 않아요 (되돌리기는 해요).
MovementGuardLogic.RevertSettle = 0.5

function MovementGuardLogic.check(prev: Sample, cur: Sample, exemptUntil: number?, cfg: GuardConfig): Verdict
	local exempt = exemptUntil ~= nil and exemptUntil > cur.t
	local maxHorizontal = if exempt then MovementGuardLogic.ExemptMaxHorizontalSpeed else cfg.MaxHorizontalSpeed
	local maxRise = if exempt then MovementGuardLogic.ExemptMaxRiseSpeed else cfg.MaxRiseSpeed
	local dt = math.clamp(cur.t - prev.t, 0, MovementGuardLogic.MaxGap)
	local dx = cur.x - prev.x
	local dz = cur.z - prev.z
	local horizontal = math.sqrt(dx * dx + dz * dz)
	if horizontal > maxHorizontal * dt + cfg.Slack then
		return "violation"
	end
	local rise = cur.y - prev.y
	if rise > maxRise * dt + cfg.Slack then
		return "violation"
	end
	return if exempt then "exempt" else "ok"
end

function MovementGuardLogic.advance(prev: Sample, cur: Sample, verdict: Verdict): Sample
	if verdict == "violation" then
		return { x = prev.x, y = prev.y, z = prev.z, t = cur.t }
	end
	if verdict == "ok" then
		local dx, dy, dz = cur.x - prev.x, cur.y - prev.y, cur.z - prev.z
		local still = dx * dx + dy * dy + dz * dz <= MovementGuardLogic.StillDistance ^ 2
		if still and cur.t - prev.t < MovementGuardLogic.StallGrace then
			return prev
		end
	end
	return { x = cur.x, y = cur.y, z = cur.z, t = cur.t }
end

function MovementGuardLogic.allowPass(lastViolationAt: number?, now: number, cfg: GuardConfig): boolean
	if lastViolationAt == nil then
		return true
	end
	return now - lastViolationAt >= cfg.PassBlockAfterViolation
end

function MovementGuardLogic.strikeLog(strikes: number, alreadyLogged: boolean, cfg: GuardConfig?): boolean
	local threshold = (cfg or Config.MovementGuard).StrikesToLog
	return not alreadyLogged and strikes >= threshold
end

-- 결승선 통과를 받을지: 감시 기록(배치 때 생김)이 없거나, 통과 순간 재검사가 위반이거나, 마지막 위반이
-- PassBlockAfterViolation 안이면 false (m4-10 QA B2).
function MovementGuardLogic.passDecision(
	hasTrack: boolean,
	violatedNow: boolean,
	lastViolationAt: number?,
	now: number,
	cfg: GuardConfig
): boolean
	if not hasTrack or violatedNow then
		return false
	end
	return MovementGuardLogic.allowPass(lastViolationAt, now, cfg)
end

function MovementGuardLogic.countsStrike(t: number, settleUntil: number?): boolean
	return settleUntil == nil or t >= settleUntil
end

return MovementGuardLogic
