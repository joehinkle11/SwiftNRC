import XCTest
@testable import SwiftNRC

final class SwiftNRCTests: XCTestCase {
    func testExample() throws {
        XCTAssertEqual(Example.__debug_swiftNRCZombies.count, 0)

        let example = Example()
        XCTAssertEqual(example.x, 4.3)
        XCTAssertEqual(example.y, 5)
        XCTAssertEqual(example.z, true)
        example.z = false
        XCTAssertEqual(example.z, false)
        example.z.toggle()
        XCTAssertEqual(example.z, true)
        example.flipZ()
        XCTAssertEqual(example.z, false)
        XCTAssertEqual(example.constant, "can't change me!")
//        example.constant = "changed!" // this is a compile-time error
        example._force_set_constant(to: "changed!") // we can override it this way
        XCTAssertEqual(example.constant, "changed!")
        
        func scoped(_ copiedRef: Example) {
            copiedRef.y = 100
        }
        XCTAssertEqual(example.y, 5)
        scoped(example)
        XCTAssertEqual(example.y, 100)
        
        var example2 = Example()
        XCTAssertNotEqual(example.id, example2.id)
        XCTAssertEqual(example.id, example.id)
        XCTAssertEqual(example2.id, example2.id)
        let oldId = example2.id
        
        example2.assert_does_exist()
        var convertedExample2 = ExampleJustOneProperty(downcastFrom: example2)
        example2.assert_does_exist()
        XCTAssertNotEqual(example.id.hashValue, convertedExample2.id.hashValue)
        XCTAssertEqual(convertedExample2.id.hashValue, oldId.hashValue)
        XCTAssertEqual(convertedExample2.y, 5)
        convertedExample2.y = 111
        XCTAssertEqual(convertedExample2.y, 111)
        convertedExample2.assert_does_exist()
        example2 = convertedExample2.upcast()
        convertedExample2.assert_does_exist()
        XCTAssertEqual(example2.y, 111)
        
        example.delete()
        example2.delete()
        convertedExample2.assert_does_not_exist()
        
        XCTAssertEqual(Example.__debug_swiftNRCZombies.count, 0)
    }
    
    func testStackAllocated() throws {
        var example: Example!
        func scope() {
            var exampleStorage: Example.StoredMembers = (
                y: 5,
                x: 5.3,
                z: true,
                constant: "the constant"
            )
            example = .init(fromStorage: &exampleStorage)
            XCTAssertEqual(example.constant, "the constant")
            XCTAssertEqual(example.y, 5)
            example.y = 1
            XCTAssertEqual(example.y, 1)
        }
        scope()
        // should be junk, because storage got deallocated from stack
        XCTAssertNotEqual(example.y, 1)
    }
}


@NRC(
    members: [
        "var y": Int.self,
        "fileprivate var x": Double.self,
        "internal fileprivate(set) var z": Bool.self,
        "let constant": String.self
    ]
)
struct Example: SwiftNRCObject {
    
    init() {
        self = Self.allocate((
            y: 5,
            x: 4.3,
            z: true,
            constant: "can't change me!"
        ))
    }
    
    func flipZ() {
        self.z.toggle()
    }
    
    func delete() {
        self.deallocate()
    }
}


@NRC(
    members: [
        "var y": Int.self
    ],
    superNRC: Example.self
)
struct ExampleJustOneProperty: SwiftNRCObject {
    
}
