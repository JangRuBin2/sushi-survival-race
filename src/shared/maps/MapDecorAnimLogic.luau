--!strict
-- 움직이는 장식의 순수 계산 (m5-23). Roblox API 없음.
-- DecorSpec.anim = { kind, period, amount, axis? } → MapKit.buildDecor가 태그(MapDecorTags.Anim)와 속성을 달고,
-- 클라이언트 MapDecorFxController가 매 프레임 offset으로 로컬 위치·각도·크기만 얹어요(서버 값은 그대로).
--   kind "Spin"  : 축(axis, 기본 Y)으로 period초에 한 바퀴. amount는 무시
--   kind "Bob"   : 축(기본 Y) 방향으로 ±amount studs 오르내림 (amount ≤ 4)
--   kind "Sway"  : 축(기본 Z)으로 ±amount도 흔들림 (amount ≤ 20)
--   kind "Pulse" : 크기가 1 ± amount 배로 숨 쉬듯 (amount ≤ 0.15). 붙은 조명 밝기도 같이
--   MapDecorAnimLogic.validate(anim) -> string?
--   MapDecorAnimLogic.offset(kind, period, amount, axis, t, phase) -> Offset
--   MapDecorAnimLogic.phaseOf(x, y, z) -> number   파츠 위치로 정하는 0~1 위상 (모든 플레이어에게 같음)

export type Axis = "X" | "Y" | "Z"
export type Kind = "Spin" | "Bob" | "Sway" | "Pulse"
export type AnimSpec = { kind: Kind, period: number, amount: number, axis: Axis? }

-- 로컬(파츠 기준) 오프셋: 이동 studs, 회전 라디안(X·Y·Z 순서), 크기 배율
export type Offset = { dx: number, dy: number, dz: number, rx: number, ry: number, rz: number, scale: number }

local MapDecorAnimLogic = {}

MapDecorAnimLogic.KINDS = { "Spin", "Bob", "Sway", "Pulse" }
MapDecorAnimLogic.AXES = { "X", "Y", "Z" }
MapDecorAnimLogic.PERIOD_MIN = 0.5
MapDecorAnimLogic.PERIOD_MAX = 60
MapDecorAnimLogic.MAX_AMOUNT = { Spin = math.huge, Bob = 4, Sway = 20, Pulse = 0.15 } :: { [string]: number }
MapDecorAnimLogic.DEFAULT_AXIS = { Spin = "Y", Bob = "Y", Sway = "Z", Pulse = "Y" } :: { [string]: Axis }

local function isNumber(v: any): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

function MapDecorAnimLogic.validate(anim: any): string?
	if type(anim) ~= "table" then
		return "anim must be a table"
	end
	if not table.find(MapDecorAnimLogic.KINDS, anim.kind) then
		return `anim.kind must be Spin, Bob, Sway or Pulse (got {tostring(anim.kind)})`
	end
	if
		not isNumber(anim.period)
		or anim.period < MapDecorAnimLogic.PERIOD_MIN
		or anim.period > MapDecorAnimLogic.PERIOD_MAX
	then
		return `anim.period must be {MapDecorAnimLogic.PERIOD_MIN}~{MapDecorAnimLogic.PERIOD_MAX}`
	end
	if anim.kind ~= "Spin" then
		local max = MapDecorAnimLogic.MAX_AMOUNT[anim.kind]
		if not isNumber(anim.amount) or anim.amount < 0 or anim.amount > max then
			return `anim.amount for {anim.kind} must be 0~{max}`
		end
	elseif anim.amount ~= nil and not isNumber(anim.amount) then
		return "anim.amount must be a number"
	end
	if anim.axis ~= nil and not table.find(MapDecorAnimLogic.AXES, anim.axis) then
		return "anim.axis must be X, Y or Z"
	end
	return nil
end

-- t: 시각(초, 서버 시간), phase: 0~1
function MapDecorAnimLogic.offset(
	kind: string,
	period: number,
	amount: number,
	axis: string?,
	t: number,
	phase: number
): Offset
	local out: Offset = { dx = 0, dy = 0, dz = 0, rx = 0, ry = 0, rz = 0, scale = 1 }
	local a = axis or MapDecorAnimLogic.DEFAULT_AXIS[kind] or "Y"
	local cycle = ((t / period) + phase) % 1
	local wave = math.sin(cycle * 2 * math.pi)
	if kind == "Spin" then
		local angle = cycle * 2 * math.pi
		if a == "X" then
			out.rx = angle
		elseif a == "Z" then
			out.rz = angle
		else
			out.ry = angle
		end
	elseif kind == "Bob" then
		local d = wave * amount
		if a == "X" then
			out.dx = d
		elseif a == "Z" then
			out.dz = d
		else
			out.dy = d
		end
	elseif kind == "Sway" then
		local angle = math.rad(wave * amount)
		if a == "X" then
			out.rx = angle
		elseif a == "Y" then
			out.ry = angle
		else
			out.rz = angle
		end
	elseif kind == "Pulse" then
		out.scale = 1 + wave * amount
	end
	return out
end

-- 파츠 위치로 정하는 위상 (같은 장식이면 모든 클라이언트에서 같은 값)
function MapDecorAnimLogic.phaseOf(x: number, y: number, z: number): number
	local h = math.sin(math.floor(x * 10) * 12.9898 + math.floor(y * 10) * 78.233 + math.floor(z * 10) * 37.719)
		* 43758.5453
	return h - math.floor(h)
end

return MapDecorAnimLogic
