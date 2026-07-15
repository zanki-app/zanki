import AppKit
import SwiftUI

final class StatusBarController: NSObject {
    private let item: NSStatusItem
    private let popover = NSPopover()
    private let state: AppState

    init(state: AppState, onRefresh: @escaping () -> Void) {
        self.state = state
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        popover.behavior = .transient
        popover.appearance = NSAppearance(named: .darkAqua)  // ダーク地のデザインなのでOS設定によらずダーク固定
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(state: state, onRefresh: onRefresh)
        )
        render()
    }

    /// state の内容をメニューバーへ反映する
    func render() {
        guard let button = item.button else { return }
        button.attributedTitle = NSAttributedString(string: "")
        button.image = StatusRenderer.image(for: state.snapshot, errorText: state.errorText)
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
        }
    }
}
