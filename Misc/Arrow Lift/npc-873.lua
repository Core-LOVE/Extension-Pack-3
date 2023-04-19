local npc = {}
local id = NPC_ID

local npcManager = require("npcManager")
local npcutils = require("npcs/npcutils")

local rad = math.rad
local sin = math.sin
local cos = math.cos

npcManager.setNpcSettings{
	id = id,

	height = 64,
	width = 64,
	
	gfxwidth = 64,
	gfxheight = 64,
	
	frames = 1,
	framespeed = 8,
	
	npcblocktop = true,
	playerblocktop = true,

	jumphurt = true,
	nogravity = true,
	nohurt = true,
	noyoshi = true,
	nofireball = true,
	noiceball = true,
	nohammer = true,
	noshell = true,
	
	score = 0,
	rotation = 2,
}

local speed = 2.5;
local buffer = 1;

local function rebounder(v)
	local data = v.data._basegame
    
    local cfg = NPC.config[v.id]
	
	if not data.init then
		data.init = true;
		data.velocity = vector(v.speedX, v.speedY)
		data.hCollider = Colliders.Box(v.x-buffer,v.y+buffer,v.width+2*buffer,v.height-2*buffer);
		data.vCollider = Colliders.Box(v.x+buffer,v.y-buffer,v.width-2*buffer,v.height+2*buffer);
		data.frame = v.animationFrame;
		data.frameOffset = 0;
        data.despawned = true;
        data.hasTail = cfg.taillength
		if(data.hasTail) then
			data.tail = {};
			data.tailIndex = 0;
			data.tailCounter = 0;
			data.tailOffset = 0;
		end
	end
			
	if(not data.hasTail) then
		if(data.despawned and v:mem(0x124,FIELD_WORD) ~= 0) then
			data.velocity = vector(v.speedX, v.speedY)
		end
	end
	
	if not data.despawned then
		
	
		do
			local id = v.id;
			local x = v.x;
			local y = v.y;
			local width = v.width;
			local height = v.height;
		
		
			v.speedX = data.velocity.x;
			v.speedY = data.velocity.y;
			
			data.hCollider.x = x-buffer;
			data.hCollider.y = y+buffer;
			data.hCollider.width = width+2*buffer;
			data.hCollider.height = height-2*buffer;
			
			data.vCollider.x = x+buffer;
			data.vCollider.y = y-buffer;
			data.vCollider.width = width-2*buffer;
			data.vCollider.height = height+2*buffer;
		end
	
		if(v:mem(0x120,FIELD_BOOL) and not v.collidesBlockLeft and not v.collidesBlockRight) then
			data.velocity.x = -data.velocity.x;
		elseif(data.velocity.x < 0 and v.collidesBlockLeft) or (data.velocity.x > 0 and v.collidesBlockRight) then
			local bs = Colliders.getColliding{a=data.hCollider, b=Block.ALL, btype = Colliders.BLOCK};
			if(#bs > 0) then
				if(Block.SLOPE_MAP[bs[1].id]) then
					data.velocity.y = -data.velocity.y;
				end
				data.velocity.x = -data.velocity.x;
			end
		end
		if((data.velocity.y < 0 and v.collidesBlockUp) or (data.velocity.y > 0 and v.collidesBlockBottom)) then
			local bs = Colliders.getColliding{a=data.vCollider, b=Block.ALL, btype = Colliders.BLOCK};
			if(#bs > 0) then
				if(Block.SLOPE_MAP[bs[1].id]) then
					data.velocity.x = -data.velocity.x;
				end
				data.velocity.y = -data.velocity.y;
			else
				bs = Colliders.getColliding{a=data.vCollider, b=NPC.ALL, btype = Colliders.NPC};
				for _,w in ipairs(bs) do
					if(w.idx ~= v.idx) then
						if(NPC.config[w.id].npcblocktop) then
							data.velocity.y = -data.velocity.y;
							break;
						end
					end
				end
			end
		end
		
		if(not data.hasTail) then
			if(data.velocity.y > 0) then
				data.frameOffset = cfg.frames*2;
			else
				data.frameOffset = 0;
			end
		else
			if(data.despawned and v:mem(0x124,FIELD_WORD) == -1 or data.tail == nil) then
				data.tailCounter = 0;
				data.tail = {};
			end
			if(v:mem(0x138, FIELD_WORD) == 0) then --Mid generating or inside a container
				if (not v.friendly) and v:mem(0x12C, FIELD_WORD) == 0 then
					for l,w in ipairs(data.tail) do	
						for _,p in ipairs(Player.get()) do
							if(Colliders.collide(p,w.hitbox)) then
								p:harm();
							end
						end
					end
				end
				data.tailCounter = data.tailCounter+1;
				if(data.tailCounter > 8) then
					if(#data.tail >= cfg.taillength) then
						table.remove(data.tail,1);
					end
					table.insert(data.tail, {x = v.x, y = v.y,frame=data.tailIndex, offset=data.tailOffset,direction=v.direction, hitbox = Colliders.Box(v.x+2,v.y+2,math.max(1,v.width-4),math.max(1,v.height-4))});
					data.tailIndex = (data.tailIndex+1)%3;
					if(data.tailIndex == 0) then
						data.tailOffset = 1-data.tailOffset;
					end
					data.tailCounter = 0;
				end
			end
		end
	else
		v.speedX = 0;
		v.speedY = 0;
	end
	
	data.despawned = v:mem(0x124,FIELD_WORD) == 0 or v.isHidden;
end

local function standingPlayer(v)
	for _,p in ipairs(Player.get()) do
		if p.standingNPC == v then
			return p
		end
	end
end

function npc.onTickNPC(v)
	if Defines.levelFreeze or v.isHidden then return end
	
	local data = v.data._basegame
	local cfg = NPC.config[id]
	
	data.state = (data.state or 0)
	data.rotation = data.rotation or 0
	
	if data.state == 0 then
		data.rotation = (data.rotation + cfg.rotation)
		
		if standingPlayer(v) then
			local rot = rad(data.rotation)
			
			if data.velocity then
				data.velocity.x = cos(rot) * speed
				data.velocity.y = sin(rot) * speed
			end
			
			v.speedX = cos(rot) * speed
			v.speedY = sin(rot) * speed
			
			data.state = 1
		end
	end
	
	if data.state ~= 0 then
		rebounder(v)

		if data.velocity then
			local startX = 0
			local startY = 0
			local X = v.speedX
			local Y = v.speedY
			
			data.rotation = math.deg(math.atan2((Y - startY), (X - startX)))
		end
		
		if not standingPlayer(v) then
			v.speedX = 0
			v.speedY = 0
			
			data.state = 0
		end
	end

	npcutils.applyLayerMovement(v)
end

do
	local drawBox = Graphics.drawBox

	local spawnedbygenerator = {
		[1] = true,
		[3] = true,
		[4] = true,
	}

	function npc.onDrawNPC(v)
		if v.despawnTimer <= 0 then return end
		
		local data = v.data._basegame
		local cfg = NPC.config[id]
		
		local texture = Graphics.sprites.npc[id].img
		
		local trueWidth = cfg.gfxwidth
		if trueWidth == 0 then trueWidth = v.width end

		local trueHeight = cfg.gfxheight
		if trueHeight == 0 then trueHeight = v.height end
		
		local p = -45
		
		if cfg.foreground then
			p = -15
		end

		if spawnedbygenerator[v:mem(0x138, FIELD_WORD)] then
			p = -75
		end
	
		local x = v.x + 0.5 * v.width - 0.5 * trueWidth + cfg.gfxoffsetx
		local y = v.y + v.height - trueHeight + cfg.gfxoffsety
	
		drawBox{
			texture = texture,
			
			x = x + (v.width * .5),
			y = y + (v.height * .5),
			
			sourceY = trueHeight * v.animationFrame,
			sourceHeight = v.height,
			
			rotation = data.rotation,
			centered = true,
			
			sceneCoords = true,
			priority = p,
		}
		
		-- Graphics.drawBox{
			-- x = v.x,
			-- y = v.y,
			-- width = v.width,
			-- height = v.height,
			
			-- color = Color.red .. 0.5,
			
			-- sceneCoords = true,
			-- priority = p,	
		-- }
		
		npcutils.hideNPC(v)
	end
end

function npc.onInitAPI()
	npcManager.registerEvent(id, npc, 'onDrawNPC')
	npcManager.registerEvent(id, npc, 'onTickNPC')
end

return npc