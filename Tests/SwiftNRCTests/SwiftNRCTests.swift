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
        
        let example2 = Example()
        XCTAssertNotEqual(example.id, example2.id)
        XCTAssertEqual(example.id, example.id)
        XCTAssertEqual(example2.id, example2.id)
        
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
struct Example {
    
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
