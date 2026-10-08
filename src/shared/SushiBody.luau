--!strict
-- 초밥 캐릭터 몸 (껍데기, m3-02가 채워요).
--   layout(appearanceId)  파츠 목록 (순수 함수, lune 테스트 가능). 지금은 빈 목록.
--   build(appearanceId)   PrimaryPart `Body`가 있는 Model. 지금은 회색 박스 1개.
-- 연출(m3-03 탈락, m3-05 우승)이 build로 "인형"을 만들어요.

local SushiBody = {}

-- 파츠 하나. 모양은 m3-02가 정해요.
export type PartSpec = {
	name: string,
}

-- 모듈 맨 위에서는 Roblox 자료형(Vector3 등)을 쓰지 않아요 — lune 테스트가 layout만 불러요.
local PLACEHOLDER_SIZE = { 2.4, 4, 1.8 }

function SushiBody.layout(_appearanceId: string): { PartSpec }
	return {}
end

function SushiBody.build(appearanceId: string): Model
	local model = Instance.new("Model")
	model.Name = `SushiBody_{appearanceId}`

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(PLACEHOLDER_SIZE[1], PLACEHOLDER_SIZE[2], PLACEHOLDER_SIZE[3])
	body.Color = Color3.fromRGB(163, 162, 165)
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.Parent = model

	model.PrimaryPart = body
	return model
end

return SushiBody
