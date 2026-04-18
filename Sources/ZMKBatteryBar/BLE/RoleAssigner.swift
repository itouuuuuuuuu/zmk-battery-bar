import Foundation

enum RoleAssigner {
  /// Infers the role for `target` when it has no explicit role yet.
  /// Returns the existing role unchanged if already assigned.
  /// Returns nil when the target is not in `allCharacteristics`, or when
  /// its sibling's role is still unknown.
  static func remainingRole<Key: Hashable>(
    target: Key,
    allCharacteristics: [Key],
    roles: [Key: DeviceRole]
  ) -> DeviceRole? {
    if let existing = roles[target] {
      return existing
    }
    guard allCharacteristics.contains(target) else { return nil }

    if allCharacteristics.count == 1 {
      return .central
    }

    guard allCharacteristics.count == 2,
          let other = allCharacteristics.first(where: { $0 != target }),
          let otherRole = roles[other]
    else {
      return nil
    }

    return otherRole == .central ? .peripheral : .central
  }

  /// Array-index fallback: first characteristic is central, any subsequent one
  /// is peripheral. Returns nil if the target already has a role or is not in
  /// the array.
  static func roleByIndex<Key: Hashable>(
    target: Key,
    allCharacteristics: [Key],
    roles: [Key: DeviceRole]
  ) -> DeviceRole? {
    guard roles[target] == nil,
          let index = allCharacteristics.firstIndex(of: target)
    else {
      return nil
    }
    return index == 0 ? .central : .peripheral
  }

  /// Cascade-assigns roles to unresolved characteristics. Returns the updated
  /// role map. When there is exactly one unresolved characteristic, tries
  /// sibling-inference only. When there are multiple and all of them have hit
  /// terminal failure, applies sibling inference then index-based fallback.
  static func assignFallbackRoles<Key: Hashable>(
    allCharacteristics: [Key],
    roles: [Key: DeviceRole],
    terminallyFailed: Set<Key>
  ) -> [Key: DeviceRole] {
    var updated = roles
    let unresolved = allCharacteristics.filter { updated[$0] == nil }
    guard !unresolved.isEmpty else { return updated }

    if unresolved.count == 1 {
      if let role = remainingRole(
        target: unresolved[0],
        allCharacteristics: allCharacteristics,
        roles: updated
      ) {
        updated[unresolved[0]] = role
      }
      return updated
    }

    guard unresolved.allSatisfy({ terminallyFailed.contains($0) }) else {
      return updated
    }

    for target in unresolved {
      if let role = remainingRole(
        target: target,
        allCharacteristics: allCharacteristics,
        roles: updated
      ) {
        updated[target] = role
      } else if let role = roleByIndex(
        target: target,
        allCharacteristics: allCharacteristics,
        roles: updated
      ) {
        updated[target] = role
      }
    }
    return updated
  }
}
