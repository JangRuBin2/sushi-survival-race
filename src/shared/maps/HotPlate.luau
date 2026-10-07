--!strict
-- Survival 맵 "뜨거운 철판" (GDD 5.2 ⑤). 지금은 stub(떨어지면 탈락하는 회색 바닥)이에요.
-- 실제 층·HotTile 타일은 m2-03이 이 파일을 덮어써서 만들어요.

local StubMap = require(script.Parent.StubMap)

return StubMap.create({
	id = "hot-plate",
	kind = "Survival",
	displayName = "뜨거운 철판",
	rule = "밟은 철판은 곧 사라져요. 계속 움직여서 끝까지 버티세요!",
})
