/// 1回の更新で並行に走る取得（Claude と Codex）から、外への送信を1回だけ出すための数え役。
/// 2026-11-16。以前は取得ごとに送っていて1分に2回 Supabase に書き、ログの取り込み量を倍にしていた。
/// - 両方の取得が終わったら送る
/// - 片方が遅い・終わらないときは、期限（AppDelegate の sendDeadline）で取得済みの状態を送る
/// - どちらの道でも1つの更新につき送るのは1回。期限のあとに届いた取得では送らない
/// - 途中で次の更新が始まったら、古い更新はもう送らない（次の更新が送る）
struct RefreshGate {
    private(set) var round = 0
    private var pending = 0
    private var sent = false

    /// 新しい更新を始める。戻り値はこの更新の番号。
    mutating func start(fetches: Int) -> Int {
        round += 1
        pending = fetches
        sent = false
        return round
    }

    /// 取得が1つ終わった。この更新の最後の1つで、まだ送っていなければ true（ここで送る）。
    mutating func finish(round finished: Int) -> Bool {
        guard finished == round, pending > 0 else { return false }
        pending -= 1
        return pending == 0 && claim()
    }

    /// 期限が来た。この更新でまだ送っていなければ true（取得済みの状態で送る）。
    mutating func expire(round expired: Int) -> Bool {
        guard expired == round else { return false }
        return claim()
    }

    private mutating func claim() -> Bool {
        guard !sent else { return false }
        sent = true
        return true
    }
}
