# Swift No Reference Counting (NRC)

Swift objects without ARC/reference counting.

This is an experimental idea to provide objects in Swift without having the overhead of reference counting and other features baked into native Swift classes.

The core concept is to just to use Swift macros to prettify the usage of `UnsafeMutablePointer` and `UnsafeMutableRawPointer` to create a simple object system.

## Setup

```swift
    
    dependencies: [
        .package(
            url: "https://github.com/joehinkle11/SwiftNRC",
            .upToNextMajor(from: "1.0.0")),
    ],
    targets: [
        .target(
            name: "YourTarget",
            plugins: ["SwiftNRC"]
        ),
    ]
```

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

## Static Array Support

You can also now allocate a static array between/among other properties in your object like in a c struct:

```swift
@NRC(
    members: [
        "let before" : String.self,
        "var myArray": NRCStaticArray(Int.self, 10),
        "let after" : String.self,
    ]
)
struct ExampleStaticArray: SwiftNRCObject {
    
    init?(_ numbers: Int...) {
        guard numbers.count == Self.myArrayCount else {
            return nil
        }
        self = .allocate()
        self._force_set_before(to: "before string")
        for (i, number) in numbers.enumerated() {
            self.myArray[i] = number
        }
        self._force_set_after(to: "after string")
    }
    func delete() {
        self.deallocate()
    }
    
}

func arrayUsage() {
    let exampleStaticArray = ExampleStaticArray(9, 8, 7, 6, 5, 4, 3, 2, 1, 0)!
    for i in 0..<10 {
        XCTAssertEqual(exampleStaticArray.myArray[i], 9 - i)
        exampleStaticArray.myArray[i] = i
    }
    let pointerToFirstElement = exampleStaticArray.myArrayPointer
}
```

All static array values (and properties for that matter) will be contiguous in memory. This means that you can pass a pointer to the first element of the array to a c function and it will be able to read all the values in the array.

## Use Cases

Uses these non-reference counted objects is more performant than traditional classes in Swift. In a performance critical application, this objects of this sort can help reduce the overhead associated with ARC.

