--!strict
-- 맵 풀. 새 맵은 이 폴더에 모듈을 만들고 ALL에 추가하면 라운드 구성에 바로 들어가요.
-- 모듈이 inPool = false면 랜덤 판(Maps.infos)에서 빠지고 Maps.get·강제 플랜(Maps.allInfos)으로만 돌아요 (m5-03).

local Config = require(script.Parent.Config)
local MapTypes = require(script.MapTypes)
local Rules = require(script.Parent.Rules)

local ALL: { MapTypes.MapModule } = {
	require(script.RotatingBelt),
	require(script.SoySwamp),
	require(script.RamenRapids), -- m4-01 stub → m4-04
	require(script.HotPlate),
	require(script.ChefBoard), -- m4-01 stub → m4-05
	require(script.SkewerShowdown),
	require(script.IkuraBombs), -- m5-03 껍데기 → m5-04 (inPool = false)
	require(script.TempuraPot), -- m5-03 껍데기 → m5-05 (inPool = false)
	require(script.DessertFridge), -- m5-03 껍데기 → m5-06 (inPool = false)
}

local byId: { [string]: MapTypes.MapModule } = {}
local infos: { Rules.MapInfo } = {} -- 랜덤 판 풀 (inPool ~= false)
local allInfos: { Rules.MapInfo } = {} -- 모든 맵 (강제 플랜용)
for _, map in ALL do
	local problem = MapTypes.validate(map)
	assert(problem == nil, problem)
	assert(not byId[map.id], `duplicate map id {map.id}`)
	byId[map.id] = map
	local info: Rules.MapInfo = { id = map.id, kind = map.kind }
	table.insert(allInfos, info)
	if map.inPool ~= false then
		table.insert(infos, info)
	end
end

local Maps = {}

function Maps.get(id: string): MapTypes.MapModule
	return assert(byId[id], `unknown map {id}`)
end

-- Rules.buildRoundPlan에 넘길 맵 풀 (inPool = false인 껍데기는 빠져요)
function Maps.infos(): { Rules.MapInfo }
	return infos
end

-- 모든 맵 (껍데기 포함). Rules.resolveForcedPlan(Config.DEBUG.forceMapPlan)에 넘겨요
function Maps.allInfos(): { Rules.MapInfo }
	return allInfos
end

function Maps.timeLimit(map: MapTypes.MapModule): number
	return map.timeLimit or (Config.TimeLimit :: { [string]: number })[map.kind]
end

return Maps
