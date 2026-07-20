import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItem: NSStatusItem!
  private var panel: StatusBarPanel!

  private let batteryState = BatteryState()
  private let appSettings = AppSettings()
  private let panelNavigation = PanelNavigation()
  private var bleManager: BLEManager!

  private var lastRenderedRows: [StatusBarRow] = []
  private var renderTimer: Timer?
  private var panelLayoutScheduled = false

  func applicationDidFinishLaunching(_ notification: Notification) {
    bleManager = BLEManager(batteryState: batteryState, appSettings: appSettings)

    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    if let button = statusItem.button {
      button.action = #selector(togglePanel(_:))
      button.target = self
      updateButtonImage()
    }

    renderTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
      // Timer fires on the main run loop, so this is always on the main actor.
      MainActor.assumeIsolated {
        self?.updateButtonImageIfNeeded()
      }
    }

    let menuContent = MenuContentView(
      bleManager: bleManager,
      appSettings: appSettings,
      batteryState: batteryState,
      navigation: panelNavigation,
      onLabelChange: { [weak self] in
        MainActor.assumeIsolated {
          self?.updateButtonImage()
        }
      }
    )
    panel = StatusBarPanel(content: menuContent)
    panel.onClose = { [weak self] in
      guard let self else { return }
      // The panel can be dismissed without going through the in-view Back
      // button (status-item toggle, click outside). Reset navigation and stop
      // any in-progress scan here so neither survives invisibly.
      self.panelNavigation.showKeyboardList = false
      self.bleManager.stopScanning()
    }
    panel.onContentSizeChange = { [weak self] in
      self?.schedulePanelLayout()
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    renderTimer?.invalidate()
    renderTimer = nil
  }

  // MARK: - Status bar rendering

  @MainActor private func updateButtonImageIfNeeded() {
    let rows = currentStatusBarRows()
    guard rows != lastRenderedRows else { return }
    renderStatusBar(rows: rows)
  }

  @MainActor func updateButtonImage() {
    renderStatusBar(rows: currentStatusBarRows())
  }

  @MainActor private func renderStatusBar(rows: [StatusBarRow]) {
    guard let button = statusItem.button else { return }

    let renderScale = button.window?.screen?.backingScaleFactor
      ?? NSScreen.main?.backingScaleFactor
      ?? 2.0
    let content = StatusBarView(
      rows: rows,
      showBatteryIcon: appSettings.showBatteryIcon,
      singleLine: appSettings.singleLineLayout
    )
    .environment(\.displayScale, renderScale)
    let renderer = ImageRenderer(content: content)
    renderer.scale = renderScale

    guard let cgImage = renderer.cgImage else { return }
    let imageScale = renderer.scale
    let image = NSImage(cgImage: cgImage,
                        size: NSSize(width: CGFloat(cgImage.width) / imageScale,
                                     height: CGFloat(cgImage.height) / imageScale))
    image.isTemplate = true
    button.image = image
    // Cache only after the image actually reached the button, so a failed
    // render is retried on the next tick instead of being skipped as
    // already-rendered.
    lastRenderedRows = rows
  }

  @MainActor private func currentStatusBarRows() -> [StatusBarRow] {
    let rows = baseStatusBarRows()
    // The swap only reorders the rows in the icon; each row keeps its own
    // label/level pairing, so the label-to-data mapping (including L/R) is
    // preserved.
    return appSettings.swapBatteryIconPositions ? rows.reversed() : rows
  }

  @MainActor private func baseStatusBarRows() -> [StatusBarRow] {
    let stale = batteryState.isStale()

    guard let kb = appSettings.selectedKeyboard else {
      return [
        StatusBarRow(label: "C", level: stale ? nil : batteryState.centralLevel),
        StatusBarRow(label: "P", level: stale ? nil : batteryState.peripheralLevel),
      ]
    }

    let peripheralCount = batteryState.peripherals.count

    // Multi-peripheral with valid custom labels → show only labeled peripherals
    if peripheralCount > 1, kb.hasValidPeripheralLabels(count: peripheralCount) {
      return batteryState.peripherals.prefix(2).enumerated().map { i, p in
        StatusBarRow(label: kb.peripheralLabels[i], level: stale ? nil : p.level)
      }
    }

    // Default / legacy: Central + first peripheral
    return [
      StatusBarRow(label: kb.centralLabelShort, level: stale ? nil : batteryState.centralLevel),
      StatusBarRow(label: kb.peripheralLabelShort, level: stale ? nil : batteryState.peripheralLevel),
    ]
  }

  // MARK: - Panel

  @objc private func togglePanel(_ sender: Any?) {
    if panel.isVisible {
      panel.close()
      return
    }
    layoutPanel()
    panel.makeKeyAndOrderFront(nil)
  }

  /// Sizes the panel to the hosted content's ideal size (clamped to the space
  /// below the status item) and anchors it under the status item. Called at
  /// open time and again whenever the content's ideal size changes while the
  /// panel is open, so navigation to the (taller) keyboard list or a growing
  /// device list never clips.
  @MainActor private func layoutPanel() {
    guard let button = statusItem.button,
          let buttonWindow = button.window,
          let contentView = panel.contentView else { return }

    var size = contentView.fittingSize
    let buttonRect = buttonWindow.frame
    let visible = (buttonWindow.screen ?? NSScreen.main)?.visibleFrame
    if let visible {
      size.height = min(size.height, buttonRect.minY - visible.minY - 8)
    }

    var origin = NSPoint(
      x: buttonRect.midX - size.width / 2,
      y: buttonRect.minY - size.height - 4
    )
    if let visible {
      origin.x = min(max(origin.x, visible.minX + 4), visible.maxX - size.width - 4)
    }

    // Skip the no-op frame set so an intrinsic-size invalidation caused by
    // our own resize cannot ping-pong into an endless layout loop.
    let target = NSRect(origin: origin, size: size)
    guard abs(panel.frame.minX - target.minX) > 0.5
      || abs(panel.frame.minY - target.minY) > 0.5
      || abs(panel.frame.width - target.width) > 0.5
      || abs(panel.frame.height - target.height) > 0.5
    else { return }

    panel.setContentSize(size)
    panel.setFrameOrigin(origin)
  }

  /// Coalesces content-size-change callbacks (which can fire mid-layout) into
  /// a single relayout on the next run loop turn.
  private func schedulePanelLayout() {
    guard panel.isVisible, !panelLayoutScheduled else { return }
    panelLayoutScheduled = true
    DispatchQueue.main.async { [weak self] in
      // Dispatched to the main queue, so this is always on the main actor.
      MainActor.assumeIsolated {
        guard let self else { return }
        self.panelLayoutScheduled = false
        if self.panel.isVisible {
          self.layoutPanel()
        }
      }
    }
  }
}

// MARK: - StatusBarPanel

final class StatusBarPanel: NSPanel {
  /// Called whenever the panel actually closes, regardless of the close path
  /// (status-item toggle, outside click, programmatic close).
  var onClose: (@MainActor () -> Void)?
  /// Called when the hosted SwiftUI content's ideal size changes, so the
  /// owner can resize the panel while it is open.
  var onContentSizeChange: (@MainActor () -> Void)?

  // NSEvent monitor handle. Marked nonisolated(unsafe) so `deinit` (which is
  // nonisolated) can clean it up. NSEvent.addGlobalMonitorForEvents /
  // removeMonitor are documented as thread-safe, and all non-deinit accesses
  // happen on the main actor, so there is no race.
  private nonisolated(unsafe) var monitor: Any?

  init<Content: View>(content: Content) {
    super.init(
      contentRect: .zero,
      styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
      backing: .buffered,
      defer: true
    )
    level = .popUpMenu
    isMovableByWindowBackground = false
    backgroundColor = .clear
    hasShadow = true
    isOpaque = false

    let containerView = NSView()
    containerView.wantsLayer = true
    containerView.layer?.cornerRadius = 12
    containerView.layer?.masksToBounds = true

    let visualEffect = NSVisualEffectView()
    visualEffect.material = .popover
    visualEffect.state = .active
    visualEffect.blendingMode = .behindWindow
    visualEffect.frame = containerView.bounds
    visualEffect.autoresizingMask = [.width, .height]
    containerView.addSubview(visualEffect)

    let hostingView = AutoSizingHostingView(rootView: content)
    hostingView.translatesAutoresizingMaskIntoConstraints = false
    visualEffect.addSubview(hostingView)
    NSLayoutConstraint.activate([
      hostingView.topAnchor.constraint(equalTo: visualEffect.topAnchor),
      hostingView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
      hostingView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
      hostingView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
    ])

    contentView = containerView

    hostingView.onIntrinsicSizeChange = { [weak self] in
      self?.onContentSizeChange?()
    }
  }

  override var canBecomeKey: Bool { true }

  override func makeKeyAndOrderFront(_ sender: Any?) {
    removeMonitor()
    super.makeKeyAndOrderFront(sender)
    monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
      self?.close()
    }
  }

  override func close() {
    super.close()
    removeMonitor()
    onClose?()
  }

  deinit {
    removeMonitor()
  }

  private nonisolated func removeMonitor() {
    if let monitor {
      NSEvent.removeMonitor(monitor)
    }
    monitor = nil
  }
}

// MARK: - AutoSizingHostingView

/// NSHostingView that reports SwiftUI ideal-size changes to its owner. AppKit
/// has no public notification for this, and the panel needs it to resize
/// itself while open (the hosting view is pinned to the panel's bounds, so
/// its frame alone never reflects the content's ideal size).
private final class AutoSizingHostingView<Content: View>: NSHostingView<Content> {
  var onIntrinsicSizeChange: (@MainActor () -> Void)?

  override func invalidateIntrinsicContentSize() {
    super.invalidateIntrinsicContentSize()
    onIntrinsicSizeChange?()
  }
}
