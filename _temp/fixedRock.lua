local npc = {}
local id = NPC_ID

local settings = {
    id = id,
    
    frames = 4,
    framespeed = 16,
    
    jumphurt = true,
    nohurt = false,
    
    npcblock = true,
    npcblocktop = true,
    playerblock = true,
    playerblocktop = true,
    noblockcollision = false,
    
    grabside = false,
    grabtop = true,
    
    noiceball = true,
    noyoshi= false,
    nofireball = true,

    nowalldeath = true,

    harmlessgrab=true,
    hitbounceheight=3,
    bounceheight = 3,
    speed = 2,
    luahandlesspeed = true,
    useclearpipe = true
}

function npc.onDrawNPC(v)
    if v.despawnTimer <= 0 then return end
    
    if v.speedX == 0 then
        v.animationFrame = 0
    end
end

function npc.onNPCHarm(e, v, reason, culprit)
    if culprit ~= nil and culprit.isValid and culprit.id == NPC_ID then
        culprit.noblockcollision = true
        culprit:mem(0x136, FIELD_BOOL, false)
        culprit.speedY = math.min(culprit.speedY, -NPC.config[culprit.id].hitbounceheight)
    end
end

function npc.onTickEndNPC(v)
    if Defines.levelFreeze then return end
    if v.despawnTimer <= 0 then return end
    if v:mem(0x12C, FIELD_WORD) ~= 0 then return end
    if v:mem(0x138, FIELD_WORD) > 0 then return end
    local data = v.data._basegame
    
    if v.speedX ~= 0 then

        data.lastDirection = data.lastDirection or v.direction
        if v.collidesBlockBottom then
            v.speedY = -NPC.config[v.id].hitbounceheight
        end

        if v.direction ~= data.lastDirection then
            v.speedX = v.direction * math.min(math.abs(v.speedX), NPC.config[v.id].speed)
        end

        data.lastDirection = v.direction
    end

    if v.speedX == 0 and v.speedY == 0 then
        v:mem(0x136, FIELD_BOOL, false)
    end
end

function npc.onInitAPI()
    local nm = require 'npcManager'
    
    nm.setNpcSettings(settings)
    nm.registerHarmTypes(NPC_ID, {HARM_TYPE_LAVA, HARM_TYPE_SWORD, {
        [HARM_TYPE_SWORD] = 10,
        [HARM_TYPE_LAVA] = {id = 13, xoffset = 0.5, xoffsetBack = 0, yoffset = 1, yoffsetBack = 1.5}
    }})
    nm.registerEvent(NPC_ID, npc, 'onDrawNPC')
    nm.registerEvent(NPC_ID, npc, 'onTickEndNPC')
    registerEvent(npc, "onNPCHarm")
end

return npc