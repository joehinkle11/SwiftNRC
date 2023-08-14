
import Foundation

@attached(member, names: arbitrary)
public macro NRC(
    members: [String : Any.Type]
) = #externalMacro(
    module: "SwiftNRCMacrosPlugin",
    type: "NRC"
)

public protocol SwiftNRCObject {
    associatedtype StoredMembers
    init(fromRawPointer rawPointer: UnsafeMutableRawPointer)
    init(fromPointer pointer: UnsafeMutablePointer<StoredMembers>)
}

#if DEBUG
/// Set this to false to improve performance in debug builds
public var __debug_enableSwiftNRCZombies = true
public typealias __debug_os_unfair_lock = Foundation.os_unfair_lock
public let __debug_os_unfair_lock_lock = Foundation.os_unfair_lock_lock
public let __debug_os_unfair_lock_unlock = Foundation.os_unfair_lock_unlock
#endif
