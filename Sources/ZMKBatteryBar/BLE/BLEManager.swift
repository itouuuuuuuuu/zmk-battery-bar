@preconcurrency import CoreBluetooth
import Foundation

// MARK: - DeviceRole

enum DeviceRole {
  case central, peripheral
}

// MARK: - DiscoveredDevice

struct DiscoveredDevice: Identifiable {
  let peripheral: CBPeripheral
  let name: String
  let uuid: String

  var id: String { uuid }
}

// MARK: - BLEManager

@MainActor
final class BLEManager: NSObject, ObservableObject, @preconcurrency CBCentralManagerDelegate, @preconcurrency CBPeripheralDelegate {

  // MARK: - BLE UUIDs

  private static let batteryServiceUUID = CBUUID(string: "180F")
  private static let batteryLevelCharacteristicUUID = CBUUID(string: "2A19")
  private static let characteristicUserDescriptionUUID = CBUUID(string: "2901")

  // MARK: - Published Properties

  @Published var discoveredDevices: [DiscoveredDevice] = []
  @Published var isScanning: Bool = false
  @Published var bluetoothState: CBManagerState = .unknown

  // MARK: - State

  private var centralManager: CBCentralManager!
  private var connectedPeripheral: CBPeripheral?
  private let batteryState: BatteryState
  private let appSettings: AppSettings
  private var batteryCharacteristics: [CBCharacteristic] = []
  private var characteristicRoles: [CBCharacteristic: DeviceRole] = [:]
  private var pollingTimer: Timer?
  private var reconnectDelay: TimeInterval = 5
  private static let maxReconnectDelay: TimeInterval = 300

  // MARK: - Init

  init(batteryState: BatteryState, appSettings: AppSettings) {
    self.batteryState = batteryState
    self.appSettings = appSettings
    super.init()
    self.centralManager = CBCentralManager(delegate: self, queue: nil)
  }

  // MARK: - Public Methods

  func startScanning() {
    guard centralManager.state == .poweredOn else { return }
    discoveredDevices = []
    isScanning = true

    // Already-connected peripherals won't appear in scan results.
    let connected = centralManager.retrieveConnectedPeripherals(withServices: [Self.batteryServiceUUID])
    for peripheral in connected {
      let device = DiscoveredDevice(
        peripheral: peripheral,
        name: peripheral.name ?? "Unknown",
        uuid: peripheral.identifier.uuidString
      )
      discoveredDevices.append(device)
    }

    centralManager.scanForPeripherals(
      withServices: [Self.batteryServiceUUID],
      options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
    )
  }

  func stopScanning() {
    centralManager.stopScan()
    isScanning = false
  }

  func connect(peripheral: CBPeripheral) {
    stopScanning()

    // Cancel any existing connection before overwriting connectedPeripheral.
    // Without this, the old peripheral stays connected at the BLE layer and
    // its notify / delegate callbacks can leak into the new keyboard's state.
    if let existing = connectedPeripheral, existing.identifier != peripheral.identifier {
      existing.delegate = nil
      centralManager.cancelPeripheralConnection(existing)
    }
    stopPollingTimer()
    resetCharacteristicState()
    batteryState.centralConnected = false
    batteryState.peripheralConnected = false
    batteryState.centralLevel = nil
    batteryState.peripheralLevel = nil
    batteryState.lastUpdated = nil

    connectedPeripheral = peripheral
    peripheral.delegate = self
    centralManager.connect(peripheral, options: nil)

    let uuid = peripheral.identifier.uuidString
    let name = peripheral.name ?? "Unknown"
    appSettings.selectedKeyboardUUID = uuid
    appSettings.addKeyboard(uuid: uuid, name: name)
  }

  func connectSavedKeyboard() {
    guard let uuidString = appSettings.selectedKeyboardUUID,
          let uuid = UUID(uuidString: uuidString)
    else { return }

    let peripherals = centralManager.retrievePeripherals(withIdentifiers: [uuid])
    guard let peripheral = peripherals.first else { return }

    connectedPeripheral = peripheral
    peripheral.delegate = self
    centralManager.connect(peripheral, options: nil)
  }

  func disconnect() {
    stopPollingTimer()
    if let peripheral = connectedPeripheral {
      peripheral.delegate = nil
      centralManager.cancelPeripheralConnection(peripheral)
    }
    connectedPeripheral = nil
    reconnectDelay = 5
    resetCharacteristicState()
    batteryState.centralConnected = false
    batteryState.peripheralConnected = false
    batteryState.centralLevel = nil
    batteryState.peripheralLevel = nil
    batteryState.lastUpdated = nil
  }

  // MARK: - Private Methods

  private func resetCharacteristicState() {
    batteryCharacteristics = []
    characteristicRoles = [:]
  }

  private func startPollingTimer() {
    stopPollingTimer()
    pollingTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
      // Timer fires on the main run loop, so this is always on the main actor.
      MainActor.assumeIsolated {
        self?.readAllBatteryCharacteristics()
      }
    }
  }

  private func stopPollingTimer() {
    pollingTimer?.invalidate()
    pollingTimer = nil
  }

  private func readAllBatteryCharacteristics() {
    guard let peripheral = connectedPeripheral else { return }
    for characteristic in batteryCharacteristics {
      peripheral.readValue(for: characteristic)
    }
  }

  private func scheduleReconnect() {
    let delay = reconnectDelay
    reconnectDelay = min(reconnectDelay * 2, Self.maxReconnectDelay)

    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
      self?.connectSavedKeyboard()
    }
  }

  // MARK: - CBCentralManagerDelegate

  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    bluetoothState = central.state
    if central.state == .poweredOn {
      connectSavedKeyboard()
    }
  }

  func centralManager(
    _ central: CBCentralManager,
    didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any],
    rssi RSSI: NSNumber
  ) {
    let uuid = peripheral.identifier.uuidString
    guard !discoveredDevices.contains(where: { $0.uuid == uuid }) else { return }

    let name = peripheral.name
      ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
      ?? "Unknown"

    let device = DiscoveredDevice(peripheral: peripheral, name: name, uuid: uuid)
    discoveredDevices.append(device)
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    guard peripheral.identifier == connectedPeripheral?.identifier else { return }
    reconnectDelay = 5
    resetCharacteristicState()
    peripheral.discoverServices([Self.batteryServiceUUID])
    startPollingTimer()
  }

  func centralManager(
    _ central: CBCentralManager,
    didDisconnectPeripheral peripheral: CBPeripheral,
    error: Error?
  ) {
    // Ignore disconnect callbacks for peripherals we have already moved on
    // from (user-initiated disconnect, or a switch to a different keyboard).
    // Without this guard, a stale disconnect would wipe the new peripheral's
    // state and schedule an unwanted reconnect to the old one.
    guard peripheral.identifier == connectedPeripheral?.identifier else { return }

    stopPollingTimer()
    resetCharacteristicState()
    batteryState.centralConnected = false
    batteryState.peripheralConnected = false
    batteryState.centralLevel = nil
    batteryState.peripheralLevel = nil
    batteryState.lastUpdated = nil
    scheduleReconnect()
  }

  func centralManager(
    _ central: CBCentralManager,
    didFailToConnect peripheral: CBPeripheral,
    error: Error?
  ) {
    guard peripheral.identifier == connectedPeripheral?.identifier else { return }
    print("[BLEManager] Failed to connect: \(error?.localizedDescription ?? "unknown error")")
    scheduleReconnect()
  }

  // MARK: - CBPeripheralDelegate

  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    if let error {
      print("[BLEManager] Service discovery error: \(error.localizedDescription)")
      return
    }
    guard let services = peripheral.services else { return }
    for service in services {
      peripheral.discoverCharacteristics([Self.batteryLevelCharacteristicUUID], for: service)
    }
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didDiscoverCharacteristicsFor service: CBService,
    error: Error?
  ) {
    if let error {
      print("[BLEManager] Characteristic discovery error: \(error.localizedDescription)")
      return
    }
    guard let characteristics = service.characteristics else { return }
    for characteristic in characteristics {
      batteryCharacteristics.append(characteristic)
      peripheral.setNotifyValue(true, for: characteristic)
      peripheral.discoverDescriptors(for: characteristic)
      // The initial readValue is deferred until the characteristic's role is
      // known (see didDiscoverDescriptorsFor / didUpdateValueFor descriptor).
      // Reading here would race descriptor discovery, and since GATT does not
      // guarantee characteristic ordering, the array-index fallback can map
      // central/peripheral to the wrong slots until the next polled update.
    }
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didDiscoverDescriptorsFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    if let error {
      print("[BLEManager] Descriptor discovery error: \(error.localizedDescription)")
      return
    }

    let userDescriptionDescriptor = characteristic.descriptors?.first { descriptor in
      descriptor.uuid == Self.characteristicUserDescriptionUUID
    }

    if let descriptor = userDescriptionDescriptor {
      // Role is resolved in didUpdateValueFor descriptor, which then triggers
      // the initial battery read for this characteristic.
      peripheral.readValue(for: descriptor)
    } else {
      // No user-description descriptor available — fall back to array-index
      // ordering so the initial read has a definitive role to attach to.
      if characteristicRoles[characteristic] == nil,
         let index = batteryCharacteristics.firstIndex(of: characteristic) {
        characteristicRoles[characteristic] = index == 0 ? .central : .peripheral
      }
      peripheral.readValue(for: characteristic)
    }
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didUpdateValueFor descriptor: CBDescriptor,
    error: Error?
  ) {
    // Only user description descriptors carry role information. Other
    // descriptors can reach this callback but are not ours to handle.
    guard descriptor.uuid == Self.characteristicUserDescriptionUUID,
          let characteristic = descriptor.characteristic
    else { return }

    if let error {
      print("[BLEManager] Descriptor read error: \(error.localizedDescription)")
    } else if let value = descriptor.value as? String {
      let lowered = value.lowercased()
      if lowered.contains("central") {
        characteristicRoles[characteristic] = .central
      } else if lowered.contains("peripheral") {
        characteristicRoles[characteristic] = .peripheral
      }
    }

    // Regardless of whether the descriptor read succeeded or produced a
    // recognizable role string, make sure the characteristic ends up with
    // *some* role before we read its value. Otherwise the unknown-role guard
    // in didUpdateValueFor characteristic would drop every subsequent
    // notify / poll update for this characteristic — which keyboards that
    // expose 0x2901 but cannot reliably serve it would hit permanently.
    if characteristicRoles[characteristic] == nil,
       let index = batteryCharacteristics.firstIndex(of: characteristic) {
      characteristicRoles[characteristic] = index == 0 ? .central : .peripheral
    }

    peripheral.readValue(for: characteristic)
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didUpdateValueFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    guard peripheral.identifier == connectedPeripheral?.identifier else { return }

    if let error {
      print("[BLEManager] Battery read error: \(error.localizedDescription)")
      return
    }
    guard let data = characteristic.value, let byte = data.first else { return }
    let level = Int(byte)

    // If the role has not been determined yet (e.g. a notify-driven update
    // arrives during the initial connection window before descriptor
    // discovery completes), drop the update. The explicit readValue in
    // didUpdateValueFor descriptor / didDiscoverDescriptorsFor will re-fetch
    // the value once the role is known.
    guard let role = characteristicRoles[characteristic] else { return }

    switch role {
    case .central:
      batteryState.centralLevel = level
      batteryState.centralConnected = true
    case .peripheral:
      batteryState.peripheralLevel = level
      batteryState.peripheralConnected = true
    }
    batteryState.lastUpdated = Date()
  }
}
