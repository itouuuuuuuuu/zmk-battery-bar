import SwiftUI

struct KeyboardListView: View {
  @ObservedObject var bleManager: BLEManager
  let appSettings: AppSettings
  var onDismiss: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Button("Back") {
          bleManager.stopScanning()
          onDismiss()
        }
        Spacer()
        Text("Find Keyboards")
          .font(.headline)
        Spacer()
      }

      Divider()

      if bleManager.discoveredDevices.isEmpty && !bleManager.isScanning {
        Text("No devices found")
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.vertical, 8)
      }

      if bleManager.isScanning {
        HStack(spacing: 6) {
          ProgressView()
            .controlSize(.small)
          Text("Scanning...")
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
      }

      ForEach(bleManager.discoveredDevices) { device in
        HStack {
          Text(device.name)
            .lineLimit(1)
          Spacer()
          Button("Connect") {
            bleManager.connect(peripheral: device.peripheral)
            onDismiss()
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.small)
        }
      }

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
    .frame(width: 250)
    .onAppear {
      bleManager.startScanning()
    }
  }
}
