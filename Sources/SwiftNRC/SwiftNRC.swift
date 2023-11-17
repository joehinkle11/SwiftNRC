
import Foundation

@attached(accessor, names: overloaded, suffixed(Pointer))
public macro Prop(
    atOffset offset: Int
) = #externalMacro(
    module: "SwiftNRCMacrosPlugin",
    type: "Prop"
)

@attached(member, names: arbitrary)
public macro NRC(
    members: [String : Any]
) = #externalMacro(
    module: "SwiftNRCMacrosPlugin",
    type: "NRC"
)

@attached(member, names: arbitrary)
public macro NRC<T: SwiftNRCObject>(
    members: [String : Any],
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


public struct NRCStaticArray<Element> {
    @_alwaysEmitIntoClient
    @inline(__always)
    private var _storage: UnsafeMutablePointer<Element>
    
    public init?(_ t: Element.Type, _ count: Int) { assertionFailure(); return nil}
    
    @_alwaysEmitIntoClient
    @inline(__always)
    private init(_storage: UnsafeMutablePointer<Element>) {
        self._storage = _storage
    }
    
    @_alwaysEmitIntoClient
    @inline(__always)
    public static func createForSwiftNRCObject<T: SwiftNRCObject>(
        _ obj: T,
        _ keyPath: KeyPath<T, UnsafeMutablePointer<Element>>
    ) -> NRCStaticArray<Element> {
        return .init(_storage: obj[keyPath: keyPath])
    }
    
    @_alwaysEmitIntoClient
    @inline(__always)
    public subscript(index: Int) -> Element {
        get {
            return self._storage.advanced(by: index).pointee
        }
        nonmutating set(newValue) {
            self._storage.advanced(by: index).pointee = newValue
        }
    }
}

#if DEBUG
/// Set this to false to improve performance in debug builds
public var __debug_enableSwiftNRCZombies = true
public typealias __debug_os_unfair_lock = Foundation.os_unfair_lock
public let __debug_os_unfair_lock_lock = Foundation.os_unfair_lock_lock
public let __debug_os_unfair_lock_unlock = Foundation.os_unfair_lock_unlock
#endif
