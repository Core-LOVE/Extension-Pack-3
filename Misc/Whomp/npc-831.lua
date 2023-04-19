local npcManager = require("npcManager")
local npc = {}
local id = NPC_ID

npcManager.setNpcSettings({
	id = id,
	
	width=41,
	gfxwidth=82,
	height = 88,
	gfxheight = 88,
	
	jumphurt = true,
	nohurt = true,
	
	noyoshi = true,
	nofireball = true,
	noiceball = true,
	
	cliffturn = true,
	
	frames = 2,
	framestyle = 1,
})

function npc.onInitAPI()
	local harmTypes = {
		[HARM_TYPE_HELD] = 781,
		[HARM_TYPE_NPC] = 781,
		[HARM_TYPE_LAVA] = 10
	}

	npcManager.registerHarmTypes(id, table.unmap(harmTypes), harmTypes)
	npcManager.registerEvent(id, npc, 'onTickEndNPC')
end

function npc.onTickEndNPC(v)
	if Defines.levelFreeze then return end
	
	if v:mem(0x12C, FIELD_WORD) > 0    --Grabbed
	or v:mem(0x136, FIELD_BOOL)        --Thrown
	or v:mem(0x138, FIELD_WORD) > 0    --Contained within
	then
		if v:mem(0x136, FIELD_BOOL) and v.speedX ~= 0 then
			v.speedX = v.speedX - (0.06 * v.direction) 
		end
		
		return
	end
	
	local data = v.data._basegame
	local cfg = NPC.config[id]
	
	data.frame = data.frame or 0
	
	if v.ai1 == 0 then
		v.speedX = 1 * v.direction
	elseif v.ai1 == 1 then
		v.speedX = 0
		
		if data.frame < 8 then
			data.frame = data.frame + (1 / cfg.framespeed)
		else
			if v.collidesBlockBottom then
				SFX.play(37)
				
				for i = 0, 1 do
					local e = Effect.spawn(131, v.x + (32 * i) - 10, v.y + v.height - 16)
					e.speedX = (i == 0 and -1) or 1
				end
				
				for k,p in ipairs(Player.getIntersecting(v.x, v.y + (v.height - 16), v.x + v.width, v.y + v.height)) do
					p:harm()
				end
				
				for k,b in Block.iterateIntersecting(v.x, v.y + v.height, v.x + v.width, v.y + v.height + 32) do
					local invis1 = b:mem(0x5A, FIELD_WORD)
					local invis2 = b.isHidden
					
					if not invis2 and invis1 >= 0 and Block.MEGA_SMASH[b.id] and Block.config[b.id].bumpable then
						if b.id == 667 then
							b:hit()
							v.speedX = v.speedX * 0.85
						else
							b:remove(true)
							v.speedX = v.speedX * 0.85
						end
					end
				end
				
				Defines.earthquake = 5
				
				v.ai1 = 2
			end
		end
		
		v.animationFrame = math.floor(data.frame)
	elseif v.ai1 == 2 then
		v.speedX = 0
		
		v.animationFrame = 8
		v.ai2 = v.ai2 + 1
		
		if v.ai2 > 32 and v.collidesBlockBottom then
			v.ai1 = 3
			v.ai2 = 0
		end
	else
		data.frame = data.frame + (1 / cfg.framespeed)
		
		if data.frame == 10 then
			data.frame = 9
			v.ai1 = 0
		end
		
		v.animationFrame = math.floor(data.frame)	
	end
	
	for k,p in ipairs(Player.getIntersecting(v.x, v.y, v.x + v.width, v.y + v.height)) do
		if v.ai1 == 0 and p.deathTimer <= 0 then
			v.ai1 = 1
			data.frame = 4
			
			if v.collidesBlockBottom then
				v.speedY = -4
			end
		end
	end
end

return npc