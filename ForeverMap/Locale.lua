local _, ns = ...

local fr = {
  title = "ForeverMap — tes communautés sur la carte",
  members = "Membres", options = "Options",
  colName = "Nom", colZone = "Zone", colDist = "Distance", colSeen = "Vu",
  none = "Personne pour l'instant. Les membres apparaissent quand ils ont ForeverMap et sont connectés.",
  noClub = "Choisis au moins une communauté dans les options (icône engrenage).",
  inInstance = "en donjon / raid", hiddenSelf = "Tu es invisible : ta position n'est pas envoyée.",
  yards = "%d m", far = "autre zone", ago = "il y a %d s", agoMin = "il y a %d min",
  waypoint = "Repère", waypointSet = "Repère posé vers %s.", waypointNone = "Pas de position pour %s.",
  optClubs = "Partager avec ces communautés :", optGuild = "Partager aussi avec ma guilde",
  optHidden = "Me rendre invisible (je vois les autres, ils ne me voient pas)",
  optMinimap = "Points sur la minicarte", optWorld = "Points sur la carte du monde",
  noCommunities = "Tu n'es dans aucune communauté de personnages.",
  tipLevel = "Niveau %d %s", tipZone = "%s", tipSeen = "Position d'il y a %d s",
  shared = "Partage avec : %s", sharedNone = "Partage : aucune communauté choisie",
  helpText = "Commandes : /fmap (fenêtre), /fmap invisible, /fmap diag",
  hiddenOn = "Invisible : ta position n'est plus envoyée.", hiddenOff = "Visible : ta position est de nouveau partagée.",
  diagTitle = "Diagnostic ForeverMap (copie ce texte)",
}

local en = {
  title = "ForeverMap — your communities on the map",
  members = "Members", options = "Options",
  colName = "Name", colZone = "Zone", colDist = "Distance", colSeen = "Seen",
  none = "Nobody yet. Members show up when they have ForeverMap and are online.",
  noClub = "Pick at least one community in the options (gear icon).",
  inInstance = "in a dungeon / raid", hiddenSelf = "You are invisible: your position is not sent.",
  yards = "%d yd", far = "other zone", ago = "%ds ago", agoMin = "%d min ago",
  waypoint = "Waypoint", waypointSet = "Waypoint set to %s.", waypointNone = "No position for %s.",
  optClubs = "Share with these communities:", optGuild = "Also share with my guild",
  optHidden = "Make me invisible (I see others, they don't see me)",
  optMinimap = "Dots on the minimap", optWorld = "Dots on the world map",
  noCommunities = "You are not in any character community.",
  tipLevel = "Level %d %s", tipZone = "%s", tipSeen = "Position from %ds ago",
  shared = "Sharing with: %s", sharedNone = "Sharing: no community selected",
  helpText = "Commands: /fmap (window), /fmap invisible, /fmap diag",
  hiddenOn = "Invisible: your position is no longer sent.", hiddenOff = "Visible: your position is shared again.",
  diagTitle = "ForeverMap diagnostic (copy this text)",
}

ns.lang = (GetLocale() == "frFR") and "fr" or "en"
ns.L = setmetatable({}, { __index = function(_, k) local t = (ns.lang == "en") and en or fr; return t[k] or fr[k] or k end })
