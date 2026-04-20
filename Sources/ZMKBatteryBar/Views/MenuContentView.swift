import Combine
import SwiftUI

struct MenuContentView: View {
  @ObservedObject var bleManager: BLEManager
  let appSettings: AppSettings
  let batteryState: BatteryState
  var onLabelChange: () -> Void = {}

  @State private var showKeyboardList = false
  @State private var launchAtLogin = LaunchAtLogin.isEnabled
  @State private var now = Date()
  @State private var labelStyleTick = 0

  private let updateTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

  var body: some View {
    if showKeyboardList {
      KeyboardListView(
        bleManager: bleManager,
        appSettings: appSettings,
        onDismiss: { showKeyboardList = false }
      )
    } else {
      mainContent
    }
  }

  @ViewBuilder
  private var mainContent: some View {
    VStack(alignment: .leading, spacing: 8) {
      if appSettings.savedKeyboards.count > 1 {
        Picker("Keyboard", selection: Binding(
          get: { appSettings.selectedKeyboardUUID ?? "" },
          set: { uuid in
            appSettings.selectedKeyboardUUID = uuid
            bleManager.disconnect()
            bleManager.connectSavedKeyboard()
            labelStyleTick &+= 1
            onLabelChange()
          }
        )) {
          ForEach(appSettings.savedKeyboards) { kb in
            Text(kb.name).tag(kb.uuid)
          }
        }
        .pickerStyle(.menu)
      } else if let keyboard = appSettings.selectedKeyboard {
        Text(keyboard.name)
          .font(.headline)
      } else {
        Text("Not Connected")
          .font(.headline)
          .foregroundStyle(.secondary)
      }

      Divider()

      let keyboard = appSettings.selectedKeyboard
      batteryRow(label: "Central", level: batteryState.centralLevel, peripheralIndex: nil, keyboard: keyboard)
      ForEach(batteryState.peripherals) { p in
        let label = batteryState.peripherals.count > 1 ? "Peripheral \(p.index + 1)" : "Peripheral"
        batteryRow(label: label, level: p.level, peripheralIndex: p.index, keyboard: keyboard)
      }

      if let lastUpdated = batteryState.lastUpdated {
        Text("Updated: \(TimeAgoFormatter.format(from: lastUpdated, now: now))")
          .font(.caption)
          .foregroundStyle(.secondary)
          .onReceive(updateTimer) { now = $0 }
      }

      Divider()

      Toggle("Launch at Login", isOn: $launchAtLogin)
        .onChange(of: launchAtLogin) { _, newValue in
          do {
            if newValue {
              try LaunchAtLogin.enable()
            } else {
              try LaunchAtLogin.disable()
            }
          } catch {
            launchAtLogin = !newValue
          }
        }

      Button("Add Keyboard...") {
        showKeyboardList = true
      }

      Divider()

      HStack {
        Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Button("Quit") {
          NSApplication.shared.terminate(nil)
        }
      }
    }
    .padding(12)
    .frame(width: 260)
  }

  private func batteryRow(
    label: String,
    level: Int?,
    peripheralIndex: Int?,
    keyboard: KeyboardDevice?
  ) -> some View {
    HStack(spacing: 2) {
      Text(label)
        .lineLimit(1)
        .frame(width: 85, alignment: .leading)
      BatteryIconView(level: level)
      Text(level.map { "\($0)%" } ?? "--")
        .monospacedDigit()
      Spacer()
      if let keyboard {
        if batteryState.peripherals.count <= 1 {
          // Legacy 1-peripheral: L/R toggles central/peripheral together
          let side: KeyboardSide = peripheralIndex != nil ? .peripheral : .central
          let current = keyboard.labelStyle == .leftRight ? keyboard.labelShort(for: side) : nil
          HStack(spacing: 2) {
            letterButton("L", selected: current == "L") { applyLegacy(letter: "L", to: side, for: keyboard.uuid) }
            letterButton("R", selected: current == "R") { applyLegacy(letter: "R", to: side, for: keyboard.uuid) }
          }
          .id(labelStyleTick)
        } else if let index = peripheralIndex {
          // Multi-peripheral: L/R per peripheral
          let current = index < keyboard.peripheralLabels.count ? keyboard.peripheralLabels[index] : ""
          HStack(spacing: 2) {
            letterButton("L", selected: current == "L") { applyPeripheralLabel("L", at: index, for: keyboard.uuid, current: current) }
            letterButton("R", selected: current == "R") { applyPeripheralLabel("R", at: index, for: keyboard.uuid, current: current) }
          }
          .id(labelStyleTick)
        }
      }
    }
  }

  private func letterButton(_ letter: String, selected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(letter)
        .font(.system(size: 10, weight: .semibold, design: .rounded))
        .frame(width: 16, height: 16)
        .background(
          RoundedRectangle(cornerRadius: 4)
            .fill(selected ? Color.accentColor.opacity(0.25) : Color.clear)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 4)
            .stroke(selected ? Color.accentColor : Color.secondary.opacity(0.4), lineWidth: 1)
        )
        .foregroundStyle(selected ? Color.accentColor : Color.secondary)
    }
    .buttonStyle(.plain)
  }

  private func applyLegacy(letter: String, to side: KeyboardSide, for uuid: String) {
    appSettings.updateKeyboard(uuid: uuid) { device in
      let current = device.labelStyle == .leftRight ? device.labelShort(for: side) : nil
      device.assignLetter(current == letter ? nil : letter, to: side)
    }
    labelStyleTick &+= 1
    onLabelChange()
  }

  private func applyPeripheralLabel(_ letter: String, at index: Int, for uuid: String, current: String) {
    appSettings.updateKeyboard(uuid: uuid) { device in
      device.assignPeripheralLabel(current == letter ? nil : letter, at: index)
    }
    labelStyleTick &+= 1
    onLabelChange()
  }
}
