local npc = {}
local id = NPC_ID

local npcManager = require("npcManager")
local npcutils = require("npcs/npcutils")

npcManager.setNpcSettings({
	id = id,
	
	width = 256,
	gfxwidth = 256,
	height = 256,
	gfxheight = 256,
	
	jumphurt = true,
	
	frames = 4,
	framespeed = 4,
	framestyle = 1,
	
	nogravity = true,
	noblockcollision = true,
	
	noyoshi = true,
})

function npc.onInitAPI()
	npcManager.registerEvent(id, npc, 'onTickEndNPC')
	npcManager.registerEvent(id, npc, 'onCameraDrawNPC')
	registerEvent(npc, 'onPostNPCKill')
end

local drawNPC = npcutils.drawNPC

local CHASE = 0
local DIE = 1

local function is_framestyle2(v)
	return (v:mem(0x12C, FIELD_WORD) > 0 or v:mem(0x136, FIELD_BOOL))
end

local function drawEye(v, sourceX)
	local config = NPC.config[v.id]
	local data = v.data._basegame
	
	drawNPC(v, {
		frame = config.frames,
		sourceX = sourceX,
		applyFrameStyle = false,
	})	
	
	--tear
	drawNPC(v, {
		frame = config.frames + 1,
		yOffset = data.tearOffset,
		sourceX = sourceX,
		applyFrameStyle = false,
	})	
	
	--eye
	drawNPC(v, {
		frame = config.frames + 2,
		sourceX = sourceX,
		applyFrameStyle = false,
	})	
end

function npc.onPostNPCKill(v, r)
	if v.id ~= id then return end
	
	if r ~= 9 then
		local e = Effect.spawn(764, v.x, v.y)
		e.direction = v.direction
	end
end

local floor = math.floor

function npc.onCameraDrawNPC(v)
	if v.despawnTimer <= 0 then return end
	
	local config = NPC.config[v.id]
	local texture = Graphics.sprites.npc[id].img

	local frame = v.animationFrame
	local sourceX = (v.direction == 1 and config.gfxwidth) or 0
	
	if config.framestyle > 0 and v.direction == 1 then
		frame = v.animationFrame - config.frames
	end
	
	if config.framestyle == 2 and is_framestyle2(v) then
		frame = v.animationFrame - (config.frames * 2)
		sourceX = sourceX + (config.gfxwidth * 2)
	end
	
	if config.framestyle > 0 and v.ai1 == CHASE then
		drawNPC(v, {
			frame = frame,
			sourceX = sourceX,
			applyFrameStyle = false,
		})
	elseif v.ai1 == DIE then
		drawEye(v, sourceX)
	end
	
	npcutils.hideNPC(v)
end

local function outBounce(t, b, c, d)
  t = t / d
  if t < 1 / 2.75 then
    return c * (7.5625 * t * t) + b
  elseif t < 2 / 2.75 then
    t = t - (1.5 / 2.75)
    return c * (7.5625 * t * t + 0.75) + b
  elseif t < 2.5 / 2.75 then
    t = t - (2.25 / 2.75)
    return c * (7.5625 * t * t + 0.9375) + b
  else
    t = t - (2.625 / 2.75)
    return c * (7.5625 * t * t + 0.984375) + b
  end
end

function npc.onTickEndNPC(v)
	if Defines.levelFreeze then return end
	
	local data = v.data._basegame
	
	if not data.spawned and v.despawnTimer > 0 then
		data.spawned = true
	elseif data.spawned and v.despawnTimer <= 0 then
		local despawn = true
		
		for k,p in ipairs(Player.get()) do
			if p.section == v.section and p.deathTimer == 0 then
				despawn = false
				break
			end
		end
		
		if not despawn then
			v.despawnTimer = 180
		else
			data.spawned = nil
		end
	end

	v.animationTimer = v.animationTimer + math.abs(v.speedX * 0.16)
	
	if not data.blockId then
		data.blockId = v.ai2
		data.timer = 0
	end
	
	local config = NPC.config[v.id]
	
	local p = Player.getNearest(v.x + v.width / 2, v.y + v.height / 2)
	
	if v.ai1 == CHASE then
		if v.direction == 1 then
			local distance = (p.x - p.width) - (v.x + v.width)
			
			v.speedX = (distance / 12) + 3
			
			v.speedX = math.clamp(v.speedX, 0, 6)
		else
			local distance = (p.x - p.width) - v.x
			
			v.speedX = ((distance / 12) + 3)
			
			v.speedX = math.clamp(v.speedX, -6, 0)
		end
	
		for k,b in Block.iterateIntersecting(v.x, v.y, v.x + v.width, v.y + v.height) do
			local c = Block.config[b.id]
			
			local invis1 = v:mem(0x5A, FIELD_WORD)
			local invis2 = v.isHidden
			
			if c.id == data.blockId then
				Defines.earthquake = 8
				v.speedX = 0
				v.ai1 = DIE
				data.timer = 0
				data.tearOffset = -40
				v.friendly = true
				
				return
			end
			
			if c.smashable and not invis2 and invis1 >= 0 then
				b:remove(true)
			end
		end
	else
		data.timer = data.timer + 0.0075
		
		data.timer = math.clamp(data.timer, 0, 1)
		data.tearOffset = outBounce(data.timer, -40, 40, 1)
		
		if data.timer >= 1 then
			data.dieTimer = data.dieTimer or 0
			data.dieTimer = data.dieTimer + 1
			
			if data.dieTimer > 64 then
				v:kill(3)
				SFX.play('falling_chomp.wav')		
			end
		end
	end
end

return npc