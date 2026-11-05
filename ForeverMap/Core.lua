local ADDON, ns = ...

-- ForeverMap : chaque membre qui a l'addon envoie sa position aux membres des communautés choisies (canal caché propre à
-- chaque communauté, et la guilde en option) ; l'addon les affiche sur la carte du monde, la minicarte et une liste.
-- Le jeu ne donne jamais la position d'un joueur hors de ton groupe : sans l'addon, un membre n'apparaît pas.

ns.PREFIX = "FMAP1"
ns.SEND_EVERY, ns.HEARTBEAT, ns.STALE, ns.FORGET = 5, 30, 120, 600

local db
ns.members = {}            -- nom -> { map, x, y, level, class, zone, inst, t, src }

function ns.Print(fmt, ...)
  local msg = (select("#", ...) > 0) and string.format(fmt, ...) or tostring(fmt)
  print("|cff4dc3ffForeverMap|r " .. msg)
end

local function Now() return GetTime() end
ns.Now = Now

----------------------------------------------------------------------
-- Communautés et canaux
----------------------------------------------------------------------
-- Communautés de personnages (pas Battle.net, pas la guilde) : { { id, name } }
function ns.Clubs()
  local out = {}
  if not (C_Club and C_Club.GetSubscribedClubs) then return out end
  local ok, list = pcall(C_Club.GetSubscribedClubs)
  if not ok or type(list) ~= "table" then return out end
  local charType = (Enum and Enum.ClubType and Enum.ClubType.Character) or 1
  for _, c in ipairs(list) do
    if c.clubType == charType then out[#out + 1] = { id = tostring(c.clubId), name = c.name or "?" } end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

-- Nom et mot de passe du canal caché d'une communauté (identiques chez tous ses membres)
function ns.ChannelFor(clubId)
  local digits = tostring(clubId):gsub("%D", "")
  local name = "FMap" .. digits:sub(1, 20)
  local sum = 0
  for i = 1, #digits do sum = (sum * 31 + digits:byte(i)) % 1000003 end
  return name, "fm" .. sum
end

local joined = {}
local function HideFromChat(name)
  if not ChatFrame_RemoveChannel then return end
  for i = 1, (NUM_CHAT_WINDOWS or 10) do
    local f = _G["ChatFrame" .. i]
    if f then pcall(ChatFrame_RemoveChannel, f, name) end
  end
end

-- Rejoint les canaux des communautés choisies, quitte les autres
function ns.SyncChannels()
  if not db then return end
  local wanted = {}
  for id, on in pairs(db.clubs) do
    if on then
      local name, pw = ns.ChannelFor(id)
      wanted[name] = id
      if not joined[name] and JoinTemporaryChannel then
        pcall(JoinTemporaryChannel, name, pw)
        HideFromChat(name)
        joined[name] = id
      end
    end
  end
  for name in pairs(joined) do
    if not wanted[name] then
      if LeaveChannelByName then pcall(LeaveChannelByName, name) end
      joined[name] = nil
    end
  end
  ns.channelClub = wanted
end

local function ChannelIndex(name)
  if not GetChannelName then return nil end
  local id = GetChannelName(name)
  return (id and id > 0) and id or nil
end

----------------------------------------------------------------------
-- Messages : « P|map|x|y|niveau|classe|zone|i » (i = en instance, sans position)
----------------------------------------------------------------------
function ns.Encode(p)
  if p.inst then return table.concat({ "P", "0", "0", "0", p.level or 0, p.class or "", (p.zone or ""):gsub("|", ""), "i" }, "|") end
  return table.concat({ "P", p.map, string.format("%.4f", p.x), string.format("%.4f", p.y), p.level or 0, p.class or "",
                        (p.zone or ""):gsub("|", ""), "" }, "|")
end

function ns.Decode(text)
  local kind, map, x, y, level, class, zone, flags = strsplit("|", text or "")
  if kind ~= "P" then return nil end
  local p = { map = tonumber(map), x = tonumber(x), y = tonumber(y), level = tonumber(level) or 0, class = class ~= "" and class or nil,
              zone = zone, inst = flags == "i" }
  if p.inst then p.map, p.x, p.y = nil, nil, nil
  elseif not (p.map and p.x and p.y and p.map > 0) then return nil end
  return p
end

----------------------------------------------------------------------
-- Ma position
----------------------------------------------------------------------
function ns.MyPosition()
  local _, class = UnitClass("player")
  local p = { level = UnitLevel("player"), class = class, zone = GetRealZoneText and GetRealZoneText() or "" }
  local inInstance, itype = IsInInstance()
  if inInstance and (itype == "party" or itype == "raid" or itype == "pvp" or itype == "arena" or itype == "scenario") then
    p.inst = true
    return p
  end
  if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
  local map = C_Map.GetBestMapForUnit("player")
  local pos = map and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
  if not pos then p.inst = true; return p end            -- position cachée par le jeu (instance, zone spéciale)
  local x, y = pos:GetXY()
  p.map, p.x, p.y = map, x, y
  return p
end

local last = { t = -1000 }
function ns.Broadcast(force)
  if not db or db.hidden then return false end
  local p = ns.MyPosition()
  if not p then return false end
  local moved = p.inst ~= last.inst or p.map ~= last.map or math.abs((p.x or 0) - (last.x or 0)) > 0.002
                or math.abs((p.y or 0) - (last.y or 0)) > 0.002
  if not force and not moved and Now() - last.t < ns.HEARTBEAT then return false end
  local msg = ns.Encode(p)
  local send = C_ChatInfo and C_ChatInfo.SendAddonMessage
  if not send then return false end
  local sent = false
  for name in pairs(ns.channelClub or {}) do
    local idx = ChannelIndex(name)
    if idx then pcall(send, ns.PREFIX, msg, "CHANNEL", idx); sent = true end
  end
  if db.guild and IsInGuild and IsInGuild() then pcall(send, ns.PREFIX, msg, "GUILD"); sent = true end
  last = { t = Now(), inst = p.inst, map = p.map, x = p.x, y = p.y }
  ns.lastSent = msg
  return sent
end

----------------------------------------------------------------------
-- Réception
----------------------------------------------------------------------
local function Short(name) return name and (name:match("^([^%-]+)") or name) end
ns.Short = Short

function ns.OnAddonMessage(prefix, text, channel, sender, _, _, _, chanName)
  if prefix ~= ns.PREFIX or not sender then return end
  if Short(sender) == UnitName("player") then return end
  local p = ns.Decode(text)
  if not p then return end
  local src
  if channel == "GUILD" then src = "guild"
  else
    local club = ns.channelClub and chanName and ns.channelClub[chanName]
    src = club or "channel"
  end
  p.t, p.src, p.name = Now(), src, Short(sender)
  ns.members[Short(sender)] = p
  if ns.OnMembersChanged then ns.OnMembersChanged() end
end

-- Membres connus, du plus récent au plus ancien (les trop vieux sont oubliés)
function ns.MemberList()
  local out = {}
  for name, p in pairs(ns.members) do
    if Now() - p.t > ns.FORGET then ns.members[name] = nil else out[#out + 1] = p end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

-- Distance en mètres (yards) entre toi et un membre sur la même carte ; nil sinon
function ns.Distance(p)
  local me = ns.MyPosition()
  if not (me and p and not me.inst and not p.inst and me.map == p.map) then return nil end
  local w, h = 0, 0
  if C_Map and C_Map.GetMapWorldSize then w, h = C_Map.GetMapWorldSize(p.map) end
  if not w or w == 0 then return nil end
  local dx, dy = (p.x - me.x) * w, (p.y - me.y) * h
  return math.sqrt(dx * dx + dy * dy), dx, dy
end

----------------------------------------------------------------------
-- Démarrage
----------------------------------------------------------------------
local ev = CreateFrame("Frame")
ns.eventFrame = ev
local handlers = {}
handlers.ADDON_LOADED = function(name)
  if name ~= ADDON then return end
  ForeverMapDB = ForeverMapDB or {}
  db = ForeverMapDB
  ns.db = db
  db.clubs = db.clubs or {}
  if db.minimap == nil then db.minimap = true end
  if db.world == nil then db.world = true end
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, ns.PREFIX) end
end
handlers.PLAYER_LOGIN = function()
  -- première fois : toutes tes communautés de personnages sont partagées (modifiable dans les options)
  if not db.initialized then
    for _, c in ipairs(ns.Clubs()) do db.clubs[c.id] = true end
    db.initialized = true
  end
  C_Timer.After(5, function() ns.SyncChannels(); ns.Broadcast(true) end)
  C_Timer.NewTicker(ns.SEND_EVERY, function() ns.Broadcast(false) end)
  if ns.OnLogin then ns.OnLogin() end
end
handlers.CHAT_MSG_ADDON = ns.OnAddonMessage
handlers.CLUB_ADDED = function() C_Timer.After(1, ns.SyncChannels) end
handlers.CLUB_REMOVED = function() C_Timer.After(1, ns.SyncChannels) end
handlers.ZONE_CHANGED_NEW_AREA = function() C_Timer.After(2, function() ns.Broadcast(true) end) end

ev:SetScript("OnEvent", function(_, event, ...) local h = handlers[event]; if h then h(...) end end)
for e in pairs(handlers) do pcall(ev.RegisterEvent, ev, e) end
ns._handlers = handlers
