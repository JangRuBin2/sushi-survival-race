--!strict
-- 서버 이동 감시의 순수 판정 (m4-10). Roblox API 없이 lune으로 테스트해요.
--   check(prev, cur, exemptUntil, cfg)   직전 정상 위치(prev)에서 지금(cur)까지 움직임 → "ok" | "exempt" | "violation"
--       수평 거리 > MaxHorizontalSpeed × dt + Slack 이거나, 위로 > MaxRiseSpeed × dt + Slack 이면 위반.
--       아래로 떨어지는 건 보지 않아요 (낙하는 탈락 판정이 처리).
--       exemptUntil이 cur.t보다 뒤면(서버가 옮기거나 튕긴 직후) 검사하지 않고 "exempt".
--       dt는 MaxGap까지만 써요 (오래 서 있다가 순간이동하면 허용 거리가 끝없이 커지지 않게).
--   advance(prev, cur, verdict)          다음 비교 기준(정상 위치)
--       ok·exempt → cur. 단 거의 안 움직였으면(복제가 잠깐 멈춤) prev 시각을 StallGrace까지 유지해요 —
--       멈췄던 복제가 한꺼번에 따라잡을 때 짧은 dt로 재서 오탐이 나지 않게.
--       violation → prev 위치로 되돌렸으니 prev 위치 + cur 시각.
--   allowPass(lastViolationAt, now, cfg)  마지막 위반이 PassBlockAfterViolation 안이면 false
--   strikeLog(strikes, alreadyLogged, cfg?)  이번 위반에서 서버 경고를 찍을지 (라운드당 한 번)

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
MovementGuardLogic.StallGrace = 1.0

function MovementGuardLogic.check(prev: Sample, cur: Sample, exemptUntil: number?, cfg: GuardConfig): Verdict
	if exemptUntil ~= nil and exemptUntil > cur.t then
		return "exempt"
	end
	local dt = math.clamp(cur.t - prev.t, 0, MovementGuardLogic.MaxGap)
	local dx = cur.x - prev.x
	local dz = cur.z - prev.z
	local horizontal = math.sqrt(dx * dx + dz * dz)
	if horizontal > cfg.MaxHorizontalSpeed * dt + cfg.Slack then
		return "violation"
	end
	local rise = cur.y - prev.y
	if rise > cfg.MaxRiseSpeed * dt + cfg.Slack then
		return "violation"
	end
	return "ok"
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

return MovementGuardLogic
