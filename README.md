<div align="center">

# Rideau

**Le désordre passe en coulisses.**

[![Dernière version](https://img.shields.io/github/v/release/avialet/rideau?color=8E1E80&label=version)](https://github.com/avialet/rideau/releases/latest)
[![macOS 26](https://img.shields.io/badge/macOS-26%20Tahoe-F0A020)](#installation)
[![Licence MIT](https://img.shields.io/badge/licence-MIT-2E9D6E)](LICENSE)

[**Télécharger le DMG**](https://github.com/avialet/rideau/releases/latest) · [Site](https://rideau.vialet.app)

</div>

## Ce que fait Rideau

<!-- a adapter : trois idees, une phrase chacune -->

- **Première idée.** Une phrase.
- **Deuxième idée.** Une phrase.
- **Rester chez vous.** Tout est stocké sur votre Mac. Aucun compte, aucun serveur, aucune télémétrie.

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

<!-- a adapter -->

- **Raccourci global** (⌃⌥⇧Espace par défaut, modifiable dans les Réglages) : affiche ou masque Rideau depuis n'importe quelle app.
- Fermer la fenêtre ne quitte pas l'app : le raccourci et l'icône de la barre des menus restent actifs. **⌘Q** quitte vraiment.
- Le lien `rideau://` ouvre la fenêtre principale.
- **À propos de Rideau** (menu de l'app ou de la barre des menus) : version, licence MIT, liens vers le site et le code source.

### Vos données

```text
~/Library/Application Support/Rideau/rideau.sqlite
```

Pour sauvegarder, copiez ce dossier. Pour repartir de zéro, quittez l'app et supprimez-le.

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
| `Packages/RideauCore` | Noyau sans interface : modèles, base SQLite ([GRDB](https://github.com/groue/GRDB.swift)), logique |
| `Rideau` | L'application SwiftUI ; `App/Brand.swift` porte son identité |
| `scripts` | Assemblage de l'app et du DMG ; `scripts/dmg` : fond et disposition de sa fenêtre |
| `docs` | [Publier une version](docs/publier-une-version.md), [tests](docs/tests.md), notes de version |

Le socle commun (mises à jour, thème, raccourci global, panneau flottant) vient de
[VialetKit](https://github.com/avialet/vialetkit). Publier une version ne demande que de
modifier `VERSION` puis de pousser un tag `vX.Y.Z` : la CI construit et publie le DMG, et
les utilisateurs reçoivent la mise à jour dans l'app.

## Confidentialité

Rideau ne collecte rien. Vos données ne quittent jamais votre Mac. La seule requête
réseau est la lecture de la dernière version publiée sur GitHub, que vous pouvez désactiver.

## Licence

[MIT](LICENSE) © 2026 Aurélien Vialet
