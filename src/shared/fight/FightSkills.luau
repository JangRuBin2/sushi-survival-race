--!strict
-- 스시 파이트 특수 스킬 (f1-02, GDD 5.1). 순수 로직.
-- 원칙: 스킬 6종은 누구나 하나 골라 쓴다(공짜). 에픽·전설 스킨은 "시그니처 스킬"의 **연출만** 다르다
-- (색·효과 종류). 수치·판정에 스킨 id는 절대 들어가지 않는다 — 테스트가 고정.
--   카탈로그:  IDS · isSkill · SIGNATURES · signatureFor · defaultSkillFor · resolveLoadout
--   스킬 게이지: newMeter · charge · tick · isReady · consume
--   판정 도우미: burstTargets · shieldGuard · dashEnd · stickySpeed · cleanse

local FightConfig = require(script.Parent.FightConfig)
local FightLogic = require(script.Parent.FightLogic)

export type SkillId = "WasabiBurst" | "NoriShield" | "SoyDash" | "RiceSticky" | "SushiSpin" | "GingerCleanse"
export type FxKind = "Fire" | "Sparkles" | "Smoke" | "Glow"

-- 스킨 시그니처: 겉모습 필드만 (skill, color, fx). 수치 필드를 넣으면 테스트가 막아요.
export type Signature = {
	skill: SkillId,
	color: { number }, -- RGB 0~255, 스킬 효과 색
	fx: FxKind, -- 스킬 효과에 붙는 파티클 종류 (SushiBody 효과 종류와 같은 이름)
}

local FightSkills = {}

FightSkills.IDS = {
	"WasabiBurst", -- 와사비 폭발: 내 주변 반경 9 안 상대를 밀어냄
	"NoriShield", -- 김 방패: 2.5초 동안 넉백 35%·게이지 50%만 받음
	"SoyDash", -- 간장 대시: 18 studs 순간 돌진, 경로 위 상대 타격, 돌진 중 무적
	"RiceSticky", -- 밥알 끈끈이: 던지는 탄, 맞은 상대 2.5초 이동 속도 절반
	"SushiSpin", -- 회전 초밥: 1.5초 회전, 반경 5 안 상대를 0.3초마다 작게 침
	"GingerCleanse", -- 초생강 입가심: 게이지 -25%, 0.6초 무적
} :: { SkillId }

local SKILL_SET: { [string]: boolean } = {}
for _, id in FightSkills.IDS do
	SKILL_SET[id] = true
end

FightSkills.DEFAULT = "WasabiBurst" :: SkillId

function FightSkills.isSkill(value: unknown): boolean
	return type(value) == "string" and SKILL_SET[value] == true
end

-- 에픽·전설 스킨 14종의 시그니처 (Skins.luau의 tier가 Epic·Legendary인 스킨 전부와 정확히 같아야 함 — 테스트)
FightSkills.SIGNATURES = {
	-- 전설
	["golden-otoro"] = { skill = "SushiSpin", color = { 255, 196, 64 }, fx = "Sparkles" }, -- 황금 회오리
	["diamond-uni"] = { skill = "NoriShield", color = { 170, 230, 255 }, fx = "Sparkles" }, -- 다이아 가시 방패
	["dragon-roll"] = { skill = "SoyDash", color = { 90, 200, 110 }, fx = "Fire" }, -- 용의 돌진
	["crown-tuna"] = { skill = "WasabiBurst", color = { 230, 60, 70 }, fx = "Glow" }, -- 왕관 충격파
	["unicorn-roll"] = { skill = "SoyDash", color = { 255, 150, 220 }, fx = "Sparkles" }, -- 무지개 돌진
	["vip-gold-tamago"] = { skill = "GingerCleanse", color = { 255, 215, 90 }, fx = "Glow" }, -- 금박 입가심
	["fresh-mackerel"] = { skill = "SushiSpin", color = { 120, 170, 210 }, fx = "Smoke" }, -- 팔딱 회오리
	-- 에픽
	["rainbow-roll"] = { skill = "RiceSticky", color = { 255, 120, 90 }, fx = "Sparkles" }, -- 무지개 밥알
	["aburi-salmon"] = { skill = "WasabiBurst", color = { 255, 120, 40 }, fx = "Fire" }, -- 불꽃 폭발
	["california-roll"] = { skill = "RiceSticky", color = { 150, 200, 90 }, fx = "Glow" }, -- 아보카도 탄
	["galaxy-roll"] = { skill = "NoriShield", color = { 130, 110, 255 }, fx = "Sparkles" }, -- 별빛 방패
	["softserve-roll"] = { skill = "GingerCleanse", color = { 255, 240, 220 }, fx = "Smoke" }, -- 아이스크림 녹이기
	["pumpkin-sushi"] = { skill = "WasabiBurst", color = { 255, 150, 30 }, fx = "Smoke" }, -- 호박 폭탄 (시즌)
	["santa-shrimp"] = { skill = "RiceSticky", color = { 235, 245, 255 }, fx = "Sparkles" }, -- 눈뭉치 (시즌)
} :: { [string]: Signature }

-- 스킨의 시그니처. 에픽·전설이 아니면 nil (기본 연출).
function FightSkills.signatureFor(skinId: unknown): Signature?
	if type(skinId) ~= "string" then
		return nil
	end
	return FightSkills.SIGNATURES[skinId]
end

-- 처음 입장했을 때 골라 둘 스킬: 시그니처가 있으면 그 스킬, 없으면 기본. 바꾸는 건 자유.
function FightSkills.defaultSkillFor(skinId: unknown): SkillId
	local sig = FightSkills.signatureFor(skinId)
	return if sig then sig.skill else FightSkills.DEFAULT
end

-- 클라이언트가 보낸 스킬 선택을 검증. 이상한 값이면 스킨 기본값.
function FightSkills.resolveLoadout(requested: unknown, skinId: unknown): SkillId
	if FightSkills.isSkill(requested) then
		return requested :: SkillId
	end
	return FightSkills.defaultSkillFor(skinId)
end

------------------------------------------------------------------------
-- 스킬 게이지
------------------------------------------------------------------------

export type Meter = { value: number }
export type ChargeReason = "DealtHit" | "TakenHit" | "Ko"

function FightSkills.newMeter(): Meter
	return { value = 0 }
end

local function add(meter: Meter, amount: number)
	meter.value = math.clamp(meter.value + amount, 0, FightConfig.Skills.Meter.Max)
end

function FightSkills.charge(meter: Meter, reason: ChargeReason)
	local m = FightConfig.Skills.Meter
	add(meter, if reason == "DealtHit" then m.DealtHit elseif reason == "TakenHit" then m.TakenHit else m.Ko)
end

-- 시간이 dt초 흐름 (가만히 있어도 참). 스킬을 쓰는 중에도 차요.
function FightSkills.tick(meter: Meter, dt: number)
	add(meter, math.max(dt, 0) * FightConfig.Skills.Meter.PerSecond)
end

function FightSkills.isReady(meter: Meter): boolean
	return meter.value >= FightConfig.Skills.Meter.Max - 1e-6
end

-- 발동: 차 있으면 0으로 돌리고 true. 덜 찼으면 아무것도 안 하고 false.
function FightSkills.consume(meter: Meter): boolean
	if not FightSkills.isReady(meter) then
		return false
	end
	meter.value = 0
	return true
end

------------------------------------------------------------------------
-- 판정 도우미 (서버가 씀)
------------------------------------------------------------------------

type Vec3 = FightLogic.Vec3

-- 와사비 폭발 대상: 나를 뺀 사람 중 수평 거리 radius 이내(경계 포함). userId 오름차순.
function FightSkills.burstTargets(userId: number, center: Vec3, positions: { [number]: Vec3 }): { number }
	local radius = FightConfig.Skills.WasabiBurst.radius
	local ids = {}
	for id, pos in positions do
		if id ~= userId then
			local dx, dz = pos.x - center.x, pos.z - center.z
			if dx * dx + dz * dz <= radius * radius + 1e-6 then
				table.insert(ids, id)
			end
		end
	end
	table.sort(ids)
	return ids
end

-- 김 방패가 켜져 있을 때 FightLogic.hit에 넘길 guard. 꺼져 있으면 nil.
function FightSkills.shieldGuard(shieldUntil: number?, now: number): FightLogic.Guard?
	if shieldUntil == nil or now >= shieldUntil - 1e-6 then
		return nil
	end
	local s = FightConfig.Skills.NoriShield
	return { gaugeMul = s.gaugeMul, knockbackMul = s.knockbackMul }
end

-- 간장 대시 도착점: 보는 방향(수평)으로 distance만큼. 방향이 없으면 제자리.
function FightSkills.dashEnd(from: Vec3, facing: Vec3): Vec3
	local length = math.sqrt(facing.x * facing.x + facing.z * facing.z)
	if length < 1e-6 then
		return { x = from.x, y = from.y, z = from.z }
	end
	local d = FightConfig.Skills.SoyDash.distance / length
	return { x = from.x + facing.x * d, y = from.y, z = from.z + facing.z * d }
end

-- 밥알 끈끈이에 맞은 사람의 이동 속도. slowUntil 전이면 slowMul을 곱함.
function FightSkills.stickySpeed(baseSpeed: number, slowUntil: number?, now: number): number
	if slowUntil ~= nil and now < slowUntil - 1e-6 then
		return baseSpeed * FightConfig.Skills.RiceSticky.slowMul
	end
	return baseSpeed
end

-- 초생강 입가심: 게이지 회복값.
function FightSkills.cleanse(gauge: number): number
	return FightLogic.applyGauge(gauge, -FightConfig.Skills.GingerCleanse.heal)
end

return FightSkills
