
import Foundation

@attached(accessor, names: overloaded, suffixed(Pointer))
public macro Prop(
    atOffset offset: Int
) = #externalMacro(
    module: "SwiftNRCMacrosPlugin",
    type: "Prop"
)

@attached(accessor, names: overloaded, suffixed(Pointer))
public macro AltView(
    startOffset offset: Int
) = #externalMacro(
    module: "SwiftNRCMacrosPlugin",
    type: "AltView"
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
    
    @_alwaysEmitIntoClient
    @inline(__always)
    public func initialize(index: Int, to startingValue: Element) {
        self._storage.advanced(by: index).initialize(to: startingValue)
    }
}

public struct NRCStaticStack<Element> {
    @_alwaysEmitIntoClient
    @inline(__always)
    private var _storage: UnsafeMutableRawPointer
    @_alwaysEmitIntoClient
    @inline(__always)
    private let capacity: Int
    
    @_alwaysEmitIntoClient
    @inline(__always)
    private init(_storage: UnsafeMutableRawPointer, capacity: Int) {
        self._storage = _storage
        self.capacity = capacity
    }
    
    @_alwaysEmitIntoClient
    @inline(__always)
    private var countPt: UnsafeMutablePointer<Int> { _storage.assumingMemoryBound(to: Int.self) }
    
    @_alwaysEmitIntoClient
    @inline(__always)
    public var count: Int { return countPt.pointee }
    
    @_alwaysEmitIntoClient
    @inline(__always)
    private var firstElement: UnsafeMutablePointer<Element> {
        _storage.advanced(by: MemoryLayout<Int>.size).assumingMemoryBound(to: Element.self)
    }
    
    public init?(_ t: Element.Type, _ capacity: Int) { assertionFailure(); return nil}
    
    @_alwaysEmitIntoClient
    @inline(__always)
    public func initialize() {
        self.countPt.pointee = 0
    }
    
    /// Allows you to set the value of the uninitialized buffer which stores the stack values.
    @_alwaysEmitIntoClient
    @inline(__always)
    public func initialize(nilOutRawBuffer: (_ rawBuffer: UnsafeMutableRawBufferPointer) -> Void) {
        self.countPt.pointee = 0
        let buffer = UnsafeMutableBufferPointer<Element>(start: self.firstElement, count: self.capacity)
        let rawBuffer = UnsafeMutableRawBufferPointer(buffer)
        nilOutRawBuffer(rawBuffer)
    }
    
    @_alwaysEmitIntoClient
    @inline(__always)
    public static func createForSwiftNRCObject<T: SwiftNRCObject>(
        _ obj: T,
        _ keyPath: KeyPath<T, UnsafeMutableRawPointer>,
        _ capacity: Int
    ) -> NRCStaticStack<Element> {
        return .init(_storage: obj[keyPath: keyPath], capacity: capacity)
    }
    
    /// Returns success
    @discardableResult
    @_alwaysEmitIntoClient
    @inline(__always)
    public func push(_ element: Element) -> Bool {
        let newIndex = self.count
        guard newIndex < self.capacity else {
            return false
        }
        self.countPt.pointee += 1
        self.firstElement.advanced(by: newIndex).initialize(to: element)
        return true
    }
    
    @discardableResult
    @_alwaysEmitIntoClient
    @inline(__always)
    public func pop(defaultIfEmpty: Element) -> Element {
        let index = self.count - 1
        guard index > 0 else {
            return defaultIfEmpty
        }
        let result = self.firstElement.advanced(by: index).pointee
        self.firstElement.advanced(by: index).deinitialize(count: 1)
        self.countPt.pointee -= 1
        return result
    }
    
    @discardableResult
    @_alwaysEmitIntoClient
    @inline(__always)
    public func pop() -> Element? {
        let index = self.count - 1
        guard index >= 0 else {
            return nil
        }
        let result = self.firstElement.advanced(by: index).pointee
        self.firstElement.advanced(by: index).deinitialize(count: 1)
        self.countPt.pointee -= 1
        return result
    }
    
    @_alwaysEmitIntoClient
    @inline(__always)
    public func peak(defaultIfEmpty: Element) -> Element {
        let index = self.count - 1
        guard index >= 0 else {
            return defaultIfEmpty
        }
        return self.firstElement.advanced(by: index).pointee
    }
    
    @_alwaysEmitIntoClient
    @inline(__always)
    public func peak() -> Element? {
        let index = self.count - 1
        guard index >= 0 else {
            return nil
        }
        return self.firstElement.advanced(by: index).pointee
    }
    
    /// Returns success
    @_alwaysEmitIntoClient
    @inline(__always)
    public func pop(amount: Int) -> Bool {
        let indexToStartPop = self.count - amount
        guard indexToStartPop >= 0 else {
            return false
        }
        self.firstElement.advanced(by: indexToStartPop).deinitialize(count: amount)
        self.countPt.pointee -= amount
        return true
    }
    
    @_alwaysEmitIntoClient
    @inline(__always)
    public var pointerToFirst: UnsafeMutablePointer<Element> {
        return self.firstElement
    }
    
    @_alwaysEmitIntoClient
    @inline(__always)
    public var pointerToLast: UnsafeMutablePointer<Element> {
        return self.firstElement.advanced(by: self.count - 1)
    }
}

#if DEBUG
/// Set this to false to improve performance in debug builds
public var __debug_enableSwiftNRCZombies = true
public typealias __debug_os_unfair_lock = Foundation.os_unfair_lock
public let __debug_os_unfair_lock_lock = Foundation.os_unfair_lock_lock
public let __debug_os_unfair_lock_unlock = Foundation.os_unfair_lock_unlock
#endif
