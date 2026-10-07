--!strict
-- 맵 풀. 새 맵은 이 폴더에 모듈을 만들고 ALL에 추가하면 라운드 구성에 바로 들어가요.

local Config = require(script.Parent.Config)
local MapTypes = require(script.MapTypes)
local Rules = require(script.Parent.Rules)

local ALL: { MapTypes.MapModule } = {
	require(script.RotatingBelt),
	require(script.SoySwamp),
	require(script.HotPlate),
	require(script.SkewerShowdown),
}

local byId: { [string]: MapTypes.MapModule } = {}
local infos: { Rules.MapInfo } = {}
for _, map in ALL do
	local problem = MapTypes.validate(map)
	assert(problem == nil, problem)
	assert(not byId[map.id], `duplicate map id {map.id}`)
	byId[map.id] = map
	table.insert(infos, { id = map.id, kind = map.kind })
end

local Maps = {}

function Maps.get(id: string): MapTypes.MapModule
	return assert(byId[id], `unknown map {id}`)
end

-- Rules.buildRoundPlan에 넘길 맵 풀
function Maps.infos(): { Rules.MapInfo }
	return infos
end

function Maps.timeLimit(map: MapTypes.MapModule): number
	return map.timeLimit or Config.TimeLimit[map.kind]
end

return Maps
