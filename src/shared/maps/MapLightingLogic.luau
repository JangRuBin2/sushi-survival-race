--!strict
-- 맵 조명 전환의 순수 판단 (m5-23). Roblox API 없음 — 클라이언트 MapLightingController가 써요.
--   MapLightingLogic.pickArena(pos, arenas, current?) -> string?
--       카메라 위치가 들어 있는 아레나 key. 들어갈 때는 경계 상자 + ENTER_MARGIN,
--       이미 들어가 있는 아레나(current)는 + EXIT_MARGIN까지 유지(히스테리시스 — 경계에서 깜빡이지 않게).
--       여러 개면 중심이 가장 가까운 것. 없으면 nil (= 로비 조명).
--   MapLightingLogic.blendAlpha(elapsed) -> number   0~1 (부드럽게 시작·끝)

export type Vec3 = { x: number, y: number, z: number }
-- 아레나 하나: 클라이언트가 Workspace의 맵 Model(MapDecorTags.Arena 태그)에서 판정 파츠 경계 상자로 모아요
export type Arena = { key: string, center: Vec3, size: Vec3 }

local MapLightingLogic = {}

MapLightingLogic.ENTER_MARGIN = 40
MapLightingLogic.EXIT_MARGIN = 80
-- 떨어지는 중(낙하 탈락 높이까지)에도 맵 조명이 유지되게 아래로는 더 넉넉히 봐요
MapLightingLogic.BELOW_EXTRA = 150
MapLightingLogic.BLEND_SECONDS = 1.2
MapLightingLogic.POLL_SECONDS = 0.25

local function inside(pos: Vec3, arena: Arena, margin: number): boolean
	local hx, hy, hz = arena.size.x / 2, arena.size.y / 2, arena.size.z / 2
	if math.abs(pos.x - arena.center.x) > hx + margin or math.abs(pos.z - arena.center.z) > hz + margin then
		return false
	end
	local bottom = arena.center.y - hy - margin - MapLightingLogic.BELOW_EXTRA
	local top = arena.center.y + hy + margin
	return pos.y >= bottom and pos.y <= top
end

function MapLightingLogic.pickArena(pos: Vec3, arenas: { Arena }, current: string?): string?
	if current then
		for _, arena in arenas do
			if arena.key == current and inside(pos, arena, MapLightingLogic.EXIT_MARGIN) then
				return current
			end
		end
	end
	local best: string? = nil
	local bestDistance = math.huge
	for _, arena in arenas do
		if inside(pos, arena, MapLightingLogic.ENTER_MARGIN) then
			local dx, dy, dz = pos.x - arena.center.x, pos.y - arena.center.y, pos.z - arena.center.z
			local distance = dx * dx + dy * dy + dz * dz
			if distance < bestDistance then
				best, bestDistance = arena.key, distance
			end
		end
	end
	return best
end

-- 전환 진행도 (smoothstep)
function MapLightingLogic.blendAlpha(elapsed: number): number
	local t = math.clamp(elapsed / MapLightingLogic.BLEND_SECONDS, 0, 1)
	return t * t * (3 - 2 * t)
end

return MapLightingLogic
