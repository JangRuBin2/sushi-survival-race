--!strict
-- Final 맵 "회전 꼬치 쇼다운" (GDD 5.2 ⑥, 생존형 결승). 지금은 stub(떨어지면 탈락하는 회색 바닥)이에요.
-- 실제 원형 무대·꼬치·셰프 손은 m2-04가 이 파일을 덮어써서 만들어요.

local StubMap = require(script.Parent.StubMap)

return StubMap.create({
	id = "skewer-showdown",
	kind = "Final",
	displayName = "회전 꼬치 쇼다운",
	rule = "돌아오는 꼬치를 뛰어넘고 끝까지 버티세요! 마지막 1명만 탈출해요",
})
