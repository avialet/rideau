<div align="center">

# Rideau

**Le désordre passe en coulisses.**

[![Dernière version](https://img.shields.io/github/v/release/avialet/rideau?color=8E1E80&label=version)](https://github.com/avialet/rideau/releases/latest)
[![macOS 26](https://img.shields.io/badge/macOS-26%20Tahoe-F0A020)](#installation)
[![Licence MIT](https://img.shields.io/badge/licence-MIT-2E9D6E)](LICENSE)

[**Télécharger le DMG**](https://github.com/avialet/rideau/releases/latest) · [Site](https://rideau.vialet.app)

</div>

## Ce que fait Rideau

Avant un partage d'écran ou une démo, un appui sur **⌥⇧⌘Espace** baisse le rideau ; un second remet tout à l'identique.

- **Les autres apps passent en coulisses.** Mail, Messages et le reste se masquent ; l'app que vous présentez reste devant, les visios (Zoom, Teams, Webex, FaceTime) restent visibles.
- **Le bureau se tait.** Icônes et widgets disparaissent sous votre fond d'écran (ou une couleur unie), sur chaque écran, sans toucher au Finder.
- **Tout revient exactement.** Seules les apps masquées par Rideau reviennent, dans leur ordre ; celles que vous aviez masquées vous-même restent masquées. Même après un plantage, Rideau propose de lever le rideau à son lancement.
- **Sans autorisation.** Ni Accessibilité, ni Enregistrement de l'écran. Aucun compte, aucun serveur, aucune télémétrie.

## Installation

**Prérequis :** un Mac Apple Silicon sous macOS 26 (Tahoe) ou plus récent.

1. Téléchargez `Rideau-X.Y.Z.dmg` depuis la [dernière version](https://github.com/avialet/rideau/releases/latest).
2. Ouvrez le DMG et glissez **Rideau** dans **Applications**, puis double-cliquez.
3. Au premier lancement, macOS indique qu'il n'a pas pu vérifier l'app (elle est signée
   sans certificat Apple Developer). Cliquez **Terminé** (pas « Placer dans la corbeille »),
   ouvrez **Réglages Système › Confidentialité et sécurité**, descendez jusqu'à
   « Rideau a été bloqué… », cliquez **Ouvrir quand même**, authentifiez-vous, puis **Ouvrir**.
   Cette étape n'a lieu qu'une fois par téléchargement. Dans le Terminal :

   ```bash
   xattr -d com.apple.quarantine /Applications/Rideau.app
   ```

Pour vérifier le fichier téléchargé, comparez son empreinte avec celle publiée dans la même version :

```bash
shasum -a 256 -c Rideau-X.Y.Z.dmg.sha256
```

### Mises à jour

Rideau consulte une fois par jour la dernière version publiée sur GitHub. S'il en
existe une plus récente, un clic la télécharge, **vérifie son empreinte SHA-256**, contrôle
l'application qu'elle contient, la remplace et relance l'app. Si une étape échoue, l'app
installée n'est pas touchée. La recherche automatique se désactive dans **Réglages › Mises à jour**.

Le seul échange réseau de Rideau est cette lecture de la version publiée. Aucune donnée n'est envoyée.

## Notice

- **Raccourci global** (⌥⇧⌘Espace par défaut, modifiable dans les Réglages) : baisse le rideau, puis le lève.
- **Scène** (fenêtre principale) : l'état du rideau, les apps qui passeront en coulisses, et ce que le rideau cache :
  fenêtres (garder l'app au premier plan, laisser les apps en plein écran), apps toujours visibles, bureau
  (fond d'écran ou couleur unie), notifications.
- **Rideau baissé** : l'icône du rideau fermé s'affiche dans la barre des menus (même quand Vialet rassemble les apps) ; un clic le lève.
- **Notifications** : macOS les coupe pendant un partage d'écran si l'option « Autoriser les notifications lors de la
  recopie ou du partage de l'écran » est désactivée (Réglages Système › Notifications) ; la Scène y mène.
- Fermer la fenêtre ne quitte pas l'app : le raccourci et l'icône de la barre des menus restent actifs.
  **⌘Q** quitte vraiment, et lève toujours le rideau.
- Liens et automatisations (Raccourcis, Vialet) : `rideau://basculer`, `rideau://baisser`, `rideau://lever` ;
  `rideau://` ouvre la Scène.
- **À propos de Rideau** (menu de l'app ou de la barre des menus) : version, licence MIT, liens vers le site et le code source.

### Vos données

Pas de base de données. Tant que le rideau est baissé, la liste des apps à réafficher est gardée dans :

```text
~/Library/Application Support/Rideau/scene.json
```

Le fichier disparaît quand le rideau se lève. Les réglages vivent dans les préférences (`fr.vialet.rideau`).

## Compiler depuis les sources

Il faut Swift 6.3 ou plus récent (les Command Line Tools suffisent, Xcode n'est pas nécessaire).

```bash
git clone https://github.com/avialet/rideau.git
cd rideau
make test      # tests du noyau
make run       # construit et lance l'app
make install   # installe dans /Applications
make release   # fabrique build/Rideau-X.Y.Z.dmg et son empreinte
```

L'icône et l'habillage du DMG viennent de l’outillage commun des apps vialet.app
(`scripts/plaque.swift`), cloné à côté de l'app (sinon `VIALETAPPS_PATH=<chemin>`) :

```bash
make icon         # icône : plaque aux teintes de App/Brand.swift, son glyphe (initiale s'il est vide)
make dmg-layout   # fond et disposition de la fenêtre du DMG, dans scripts/dmg (à committer)
```

| Dossier | Contenu |
|---|---|
| `Packages/RideauCore` | Noyau sans interface : plans de masquage et de restitution, état sauvegardé, machine du rideau |
| `Rideau` | L'application SwiftUI ; `App/Brand.swift` porte son identité |
| `scripts` | Assemblage de l'app et du DMG ; `scripts/dmg` : fond et disposition de sa fenêtre |
| `docs` | [Publier une version](docs/publier-une-version.md), [tests](docs/tests.md), notes de version |

Le socle commun (mises à jour, thème, raccourci global, panneau flottant) vient de
[VialetKit](https://github.com/avialet/vialetkit). Publier une version ne demande que de
modifier `VERSION` puis de pousser un tag `vX.Y.Z` : la CI construit et publie le DMG, et
les utilisateurs reçoivent la mise à jour dans l'app.

## Confidentialité

Rideau ne collecte rien et ne lit ni le titre ni le contenu des fenêtres (seulement leur ordre). La seule requête
réseau est la lecture de la dernière version publiée sur GitHub, que vous pouvez désactiver.

## Licence

[MIT](LICENSE) © 2026 Aurélien Vialet
