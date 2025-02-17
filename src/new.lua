require "quaternions"

local dialog = Dialog("Minecraft Skin Preview")

if (dialog == nil) then
	error("Couldn't initialize, can't create dialog")
	return
end

function onClick()
	dialog
	:canvas {
		id = "canvas",
		width = 1000,
		height = 1000,
		onpaint = function(ev) end,
		onmousedown = function(ev) end,
		onmouseup = function(ev) end,
		onwheel = function(ev) end,
		onmousemove = function(ev) end
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
	:button {
		text = "Reset",
		onclick = function()
			
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
		onclick = onClick
	}
end

local _ = onClick();
