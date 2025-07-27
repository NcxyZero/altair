local HapticService = game:GetService("HapticService")

return function(duration: number?): ()
	local motorToUse: Enum.VibrationMotor = HapticService:IsMotorSupported(
		Enum.UserInputType.Gamepad1,
		Enum.VibrationMotor.Small
	) and Enum.VibrationMotor.Small or Enum.VibrationMotor.Large

	HapticService:SetMotor(Enum.UserInputType.Gamepad1, motorToUse, 1)

	task.delay(duration or 1 / 30, function(): ()
		HapticService:SetMotor(Enum.UserInputType.Gamepad1, motorToUse, 0)
	end)
end
