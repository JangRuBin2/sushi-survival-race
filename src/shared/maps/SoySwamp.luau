--!strict
-- Race 맵 "간장 늪 & 와사비 산" (GDD 5.2 ②). 지금은 stub(곧은 회색 길 + 결승선)이에요.
-- 실제 코스·장애물은 m2-02가 이 파일을 덮어써서 만들어요.

local StubMap = require(script.Parent.StubMap)

return StubMap.create({
	id = "soy-swamp",
	kind = "Race",
	displayName = "간장 늪 & 와사비 산",
	rule = "간장 웅덩이는 피하고, 와사비 패드로 튀어 올라 결승선까지!",
})
