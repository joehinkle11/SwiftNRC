
import Foundation

@attached(member, names: arbitrary)
public macro NRC(
    members: [String : Any.Type]
) = #externalMacro(
    module: "SwiftNRCMacrosPlugin",
    type: "NRC"
)

@attached(member, names: arbitrary)
public macro NRC<T: SwiftNRCObject>(
    members: [String : Any.Type],
    superNRC: T.Type
) = #externalMacro(
    module: "SwiftNRCMacrosPlugin",
    type: "NRC"
)

public protocol SwiftNRCObject {
    associatedtype StoredMembers
    var pointer: UnsafeMutablePointer<StoredMembers>? { get set }
    init(fromRawPointer rawPointer: UnsafeMutableRawPointer)
    init(fromPointer pointer: UnsafeMutablePointer<StoredMembers>)
}

public struct SwiftNRCObjectID: Equatable, Hashable {
    @usableFromInline
    internal let pointer: UnsafeRawPointer
    @inline(__always) @_alwaysEmitIntoClient
    public init(_ pointer: UnsafeRawPointer) {
        self.pointer = pointer
    }
}

#if DEBUG
/// Set this to false to improve performance in debug builds
public var __debug_enableSwiftNRCZombies = true
public typealias __debug_os_unfair_lock = Foundation.os_unfair_lock
public let __debug_os_unfair_lock_lock = Foundation.os_unfair_lock_lock
public let __debug_os_unfair_lock_unlock = Foundation.os_unfair_lock_unlock
#endif
