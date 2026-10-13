# Tests

Les Command Line Tools n'embarquent ni XCTest ni Swift Testing. En attendant
Xcode, les tests du noyau vivent dans
`Packages/RideauCore/Sources/rideaucore-check/` et tournent avec :

    make test        # = swift run rideaucore-check [filtre]

API du harnais (`Check.swift`) : `Test("nom") { ... }`, `expect(cond)`,
`expectEqual(a, b)`, `expectThrows { ... }`.

Règle : toute fonction du noyau a un test, écrit avant le code, que l'on a vu
échouer puis réussir.

## Migration vers Swift Testing (dès que Xcode est installé)

1. Déplacer les fichiers de tests vers `Packages/RideauCore/Tests/RideauCoreTests/`.
2. Remplacer `Test("x") {` par `@Test func x() throws {`, `expect(` par
   `#expect(`, `expectEqual(a, b)` par `#expect(a == b)`.
3. Supprimer `Check.swift`, `main.swift` et la cible `rideaucore-check`,
   ajouter un `testTarget` dans `Package.swift`.

## Essais réels sans déranger le Mac (DEBUG)

Masquer les apps de la session est visible : on limite un essai à des apps lancées pour lui, sans toucher aux
préférences ni à l'état réel.

    open -g -a TextEdit essai.txt; open -g -a Calculator
    open -g --env RIDEAU_STATE_PATH=/tmp/rideau-essai/scene.json \
         --env RIDEAU_ONLY_BUNDLES=com.apple.TextEdit,com.apple.calculator \
         --env RIDEAU_TRACE=/tmp/rideau-essai/trace.log \
         build/Rideau.app --args -RideauCoverDesktop NO
    open -g rideau://baisser    # puis rideau://lever, kill -9 puis relance, kill -TERM...

`RIDEAU_ONLY_BUNDLES` : seules ces apps sont vues par Rideau. `RIDEAU_TRACE` : journal des plans (masquées,
refus, réaffichées, réactivée). Les arguments `-Rideau<Cle> NO|YES` remplacent un réglage sans l'écrire.
