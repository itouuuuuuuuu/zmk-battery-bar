import Combine
import SwiftUI

struct MenuContentView: View {
  @ObservedObject var bleManager: BLEManager
  let appSettings: AppSettings
  let batteryState: BatteryState

  @State private var showKeyboardList = false
  @State private var launchAtLogin = LaunchAtLogin.isEnabled
  @State private var now = Date()

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

      batteryRow(label: "Central", level: batteryState.centralLevel)
      batteryRow(label: "Peripheral", level: batteryState.peripheralLevel)

      if let lastUpdated = batteryState.lastUpdated {
        Text("Updated: \(timeAgoString(from: lastUpdated))")
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
    .frame(width: 250)
  }

  private func timeAgoString(from date: Date) -> String {
    let seconds = Int(now.timeIntervalSince(date))
    if seconds < 60 {
      return "\(max(seconds, 0))s ago"
    } else if seconds < 3600 {
      return "\(seconds / 60)m ago"
    } else {
      return "\(seconds / 3600)h ago"
    }
  }

  private func batteryRow(label: String, level: Int?) -> some View {
    HStack(spacing: 2) {
      Text(label)
        .frame(width: 70, alignment: .leading)
      BatteryIconView(level: level)
      Text(level.map { "\($0)%" } ?? "--")
        .monospacedDigit()
    }
  }
}
