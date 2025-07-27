local RunService = game:GetService("RunService")

return function(strenght: number, duration: number): ()
	local camera: Camera = workspace.CurrentCamera
	local originalCameraCFrame: CFrame = camera.CFrame

	local shakeDuration: number = duration / 10
	local shakeMagnitude: number = strenght
	local startTime: number = tick()

	while tick() - startTime < shakeDuration do
		local elapsed = tick() - startTime
		local intensity = shakeMagnitude * (1 - elapsed / shakeDuration)

		local offset: Vector3 =
			Vector3.new(math.noise(elapsed * 10, 0) * intensity, math.noise(0, elapsed * 10) * intensity, 0)

		camera.CFrame = originalCameraCFrame * CFrame.new(offset)

		RunService.RenderStepped:Wait()
	end

	camera.CFrame = originalCameraCFrame
end
