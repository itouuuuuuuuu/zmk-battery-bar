import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItem: NSStatusItem!
  private var panel: StatusBarPanel!

  private let batteryState = BatteryState()
  private let appSettings = AppSettings()
  private var bleManager: BLEManager!

  private var lastRenderedRows: [StatusBarRow] = []
  private var renderTimer: Timer?

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
      onLabelChange: { [weak self] in
        MainActor.assumeIsolated {
          self?.updateButtonImage()
        }
      }
    )
    panel = StatusBarPanel(content: menuContent)
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

    lastRenderedRows = rows

    let renderScale = button.window?.screen?.backingScaleFactor
      ?? NSScreen.main?.backingScaleFactor
      ?? 2.0
    let content = StatusBarView(rows: rows)
      .environment(\.displayScale, renderScale)
    let renderer = ImageRenderer(content: content)
    renderer.scale = renderScale

    guard let cgImage = renderer.cgImage else { return }
    let imageScale = Int(renderer.scale)
    let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width / imageScale,
                                                        height: cgImage.height / imageScale))
    image.isTemplate = true
    button.image = image
  }

  @MainActor private func currentStatusBarRows() -> [StatusBarRow] {
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
    guard let button = statusItem.button,
          let buttonWindow = button.window else { return }

    if panel.isVisible {
      panel.close()
      return
    }

    let buttonRect = buttonWindow.frame
    guard let contentView = panel.contentView else { return }
    let panelSize = contentView.fittingSize

    let x = buttonRect.midX - panelSize.width / 2
    let y = buttonRect.minY - panelSize.height - 4

    panel.setContentSize(panelSize)
    panel.setFrameOrigin(NSPoint(x: x, y: y))
    panel.makeKeyAndOrderFront(nil)
  }
}

// MARK: - StatusBarPanel

final class StatusBarPanel: NSPanel {
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

    let hostingView = NSHostingView(rootView: content)
    hostingView.translatesAutoresizingMaskIntoConstraints = false
    visualEffect.addSubview(hostingView)
    NSLayoutConstraint.activate([
      hostingView.topAnchor.constraint(equalTo: visualEffect.topAnchor),
      hostingView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
      hostingView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
      hostingView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
    ])

    contentView = containerView
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
