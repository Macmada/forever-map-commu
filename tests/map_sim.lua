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
_G.Enum.ClubMemberPresence = { Unknown = 0, Online = 1, OnlineMobile = 2, Offline = 3, Away = 4, Busy = 5 }
local MEMBERS = { ["123456789"] = { { name = "Machin", isSelf = true, presence = 1 }, { name = "Grosbill", presence = 1 },
                                    { name = "Lyra", presence = 3 }, { name = "Mobile", presence = 2 }, { name = "Absent-Autreroyaume", presence = 4 },
                                    { name = "Alain Tendance", guid = "Player-1-0A", presence = 1 } },
                  ["987654321"] = { { name = "Grosbill", presence = 1 } } }
_G.C_Club = { GetSubscribedClubs = function()
  return { { clubId = "123456789", name = "Les Gnomes", clubType = 1 }, { clubId = "987654321", name = "Raid du jeudi", clubType = 1 },
           { clubId = "555", name = "Amis Battle.net", clubType = 0 } } end,
  GetClubMembers = function(id) local t = {}; for i = 1, #(MEMBERS[tostring(id)] or {}) do t[i] = i end; return t end,
  GetMemberInfo = function(id, mid) return MEMBERS[tostring(id)][mid] end }
_G.GetPlayerInfoByGUID = function(g) if g == "Player-1-0A" then return "Prêtre", "PRIEST", "Gnome", "Gnome", 3, "Alain Tendance", "" end end
_G.ERR_CHAT_PLAYER_NOT_FOUND_S = "Aucun joueur nommé '%s' ne joue actuellement."
local filters = {}
_G.ChatFrame_AddMessageEventFilter = function(ev, f) filters[ev] = f end
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

local ns = W.load("ForeverMapCommu")
W.fire("ADDON_LOADED", "ForeverMapCommu")
local disabled
_G.C_AddOns.IsAddOnLoaded = function(n) return n == "ForeverMap" end      -- ancienne version encore installée
_G.C_AddOns.DisableAddOn = function(n) disabled = n end
W.fire("PLAYER_LOGIN")
W.run(6)
check(disabled == "ForeverMap" and ns.oldDisabled, "ancien addon « ForeverMap » détecté et désactivé (renommage en ForeverMapCommu)")
check(ForeverMapCommuDB and ForeverMapCommuDB.clubs["123456789"] and ForeverMapCommuDB.clubs["987654321"] and not ForeverMapCommuDB.clubs["555"],
      "première connexion : les 2 communautés de personnages sont partagées (pas la Battle.net)")
local ch1, pw1 = ns.ChannelFor("123456789")
check(joinedCh[ch1] and joinedCh[ch1].pw == pw1 and ch1 == "FMap123456789", "canal caché de la communauté rejoint (" .. ch1 .. ")")
local wh, chn = {}, 0
for _, m in ipairs(sent) do if m[3] == "WHISPER" then wh[m[4]] = true elseif m[3] == "CHANNEL" then chn = chn + 1 end end
check(wh.Grosbill and wh["Absent-Autreroyaume"] and not wh.Lyra and not wh.Mobile and not wh.Machin,
      "message privé d'addon aux membres connectés (pas hors ligne, pas mobile, pas toi), une seule fois chacun")
check(chn == 2 and sent[1][1] == "FMAP1", "et sur les 2 canaux cachés")
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
W.fire("CHAT_MSG_ADDON", "FMAP1", "P|1426|0.4200|0.5|9|PRIEST|Y|", "WHISPER", "Absent-Autreroyaume", "Machin", 0, 0, "")
check(ns.members.Absent and ns.members.Absent.src == "123456789", "reçu en message privé : rattaché à sa communauté")
W.fire("CHAT_MSG_ADDON", "FMAP1", "P|1426|0.1|0.1|5|PRIEST|X|", "CHANNEL", "Machin-Forever", ch1, 0, 1, ch1)
check(not ns.members.Machin, "ton propre message est ignoré")
W.fire("CHAT_MSG_ADDON", "AUTRE", "P|1426|0.1|0.1|5|PRIEST|X|", "CHANNEL", "Lyra", ch1, 0, 1, ch1)
check(not ns.members.Lyra, "message d'un autre addon ignoré")

-- liaison réciproque : un membre absent de ma liste « connectés » (état inconnu) mais qui m'envoie sa position
sent = {}
W.fire("CHAT_MSG_ADDON", "FMAP1", "P|1426|0.4300|0.5|6|HUNTER|Z|", "WHISPER", "Inconnu-Forever", "Machin", 0, 0, "")
W.run(2)
local back = false
for _, m in ipairs(sent) do if m[3] == "WHISPER" and m[4] == "Inconnu-Forever" then back = true end end
check(back, "premier contact : je lui réponds aussitôt (il me verra même si sa liste ne me montre pas connecté)")

-- WoW Forever : prénom ET nom (« Alain Tendance ») : message privé au nom complet, espace compris
sent = {}
ns.Broadcast(true)
local toAlain, toSpace = false, false
for _, m in ipairs(sent) do
  if m[3] == "WHISPER" and m[4] == "Alain" then toAlain = true end
  if m[3] == "WHISPER" and m[4] == "Alain Tendance" then toSpace = true end
end
check(toSpace and not toAlain, "message privé à « Alain Tendance » (prénom et nom de Forever), pas à « Alain » seul")
check(ns.WhisperName({ name = "Jo Martin" }) == "Jo Martin" and ns.WhisperName({ name = "Jo Martin-Autre Royaume" }) == "Jo Martin-AutreRoyaume",
      "sans identifiant : nom complet gardé, seul le royaume perd ses espaces")
-- membre déconnecté : le message « aucun joueur nommé » est masqué, plus de nouvel envoi pendant 5 min
check(filters.CHAT_MSG_SYSTEM and filters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", "Aucun joueur nommé 'Alain Tendance' ne joue actuellement.") == true,
      "« Aucun joueur nommé 'Alain Tendance'… » après un envoi de l'addon : masqué")
check(filters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", "Aucun joueur nommé 'Inconnu2' ne joue actuellement.") == false,
      "même message pour un nom que l'addon n'a pas visé : laissé (c'est toi qui as écrit)")
sent = {}
ns.Broadcast(true)
local again = false
for _, m in ipairs(sent) do if m[3] == "WHISPER" and m[4] == "Alain Tendance" then again = true end end
check(not again, "membre noté absent : plus de message privé (donc plus de spam)")
W.fire("CLUB_MEMBER_PRESENCE_UPDATED")
sent = {}
ns.Broadcast(true)
again = false
for _, m in ipairs(sent) do if m[3] == "WHISPER" and m[4] == "Alain Tendance" then again = true end end
check(again, "il revient en ligne : de nouveau contacté")

-- distance et minicarte
POS.x = 0.40
local d, dx = ns.Distance(g)
check(d and math.abs(d - 50) < 0.5 and dx > 0, "distance : Grosbill à 50 m à l'est")
local mx, my = ns.MinimapOffset(100, 0, 200, 70)
check(math.abs(mx - 35) < 0.01 and math.abs(my) < 0.01, "minicarte : 100 m à l'est, rayon 200 m = 35 px à droite")
check(ns.MinimapOffset(300, 0, 200, 70) == nil, "minicarte : hors du rayon, pas de point")
ns.UpdateMinimapPins()
check(ns.miniPinsShown == 3, "minicarte : un point par membre proche")

-- carte du monde
_G.WorldMapFrame = W.Obj("WorldMapFrame")
WorldMapFrame.ScrollContainer = { Child = W.Obj() }
WorldMapFrame.GetMapID = function() return 1426 end
WorldMapFrame:Show()
ns.UpdateWorldPins()
check(ns.worldPinsShown == 3, "carte du monde : un point par membre")

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
ForeverMapCommuDB.clubs["987654321"] = nil
ns.SyncChannels()
check(not joinedCh[ns.ChannelFor("987654321")], "communauté décochée : canal quitté")
ns.ShowOptions()
check(ForeverMapCommuOptionsFrame:IsShown(), "options ouvertes")

-- diagnostic
local diag = ns.DiagText()
check(diag:find("Les Gnomes", 1, true) and diag:find("Grosbill", 1, true) and diag:find("C_ChatInfo.SendAddonMessage : oui", 1, true), "diagnostic complet")
W.rprint("\nTOUT OK (" .. LANG .. ")")
