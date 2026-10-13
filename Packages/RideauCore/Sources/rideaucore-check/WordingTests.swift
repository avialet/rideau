import RideauCore

let wordingTests: [Test] = [
    Test("coulisses : pluriel et zero") {
        expectEqual(Wording.backstage(0), "Aucune app en coulisses")
        expectEqual(Wording.backstage(1), "1 app en coulisses")
        expectEqual(Wording.backstage(7), "7 apps en coulisses")
    },
    Test("retour en scene") {
        expectEqual(Wording.returned(1), "1 app de retour")
        expectEqual(Wording.returned(3), "3 apps de retour")
        expectEqual(Wording.returned(0), "Rien \u{00E0} r\u{00E9}afficher")
    },
    Test("apercu avant de baisser") {
        expectEqual(Wording.preview(0), "Rien \u{00E0} masquer pour l\u{2019}instant")
        expectEqual(Wording.preview(1), "1 app passera en coulisses")
        expectEqual(Wording.preview(4), "4 apps passeront en coulisses")
    },
]
