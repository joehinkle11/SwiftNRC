# Swift No Reference Counting (NRC)

Swift objects without ARC/reference counting.

This is an experimental idea to provide objects in Swift without having the overhead of reference counting and other features baked into native Swift classes.

The core concept is to just to use Swift macros to prettify the usage of `UnsafeMutablePointer` and `UnsafeMutableRawPointer` to create a simple object system.


## Examples

```swift
@NRC(
    members: [
        "var y": Int.self,
        "private var x": Double.self,
        "internal var z": Bool.self,
    ]
)
struct Example: SwiftNRCObject {
    
    init() {
        self = Self.allocate((
            y: 5,
            x: 4.3,
            z: true
        ))
    }
    
    func flipZ() {
        self.z.toggle()
    }
    
    func delete() {
        self.deallocate()
    }
}

let example = Example()
// XCTAssertEqual(example.x, 4.3) // no access, x is private
XCTAssertEqual(example.y, 5)
XCTAssertEqual(example.z, true)
example.z = false
XCTAssertEqual(example.z, false)
func scoped(_ copiedRef: Example) {
    copiedRef.y = 100
}
XCTAssertEqual(example.y, 5)
scoped(example)
XCTAssertEqual(example.y, 100)
```


## Use Cases

Uses these non-reference counted objects is more performant than traditional classes in Swift. In a performance critical application, this objects of this sort can help reduce the overhead associated with ARC.
