local _, ns = ...
local L = ns.L

local GOLD = { 1, 0.82, 0 }
local PIN = "Interface\\WorldMap\\WorldMapPartyIcon"

local function ClassColor(class)
  local c = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {})[class or ""]
  if c then return c.r, c.g, c.b end
  return 0.3, 0.75, 1
end

local function Ago(p)
  local s = math.floor(ns.Now() - p.t)
  if s >= 60 then return string.format(L.agoMin, math.floor(s / 60)) end
  return string.format(L.ago, s)
end

local function Border(f, r, g, b, a)
  for i = 1, 4 do
    local t = f:CreateTexture(nil, "BORDER")
    t:SetColorTexture(r, g, b, a)
    if i == 1 then t:SetPoint("TOPLEFT"); t:SetPoint("TOPRIGHT"); t:SetHeight(1)
    elseif i == 2 then t:SetPoint("BOTTOMLEFT"); t:SetPoint("BOTTOMRIGHT"); t:SetHeight(1)
    elseif i == 3 then t:SetPoint("TOPLEFT"); t:SetPoint("BOTTOMLEFT"); t:SetWidth(1)
    else t:SetPoint("TOPRIGHT"); t:SetPoint("BOTTOMRIGHT"); t:SetWidth(1) end
  end
end

local function PinTooltip(self)
  local p = self.member
  if not p then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  local r, g, b = ClassColor(p.class)
  GameTooltip:AddLine(p.name, r, g, b)
  local cname = (LOCALIZED_CLASS_NAMES_MALE or {})[p.class or ""] or (p.class or "")
  GameTooltip:AddLine(string.format(L.tipLevel, p.level or 0, cname), 1, 1, 1)
  GameTooltip:AddLine(p.inst and L.inInstance or (p.zone or ""), 0.8, 0.8, 0.8)
  GameTooltip:AddLine(Ago(p), 0.6, 0.6, 0.6)
  GameTooltip:Show()
end

local function MakePin(parent, size)
  local f = CreateFrame("Button", nil, parent)
  f:SetSize(size, size)
  f.tex = f:CreateTexture(nil, "OVERLAY")
  f.tex:SetAllPoints()
  f.tex:SetTexture(PIN)
  f:SetScript("OnEnter", PinTooltip)
  f:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f:SetScript("OnClick", function(self) if self.member then ns.SetWaypoint(self.member) end end)
  return f
end

local function StylePin(f, p)
  f.member = p
  local r, g, b = ClassColor(p.class)
  local stale = ns.Now() - p.t > ns.STALE
  f.tex:SetVertexColor(r, g, b, stale and 0.45 or 1)
end

----------------------------------------------------------------------
-- Carte du monde : un point par membre (sa carte, ou convertie vers la carte affichée)
----------------------------------------------------------------------
-- Position d'un membre sur la carte affichée (0-1), ou nil
function ns.PosOnMap(p, mapID)
  if p.inst or not p.map then return nil end
  if p.map == mapID then return p.x, p.y end
  if not (C_Map and C_Map.GetWorldPosFromMapPos and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return nil end
  local ok, cont, world = pcall(C_Map.GetWorldPosFromMapPos, p.map, CreateVector2D(p.x, p.y))
  if not ok or not world then return nil end
  local ok2, _, mp = pcall(C_Map.GetMapPosFromWorldPos, cont, world, mapID)
  if not ok2 or not mp then return nil end
  local x, y = mp:GetXY()
  if x < 0 or x > 1 or y < 0 or y > 1 then return nil end
  return x, y
end

local worldPins = {}
function ns.UpdateWorldPins()
  for _, f in ipairs(worldPins) do f:Hide() end
  local wm = _G.WorldMapFrame
  if not (ns.db and ns.db.world and wm and wm:IsShown()) then return end
  local canvas = wm.ScrollContainer and wm.ScrollContainer.Child
  local mapID = wm.GetMapID and wm:GetMapID()
  if not (canvas and mapID) then return end
  local w, h = canvas:GetWidth(), canvas:GetHeight()
  local n = 0
  for _, p in ipairs(ns.MemberList()) do
    local x, y = ns.PosOnMap(p, mapID)
    if x then
      n = n + 1
      local f = worldPins[n] or MakePin(canvas, 18)
      worldPins[n] = f
      f:SetParent(canvas)
      f:SetFrameLevel(2000)
      StylePin(f, p)
      f:ClearAllPoints()
      f:SetPoint("CENTER", canvas, "TOPLEFT", x * w, -y * h)
      f:Show()
    end
  end
  ns.worldPinsShown = n
end

----------------------------------------------------------------------
-- Minicarte : membres sur la même carte que toi, à la bonne distance et orientation
----------------------------------------------------------------------
local OUTDOOR = { 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 }
local INDOOR = { 300, 240, 180, 120, 80, 50 }
local miniPins = {}

function ns.MinimapOffset(dx, dy, radiusYards, half, facing)
  local x, y = dx / radiusYards * half, -dy / radiusYards * half
  if facing then
    local c, s = math.cos(facing), math.sin(facing)
    x, y = x * c - y * s, x * s + y * c
  end
  if math.sqrt(x * x + y * y) > half then return nil end
  return x, y
end

function ns.UpdateMinimapPins()
  for _, f in ipairs(miniPins) do f:Hide() end
  if not (ns.db and ns.db.minimap and Minimap) then return end
  local zoom = (Minimap.GetZoom and Minimap:GetZoom()) or 0
  local radius = ((IsIndoors and IsIndoors()) and INDOOR or OUTDOOR)[zoom + 1] or 233
  local half = (Minimap:GetWidth() or 140) / 2
  local facing
  if GetCVar and GetCVar("rotateMinimap") == "1" and GetPlayerFacing then facing = GetPlayerFacing() end
  local n = 0
  for _, p in ipairs(ns.MemberList()) do
    local _, dx, dy = ns.Distance(p)
    if dx then
      local x, y = ns.MinimapOffset(dx, dy, radius, half, facing)
      if x then
        n = n + 1
        local f = miniPins[n] or MakePin(Minimap, 12)
        miniPins[n] = f
        StylePin(f, p)
        f:ClearAllPoints()
        f:SetPoint("CENTER", Minimap, "CENTER", x, y)
        f:Show()
      end
    end
  end
  ns.miniPinsShown = n
end

----------------------------------------------------------------------
-- Repère vers un membre (TomTom s'il est là, sinon le repère du jeu)
----------------------------------------------------------------------
function ns.SetWaypoint(p)
  if not p or p.inst or not p.map then return ns.Print(L.waypointNone, p and p.name or "?") end
  local TT = _G.TomTom
  if TT and TT.AddWaypoint and pcall(TT.AddWaypoint, TT, p.map, p.x, p.y, { title = p.name, persistent = false }) then
    return ns.Print(L.waypointSet, p.name)
  end
  if C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
    if pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(p.map, p.x, p.y)) then
      if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true) end
      return ns.Print(L.waypointSet, p.name)
    end
  end
  ns.Print(L.waypointNone, p.name)
end

----------------------------------------------------------------------
-- Fenêtre : liste des membres, options
----------------------------------------------------------------------
local ui
local rows = {}

local function Row(i)
  local r = rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, ui.list)
  r:SetHeight(22)
  r:SetPoint("TOPLEFT", 0, -(i - 1) * 24)
  r:SetPoint("RIGHT", ui.list, "RIGHT", 0, 0)
  r.bg = r:CreateTexture(nil, "BACKGROUND")
  r.bg:SetAllPoints()
  r.dot = r:CreateTexture(nil, "ARTWORK")
  r.dot:SetSize(14, 14)
  r.dot:SetPoint("LEFT", 4, 0)
  r.dot:SetTexture(PIN)
  r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  r.name:SetPoint("LEFT", 24, 0)
  r.name:SetWidth(130)
  r.name:SetJustifyH("LEFT")
  r.zone = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.zone:SetPoint("LEFT", 160, 0)
  r.zone:SetWidth(170)
  r.zone:SetJustifyH("LEFT")
  r.dist = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.dist:SetPoint("LEFT", 335, 0)
  r.dist:SetWidth(80)
  r.seen = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  r.seen:SetPoint("LEFT", 420, 0)
  r.seen:SetWidth(80)
  r.wp = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
  r.wp:SetSize(70, 20)
  r.wp:SetPoint("RIGHT", -4, 0)
  r.wp:SetText(L.waypoint)
  r.wp:SetScript("OnClick", function(self) ns.SetWaypoint(self:GetParent().member) end)
  r:SetScript("OnEnter", PinTooltip)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  rows[i] = r
  return r
end

function ns.RefreshWindow()
  if not (ui and ui:IsShown()) then return end
  for _, r in ipairs(rows) do r:Hide() end
  local list = ns.MemberList()
  for i, p in ipairs(list) do
    local r = Row(i)
    r.member = p
    r.bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.04 or 0)
    local cr, cg, cb = ClassColor(p.class)
    r.dot:SetVertexColor(cr, cg, cb)
    r.name:SetText(p.name .. " |cffa0a0a0" .. (p.level or "") .. "|r")
    r.name:SetTextColor(cr, cg, cb)
    r.zone:SetText(p.inst and ("|cffff9a1a" .. L.inInstance .. "|r") or (p.zone or ""))
    local d = ns.Distance(p)
    r.dist:SetText(d and string.format(L.yards, d) or ("|cff808080" .. L.far .. "|r"))
    r.seen:SetText(Ago(p))
    r.wp:SetEnabled(not p.inst)
    r:Show()
  end
  ui.list:SetHeight(math.max(24, #list * 24))
  local names = {}
  for _, c in ipairs(ns.Clubs()) do if ns.db.clubs[c.id] then names[#names + 1] = c.name end end
  if ns.db.guild then names[#names + 1] = GUILD or "Guilde" end
  ui.status:SetText((ns.db.hidden and ("|cffff9a1a" .. L.hiddenSelf .. "|r  ") or "")
                    .. (#names > 0 and string.format(L.shared, table.concat(names, ", ")) or ("|cffff6a5a" .. L.sharedNone .. "|r")))
  ui.empty:SetShown(#list == 0)
  ui.empty:SetText(#names == 0 and L.noClub or L.none)
end

local opt
local function ShowOptions()
  if not opt then
    opt = CreateFrame("Frame", "ForeverMapCommuOptionsFrame", ui, "BasicFrameTemplateWithInset")
    if opt.CloseButton then opt.CloseButton:SetScript("OnClick", function() opt:Hide() end) end
    opt:SetSize(420, 320)
    opt:SetPoint("TOPRIGHT", ui, "TOPRIGHT", -10, -60)
    opt:SetFrameStrata("DIALOG")
    local t = opt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("TOPLEFT", 12, -6)
    t:SetText(L.options)
    opt.checks = {}
  end
  for _, c in ipairs(opt.checks) do c:Hide() end
  local y, n = -34, 0
  local function C(text, get, set)
    n = n + 1
    local cb = opt.checks[n]
    if not cb then
      cb = CreateFrame("CheckButton", nil, opt, "UICheckButtonTemplate")
      cb:SetSize(22, 22)
      cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
      cb.label:SetWidth(360)
      cb.label:SetJustifyH("LEFT")
      opt.checks[n] = cb
    end
    cb:ClearAllPoints()
    cb:SetPoint("TOPLEFT", 14, y)
    cb.label:SetText(text)
    cb:SetChecked(get())
    cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false); ns.SyncChannels(); ns.Broadcast(true); ns.RefreshWindow() end)
    cb:Show()
    y = y - 26
  end
  local head = opt.head or opt:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  opt.head = head
  head:SetPoint("TOPLEFT", 16, y + 4)
  head:SetText(L.optClubs)
  y = y - 16
  local clubs = ns.Clubs()
  if #clubs == 0 then
    local e = opt.emptyClubs or opt:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    opt.emptyClubs = e
    e:SetPoint("TOPLEFT", 20, y)
    e:SetText(L.noCommunities)
    y = y - 22
  end
  for _, c in ipairs(clubs) do
    C(c.name, function() return ns.db.clubs[c.id] end, function(v) ns.db.clubs[c.id] = v or nil end)
  end
  y = y - 6
  C(L.optGuild, function() return ns.db.guild end, function(v) ns.db.guild = v end)
  C(L.optHidden, function() return ns.db.hidden end, function(v) ns.db.hidden = v end)
  C(L.optWorld, function() return ns.db.world end, function(v) ns.db.world = v; ns.UpdateWorldPins() end)
  C(L.optMinimap, function() return ns.db.minimap end, function(v) ns.db.minimap = v; ns.UpdateMinimapPins() end)
  opt:SetHeight(-y + 20)
  opt:Show()
end
ns.ShowOptions = ShowOptions

local function CreateUI()
  if ui then return ui end
  ui = CreateFrame("Frame", "ForeverMapCommuFrame", UIParent, "BasicFrameTemplateWithInset")
  ns.ui = ui
  if ui.CloseButton then ui.CloseButton:SetScript("OnClick", function() ui:Hide() end) end   -- pas de HideUIPanel (bloqué en combat)
  ui:SetSize(600, 420)
  ui:SetPoint("CENTER")
  ui:SetFrameStrata("HIGH")
  ui:SetMovable(true)
  ui:SetClampedToScreen(true)
  ui:EnableMouse(true)
  ui:RegisterForDrag("LeftButton")
  ui:SetScript("OnDragStart", ui.StartMoving)
  ui:SetScript("OnDragStop", ui.StopMovingOrSizing)
  tinsert(UISpecialFrames, "ForeverMapCommuFrame")
  ui:Hide()
  local logo = ui:CreateTexture(nil, "OVERLAY")
  logo:SetSize(16, 16)
  logo:SetPoint("TOPLEFT", 8, -4)
  logo:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
  logo:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  local title = ui:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("LEFT", logo, "RIGHT", 6, 0)
  title:SetText(L.title)
  ui.status = ui:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ui.status:SetPoint("TOPLEFT", 16, -34)
  ui.status:SetPoint("RIGHT", -60, 0)
  ui.status:SetJustifyH("LEFT")
  local gear = CreateFrame("Button", nil, ui)
  gear:SetSize(28, 28)
  gear:SetPoint("TOPRIGHT", -16, -28)
  gear.tex = gear:CreateTexture(nil, "ARTWORK")
  gear.tex:SetAllPoints()
  gear.tex:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
  gear.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  gear:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  gear:SetScript("OnClick", function() if opt and opt:IsShown() then opt:Hide() else ShowOptions() end end)
  gear:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetText(L.options); GameTooltip:Show() end)
  gear:SetScript("OnLeave", function() GameTooltip:Hide() end)
  ui.gear = gear
  local sheet = CreateFrame("Frame", nil, ui)
  sheet:SetPoint("TOPLEFT", 12, -64)
  sheet:SetPoint("BOTTOMRIGHT", -12, 12)
  local bg = sheet:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.10, 0.07, 0.04, 0.6)
  Border(sheet, 0.55, 0.42, 0.18, 0.9)
  local sf = CreateFrame("ScrollFrame", nil, sheet, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", 6, -6)
  sf:SetPoint("BOTTOMRIGHT", -28, 6)
  local list = CreateFrame("Frame", nil, sf)
  list:SetSize(540, 24)
  sf:SetScrollChild(list)
  ui.list = list
  ui.empty = sheet:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  ui.empty:SetPoint("CENTER")
  ui.empty:SetWidth(480)
  ui:SetScript("OnShow", function() ns.RefreshWindow() end)
  return ui
end

function ns.Toggle()
  CreateUI()
  if ui:IsShown() then ui:Hide() else ui:Show() end
end
ns.OnMembersChanged = function() ns.RefreshWindow(); ns.UpdateMinimapPins() end

----------------------------------------------------------------------
-- Diagnostic : ce que le client de Forever permet (canaux, messages d'addon, cartes)
----------------------------------------------------------------------
function ns.DiagText()
  local out = {}
  local function add(s) out[#out + 1] = s end
  local v, build, _, iface = GetBuildInfo()
  add(string.format("### ForeverMapCommu %s — %s", tostring((C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("ForeverMapCommu", "Version"))
      or (GetAddOnMetadata and GetAddOnMetadata("ForeverMapCommu", "Version")) or "?"), date("%Y-%m-%d %H:%M")))
  add(string.format("Client %s build %s, interface %s, %s", tostring(v), tostring(build), tostring(iface), GetLocale()))
  for _, f in ipairs({ "C_ChatInfo.SendAddonMessage", "C_Club.GetSubscribedClubs", "JoinTemporaryChannel", "GetChannelName",
                       "C_Map.GetPlayerMapPosition", "C_Map.GetWorldPosFromMapPos", "C_Map.GetMapWorldSize", "C_Map.SetUserWaypoint" }) do
    local a, b = f:match("^(.-)%.(.+)$")
    local ok = a and _G[a] and _G[a][b] or _G[f]
    add(f .. " : " .. (ok and "oui" or "NON"))
  end
  local clubs = ns.Clubs()
  add("Communautés : " .. #clubs)
  for _, c in ipairs(clubs) do
    local name = ns.ChannelFor(c.id)
    add(string.format("  %s (%s) — partagée %s, canal %s n° %s", c.name, c.id, tostring(ns.db.clubs[c.id] == true), name,
        tostring(GetChannelName and GetChannelName(name))))
  end
  local me = ns.MyPosition()
  add("Ma position : " .. (me and (me.inst and "instance" or string.format("carte %s, %.3f, %.3f", tostring(me.map), me.x or 0, me.y or 0)) or "aucune"))
  add("Préfixe : enregistrement " .. tostring(ns.prefixResult) .. ", enregistré "
      .. tostring(C_ChatInfo and C_ChatInfo.IsAddonMessagePrefixRegistered and C_ChatInfo.IsAddonMessagePrefixRegistered(ns.PREFIX)))
  for _, c in ipairs(clubs) do
    local on = ns.OnlineMembers(c.id)
    if C_Club and C_Club.GetClubMembers and C_Club.GetMemberInfo then
      local raw = {}
      for _, mid in ipairs(C_Club.GetClubMembers(c.id) or {}) do
        local i = C_Club.GetMemberInfo(c.id, mid)
        if i then raw[#raw + 1] = string.format("%s→%s(%s)", tostring(i.name), tostring(ns.WhisperName(i)), tostring(i.presence)) end
      end
      add("  noms de la communauté → nom visé (présence) : " .. table.concat(raw, ", "))
    end
    add(string.format("  %s : %d membre(s) connecté(s) vu(s) par l'addon : %s", c.name, #on, table.concat(on, ", ")))
  end
  local peers = {}
  for full in pairs(ns.peers or {}) do peers[#peers + 1] = full end
  local offl = {}
  for n in pairs(ns.offline or {}) do offl[#offl + 1] = n end
  add("Notés absents (« aucun joueur nommé ») : " .. (#offl > 0 and table.concat(offl, ", ") or "aucun"))
  add("Membres à qui je réponds (ils m'ont envoyé leur position) : " .. (#peers > 0 and table.concat(peers, ", ") or "aucun"))
  add("Dernier envoi : " .. tostring(ns.lastSent))
  for _, r in ipairs(ns.lastResults or {}) do add("  " .. r) end
  local n = 0
  for _, p in pairs(ns.members) do
    n = n + 1
    add(string.format("  reçu de %s : %s il y a %d s (source %s)", p.name, p.inst and "instance" or (tostring(p.map) .. " " .. (p.zone or "")),
        math.floor(ns.Now() - p.t), tostring(p.src)))
  end
  add("Membres reçus : " .. n)
  return table.concat(out, "\n")
end

local diag
function ns.ShowDiag()
  if not diag then
    diag = CreateFrame("Frame", "ForeverMapCommuDiagFrame", UIParent, "BasicFrameTemplateWithInset")
    if diag.CloseButton then diag.CloseButton:SetScript("OnClick", function() diag:Hide() end) end
    diag:SetSize(620, 420)
    diag:SetPoint("CENTER")
    diag:SetFrameStrata("FULLSCREEN_DIALOG")
    local t = diag:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("TOPLEFT", 12, -6)
    t:SetText(L.diagTitle)
    local sf = CreateFrame("ScrollFrame", nil, diag, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 12, -30)
    sf:SetPoint("BOTTOMRIGHT", -30, 12)
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetFontObject(ChatFontNormal)
    eb:SetWidth(560)
    eb:SetAutoFocus(false)
    eb:SetScript("OnEscapePressed", function() diag:Hide() end)
    sf:SetScrollChild(eb)
    diag.edit = eb
  end
  ns.lastDiag = ns.DiagText()
  diag.edit:SetText(ns.lastDiag)
  diag:Show()
  diag.edit:SetFocus()
  diag.edit:HighlightText()
end

----------------------------------------------------------------------
-- Démarrage : rafraîchissements, commandes
----------------------------------------------------------------------
ns.OnLogin = function()
  C_Timer.NewTicker(0.5, function()
    if _G.WorldMapFrame and _G.WorldMapFrame:IsShown() then ns.UpdateWorldPins() end
    ns.UpdateMinimapPins()
  end)
  C_Timer.NewTicker(5, function() ns.RefreshWindow() end)
  local LS = _G.LibStub
  local LDB = LS and LS("LibDataBroker-1.1", true)
  if LDB then
    LDB:NewDataObject("ForeverMapCommu", { type = "launcher", icon = "Interface\\Icons\\INV_Misc_Map_01", OnClick = function() ns.Toggle() end,
      OnTooltipShow = function(tt) tt:AddLine("ForeverMapCommu", GOLD[1], GOLD[2], GOLD[3]) end })
  end
end

SLASH_FOREVERMAP1 = "/fmap"
SLASH_FOREVERMAP2 = "/forevermap"
SlashCmdList.FOREVERMAP = function(msg)
  msg = ((msg or ""):match("^%s*(.-)%s*$")):lower()
  if msg == "" then ns.Toggle()
  elseif msg == "invisible" or msg == "hide" then
    ns.db.hidden = not ns.db.hidden
    ns.Print(ns.db.hidden and L.hiddenOn or L.hiddenOff)
    if not ns.db.hidden then ns.Broadcast(true) end
    ns.RefreshWindow()
  elseif msg == "diag" then ns.ShowDiag()
  else ns.Print(L.helpText) end
end

function ForeverMapCommu_OnCompartmentClick() ns.Toggle() end
