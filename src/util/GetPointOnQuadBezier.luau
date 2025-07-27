return function(t: number, p0: Vector3, p1: Vector3, p2: Vector3): Vector3
	return (1 - t) ^ 2 * p0 + 2 * (1 - t) * t * p1 + t ^ 2 * p2
end
