local npcutils = require("npcs/npcutils")

local npc = {}
local id = NPC_ID
local settings = {
	id = id,
	
	width = 64,
	height = 64,
	gfxwidth = 64,
	gfxheight = 64,
	
	frames = 12, -- Directional frames
	walkframes = 4, -- Walk frames
	hurtframes = 4, -- Hurt frames
	-- Layout as such:
	-- Walk -> Lift (2) -> Grab left (1) -> Grab right (1) -> Hurt
	-- For higher frame styles, all frames get duplicated
	framespeed = 6,
	hurtframespeed = 4,
	
	jumphurt = true,
	spinjumpsafe = true,
	luahandlesspeed = true,
	noiceball = true,
	noyoshi= true,
	
	grabCheckTime = 45,
	picktime = 32,
	holdtime = 32,
	readytime = 32,
	hurttime = 64,
	
	speed = 2,
	cliffturn = true,
	
	grabsfx = 23,
	
	throwsfx = 25,
	throwspeedx = 6.5,
	throwspeedy1 = -7,
	throwspeedy2 = -3.5,
	throwid = id + 1,
	
	hp = 5,
	score = 0,
	weight = 2,
	
	effect = 751,
}

local WALKING = 0
local PICKING = 1
local HOLDING = 2
local READY = 3
local HURT = 4

local function init(v)
	local data = v.data._basegame
	
	if not data.init then
		if v.friendly then
			data.friendly = true
		end

		data.grabdirection = v.direction
		data.nextWalkDirection = v.direction
		data.heldNPC = nil

		data.throwspeeds = data.throwspeeds or {}
		local cfg = NPC.config[v.id]

		if #data.throwspeeds == 0 then
			local i = 1
			local throwspeed = NPC.config[v.id]["throwspeedy" .. i]
			while throwspeed ~= nil do
				table.insert(data.throwspeeds, throwspeed)
				i = i + 1
				throwspeed = NPC.config[v.id]["throwspeedy" .. i]
			end
		end

		if #data.throwspeeds == 0 then
			table.insert(data.throwspeeds, -2)
		end
		
		data.hp = NPC.config[id].hp
		data.time = 0
		data.state = WALKING
		
		data.frametimer = 0
		
		data.init = true
	end
end

local function animation(v)
	local data = v.data._basegame
	
	local config = NPC.config[id]
	
	local walkframes = config.walkframes
	local hurtframes = config.hurtframes

	local framespeed = (data.state == HURT and config.hurtframespeed) or config.framespeed
	
	data.frametimer = data.frametimer + 1

	local frame = math.floor(data.frametimer / framespeed)

	if data.state == PICKING then
		frame = (data.grabdirection == -1 and config.walkframes + 2) or config.walkframes + 3
	elseif data.state == HOLDING or not v.collidesBlockBottom then
		frame = config.walkframes
	elseif data.state == READY then
		frame = config.walkframes + 1
	elseif data.state == HURT then
		frame = (frame % hurtframes) + config.walkframes + 4
	else
		frame = frame % walkframes
	end

	if config.framestyle >= 1 then
		if v.direction == 1 then
			frame = frame + config.frames
		end

		if config.framestyle >= 2 and (v:mem(0x12C, FIELD_WORD) ~= 0 or v:mem(0x136, FIELD_BOOL)) then
			frame = frame + 2 * config.frames
		end
	end
	
	v.animationFrame = frame
	v.animationTimer = 0
end

local function grabableNPCFilter(v)
    if v.isGenerator or v.friendly or v.despawnTimer <= 0 or v:mem(0x138,FIELD_WORD) > 0 or v:mem(0x136, FIELD_BOOL) or v:mem(0x12C, FIELD_WORD) > 0 then
        return false
    end

    if v.id == id then
        return false
    end

    local config = NPC.config[v.id]

    if config.grabside or config.grabtop then
        return true
    end

    return false
end

local function detach(v)
	if v.data._basegame.heldNPC and v.data._basegame.heldNPC.isValid then
		local heldNPC = v.data._basegame.heldNPC
		if heldNPC:mem(0x12C, FIELD_WORD) < 0 then
			heldNPC:mem(0x12C, FIELD_WORD, 0)
		end
		heldNPC.data._basegame.parent = nil
	end
	v.data._basegame.heldNPC = nil
end

local function throw(v)
	local config = NPC.config[id]
	SFX.play(config.throwsfx)

	local rock = v.data._basegame.heldNPC

	if rock and rock.isValid then		
		local p = Player.getNearest(v.x + v.width / 2, v.y + v.height / 2)
		
		if p.x + 0.5 * p.width < v.x + 0.5 * v.width then
			rock.direction = -1
		else
			rock.direction = 1
		end
		
		v.speedY = -2
		rock.speedX = config.throwspeedx * rock.direction
		rock.speedY = RNG.irandomEntry(v.data._basegame.throwspeeds)
		rock.layerName = "Spawned NPCs"
		rock.y = v.y - rock.height - 12
		rock:mem(0x136, FIELD_BOOL, true)
		rock.despawnTimer = 100
		detach(v)
	end
	v.direction = v.data._basegame.nextWalkDirection
end

local function setState(v, data, state, time, newState, f)
	if data.state == state then
		if time > 0 and data.time >= time then
			if f then
				f(v)
			end
			
			data.state = newState
			data.frametimer = 0
			data.time = 0
		end
	end
end

local function playGrabSound(v)
	SFX.play(NPC.config[v.id].grabsfx)
end

local function die(v)
	local data = v.data._basegame
	if data.hp <= 0 then
		if v.legacyBoss then
			local ball = NPC.spawn(41, v.x + 0.5 * v.width, v.y + 0.5 * v.height, v.section, false, true)
			ball.spawnX = 0
			ball.spawnY = 0
			ball.spawnWidth = 0
			ball.spawnHeight = 0
			ball.speedY = -6
			
			SFX.play(41)
		end
		v:kill(3)
	end
end

function npc.onTickEndNPC(v)
	if Defines.levelFreeze or v.despawnTimer <= 0 then return end
	
	local config = NPC.config[id]
	local data = v.data._basegame
	init(v)
	
	if v:mem(0x12C, FIELD_WORD) > 0    --Grabbed
	or v:mem(0x136, FIELD_BOOL)        --Thrown
	or v:mem(0x138, FIELD_WORD) > 0    --Contained within
	then
		if v:mem(0x138, FIELD_WORD) ~= 8 then
			v.animationFrame = 0
		end
		
		return
	end
	
	if v.despawnTimer > 1 and v.legacyBoss then
		v.despawnTimer = 100
		
		local section = Section(v.section)
		
		if section.musicID ~= 6 and section.musicID ~= 15 and section.musicID ~= 21 then
			Audio.MusicChange(v.section, 15)
		end
	end
	
	if not data.friendly then
		v.friendly = (data.state == HURT)
	end

	if v.collidesBlockBottom then
		
		if (data.time > 0 or RNG.random() > 0.5) and data.state == WALKING and (v:mem(0x120, FIELD_BOOL) or data.time % config.grabCheckTime == 0) then
			data.nextWalkDirection = v.direction
			if v:mem(0x120, FIELD_BOOL) then
				data.nextWalkDirection = -v.direction
			end
			local offset = 24
			
			local x = v.x - offset
			local y = v.y
			local w = x + v.width + 2 * offset
			local h = y + v.height + 2

			local candidate = nil
			local oldDist = 999999

			local preferredDirection = data.nextWalkDirection
			
			for _, npc in NPC.iterateIntersecting(x, y, w, h) do
				if grabableNPCFilter(npc) then
					local dist = (npc.x + 0.5 * npc.width) - (v.x + 0.5 * v.width)
					local distSign = math.sign(dist)
					local sameDir = distSign == data.nextWalkDirection
					local oldSameDir = math.sign(oldDist) == data.nextWalkDirection
					dist = math.abs(dist)
					
					if candidate == nil or ((sameDir and ((oldSameDir and dist < oldDist) or not oldSameDir)) or (not oldSameDir and not sameDir and dist < oldDist)) then
						oldDist = dist
						candidate = npc
						data.grabdirection = distSign
						data.heldNPC = npc
					end
				end
			end
			
			if candidate ~= nil then

				if candidate.id == 91 then
					candidate:transform(candidate.ai1)
				end
				SFX.play(config.grabsfx)
				local parent = data.heldNPC.data._basegame.parent
				
				if parent ~= nil and parent.isValid then
					parent.data.heldNPC = nil
				end
				data.heldNPC.data._basegame.parent = v
				data.state = PICKING
				data.frametimer = 0
				data.time = 0
				
				v.speedX = 0
			end
		end
		data.time = data.time + 1
	end

	if data.heldNPC and data.heldNPC.isValid and data.heldNPC.data._basegame.parent == v then
		local n = data.heldNPC
		local held = n:mem(0x12C, FIELD_WORD)
		if held > 0 then
			detach(v)
		else
			n.x = v.x + 0.5 * v.width - 0.5 * n.width
			n.y = v.y + v.height - n.height
	
			if data.state == PICKING then
				n.x = n.x + (0.5 * v.width + 0.5 * n.width) * data.grabdirection
				n:mem(0x12C, FIELD_WORD, -1)
				n.y = n.y - 4
			elseif data.state == HOLDING then
				n:mem(0x12C, FIELD_WORD, -1)
				n.y = n.y - 4
			elseif data.state == READY then
				n.y = n.y - v.height - 16 * math.max(0, math.sin(math.min(data.time * 0.2, 4)))
				n:mem(0x12C, FIELD_WORD, 0)
				n.speedX = 0
				n.speedY = -Defines.npc_grav
			end
		end
	end
	
	if v.collidesBlockBottom and data.state == WALKING then
		v.speedX = config.speed * v.direction
	else
		v.speedX = 0
	end
	
	setState(v, data, PICKING, config.picktime, HOLDING)
	setState(v, data, HOLDING, config.holdtime, READY)
	if v.friendly and data.state == READY then
		setState(v, data, READY, 0, WALKING)
		if data.heldNPC and data.heldNPC.isValid then
			if data.heldNPC.data._basegame.parent ~= v then
				data.state = WALKING
				data.frametimer = 0
				data.time = 0
			end
		else
			data.state = WALKING
			data.frametimer = 0
			data.time = 0
		end
	else
		setState(v, data, READY, config.readytime, WALKING, throw)
	end
	setState(v, data, HURT, config.hurttime, WALKING, die)

	animation(v)
end

function npc.onDrawNPC(v)
	if v.despawnTimer <= 0 then return end

	local p = -45.01
	if NPC.config[v.id].foreground then
		p = -15.01
	end

	npcutils.drawNPC(v, {
		priority = p
	})
	npcutils.hideNPC(v)
end

function npc.onNPCHarm(e, v, r, o)
	if v.id ~= id then return end
	
	if r == 9 or r == HARM_TYPE_LAVA then return end
	
	local data = v.data._basegame
	local hp = data.hp
	
	if data.state ~= HURT then
		SFX.play(39)
		detach(v)
		
		if (r == HARM_TYPE_NPC and o and o.id ~= 13) or r == HARM_TYPE_HELD or r == HARM_TYPE_PROJECTILE_USED or r == HARM_TYPE_SWORD then
			data.time = 0
			data.state = HURT
			data.hp = data.hp - 1
			data.frametimer = 0
		elseif (r == HARM_TYPE_NPC and o and o.id == 13) then
			data.hp = data.hp - 0.25	
		end
	end
		
	e.cancelled = true
end

function npc.onInitAPI()
	local nm = require 'npcManager'
	
	nm.setNpcSettings(settings)
	nm.registerHarmTypes(id,
		{
			HARM_TYPE_NPC,
			HARM_TYPE_HELD,
			HARM_TYPE_PROJECTILE_USED,
			HARM_TYPE_SWORD,
			HARM_TYPE_LAVA
		},
		{
			[HARM_TYPE_NPC] = 295,
			[HARM_TYPE_HELD] = 295,
			[HARM_TYPE_PROJECTILE_USED] = 295,
			[HARM_TYPE_SWORD] = 295,
			[HARM_TYPE_LAVA]={id=13, xoffset=0.5, xoffsetBack = 0, yoffset=1, yoffsetBack = 1.5}
		}
	);

	nm.registerEvent(id, npc, 'onDrawNPC')
	nm.registerEvent(id, npc, 'onTickEndNPC')
	registerEvent(npc, 'onNPCHarm')
end

return npc