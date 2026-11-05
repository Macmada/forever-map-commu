# ForeverMapCommu

Les membres de tes **communautés** (et de ta guilde, en option) sur la **carte du monde** et la **minicarte**, pour **WoW Forever**.

> Le jeu ne donne jamais aux addons la position d'un joueur hors de ton groupe : **chaque membre doit avoir ForeverMapCommu**. Chacun envoie sa propre position aux autres membres de la communauté, par un canal caché propre à l'addon.

## Installation

- **WowUp** : *Get Addons → Install from URL* → `https://github.com/Macmada/forever-map`
- **À la main** : télécharge `ForeverMapCommu-vX.zip` dans les [versions](https://github.com/Macmada/forever-map/releases) et décompresse-le dans `World of Warcraft\_forever_\Interface\AddOns`.

> Anciennement **ForeverMap** : si tu avais l'ancienne version, elle est désactivée automatiquement ; supprime ensuite le dossier `Interface\AddOns\ForeverMap`.

## Ce que ça fait

- Un **point de la couleur de sa classe** pour chaque membre, sur la carte du monde et sur la minicarte (à la bonne distance). Au survol : nom, niveau, zone, depuis quand ; un clic pose un **repère** (TomTom s'il est installé, sinon le repère du jeu).
- **`/fmap`** : la liste des membres (zone, distance, dernière position, bouton Repère).
- **Options** (engrenage) : les communautés avec qui partager (toutes au départ), la guilde, et **« me rendre invisible »** (tu vois les autres, ils ne te voient pas).
- **Jamais de position en donjon ou en raid** : les autres voient seulement « en donjon / raid ».
- `/fmap invisible` bascule l'invisibilité ; `/fmap diag` ouvre un diagnostic à copier si quelque chose ne marche pas.

Positions envoyées toutes les 5 s quand tu bouges, toutes les 30 s sinon. Rien n'est envoyé hors de tes communautés choisies.

---

**English** — Shows your community (and optionally guild) members on the world map and minimap in WoW Forever. Every member needs the addon (the game never gives addons the position of players outside your group). `/fmap` for the list, gear icon for options (communities, guild, invisible mode), `/fmap diag` for a diagnostic. No position is ever sent from dungeons or raids.
