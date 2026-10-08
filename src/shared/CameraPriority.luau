--!strict
-- 카메라 요청 중 누가 카메라를 쓸지 고르는 순수 함수 (CameraDirector가 써요).
-- 우선순위가 가장 높은 요청이 이기고, 같은 우선순위면 목록에서 뒤에 있는(나중에 요청한) 쪽이 이겨요.

local CameraPriority = {}

export type Request = {
	owner: string,
	priority: number,
}

function CameraPriority.pick(requests: { Request }): string?
	local best: Request? = nil
	for _, request in requests do
		if best == nil or request.priority >= best.priority then
			best = request
		end
	end
	return if best then best.owner else nil
end

return CameraPriority
