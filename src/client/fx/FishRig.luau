--!strict
-- 물고기 관절 묶음 (m5-32, 클라이언트 로컬 연출). 초밥 Model에서 관절 이름(CharacterAnimLogic.FISH_JOINTS:
-- FishRoot·FishMid·FishTail·FishFinL·FishFinR·Splash1~4)으로 Motor6D(SushiBody.PART_JOINT_NAME)를 찾아요 — 스킨 id는 몰라요.
-- 관절 속성: "Pivot"(경첩, Body 좌표), "Reach"(물방울이 splash 1일 때 옮겨 가는 거리). SushiBody.build가 달아요.
--   FishRig.find(model) -> Rig?         FishRoot 관절이 없으면 nil (고등어가 아닌 스킨은 아무것도 안 해요)
--   FishRig.deltas(rig, motion, scale?) -> { [name]: CFrame }   관절별 Body 축 움직임 D (경첩을 중심으로 돌고 옮김)
--   FishRig.applyTransforms(rig, motion)   Motor6D.Transform = F⁻¹ · D · F (F = 관절 파츠의 쉰 자리, Body 기준).
--                                          사슬이라 부모 움직임은 Roblox가 이어 붙여요 (CharacterFxController)
--   FishRig.reset(rig)                    모든 Transform = identity
-- 계산은 SushiPose.posed(순수, 테스트 AC4)와 같은 규칙이에요: 관절 파츠 = 부모 · 자기 D · 쉰 자리.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterAnimLogic = require(ReplicatedStorage.Shared.CharacterAnimLogic)
local SushiBody = require(ReplicatedStorage.Shared.SushiBody)

local FishRig = {}

export type Joint = {
	name: string,
	motor: Motor6D,
	part: BasePart,
	parent: string?, -- 관절 사슬 부모 이름 (Body면 nil)
	rest: CFrame, -- 관절 파츠의 쉰 자리 (Body 기준)
	pivot: Vector3, -- 경첩 (Body 기준)
	reach: Vector3?,
}

export type Rig = {
	model: Instance,
	body: BasePart,
	joints: { Joint }, -- 부모가 먼저 (FISH_JOINTS 순서)
	byName: { [string]: Joint },
}

export type Motion = CharacterAnimLogic.FishMotion

local function partJoint(model: Instance, name: string): (BasePart?, Motor6D?)
	local part = model:FindFirstChild(name)
	if part == nil or not part:IsA("BasePart") then
		return nil, nil
	end
	local motor = part:FindFirstChild(SushiBody.PART_JOINT_NAME)
	if motor == nil or not motor:IsA("Motor6D") then
		return nil, nil
	end
	return part, motor
end

function FishRig.find(model: Instance): Rig?
	local rootPart, rootMotor = partJoint(model, "FishRoot")
	if rootPart == nil or rootMotor == nil then
		return nil
	end
	local body = rootMotor.Part0
	if body == nil then
		return nil
	end
	local rig: Rig = { model = model, body = body, joints = {}, byName = {} }
	for _, name in CharacterAnimLogic.FISH_JOINTS do
		local part, motor = partJoint(model, name)
		if part and motor and motor.Part0 then
			local parentPart = motor.Part0 :: BasePart
			local parentJoint = if parentPart == body then nil else rig.byName[parentPart.Name]
			-- 쉰 자리: 부모의 쉰 자리 · C0 · C1⁻¹ (Transform 무시 — 이미 움직이는 중이어도 같아요)
			local parentRest = if parentJoint then parentJoint.rest else CFrame.identity
			local rest = parentRest * motor.C0 * motor.C1:Inverse()
			local pivot = motor:GetAttribute("Pivot")
			local reach = motor:GetAttribute("Reach")
			local joint: Joint = {
				name = name,
				motor = motor,
				part = part,
				parent = if parentJoint then parentJoint.name else nil,
				rest = rest,
				pivot = if typeof(pivot) == "Vector3" then pivot else rest.Position,
				reach = if typeof(reach) == "Vector3" then reach else nil,
			}
			table.insert(rig.joints, joint)
			rig.byName[name] = joint
		end
	end
	return rig
end

-- 관절 하나의 Body 축 움직임 (scale = 인형 크기 배율, 경첩·이동에 곱해요)
local function delta(joint: Joint, motion: Motion?, scale: number): CFrame
	if motion == nil then
		return CFrame.identity
	end
	local move = motion.move
	local m = if move then Vector3.new(move[1], move[2], move[3]) else Vector3.zero
	local k = motion.reach or 0
	if joint.reach and k ~= 0 then
		m += joint.reach * k
	end
	local a = motion.angles
	local p = joint.pivot * scale
	if a == nil then
		return CFrame.new(m * scale)
	end
	return CFrame.new(m * scale + p) * CFrame.Angles(a[1], a[2], a[3]) * CFrame.new(-p)
end

function FishRig.deltas(rig: Rig, motion: { [string]: Motion }, scale: number?): { [string]: CFrame }
	local s = scale or 1
	local out: { [string]: CFrame } = {}
	for _, joint in rig.joints do
		out[joint.name] = delta(joint, motion[joint.name], s)
	end
	return out
end

function FishRig.applyTransforms(rig: Rig, motion: { [string]: Motion })
	for _, joint in rig.joints do
		local d = delta(joint, motion[joint.name], 1)
		joint.motor.Transform = joint.rest:Inverse() * d * joint.rest
	end
end

function FishRig.reset(rig: Rig?)
	if rig == nil then
		return
	end
	for _, joint in rig.joints do
		joint.motor.Transform = CFrame.identity
	end
end

return FishRig
