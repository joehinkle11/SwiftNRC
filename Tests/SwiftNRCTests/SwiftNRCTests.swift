import XCTest
@testable import SwiftNRC

final class SwiftNRCTests: XCTestCase {
    func testExample() throws {

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
        
        func scoped(_ copiedRef: Example) {
            copiedRef.y = 100
        }
        let id: Example.ID = example.id
        XCTAssertEqual(id.uncheckedLoadObject().y, 5)
        XCTAssertEqual(example.y, 5)
        scoped(example)
        XCTAssertEqual(example.y, 100)
        
        var example2 = Example()
        XCTAssertNotEqual(example.id, example2.id)
        XCTAssertEqual(example.id, example.id)
        XCTAssertEqual(example2.id, example2.id)
        let oldId = example2.id
        
        example2.assert_does_exist()
        var convertedExample2 = example2.forceAs(to: ExampleJustOneProperty.self)
        example2.assert_does_not_exist()
        XCTAssertNotEqual(example.id.hashValue, convertedExample2.id.hashValue)
        XCTAssertEqual(convertedExample2.id.hashValue, oldId.hashValue)
        XCTAssertEqual(convertedExample2.y, 5)
        convertedExample2.y = 111
        XCTAssertEqual(convertedExample2.y, 111)
        convertedExample2.assert_does_exist()
        example2 = convertedExample2.forceAs(to: Example.self)
        convertedExample2.assert_does_not_exist()
        XCTAssertEqual(example2.y, 111)
        
        example.delete()
        example2.delete()
    }
    
    func testStackAllocated() throws {
        var example: Example!
        func scope() {
            var exampleStorage: Example.StoredMembers = (
                y: 5,
                x: 5.3,
                z: true
            )
            example = .init(fromStorage: &exampleStorage)
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


@NRC(
    members: [
        "var y": Int.self
    ]
)
struct ExampleJustOneProperty: SwiftNRCObject {
    
}
