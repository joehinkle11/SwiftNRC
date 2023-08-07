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
}


@NRC(
    members: [
        "var y": Int.self,
        "private var x": Double.self,
        "internal var z": Bool.self,
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
