local function inverseLerp(a: number, b: number, x: number): number
	return (x - a) / (b - a)
end

return inverseLerp
