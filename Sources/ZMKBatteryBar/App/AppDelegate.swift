import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItem: NSStatusItem!
  private var panel: StatusBarPanel!

  private let batteryState = BatteryState()
  private let appSettings = AppSettings()
  private var bleManager: BLEManager!

  private var lastRenderedCentral: Int?
  private var lastRenderedPeripheral: Int?
  private var renderTimer: Timer?

  func applicationDidFinishLaunching(_ notification: Notification) {
    bleManager = BLEManager(batteryState: batteryState, appSettings: appSettings)

    statusItem = NSStatusBar.system.statusItem(withLength: 52)

    if let button = statusItem.button {
      button.action = #selector(togglePanel(_:))
      button.target = self
      updateButtonImage()
    }

    renderTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
      Task { @MainActor in self?.updateButtonImageIfNeeded() }
    }

    let menuContent = MenuContentView(
      bleManager: bleManager,
      appSettings: appSettings,
      batteryState: batteryState
    )
    panel = StatusBarPanel(content: menuContent)
  }

  // MARK: - Status bar rendering

  @MainActor private func updateButtonImageIfNeeded() {
    guard batteryState.centralLevel != lastRenderedCentral
       || batteryState.peripheralLevel != lastRenderedPeripheral
    else { return }
    updateButtonImage()
  }

  @MainActor private func updateButtonImage() {
    guard let button = statusItem.button else { return }

    lastRenderedCentral = batteryState.centralLevel
    lastRenderedPeripheral = batteryState.peripheralLevel

    let renderer = ImageRenderer(content: StatusBarView(batteryState: batteryState))
    renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0

    guard let cgImage = renderer.cgImage else { return }
    let scale = Int(renderer.scale)
    let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width / scale,
                                                        height: cgImage.height / scale))
    image.isTemplate = true
    button.image = image
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
    let panelSize = panel.contentView!.fittingSize

    let x = buttonRect.midX - panelSize.width / 2
    let y = buttonRect.minY - panelSize.height - 4

    panel.setContentSize(panelSize)
    panel.setFrameOrigin(NSPoint(x: x, y: y))
    panel.makeKeyAndOrderFront(nil)
  }
}

// MARK: - StatusBarPanel

final class StatusBarPanel: NSPanel {
  private var monitor: Any?

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

    let visualEffect = NSVisualEffectView()
    visualEffect.material = .popover
    visualEffect.state = .active
    visualEffect.blendingMode = .behindWindow
    visualEffect.wantsLayer = true
    visualEffect.layer?.cornerRadius = 12
    visualEffect.layer?.masksToBounds = true

    let hostingView = NSHostingView(rootView: content)
    hostingView.translatesAutoresizingMaskIntoConstraints = false
    visualEffect.addSubview(hostingView)
    NSLayoutConstraint.activate([
      hostingView.topAnchor.constraint(equalTo: visualEffect.topAnchor),
      hostingView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
      hostingView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
      hostingView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
    ])

    contentView = visualEffect
  }

  override var canBecomeKey: Bool { true }

  override func makeKeyAndOrderFront(_ sender: Any?) {
    if let monitor {
      NSEvent.removeMonitor(monitor)
      self.monitor = nil
    }
    super.makeKeyAndOrderFront(sender)
    monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
      self?.close()
    }
  }

  override func close() {
    super.close()
    if let monitor {
      NSEvent.removeMonitor(monitor)
    }
    monitor = nil
  }
}
