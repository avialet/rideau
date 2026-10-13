import Foundation
import RideauCore

private func app(_ pid: Int32, _ id: String?, _ name: String, rank: Int? = nil, hidden: Bool = false,
                 regular: Bool = true, fullScreen: Bool = false) -> AppSnapshot {
    AppSnapshot(pid: pid, bundleID: id, name: name, isHidden: hidden, isRegular: regular,
                isFullScreen: fullScreen, rank: rank)
}

private let policy = CurtainPolicy(keepFrontmost: true, alwaysVisible: ["us.zoom.xos"], ownPID: 99)

private let running: [AppSnapshot] = [
    app(10, "com.apple.Safari", "Safari", rank: 0),
    app(11, "com.apple.mail", "Mail", rank: 2),
    app(12, "com.apple.MobileSMS", "Messages", rank: 1),
    app(13, "com.apple.Notes", "Notes", hidden: true),
    app(14, "us.zoom.xos", "zoom.us", rank: 3),
    app(15, "com.example.agent", "Agent", regular: false),
    app(99, "fr.vialet.rideau", "Rideau"),
    app(16, "fr.vialet.vialet", "Vialet"),
    app(17, "com.apple.finder", "Finder"),
    app(18, "com.apple.Keynote", "Keynote", fullScreen: true),
]

let stageTests: [Test] = [
    Test("planLower garde l'app au premier plan, les toujours visibles, Rideau, Vialet, le plein ecran") {
        let plan = Stage.planLower(apps: running, frontmostPID: 10, policy: policy)
        expectEqual(plan.map(\.pid), [12, 11, 17])
    },
    Test("planLower ignore les apps deja masquees et non regulieres") {
        let plan = Stage.planLower(apps: running, frontmostPID: 10, policy: policy)
        expect(!plan.contains { $0.pid == 13 || $0.pid == 15 })
    },
    Test("planLower : ordre de l'avant vers l'arriere, apps sans fenetre a la fin, par nom") {
        let apps = [app(1, "a", "Zeta"), app(2, "b", "Beta", rank: 4), app(3, "c", "Alpha"), app(4, "d", "Mu", rank: 1)]
        let plan = Stage.planLower(apps: apps, frontmostPID: nil, policy: policy)
        expectEqual(plan.map(\.pid), [4, 2, 3, 1])
    },
    Test("planLower sans garder le premier plan masque aussi l'app active") {
        var p = policy
        p.keepFrontmost = false
        let plan = Stage.planLower(apps: running, frontmostPID: 10, policy: p)
        expectEqual(plan.map(\.pid), [10, 12, 11, 17])
    },
    Test("planLower masque le plein ecran si on le demande") {
        var p = policy
        p.keepFullScreen = false
        let plan = Stage.planLower(apps: running, frontmostPID: 10, policy: p)
        expect(plan.contains { $0.pid == 18 })
    },
    Test("planLower : jamais Rideau ni Vialet, meme sous un autre pid") {
        let apps = [app(5, "fr.vialet.rideau", "Rideau"), app(6, "fr.vialet.vialet", "Vialet")]
        expect(Stage.planLower(apps: apps, frontmostPID: nil, policy: policy).isEmpty)
    },
    Test("Backstage.lowered retient le premier plan et les apps dans l'ordre") {
        let plan = Stage.planLower(apps: running, frontmostPID: 10, policy: policy)
        let backstage = Backstage(loweredAt: Date(timeIntervalSince1970: 0), frontmost: running[0], hidden: plan)
        expectEqual(backstage.hidden.map(\.pid), [12, 11, 17])
        expectEqual(backstage.frontmost?.pid, 10)
        expectEqual(backstage.version, Backstage.currentVersion)
    },
    Test("planRaise : de l'arriere vers l'avant, apps sans rang d'abord") {
        let hidden = [app(12, "m", "Messages", rank: 1), app(11, "l", "Mail", rank: 2), app(17, "f", "Finder")]
        let backstage = Backstage(loweredAt: .now, frontmost: nil, hidden: hidden)
        let now = hidden.map { var a = $0; a.isHidden = true; return a }
        let plan = Stage.planRaise(backstage: backstage, running: now)
        expectEqual(plan.unhide.map(\.pid), [17, 11, 12])
        expect(plan.activate == nil)
        expect(plan.gone.isEmpty)
    },
    Test("planRaise ignore les apps quittees, relancees sous un autre pid ou deja reaffichees") {
        let hidden = [app(1, "a", "A", rank: 0), app(2, "b", "B", rank: 1), app(3, "c", "C", rank: 2)]
        let backstage = Backstage(loweredAt: .now, frontmost: nil, hidden: hidden)
        let now = [app(1, "a", "A", hidden: false), app(22, "b", "B", hidden: true), app(3, "c", "C", hidden: true)]
        let plan = Stage.planRaise(backstage: backstage, running: now)
        expectEqual(plan.unhide.map(\.pid), [3])
        expectEqual(plan.gone.map(\.pid), [2])
    },
    Test("planRaise : un pid reutilise par une autre app n'est pas reaffiche") {
        let backstage = Backstage(loweredAt: .now, frontmost: nil, hidden: [app(1, "a", "A")])
        let plan = Stage.planRaise(backstage: backstage, running: [app(1, "z", "Z", hidden: true)])
        expect(plan.unhide.isEmpty)
        expectEqual(plan.gone.map(\.pid), [1])
    },
    Test("planRaise reactive l'app du premier plan seulement si Rideau l'avait masquee") {
        let front = app(10, "s", "Safari", rank: 0)
        let hidden = [front, app(11, "m", "Mail", rank: 1)]
        let masked = hidden.map { var a = $0; a.isHidden = true; return a }
        let plan = Stage.planRaise(backstage: Backstage(loweredAt: .now, frontmost: front, hidden: hidden), running: masked)
        expectEqual(plan.activate?.pid, 10)
        expectEqual(plan.unhide.map(\.pid), [11, 10])
        let kept = Stage.planRaise(backstage: Backstage(loweredAt: .now, frontmost: front, hidden: [hidden[1]]),
                                   running: [front, masked[1]])
        expect(kept.activate == nil)
    },
    Test("Backstage.releasing retire une app que l'utilisateur a reaffichee") {
        let backstage = Backstage(loweredAt: .now, frontmost: nil, hidden: [app(1, "a", "A"), app(2, "b", "B")])
        expectEqual(backstage.releasing(pid: 1).hidden.map(\.pid), [2])
        expectEqual(backstage.releasing(pid: 7).hidden.count, 2)
    },
    Test("Backstage.keeping ne garde que les apps vraiment masquees") {
        let backstage = Backstage(loweredAt: .now, frontmost: nil, hidden: [app(1, "a", "A"), app(2, "b", "B")])
        let kept = backstage.keeping(pids: [2])
        expectEqual(kept.hidden.map(\.pid), [2])
    },
    Test("CurtainPolicy : visios par defaut toujours visibles") {
        expect(CurtainPolicy.defaultAlwaysVisible.contains("us.zoom.xos"))
        expect(CurtainPolicy.defaultAlwaysVisible.contains("com.apple.FaceTime"))
        expect(!CurtainPolicy.defaultAlwaysVisible.contains("com.tinyspeck.slackmacgap"))
    },
]
