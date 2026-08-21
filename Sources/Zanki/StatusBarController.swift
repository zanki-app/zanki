import AppKit
import SwiftUI

final class StatusBarController: NSObject, NSPopoverDelegate {
    private let item: NSStatusItem
    private let popover = NSPopover()
    private let state: AppState
    private var outsideClickMonitor: Any?

    init(state: AppState, onRefresh: @escaping () -> Void) {
        self.state = state
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(state: state, onRefresh: onRefresh)
        )
        // 配色はダーク固定（OS設定には追従しない）
        popover.appearance = NSAppearance(named: .darkAqua)
        render()
    }

    /// state の内容をメニューバーへ反映する
    func render() {
        guard let button = item.button else { return }
        button.attributedTitle = NSAttributedString(string: "")
        button.image = StatusRenderer.image(
            for: state.snapshot, errorText: state.errorText,
            codexSnapshot: state.codexSnapshot, codexErrorText: state.codexErrorText,
            isCodexAvailable: state.isCodexAvailable, theme: state.theme)
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = item.button {
            // SwiftUI側のサイズ報告が表示に間に合わずデフォルト320x320で位置決めされ
            // 隙間ができるため、表示直前に実サイズをcontentSizeへ明示する
            if let contentView = popover.contentViewController?.view {
                contentView.layoutSubtreeIfNeeded()
                popover.contentSize = contentView.fittingSize
            }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            // .transient の自動クローズはポップオーバー内でNSMenuを一度でも開くと
            // 効かなくなる（AppKit内部のイベント監視が止まる・keyは保持されたまま）ため、
            // 外側クリックの検知と閉じる処理は自前のグローバル監視で行う
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] _ in
                self?.popover.performClose(nil)
            }
        }
    }

    /// transient・自前監視のどちらで閉じても必ずここを通るので、監視の解除はここに集約する
    func popoverDidClose(_ notification: Notification) {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }
}
