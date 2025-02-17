function script_path()
	local str = debug.getinfo(2, "S").source:sub(2)
	str = str:gsub("\\", "/")
	return str:match("(.*/)") or "."
end

-- Initialize variables required for functions.
local _ = script_path()

local cube = { 128, 128, 128 }

local blockPreview = false

local spin = 0
local scale = 1

local dialog = Dialog("Block Preview")

if (dialog == nil) then
	error("Couldn't initialize, can't create dialog")
	return
end

function math.round(number) return math.floor(number + 0.5); end

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

function makeCube(x, y, z)
	x = x * scale
	y = y * scale
	z = z * scale
	return { { (x / 2) * -1, (y / 2) * -1, (z / 2) * -1 },
		{ (x / 2) * 1, (y / 2) * -1, (z / 2) * -1 },
		{ (x / 2) * 1, (y / 2) * 1, (z / 2) * -1 },
		{ (x / 2) * -1, (y / 2) * 1, (z / 2) * -1 },
		{ (x / 2) * -1, (y / 2) * -1, (z / 2) * 1 },
		{ (x / 2) * 1, (y / 2) * -1, (z / 2) * 1 },
		{ (x / 2) * 1, (y / 2) * 1, (z / 2) * 1 },
		{ (x / 2) * -1, (y / 2) * 1, (z / 2) * 1 } }
end

local block = makeCube(cube[1], cube[2], cube[3])

function calcPixel(points, canvas, x, y)
	return { 
		(points[1][1] + (((points[2][1] - points[1][1]) / canvas.width) * x) + ((points[3][1] - points[1][1]) / canvas.height) * y),
		(points[1][2] + (((points[3][2] - points[1][2]) / canvas.height) * y) + ((points[2][2] - points[1][2]) / canvas.width) * x)
	}
end

function onPaint(ev)
	local connect_points = { { { 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 1 } },
		{ { 5, 1 }, { 1, 4 }, { 4, 8 }, { 8, 5 } },
		{ { 4, 3 }, { 3, 7 }, { 7, 8 }, { 8, 4 } },
		{ { 6, 5 }, { 5, 8 }, { 8, 7 }, { 7, 6 } },
		{ { 5, 6 }, { 6, 2 }, { 2, 1 }, { 1, 5 } },
		{ { 2, 6 }, { 6, 7 }, { 7, 3 }, { 3, 2 } } }

	local colors = { Color(255, 0, 0, 64), Color(0, 255, 0, 64), Color(0, 0, 255, 64), Color(255, 255, 0, 64),
		Color(0, 255, 255, 64), Color(255, 0, 255, 64) }

	local ctx = ev.context

	local outline = dialog.data.outline

	local cx = ctx.width / 2
	local cy = ctx.height / 2

	ctx.antialias = dialog.data.antialias

	ctx.color = dialog.data.backgroundColor
	ctx:fillRect(Rectangle(0, 0, ctx.width, ctx.height))
	local remap = {}
	local recolors = {}

	local numbers = { "1", "2", "3", "4", "5", "6" }

	local numCoords = {}
	local numString = {}

	-- Cheap backface culling + face information + scaling
	for i, face in ipairs(connect_points) do

		local x = 0.0
		local y = 0.0
		local z = 0.0
		for n, edges in ipairs(face) do
			x = x + block[edges[1]][1]
			y = y + block[edges[1]][2]
			z = z + block[edges[1]][3]
		end
		x = x/#face
		y = y/#face
		z = z/#face

		if z <0 then
			remap[#remap+1] = face
			recolors[#recolors+1] = colors[i]

			numCoords[#numCoords+1] = {x, y, z}
			numString[#numString+1] = numbers[i]
		end
			
	end

	-- Outline script
	if outline > 0 then
		for i, face in ipairs(remap) do
			ctx:beginPath()
			ctx.strokeWidth = outline
			for n, edges in ipairs(face) do
				ctx:moveTo(block[edges[1]][1] + cx, block[edges[1]][2] + cy)
				ctx:lineTo(block[edges[2]][1] + cx, block[edges[2]][2] + cy)
			end
			ctx:stroke()
		end
		ctx:beginPath()
		for i, point in ipairs(block) do
			ctx:roundedRect(
			Rectangle((point[1] - (outline / 2) + 0.5) + cx, (point[2] - (outline / 2) + 0.5) +
			cy, outline, outline), outline, outline)
		end
		ctx:fill()
	end

	local canvas = Image(app.sprite.width, app.sprite.height)
	canvas:drawSprite(app.sprite, app.frame.frameNumber)
	ctx.strokeWidth = 0
	for pixel in canvas:pixels() do
		ctx.color = Color(app.pixelColor.rgbaR(pixel()), app.pixelColor.rgbaG(pixel()),
			app.pixelColor.rgbaB(pixel()), app.pixelColor.rgbaA(pixel()))
		for i, face in ipairs(remap) do
			ctx:beginPath()

			local pixelXY = {}
			local points = { block[face[1][1]], block[face[2][1]], block[face[4][1]] }

			pixelXY = calcPixel(points, canvas, pixel.x, pixel.y)
			ctx:moveTo(pixelXY[1] + cx, pixelXY[2] + cy)
			pixelXY = calcPixel(points, canvas, pixel.x + 1, pixel.y)
			ctx:lineTo(pixelXY[1] + cx, pixelXY[2] + cy)
			pixelXY = calcPixel(points, canvas, pixel.x + 1, pixel.y + 1)
			ctx:lineTo(pixelXY[1] + cx, pixelXY[2] + cy)
			pixelXY = calcPixel(points, canvas, pixel.x, pixel.y + 1)
			ctx:lineTo(pixelXY[1] + cx, pixelXY[2] + cy)

			ctx:closePath()
			ctx:fill()
			if dialog.data.antialias then
				ctx:stroke()
			end
		end
	end
end


function onClick()
	blockPreview = true
	block = makeCube(cube[1], cube[2], cube[3])

	local drag = 0

	spin = 0
	scale = 1
	quat = Q.new(0, 0, 0, 1);

	applyOrbitRotation(quat, math.pi / 4, math.pi / 6)

	dialog
		:canvas {
			id = "canvas",
			width = 256,
			height = 256,
			onpaint = onPaint,
			onmousedown = function(ev)
				drag = 1
				spin = 0
				px = ev.x
				py = ev.y
			end,
			onmouseup = function(ev)
				drag = 0
				spin = dialog.data.spin
			end,
			onwheel = function(ev)
				scale = math.max(0.1, scale - (ev.deltaY / 10))
				block = makeCube(cube[1], cube[2], cube[3])
				rotate3D(block, pitch * math.pi / 180, 0, 0)
				rotate3D(block, 0, 0, roll * math.pi / 180)
				dialog:repaint()
			end,
			onmousemove = function(ev)
				if drag == 1 then
					block = makeCube(cube[1], cube[2], cube[3])
					rotate3D(block, pitch * math.pi / 180, 0, 0)
					rotate3D(block, 0, 0, roll * math.pi / 180)
					dialog:repaint()
					px = ev.x
					py = ev.y
				end
			end
		}
		:color {
			id = "outlineColor",
			color = app.fgColor,
			onchange = function()
				dialog:repaint()
			end,
			visible = false
		}
		:color {
			id = "backgroundColor",
			color = app.bgColor,
			onchange = function()
				dialog:repaint()
			end
		}
		:slider {
			id = "outline",
			min = 0,
			max = 10,
			value = 0,
			onchange = function()
				dialog:repaint()
			end,
			visible = false
		}
		:newrow()
		:slider {
			id = "spin",
			min = -10,
			max = 10,
			value = 0,
			onchange = function()
				spin = dialog.data.spin
				dialog:repaint()
			end
		}
		:check {
			id = "antialias",
			text = "Antialias",
			selected = false,
			onclick = function()
				dialog:repaint()
			end
		}
		:slider {
			id = "x",
			min = 16,
			max = 256,
			value = cube[1],
			onchange = function()
				cube[1] = dialog.data.x
				block = makeCube(cube[1], cube[2], cube[3])
				rotate3D(block, pitch * math.pi / 180, 0, 0)
				rotate3D(block, 0, 0, roll * math.pi / 180)
				dialog:repaint()
			end,
			visible = false
		}
		:slider {
			id = "y",
			min = 16,
			max = 256,
			value = cube[2],
			onchange = function()
				cube[2] = dialog.data.y
				block = makeCube(cube[1], cube[2], cube[3])
				rotate3D(block, pitch * math.pi / 180, 0, 0)
				rotate3D(block, 0, 0, roll * math.pi / 180)
				dialog:repaint()
			end,
			visible = false
		}
		:slider {
			id = "z",
			min = 16,
			max = 256,
			value = cube[3],
			onchange = function()
				cube[3] = dialog.data.z
				block = makeCube(cube[1], cube[2], cube[3])
				rotate3D(block, pitch * math.pi / 180, 0, 0)
				rotate3D(block, 0, 0, roll * math.pi / 180)
				dialog:repaint()
			end,
			visible = false
		}
		:button {
			text = "Reset",
			onclick = function()
				pitch = 45
				roll = 30
				scale = 1
				cube = { 128, 128, 128 }
				block = makeCube(cube[1], cube[2], cube[3])
				rotate3D(block, pitch * math.pi / 180, 0, 0)
				rotate3D(block, 0, 0, roll * math.pi / 180)
				dialog:repaint()
				dialog:modify { id = "x", value = cube[1] }
				dialog:modify { id = "y", value = cube[2] }
				dialog:modify { id = "z", value = cube[3] }
			end
		}
		:button { text = "Cancel" }
	dialog:show { wait = false }
end

function init(plugin)
	plugin:newCommand {
		id = "block",
		title = "Block Preview",
		group = "view_canvas_helpers",
		onenabled = function()
			return app.cel ~= nil and app.sprite.width < 64 and app.sprite.height < 64
		end,
		onclick = onClick
	}
end

local _ = onClick();

Timer {
	interval = 0.01,
	ontick = function()
		if blockPreview then
			pitch = (pitch - (spin / 8)) % 360
			block = makeCube(cube[1], cube[2], cube[3])
			rotate3D(block, pitch * math.pi / 180, 0, 0)
			rotate3D(block, 0, 0, roll * math.pi / 180)
			dialog:repaint()
		end
	end
}:start()
