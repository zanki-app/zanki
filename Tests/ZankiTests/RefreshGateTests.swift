import Testing
@testable import Zanki

struct RefreshGateTests {
    @Test func 二つとも終わったときだけ送る() {
        var gate = RefreshGate()
        let round = gate.start(fetches: 2)
        #expect(gate.finish(round: round) == false)
        #expect(gate.finish(round: round) == true)
        #expect(gate.finish(round: round) == false)
        #expect(gate.expire(round: round) == false)
    }

    @Test func 期限が来たら取得済みで送り_あとから届いても二度送らない() {
        var gate = RefreshGate()
        let round = gate.start(fetches: 2)
        #expect(gate.finish(round: round) == false)
        #expect(gate.expire(round: round) == true)
        #expect(gate.finish(round: round) == false)
    }

    @Test func 毎回片方が周期より遅くても更新ごとに1回は送る() {
        var gate = RefreshGate()
        let first = gate.start(fetches: 2)
        #expect(gate.finish(round: first) == false)   // Codex は1秒で終わる
        #expect(gate.expire(round: first) == true)    // Claude は65秒かかるので期限で送る
        let second = gate.start(fetches: 2)
        #expect(gate.finish(round: first) == false)   // 前の更新の Claude が遅れて届いても送らない
        #expect(gate.finish(round: second) == false)
        #expect(gate.expire(round: second) == true)
    }

    @Test func 途中で次の更新が始まったら古い更新は送らない() {
        var gate = RefreshGate()
        let old = gate.start(fetches: 2)
        #expect(gate.finish(round: old) == false)
        let new = gate.start(fetches: 2)
        #expect(gate.finish(round: old) == false)
        #expect(gate.expire(round: old) == false)
        #expect(gate.finish(round: new) == false)
        #expect(gate.finish(round: new) == true)
    }
}
