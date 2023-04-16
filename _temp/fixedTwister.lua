local npcManager = require("npcManager")
local thwomps = require("npcs/ai/thwomps")
local beetle = require("npcs/ai/busterbeetle")
local springs = require("npcs/ai/springs")
local npc = {}
local npcID = NPC_ID

springs.blacklist(npcID, springs.TYPE.UP)
springs.blacklist(npcID, springs.TYPE.SIDE)

local tableinsert = table.insert
local tableremove = table.remove

local JUMP_NONE = 0
local JUMP_NORMAL = 1
local JUMP_SPIN = 2

local blacklist = {}
local whitelist = {}

npcManager.setNpcSettings({
	id = npcID,
	
	frames = 8,
	framespeed = 4,
	
	jumphurt = true,
	nohurt = true,
	cliffturn = true,
	iswalker=true,
	nowalldeath=true,
	
	windstrength = 1,
	windwidth = 96,
	windheight = 150,
	penaltyperweight = 10,
	maxspeed = 6,
	playerboostmaxspeed = 10,
	playerboosttimer = 12,
	effectid = 288,
	harmlessgrab = true,
	harmlessthrown = true,
	forcejump = JUMP_NORMAL,
	boostplayer = true,
	boostnpc = true,
})

function npc.onInitAPI()
	npcManager.registerEvent(npcID, npc, 'onTickNPC')
	npcManager.registerEvent(npcID, npc, 'onTickEndNPC')
end

npcManager.registerHarmTypes(npcID,
	{HARM_TYPE_NPC, HARM_TYPE_LAVA},
	{[HARM_TYPE_NPC] = 287,
	[HARM_TYPE_LAVA] = 287
})

thwomps.registerNPCInteraction(npcID)

beetle.registerSpecialHandling(npcID, function(v)
	v.data._basegame.friendly = false
	v.friendly = true
	v.y = v.y - 14
end)

function npc.blacklist(id)
	blacklist[id] = true
end

npc.blacklist(197) -- Doesn't have iscollectablegoal set?

function npc.whitelist(id)
	whitelist[id] = true
end

local function npcFilter(n)
	local cfg = NPC.config[n.id]
	if whitelist[n.id] then
		return true
	end

	if blacklist[n.id]
	or (cfg.iscoin and n.ai1 <= 0) 
	or cfg.iscollectablegoal
	or n.isHidden
	or n.despawnTimer <= 0
	or cfg.nogravity
	or n.isGenerator then
		return false
	end
	return true
end

local function hoverNPC(v, n)
	local cfg = NPC.config[n.id]
	local cfgv = NPC.config[v.id]

	local weightMinus = cfg.weight * cfgv.penaltyperweight
	if cfg.weight > 0 then
		if n.y + n.height < v.y - (cfgv.windheight - weightMinus) then
			return
		end
	end

	local speed = cfgv.windstrength
	local distToBottom = math.clamp(1-((v.y-(n.y + n.height)) / (cfgv.windheight)), 0, 1)
	
	if n.speedY > 0 then
		speed = speed * (0.2 + 0.8 * distToBottom)
	end

	if n.id == 427 then -- Megan interaction
		n.speedY = n.speedY - speed
	else
		n.speedY = math.clamp(n.speedY - speed, -cfgv.maxspeed + 0.1 * Defines.gravity * (weightMinus)/cfgv.windheight, Defines.gravity) - Defines.npc_grav
	end

	local cxa, cxb = v.x + 0.5 * v.width, n.x + 0.5 * n.width

	local force = (cxa - cxb) * 0.05 + v.speedX
	n.speedX = force
	n.data._basegame._twisterforce = force

	tableinsert(v.data._basegame.npcs, n)
end

local function hoverPlayer(v, n)
	local cfgv = NPC.config[v.id]

	if forcejump == 1 then
		n:mem(0x50, FIELD_BOOL, false)
	elseif forcejump == 2 then
		n:mem(0x50, FIELD_BOOL, true)
	end

	local speed = cfgv.windstrength
	local maxSpeed = -cfgv.maxspeed

	local data = v.data._basegame
	local playerBoosts = data.playerBoosts

	local distToBottom = math.clamp(1-((v.y-(n.y + n.height)) / (cfgv.windheight)), 0, 1)

	if playerBoosts[n.idx] then
		playerBoosts[n.idx] = playerBoosts[n.idx] - 1
		speed = speed * 2 + -maxSpeed * ((cfgv.playerboosttimer-playerBoosts[n.idx])/cfgv.playerboosttimer)

		maxSpeed = -cfgv.playerboostmaxspeed
		if playerBoosts[n.idx] <= 0 then
			playerBoosts[n.idx] = nil
		end
	else
		if n.speedY > 0 then
			speed = speed * (0.2 + 0.8 * distToBottom)
		end
		if n.keys.jump == KEYS_PRESSED or n.keys.altJump == KEYS_PRESSED then
			playerBoosts[n.idx] = cfgv.playerboosttimer
			speed = speed + cfgv.windstrength * 2
			maxSpeed = -cfgv.playerboostmaxspeed
		end
	end

	n.speedY = math.clamp(n.speedY - speed, maxSpeed, Defines.gravity) - Defines.player_grav

	if n:mem(0x14A, FIELD_WORD) > 0 then
		n.speedY = -Defines.player_grav + 0.1
	end
	
	local cxa, cxb = v.x + 0.5 * v.width, n.x + 0.5 * n.width
	local force = (cxa - cxb) * 0.05 + v.speedX
	local absSpeed = math.max(math.abs(force), math.abs(n.speedX))
	n.speedX = math.lerp(n.speedX, math.clamp(n.speedX * 0.5 + force, -absSpeed, absSpeed), 0.025 + distToBottom * 0.125)
end

function npc.onTickEndNPC(v)
	if Defines.levelFreeze then return end

	local data = v.data._basegame
	if not data.initialized then
		return 
	end

	if data.friendly then return end


	for i=#data.npcs, 1, -1 do
		local n = data.npcs[i]
		if n and n.isValid then
			-- n.speedX = n.speedX - n.data._basegame._twisterforce
			n.data._basegame._twisterforce = 0
		end
		tableremove(data.npcs, i)
	end
end

function npc.onTickNPC(v)
	if Defines.levelFreeze then return end

	local data = v.data._basegame

	if v.despawnTimer <= 0 then
		data.initialized = false
		return
	end

	if v:mem(0x138, FIELD_WORD) > 0 then
		return
	end

	local config = NPC.config[v.id]

	if not data.initialized then
		data.effectList = {}
		data.playerBoosts = {}
		data.npcs = {}
		data.initialized = true
		data.lastX = v.x
		data.lastY = v.y
		data.collider = data.collider or Colliders.Tri(0, 0, {0, 16}, {-0.5*config.windwidth, -config.windheight - v.height}, {0.5*config.windwidth, -config.windheight - v.height})
	end

	if data.friendly == nil and v:mem(0x12C, FIELD_WORD) == 0 then
		data.friendly = v.friendly
		v.friendly = true
	end

	if not data.friendly then
		data.collider.x = v.x + 0.5 * v.width
		data.collider.y = v.y + v.height
	
		local held = v:mem(0x12C, FIELD_WORD)

		if config.boostnpc and held >= 0 then
			for k,n in ipairs(Colliders.getColliding{a = data.collider, btype = Colliders.NPC, filter = npcFilter}) do
				if n.id ~= v.id then
					hoverNPC(v, n)
				end
			end
		end
		
		if config.boostplayer and held <= 0 then
			for k,n in ipairs(Player.get()) do
				if Colliders.collide(n, data.collider) then
					hoverPlayer(v, n)
				else
					data.playerBoosts[n.idx] = nil
				end
			end
		end
		
		if lunatime.tick() % 8 == 0 then
			local e = Effect.spawn(config.effectid, v.x + v.width / 2 - 4, v.y + 0.5 * v.height)
			e.speedY = -config.windstrength * 1.5
			e.lifetime = (config.windheight + 64) / math.abs(e.speedY)
			tableinsert(data.effectList, e)
		end

		for i=#data.effectList, 1, -1 do
			local e = data.effectList[i]
			if (e) then
				e.x = e.x + v.x - data.lastX
				e.y = e.y + v.y - data.lastY
			else
				tableremove(effectList, i)
			end
		end
		data.lastX = v.x
		data.lastY = v.y
	end

end

return npc