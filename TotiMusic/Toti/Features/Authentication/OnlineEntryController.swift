import UIKit

@MainActor
extension TotiScreen {
    /// Keep empty lists refreshable without adding a permanent action to their content.
    func installOnlinePullToRefresh(on scrollView: UIScrollView) {
        guard store.isOnlineMode else { return }
        scrollView.alwaysBounceVertical = true
        // Some surfaces already refresh a specific room or conversation.
        guard scrollView.refreshControl == nil else { return }
        let control = UIRefreshControl()
        control.tintColor = TotiTheme.plum
        control.accessibilityLabel = "Refresh content"
        control.addAction(UIAction { [weak self, weak control] _ in
            guard let self, self.isAccountContextCurrent else {
                control?.endRefreshing()
                return
            }
            Task {
                defer { control?.endRefreshing() }
                guard self.isAccountContextCurrent else { return }
                _ = await self.store.refreshOnline()
            }
        }, for: .valueChanged)
        scrollView.refreshControl = control
    }

    func appendOnlineRetry(to column: UIStackView, error: String?) {
        guard store.isOnlineMode, let error else { return }
        column.addArrangedSubview(label(error, 14, TotiTheme.muted))
        let retry = actionButton("Retry", icon: .refresh) { [weak self] in
            guard let self, self.isAccountContextCurrent else { return }
            Task {
                guard self.isAccountContextCurrent else { return }
                _ = await self.store.refreshOnline()
            }
        }
        retry.isEnabled = !store.onlineReadInProgress && !store.onlineMutationInProgress
        column.addArrangedSubview(retry)
    }
}

@MainActor
extension StackScreen {
    /// Only recovery and pagination actions occupy space in the list.
    func appendOnlineControls(to column: UIStackView? = nil) {
        guard store.isOnlineMode else { return }
        installOnlinePullToRefresh(on: scroll)
        let destination = column ?? content
        appendOnlineRetry(to: destination, error: store.onlineReadError)
        if store.onlineHasMore {
            destination.addArrangedSubview(actionButton("Load more", icon: .forward) { [weak self] in
                guard let self else { return }
                Task { await self.store.loadMoreOnline() }
            })
        }
    }
}
