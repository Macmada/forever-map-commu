# Journal des versions

## 1.1.1
- **Plus de spam « Aucun joueur nommé … ne joue actuellement »** quand un membre se déconnecte : ce message est masqué quand il suit un envoi de l'addon, et le membre n'est plus contacté pendant 5 minutes (ou jusqu'à son retour en ligne) ; un contact qui ne donne plus de nouvelles depuis 2 minutes n'est plus contacté.
- **Noms en deux parties de WoW Forever** (prénom et nom, ex. « Alain Tendance ») : le nom complet est gardé, espace compris, pour les messages privés (pris de l'identifiant du joueur quand le jeu le donne) ; seul le royaume perd ses espaces.
- `/fmap diag` : noms de la communauté et nom visé pour chacun, membres notés absents.

## 1.1.0
- **Nouveau nom : ForeverMapCommu** (dossier `ForeverMapCommu`). Si l'ancienne version « ForeverMap » est encore installée, elle est désactivée automatiquement (message dans le chat) : tape `/reload`, puis supprime le dossier `Interface\AddOns\ForeverMap`. Les réglages repartent de zéro (toutes tes communautés partagées). Compatible avec les membres qui ont encore l'ancienne version 1.0.x.

## 1.0.2
- **L'un voyait l'autre, pas l'inverse** : quand un membre reçoit ta position, il te répond aussitôt avec la sienne, même si la liste de la communauté ne te montre pas connecté chez lui (état « inconnu » tant qu'elle n'est pas chargée). La liaison devient réciproque dès qu'un des deux voit l'autre.
- `/fmap diag` liste aussi les membres à qui l'addon répond.

## 1.0.1
- **Les membres ne se voyaient pas** (premier essai à deux : positions envoyées, jamais reçues) : le client de WoW Forever ne transmet pas les messages d'addon d'un canal personnalisé. La position part maintenant **en message privé d'addon à chaque membre connecté** de tes communautés (lus dans la liste de la communauté ; pas les membres hors ligne ni sur l'application mobile). Le canal caché reste en plus.
- `/fmap diag` montre aussi le résultat de chaque envoi, l'enregistrement du préfixe et les membres connectés vus par l'addon.

## 1.0.0
- Première version : membres de tes communautés (et de ta guilde en option) sur la carte du monde et la minicarte, liste `/fmap` avec distance et repère, mode invisible, aucune position en donjon ou en raid, diagnostic `/fmap diag`.
