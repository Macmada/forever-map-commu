-- Simulation hors jeu de ForeverMap (Lua 5.1). Lancer depuis la racine : lua5.1 tests/map_sim.lua [fr|en]
local LANG = arg and arg[1] or "fr"
local W = dofile("tests/wowmock.lua")(LANG)
local check = W.check

_G.strsplit = function(sep, s)
  local out, i = {}, 1
  while true do
    local a, b = s:find(sep, i, true)
    if not a then out[#out + 1] = s:sub(i); break end
    out[#out + 1] = s:sub(i, a - 1); i = b + 1
  end
  return unpack(out)
end
_G.Enum = { ClubType = { BattleNet = 0, Character = 1, Guild = 2 } }
_G.C_Club = { GetSubscribedClubs = function()
  return { { clubId = "123456789", name = "Les Gnomes", clubType = 1 }, { clubId = "987654321", name = "Raid du jeudi", clubType = 1 },
           { clubId = "555", name = "Amis Battle.net", clubType = 0 } } end }
local joinedCh, sent, idx = {}, {}, 0
_G.JoinTemporaryChannel = function(name, pw) idx = idx + 1; joinedCh[name] = { idx = idx, pw = pw } end
_G.LeaveChannelByName = function(name) joinedCh[name] = nil end
_G.GetChannelName = function(name) local c = joinedCh[name]; return c and c.idx or 0, name end
_G.C_ChatInfo = { RegisterAddonMessagePrefix = function() return true end,
  SendAddonMessage = function(prefix, msg, kind, target) sent[#sent + 1] = { prefix, msg, kind, target } end }
local POS = { map = 1426, x = 0.40, y = 0.50 }
_G.C_Map = { GetBestMapForUnit = function() return POS.map end,
  GetPlayerMapPosition = function() return { GetXY = function() return POS.x, POS.y end } end,
  GetMapWorldSize = function(m) if m == 1426 then return 5000, 3333 end return 0, 0 end }
_G.IsInGuild = function() return false end
_G.RAID_CLASS_COLORS = { PRIEST = { r = 1, g = 1, b = 1 }, MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
local wp
_G.TomTom = { AddWaypoint = function(_, m, x, y, o) wp = { m, x, y, o.title } end }
_G.Minimap.GetWidth = function() return 140 end
_G.Minimap.GetZoom = function() return 0 end
_G.IsIndoors = function() return false end

local ns = W.load("ForeverMap")
W.fire("ADDON_LOADED", "ForeverMap")
W.fire("PLAYER_LOGIN")
W.run(6)
check(ForeverMapDB and ForeverMapDB.clubs["123456789"] and ForeverMapDB.clubs["987654321"] and not ForeverMapDB.clubs["555"],
      "première connexion : les 2 communautés de personnages sont partagées (pas la Battle.net)")
local ch1, pw1 = ns.ChannelFor("123456789")
check(joinedCh[ch1] and joinedCh[ch1].pw == pw1 and ch1 == "FMap123456789", "canal caché de la communauté rejoint (" .. ch1 .. ")")
check(#sent == 2 and sent[1][1] == "FMAP1" and sent[1][3] == "CHANNEL", "position envoyée sur les 2 canaux")
local p = ns.Decode(sent[1][2])
check(p and p.map == 1426 and math.abs(p.x - 0.40) < 1e-4 and p.class == "PRIEST", "message décodé : carte 1426, x 0,40, prêtre")

-- pas de nouvel envoi si immobile, sauf battement toutes les 30 s ; envoi si on bouge
local before = #sent
W.run(10)
check(#sent == before, "immobile : rien n'est renvoyé avant 30 s")
POS.x = 0.45
W.run(6)
check(#sent > before, "en mouvement : nouvelle position envoyée")

-- réception
W.fire("CHAT_MSG_ADDON", "FMAP1", "P|1426|0.4100|0.5000|12|MAGE|Dun Morogh|", "CHANNEL", "Grosbill-Forever", ch1, 0, 1, ch1)
local g = ns.members.Grosbill
check(g and g.src == "123456789" and g.level == 12 and g.class == "MAGE", "membre reçu : Grosbill (mage 12) de « Les Gnomes »")
W.fire("CHAT_MSG_ADDON", "FMAP1", "P|1426|0.1|0.1|5|PRIEST|X|", "CHANNEL", "Machin-Forever", ch1, 0, 1, ch1)
check(not ns.members.Machin, "ton propre message est ignoré")
W.fire("CHAT_MSG_ADDON", "AUTRE", "P|1426|0.1|0.1|5|PRIEST|X|", "CHANNEL", "Lyra", ch1, 0, 1, ch1)
check(not ns.members.Lyra, "message d'un autre addon ignoré")

-- distance et minicarte
POS.x = 0.40
local d, dx = ns.Distance(g)
check(d and math.abs(d - 50) < 0.5 and dx > 0, "distance : Grosbill à 50 m à l'est")
local mx, my = ns.MinimapOffset(100, 0, 200, 70)
check(math.abs(mx - 35) < 0.01 and math.abs(my) < 0.01, "minicarte : 100 m à l'est, rayon 200 m = 35 px à droite")
check(ns.MinimapOffset(300, 0, 200, 70) == nil, "minicarte : hors du rayon, pas de point")
ns.UpdateMinimapPins()
check(ns.miniPinsShown == 1, "minicarte : un point pour Grosbill")

-- carte du monde
_G.WorldMapFrame = W.Obj("WorldMapFrame")
WorldMapFrame.ScrollContainer = { Child = W.Obj() }
WorldMapFrame.GetMapID = function() return 1426 end
WorldMapFrame:Show()
ns.UpdateWorldPins()
check(ns.worldPinsShown == 1, "carte du monde : un point pour Grosbill")

-- instance : pas de position envoyée
W.inInstance, W.instanceType = true, "party"
sent = {}
ns.Broadcast(true)
local pi = ns.Decode(sent[1] and sent[1][2] or "")
check(pi and pi.inst and pi.map == nil, "en donjon : seulement « en donjon », sans position")
W.inInstance, W.instanceType = false, "none"

-- invisible
SlashCmdList.FOREVERMAP("invisible")
sent = {}
check(ns.Broadcast(true) == false and #sent == 0, "invisible : rien n'est envoyé")
SlashCmdList.FOREVERMAP("invisible")

-- fenêtre, repère, options
SlashCmdList.FOREVERMAP("")
check(ns.ui:IsShown(), "/fmap : fenêtre ouverte")
ns.SetWaypoint(g)
check(wp and wp[1] == 1426 and wp[4] == "Grosbill", "repère TomTom vers Grosbill")
ForeverMapDB.clubs["987654321"] = nil
ns.SyncChannels()
check(not joinedCh[ns.ChannelFor("987654321")], "communauté décochée : canal quitté")
ns.ShowOptions()
check(ForeverMapOptionsFrame:IsShown(), "options ouvertes")

-- diagnostic
local diag = ns.DiagText()
check(diag:find("Les Gnomes", 1, true) and diag:find("Grosbill", 1, true) and diag:find("C_ChatInfo.SendAddonMessage : oui", 1, true), "diagnostic complet")
W.rprint("\nTOUT OK (" .. LANG .. ")")
