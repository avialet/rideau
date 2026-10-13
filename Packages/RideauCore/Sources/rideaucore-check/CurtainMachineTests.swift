import Foundation
import RideauCore

private let t0 = Date(timeIntervalSince1970: 1000)

let curtainMachineTests: [Test] = [
    Test("bascule : leve -> baisse -> baisse, puis leve") {
        var machine = CurtainMachine()
        expectEqual(machine.state, .raised)
        expectEqual(machine.toggle(now: t0), .lower)
        expectEqual(machine.state, .lowering)
        machine.finish()
        expectEqual(machine.state, .lowered)
        expectEqual(machine.toggle(now: t0.addingTimeInterval(1)), .raise)
        expectEqual(machine.state, .raising)
        machine.finish()
        expectEqual(machine.state, .raised)
    },
    Test("appuis repetes a moins de 250 ms ignores") {
        var machine = CurtainMachine()
        expectEqual(machine.toggle(now: t0), .lower)
        machine.finish()
        expect(machine.toggle(now: t0.addingTimeInterval(0.2)) == nil)
        expectEqual(machine.state, .lowered)
        expectEqual(machine.toggle(now: t0.addingTimeInterval(0.3)), .raise)
    },
    Test("pendant une transition, rien") {
        var machine = CurtainMachine()
        _ = machine.toggle(now: t0)
        expect(machine.toggle(now: t0.addingTimeInterval(1)) == nil)
        expect(machine.request(.raise, now: t0.addingTimeInterval(1)) == nil)
    },
    Test("demandes idempotentes : baisser un rideau baisse ne fait rien") {
        var machine = CurtainMachine()
        expect(machine.request(.raise, now: t0) == nil)
        expectEqual(machine.request(.lower, now: t0), .lower)
        machine.finish()
        expect(machine.request(.lower, now: t0.addingTimeInterval(1)) == nil)
        expectEqual(machine.request(.raise, now: t0.addingTimeInterval(1)), .raise)
    },
    Test("echec d'une baisse : retour a leve") {
        var machine = CurtainMachine()
        _ = machine.toggle(now: t0)
        machine.fail()
        expectEqual(machine.state, .raised)
    },
    Test("reprise apres plantage : baisse, a lever") {
        var machine = CurtainMachine(recovering: true)
        expectEqual(machine.state, .lowered)
        expect(machine.recovered)
        expectEqual(machine.toggle(now: t0), .raise)
        machine.finish()
        expect(!machine.recovered)
    },
]
