import Observation

/// Navigation state for the status bar panel. Owned by AppDelegate rather
/// than view-local @State so the panel can reset it when it closes through
/// any path (status-item toggle, outside click), not just the in-view Back
/// button — the hosted SwiftUI view outlives every close.
@MainActor
@Observable
final class PanelNavigation {
  var showKeyboardList = false
}
