--!strict
-- 상품 상점 서비스 (m5-08). m5-03 껍데기: 리모트 핸들러만 "준비 중이에요"로 걸어 둬요.
--   RequestOfferPurchase(offerId)  상품(묶음·연출) 결제 창 열기
--   EquipFx(slot, fxId?)            연출 입기·벗기 (Shared.FxCatalog, 프로필 ownedFx/equippedFx)
-- m5-08이 이 파일을 채워요 (VIP 확인 → DataService.setViewExtra, Player 속성 Vip·EliminationFx·VictoryFx).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local OfferService = {}

local function notReady(): (boolean, string?)
	return false, "준비 중이에요"
end

function OfferService.init()
	Remotes.fn("RequestOfferPurchase").OnServerInvoke = notReady
	Remotes.fn("EquipFx").OnServerInvoke = notReady
end

function OfferService.start() end

return OfferService
