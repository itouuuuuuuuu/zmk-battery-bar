import SwiftUI

struct KeyboardListView: View {
  @ObservedObject var bleManager: BLEManager
  let appSettings: AppSettings
  var onDismiss: () -> Void
  var onSelectionChange: () -> Void = {}

  // Bumped to force a body re-evaluation after mutating AppSettings, which is
  // not observable on its own.
  @State private var refreshTick = 0
  @State private var connectedUUIDs: Set<String> = []

  private let statusTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

  private var savedKeyboards: [KeyboardDevice] { appSettings.savedKeyboards }

  /// Discovered devices that are not already saved.
  private var newDevices: [DiscoveredDevice] {
    let savedUUIDs = Set(savedKeyboards.map { $0.uuid })
    return bleManager.discoveredDevices.filter { !savedUUIDs.contains($0.uuid) }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      header

      Divider()

      savedSection

      Divider()

      newSection

      Divider()

      Button(bleManager.isScanning ? "Stop Scan" : "Start Scan") {
        if bleManager.isScanning {
          bleManager.stopScanning()
        } else {
          bleManager.startScanning()
        }
      }
      .frame(maxWidth: .infinity)
    }
    .padding(12)
    .frame(width: 260)
    .onAppear {
      connectedUUIDs = bleManager.connectedKeyboardUUIDs()
      bleManager.startScanning()
    }
    .onReceive(statusTimer) { _ in
      connectedUUIDs = bleManager.connectedKeyboardUUIDs()
    }
  }

  private var header: some View {
    HStack {
      Button("Back") {
        bleManager.stopScanning()
        onDismiss()
      }
      Spacer()
      Text("Keyboards")
        .font(.headline)
      Spacer()
    }
  }

  // MARK: - Saved

  @ViewBuilder
  private var savedSection: some View {
    Text("Saved")
      .font(.caption)
      .foregroundStyle(.secondary)

    if savedKeyboards.isEmpty {
      Text("No saved keyboards")
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 4)
    } else {
      ForEach(savedKeyboards) { kb in
        savedRow(kb)
      }
    }
  }

  private func savedRow(_ kb: KeyboardDevice) -> some View {
    let isSelected = appSettings.selectedKeyboardUUID == kb.uuid
    let isConnected = connectedUUIDs.contains(kb.uuid)
    return HStack(spacing: 6) {
      VStack(alignment: .leading, spacing: 3) {
        Text(kb.name)
          .fontWeight(isSelected ? .semibold : .regular)
          .lineLimit(1)
        statusBadge(connected: isConnected)
      }
      Spacer()
      if isSelected {
        currentBadge
      } else {
        Button("Select") { select(kb) }
          .controlSize(.small)
      }
      Button("Delete") { delete(kb) }
        .controlSize(.small)
        .buttonStyle(.borderedProminent)
        .tint(.red)
    }
    .id(refreshTick)
  }

  private func statusBadge(connected: Bool) -> some View {
    let color: Color = connected ? .green : .secondary
    return Text(connected ? "Connected" : "Disconnected")
      .font(.caption2.weight(.medium))
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(Capsule().fill(color.opacity(0.2)))
      .foregroundStyle(color)
  }

  private var currentBadge: some View {
    Text("Current")
      .font(.caption2.weight(.semibold))
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(Capsule().fill(Color.accentColor.opacity(0.2)))
      .foregroundStyle(Color.accentColor)
  }

  // MARK: - Find new

  @ViewBuilder
  private var newSection: some View {
    HStack(spacing: 6) {
      Text("Find New")
        .font(.caption)
        .foregroundStyle(.secondary)
      if bleManager.isScanning {
        ProgressView()
          .controlSize(.small)
      }
    }

    if newDevices.isEmpty {
      Text(bleManager.isScanning ? "Scanning..." : "No new devices")
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 4)
    } else {
      ForEach(newDevices) { device in
        HStack {
          Text(device.name)
            .lineLimit(1)
          Spacer()
          Button("Connect") {
            bleManager.connect(peripheral: device.peripheral)
            onSelectionChange()
            onDismiss()
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.small)
        }
      }
    }
  }

  // MARK: - Actions

  private func select(_ kb: KeyboardDevice) {
    guard appSettings.selectedKeyboardUUID != kb.uuid else { return }
    appSettings.selectedKeyboardUUID = kb.uuid
    bleManager.disconnect()
    bleManager.connectSavedKeyboard()
    onSelectionChange()
    refreshTick &+= 1
  }

  private func delete(_ kb: KeyboardDevice) {
    let wasSelected = appSettings.selectedKeyboardUUID == kb.uuid
    appSettings.removeKeyboard(uuid: kb.uuid)
    if wasSelected {
      // removeKeyboard already cleared the selection; drop the live connection
      // so the menu falls back to "Not Connected" instead of stale readings.
      bleManager.disconnect()
    }
    onSelectionChange()
    refreshTick &+= 1
  }
}
