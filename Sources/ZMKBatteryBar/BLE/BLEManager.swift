import CoreBluetooth
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

final class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {

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
      centralManager.cancelPeripheralConnection(peripheral)
    }
    connectedPeripheral = nil
    resetCharacteristicState()
    batteryState.centralConnected = false
    batteryState.peripheralConnected = false
    batteryState.centralLevel = nil
    batteryState.peripheralLevel = nil
  }

  // MARK: - Private Methods

  private func resetCharacteristicState() {
    batteryCharacteristics = []
    characteristicRoles = [:]
  }

  private func startPollingTimer() {
    stopPollingTimer()
    pollingTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
      self?.readAllBatteryCharacteristics()
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
    stopPollingTimer()
    resetCharacteristicState()
    batteryState.centralConnected = false
    batteryState.peripheralConnected = false
    scheduleReconnect()
  }

  func centralManager(
    _ central: CBCentralManager,
    didFailToConnect peripheral: CBPeripheral,
    error: Error?
  ) {
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
      peripheral.discoverDescriptors(for: characteristic)
      peripheral.setNotifyValue(true, for: characteristic)
      peripheral.readValue(for: characteristic)
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
    guard let descriptors = characteristic.descriptors else { return }
    for descriptor in descriptors where descriptor.uuid == Self.characteristicUserDescriptionUUID {
      peripheral.readValue(for: descriptor)
    }
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didUpdateValueFor descriptor: CBDescriptor,
    error: Error?
  ) {
    if let error {
      print("[BLEManager] Descriptor read error: \(error.localizedDescription)")
      return
    }
    guard descriptor.uuid == Self.characteristicUserDescriptionUUID,
          let characteristic = descriptor.characteristic,
          let value = descriptor.value as? String
    else { return }

    let lowered = value.lowercased()
    if lowered.contains("central") {
      characteristicRoles[characteristic] = .central
    } else if lowered.contains("peripheral") {
      characteristicRoles[characteristic] = .peripheral
    }
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didUpdateValueFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    if let error {
      print("[BLEManager] Battery read error: \(error.localizedDescription)")
      return
    }
    guard let data = characteristic.value, let byte = data.first else { return }
    let level = Int(byte)

    let role: DeviceRole
    if let mapped = characteristicRoles[characteristic] {
      role = mapped
    } else if let index = batteryCharacteristics.firstIndex(of: characteristic) {
      role = index == 0 ? .central : .peripheral
    } else {
      role = .central
    }

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
