import ServiceManagement

struct LaunchAtLogin {
  static var isEnabled: Bool {
    SMAppService.mainApp.status == .enabled
  }

  static func enable() throws {
    try SMAppService.mainApp.register()
  }

  static func disable() throws {
    try SMAppService.mainApp.unregister()
  }
}
