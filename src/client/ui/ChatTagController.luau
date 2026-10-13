--!strict
-- 채팅 태그 [VIP] (m5-08). 보낸 사람의 Player 속성 Attributes.Vip(서버 OfferService가 달아요)이 true면 채팅 줄 앞에
-- 금색 "[VIP] "를 붙여요 (기존 접두어 앞). 화면 표시만 — 권한·판정과 무관해요.
-- TextChatService.ChatVersion이 TextChatService(새 채팅)일 때만 동작해요. 예전 채팅(LegacyChatService)이면 아무것도 안 해요.
-- TextChatService.OnIncomingMessage는 콜백 하나뿐이라 여기 한 곳에서만 정해요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Attributes = require(ReplicatedStorage.Shared.Attributes)

local ChatTagController = {}

local VIP_TAG = `<font color="#FFD24A">[VIP]</font> `

function ChatTagController.start(_gui: Instance)
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		return
	end
	TextChatService.OnIncomingMessage = function(message: TextChatMessage): TextChatMessageProperties?
		local source = message.TextSource
		if source == nil then
			return nil
		end
		local player = Players:GetPlayerByUserId(source.UserId)
		if player == nil or player:GetAttribute(Attributes.Vip) ~= true then
			return nil
		end
		local properties = Instance.new("TextChatMessageProperties")
		properties.PrefixText = VIP_TAG .. message.PrefixText
		return properties
	end
end

return ChatTagController
