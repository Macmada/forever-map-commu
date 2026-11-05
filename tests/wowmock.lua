-- Imitation générique de l'API WoW pour les simulations hors jeu (Lua 5.1).
-- Usage : local W = dofile("tests/wowmock.lua")("fr") ; W.load("ForeverGFX") ; W.fire("ADDON_LOADED", "ForeverGFX") …
local rprint = print
return function(LANG)
  local W = { clock = 1000.0, timers = {}, printed = {}, cvars = {}, frames = {} }
  local noop = function() end

  local NUMERIC = { GetWidth = 300, GetHeight = 20, GetLeft = 100, GetRight = 400, GetTop = 600, GetBottom = 300,
                    GetFrameLevel = 5, GetStringHeight = 14, GetStringWidth = 80, GetNumPoints = 1, GetValue = 0,
                    GetEffectiveScale = 1, GetScale = 1, GetAlpha = 1, GetVerticalScroll = 0, GetVerticalScrollRange = 0,
                    GetNumLines = 0, GetCursorPosition = 0, GetID = 1, GetNumLetters = 0, GetLineHeight = 14 }
  local METHOD_PREFIXES = { "Set", "Get", "Is", "Has", "Enable", "Disable", "Register", "Unregister", "Clear", "Add", "Start",
                            "Stop", "Play", "Lock", "Unlock", "Highlight", "Click", "Raise", "Lower", "Scroll", "Update", "Refresh",
                            "Insert", "Remove", "Can", "Toggle", "Release", "Apply", "Adjust", "Fade", "Flash", "Cancel", "Reset",
                            "Move", "Resize", "Clamp", "Anchor", "Attach", "Init", "Layout", "Mark", "Wrap", "Draw" }
  local function Obj(name)
    local o = { scripts = {}, shown = false, _text = "", checked = false, value = 0, points = {} }
    if name then _G[name] = o end
    W.frames[#W.frames + 1] = o
    return setmetatable(o, { __index = function(t, k)
      local m = ({
        SetScript = function(self, n, f) self.scripts[n] = f end,
        GetScript = function(self, n) return self.scripts[n] end,
        HookScript = function(self, n, f) local old = self.scripts[n]; self.scripts[n] = function(...) if old then old(...) end f(...) end end,
        Show = function(self) local was = self.shown; self.shown = true; if not was and self.scripts.OnShow then self.scripts.OnShow(self) end end,
        Hide = function(self) local was = self.shown; self.shown = false; if was and self.scripts.OnHide then self.scripts.OnHide(self) end end,
        SetShown = function(self, v) if v then self:Show() else self:Hide() end end,
        IsShown = function(self) return self.shown end,
        IsVisible = function(self) return self.shown end,
        SetText = function(self, s) self._text = s; if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end end,
        GetText = function(self) return self._text end,
        SetChecked = function(self, v) self.checked = v and true or false end,
        GetChecked = function(self) return self.checked end,
        SetValue = function(self, v) self.value = v; if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v) end end,
        GetValue = function(self) return self.value end,
        GetMinMaxValues = function() return 0, 10 end,
        GetPoint = function() return "CENTER", nil, "CENTER", 0, 0 end,
        GetParent = function() return _G.UIParent end,
        GetName = function() return name end,
        GetRegions = function() return end,
        GetChildren = function() return end,
        GetFontObject = function() return {} end,
        GetFont = function() return "font", 12 end,
        CreateFontString = function(self, n) return Obj(n) end,
        CreateTexture = function(self, n) return Obj(n) end,
        CreateLine = function(self, n) return Obj(n) end,
        CreateAnimationGroup = function() return Obj() end,
        CreateAnimation = function() return Obj() end,
        GetTexture = function() return "" end,
        IsMouseOver = function() return false end,
        HasFocus = function() return false end,
        IsEnabled = function() return true end,
      })[k]
      if m then return m end
      if NUMERIC[k] then return function() return NUMERIC[k] end end
      -- méthodes inconnues -> fonction vide ; sous-éléments inconnus (Instructions, Label…) -> nil
      local ks = tostring(k)
      for _, prefix in ipairs(METHOD_PREFIXES) do
        if ks:sub(1, #prefix) == prefix then return noop end
      end
      return nil
    end })
  end
  W.Obj = Obj

  _G.CreateFrame = function(_, name, parent, template)
    local f = Obj(name)
    -- éléments des modèles courants
    f.Text = Obj(name and (name .. "Text") or nil)
    f.text = f.Text
    f.Left, f.Right, f.Middle = Obj(), Obj(), Obj()
    f.ScrollBar = Obj()
    if template and template:find("ScrollFrame") then f.ScrollBar = Obj() end
    if name then _G[name .. "Low"], _G[name .. "High"] = Obj(), Obj() end
    return f
  end
  _G.UIParent, _G.Minimap, _G.GameTooltip, _G.WorldFrame = Obj("UIParent"), Obj("Minimap"), Obj("GameTooltip"), Obj("WorldFrame")
  _G.ItemRefTooltip, _G.MacroFrame, _G.SettingsPanel, _G.DEFAULT_CHAT_FRAME = Obj(), Obj(), Obj(), Obj()
  _G.DEFAULT_CHAT_FRAME.AddMessage = function(_, s) W.printed[#W.printed + 1] = s end
  _G.UISpecialFrames, _G.StaticPopupDialogs, _G.SlashCmdList = {}, {}, {}
  W.popups = {}
  _G.StaticPopup_Show = function(n, a, b, data) W.popups[#W.popups + 1] = { n, a, b, data } end
  _G.YES, _G.NO, _G.CANCEL, _G.OKAY = "Oui", "Non", "Annuler", "OK"
  _G.ChatFontNormal, _G.GameFontNormal, _G.GameFontHighlight = {}, {}, {}
  _G.tinsert, _G.tremove = table.insert, table.remove
  _G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
  _G.CopyTable = function(t) local c = {}; for k, v in pairs(t) do c[k] = (type(v) == "table") and _G.CopyTable(v) or v end; return c end
  _G.strtrim = function(s) return (s or ""):match("^%s*(.-)%s*$") end
  _G.date, _G.time = os.date, os.time
  _G.print = function(...) local t = {}; for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end; W.printed[#W.printed + 1] = table.concat(t, " ") end
  _G.GetLocale = function() return LANG == "en" and "enUS" or "frFR" end
  _G.GetBuildInfo = function() return "1.16.0", "60000", "Nov 1 2026", 16001 end
  _G.GetTime = function() return W.clock end
  _G.GetFramerate = function() return 90 end
  _G.GetCursorPosition = function() return 0, 0 end
  _G.InCombatLockdown = function() return W.combat == true end
  _G.IsShiftKeyDown, _G.IsControlKeyDown, _G.IsAltKeyDown = function() return false end, function() return false end, function() return false end
  _G.IsInInstance = function() return W.inInstance == true, W.instanceType or "none" end
  _G.IsResting = function() return W.resting == true end
  _G.GetRealZoneText = function() return W.zone or "Hurlevent" end
  _G.UnitClass = function() return W.className or "Prêtre", W.class or "PRIEST" end
  _G.UnitLevel = function() return W.level or 30 end
  _G.UnitName = function() return "Machin" end
  _G.UnitRace = function() return "Humain", "Human" end
  _G.UnitFactionGroup = function() return "Alliance" end
  _G.GetRealmName = function() return "Forever" end
  _G.GetAddOnMetadata = function(_, f) return f == "Version" and "test" or nil end
  _G.IsAddOnLoaded = function() return false end
  _G.C_AddOns = { IsAddOnLoaded = function() return false end, GetAddOnMetadata = _G.GetAddOnMetadata }
  _G.HideUIPanel, _G.ShowUIPanel = noop, noop
  _G.ConsoleExec = function(s) W.lastConsole = s end
  _G.RestartGx = function() W.restartGx = (W.restartGx or 0) + 1 end
  _G.C_Timer = {
    After = function(s, f) W.timers[#W.timers + 1] = { at = W.clock + s, f = f } end,
    NewTicker = function(s, f) local t = { cancel = false }; t.Cancel = function() t.cancel = true end
      local function tick() if not t.cancel then f(t); W.timers[#W.timers + 1] = { at = W.clock + s, f = tick } end end
      W.timers[#W.timers + 1] = { at = W.clock + s, f = tick }; return t end,
    NewTimer = function(s, f) local t = { Cancel = noop }; W.timers[#W.timers + 1] = { at = W.clock + s, f = f }; return t end,
  }
  function W.run(dt)
    local target = W.clock + (dt or 1)
    while true do
      local nextT, idx
      for i, t in ipairs(W.timers) do if t.at <= target and (not nextT or t.at < nextT.at) then nextT, idx = t, i end end
      if not nextT then break end
      table.remove(W.timers, idx)
      W.clock = math.max(W.clock, nextT.at)
      nextT.f()
    end
    W.clock = target
  end
  -- variables du client (CVars)
  _G.C_CVar = {
    GetCVar = function(n) return W.cvars[n] end,
    SetCVar = function(n, v) if W.cvars[n] == nil then return false end W.cvars[n] = tostring(v); return true end,
    GetCVarDefault = function(n) return W.cvarDefaults and W.cvarDefaults[n] end,
    GetCVarInfo = function(n) local v = W.cvars[n]; if v == nil then return nil end return v, (W.cvarDefaults or {})[n] or v end,
  }
  _G.GetCVar, _G.SetCVar, _G.GetCVarInfo = _G.C_CVar.GetCVar, _G.C_CVar.SetCVar, _G.C_CVar.GetCVarInfo
  _G.GetCVarBool = function(n) return W.cvars[n] == "1" end
  _G.ConsoleGetAllCommands = function()
    local t = {}
    for n in pairs(W.cvars) do t[#t + 1] = { command = n, commandType = 0 } end
    return t
  end
  _G.Enum = { ConsoleCommandType = { Cvar = 0 } }

  W.addons = {}
  function W.load(addon)          -- chaque addon a son propre espace (comme dans le jeu)
    local ns = {}
    local toc = io.open(addon .. "/" .. addon .. ".toc"):read("*a")
    for file in toc:gmatch("\n([%w_]+%.lua)") do
      local chunk = assert(loadfile(addon .. "/" .. file))
      chunk(addon, ns)
    end
    W.addons[addon] = ns
    return ns
  end
  -- envoie un événement à toutes les fenêtres qui ont un gestionnaire OnEvent
  function W.fire(event, ...)
    for _, f in ipairs(W.frames) do
      if f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
  end
  function W.check(c, msg) if not c then error("ÉCHEC : " .. msg, 2) end rprint("ok  " .. msg) end
  W.rprint = rprint
  return W
end
