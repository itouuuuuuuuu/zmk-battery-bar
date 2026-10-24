import Foundation
import IOKit.hid

/// Watches key presses system-wide and reports the HID product name of the
/// keyboard they came from. Only the *source device* of each press is used;
/// key codes are never inspected, stored, or logged.
///
/// Requires the Input Monitoring privacy permission. Without it
/// `IOHIDManagerOpen` fails and no events are delivered, so callers should
/// check `hasAccess` / call `requestAccess()` before `start()`.
@MainActor
final class ActiveKeyboardMonitor {
  /// Called on the main actor with the product name of the keyboard that
  /// just produced a key press. Throttled to at most once per
  /// `minimumInterval` so a burst of typing does not re-run the resolver on
  /// every keystroke.
  var onKeyboardInput: ((String) -> Void)?

  private var manager: IOHIDManager?
  private var lastReported = Date.distantPast
  private let minimumInterval: TimeInterval = 0.5

  private static let keyboardUsagePage = Int(kHIDPage_KeyboardOrKeypad)

  var isRunning: Bool { manager != nil }

  // MARK: - Permission

  static var hasAccess: Bool {
    IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
  }

  /// Shows the system Input Monitoring prompt (first time only) and returns
  /// whether access is currently granted. When the user grants access from
  /// System Settings afterwards, macOS requires the app to be relaunched
  /// before events are delivered.
  @discardableResult
  static func requestAccess() -> Bool {
    IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
  }

  // MARK: - Lifecycle

  /// Starts monitoring. Returns false when the HID manager could not be
  /// opened (typically because Input Monitoring is not granted).
  @discardableResult
  func start() -> Bool {
    guard manager == nil else { return true }

    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    let matching: [[String: Any]] = [
      [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard],
      [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Keypad],
    ]
    IOHIDManagerSetDeviceMatchingMultiple(manager, matching as CFArray)

    let context = Unmanaged.passUnretained(self).toOpaque()
    IOHIDManagerRegisterInputValueCallback(manager, Self.inputValueCallback, context)
    IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

    let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    guard result == kIOReturnSuccess else {
      IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
      return false
    }
    self.manager = manager
    return true
  }

  func stop() {
    guard let manager else { return }
    IOHIDManagerRegisterInputValueCallback(manager, nil, nil)
    IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    self.manager = nil
  }

  // MARK: - Callback

  // The manager is scheduled on the main run loop, so this always runs on the
  // main thread; `assumeIsolated` makes that explicit to the compiler.
  private static let inputValueCallback: IOHIDValueCallback = { context, _, _, value in
    guard let context else { return }
    let element = IOHIDValueGetElement(value)
    // Only real key presses on the keyboard usage page count as "operating"
    // the keyboard. Releases and non-key reports (LEDs, vendor pages) are
    // ignored.
    guard Int(IOHIDElementGetUsagePage(element)) == keyboardUsagePage,
          IOHIDValueGetIntegerValue(value) != 0
    else { return }
    let device = IOHIDElementGetDevice(element)
    guard let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String else { return }

    // Resolve the object outside the closure: a raw pointer is not Sendable,
    // so capturing it directly trips the region-isolation checker.
    let monitor = Unmanaged<ActiveKeyboardMonitor>.fromOpaque(context).takeUnretainedValue()
    MainActor.assumeIsolated {
      monitor.handleInput(productName: name)
    }
  }

  private func handleInput(productName: String) {
    let now = Date()
    guard now.timeIntervalSince(lastReported) >= minimumInterval else { return }
    lastReported = now
    onKeyboardInput?(productName)
  }
}
