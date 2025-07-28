export type CurvePositions = {
	SideVector: Vector3,
	CenterPosition: Vector3,
	StartPosition: Vector3,
	EndPosition: Vector3,
	ControlPosition: Vector3,
}

local function CalculateCurvePositions(
	CameraCFrame: CFrame,
	HeightAtDistance: number,
	ITEM_DISTANCE_FROM_CAMERA: number,
	TotalWidth: number,
	Margin: number,
	CURVE_FLATNESS_FACTOR: number
): CurvePositions
	local self: { [string]: Vector3 } = {}
	self.SideVector = CameraCFrame.RightVector * (TotalWidth / 2 + Margin)
	self.CenterPosition = CameraCFrame.Position + CameraCFrame.LookVector * ITEM_DISTANCE_FROM_CAMERA
	self.StartPosition = self.CenterPosition - self.SideVector
	self.EndPosition = self.CenterPosition + self.SideVector
	self.ControlPosition = self.CenterPosition + CameraCFrame.LookVector * HeightAtDistance * CURVE_FLATNESS_FACTOR

	return self :: CurvePositions
end

local function GetHeightAtDistance(FieldOfView: number, ITEM_DISTANCE_FROM_CAMERA: number): number
	return 2 * ITEM_DISTANCE_FROM_CAMERA * math.tan(math.rad(FieldOfView) / 2)
end

local function QuadraticBezierCurve(t: number, p0: Vector3, p1: Vector3, p2: Vector3): Vector3
	return (1 - t) * (1 - t) * p0 + 2 * (1 - t) * t * p1 + t * t * p2
end

local function GetCurvePositions(
	ItemCount: number,
	ITEM_DISTANCE_FROM_CAMERA: number?,
	SCREEN_HORIZONTAL_USAGE_SCALE: number?,
	CURVE_FLATNESS_FACTOR: number?
): ({ { Vector3 } }, number)
	if not ITEM_DISTANCE_FROM_CAMERA then
		ITEM_DISTANCE_FROM_CAMERA = 1
	end

	local screenHorizontal = SCREEN_HORIZONTAL_USAGE_SCALE or 0.85
	local itemDistanceFromCamera = ITEM_DISTANCE_FROM_CAMERA or 1
	local curveFlatness = CURVE_FLATNESS_FACTOR or 1.25
	local camera: Camera = workspace.CurrentCamera
	local cameraViewportSize: Vector2 = camera.ViewportSize
	local aspectRatio: number = cameraViewportSize.X / cameraViewportSize.Y

	local heightAtDistance: number = GetHeightAtDistance(camera.FieldOfView, itemDistanceFromCamera)

	local widthAtDistance: number = heightAtDistance * aspectRatio
	local TotalWidth = widthAtDistance * (SCREEN_HORIZONTAL_USAGE_SCALE or 0.85)
	local Margin = (1 - screenHorizontal) / 2 * widthAtDistance

	local positions: { { Vector3 } } = {}
	local items: { number } = {}
	local max: number = math.ceil(math.sqrt(ItemCount))
	local center: number = max % 2 == 0 and math.ceil(max / 2) + 1 or math.ceil(max / 2)
	local column: number = center
	local last: number = 0

	for _index: number = 1, ItemCount do
		if not items[column] then
			items[column] = 0
		end

		items[column] += 1

		if items[column] == max then
			if math.abs(last) ~= last and last ~= 0 then
				last = -last
			else
				last = -last - 1
			end

			column = center + last
		end
	end

	local first: number
	last = 0

	for posColumn: number, count: number in items do
		if not first then
			first = posColumn
		end

		positions[posColumn] = {}

		local direction: number = posColumn % 2 == 0 and 1 or -1
		local pos: number = last * direction

		if direction == -1 then
			last += 1
		end

		for index: number = 1, count do
			local t: number = index / (count + 1)

			local curvePositions: CurvePositions = CalculateCurvePositions(
				camera.CFrame,
				GetHeightAtDistance(camera.FieldOfView / 2, itemDistanceFromCamera),
				itemDistanceFromCamera,
				TotalWidth,
				Margin,
				curveFlatness
			)

			local curvePosition: Vector3 = QuadraticBezierCurve(
				t,
				curvePositions.StartPosition,
				curvePositions.ControlPosition,
				curvePositions.EndPosition
			)

			if #items % 2 == 0 then
				curvePosition = curvePosition
					- 0.2 * camera.CFrame.UpVector
					+ ((1 / (math.ceil(math.sqrt(ItemCount)))) * pos * camera.CFrame.UpVector)
			else
				curvePosition = curvePosition + ((1 / (math.ceil(math.sqrt(ItemCount)))) * pos * camera.CFrame.UpVector)
			end
			table.insert(positions[posColumn], curvePosition)
		end
	end

	return positions, first
end

return GetCurvePositions
