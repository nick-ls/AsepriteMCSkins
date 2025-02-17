local Q = {}
Q.__index = Q

function Q.new(x, y, z, w)
    return setmetatable({ x = x, y = y, z = z, w = w }, Q)
end

function Q:multiply(q)
    return Q.new(
        self.w * q.x + self.x * q.w + self.y * q.z - self.z * q.y,
        self.w * q.y - self.x * q.z + self.y * q.w + self.z * q.x,
        self.w * q.z + self.x * q.y - self.y * q.x + self.z * q.w,
        self.w * q.w - self.x * q.x - self.y * q.y - self.z * q.z
    )
end

function Q:toMatrix()
    local x, y, z, w = self.x, self.y, self.z, self.w
    return {
        1 - 2 * (y * y + z * z), 2 * (x * y - w * z), 2 * (x * z + w * y),
        2 * (x * y + w * z), 1 - 2 * (x * x + z * z), 2 * (y * z - w * x),
        2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y)
    }
end

function Q.fromAxisAngle(axis, angle)
    local halfAngle = angle / 2
    local s = math.sin(halfAngle)
    return Q.new(axis[1] * s, axis[2] * s, axis[3] * s, math.cos(halfAngle))
end

function applyOrbitRotation(prevQ, deltaX, deltaY, sensitivity)
    sensitivity = sensitivity or 1
    local xAxis = {1, 0, 0}
    local yAxis = {0, 1, 0}

    local qX = Q.fromAxisAngle(xAxis, deltaY * sensitivity)
    local qY = Q.fromAxisAngle(yAxis, deltaX * sensitivity)

    return qY:multiply(prevQ):multiply(qX)
end