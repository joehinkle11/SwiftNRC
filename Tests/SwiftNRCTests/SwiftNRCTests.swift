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
        XCTAssertEqual(example.constant, "can't change me!")
        
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
        let convertedExample2 = ExampleJustOneProperty(downcastFrom: example2)
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
        
        XCTAssertEqual(ExampleStaticArray.__debug_swiftNRCZombies.count, 0)
        XCTAssertNil(ExampleStaticArray())
        XCTAssertNil(ExampleStaticArray(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11))
        guard let exampleStaticArray = ExampleStaticArray(9, 8, 7, 6, 5, 4, 3, 2, 1, 0) else {
            return XCTFail()
        }
        let expectedSize = 2 * 8 + // first string
            10 * 8 + // array
            2 * 8 // last string
        let actualSize = MemoryLayout<String>.size +
            MemoryLayout<Int>.size * ExampleStaticArray.myArrayCount +
            MemoryLayout<String>.size
        XCTAssertEqual(actualSize, expectedSize)
        XCTAssertEqual(exampleStaticArray.before, "before string")
        XCTAssertEqual(exampleStaticArray.after, "after string")
        for i in 0..<10 {
            XCTAssertEqual(exampleStaticArray.myArray[i], 9 - i)
            exampleStaticArray.myArray[i] = i
        }
        XCTAssertEqual(exampleStaticArray.before, "before string")
        XCTAssertEqual(exampleStaticArray.after, "after string")
        for i in 0..<10 {
            XCTAssertEqual(exampleStaticArray.myArray[i], i)
        }
        XCTAssertEqual(exampleStaticArray.myArrayPointer, exampleStaticArray.myArrayPointer(at: 0))
        exampleStaticArray.delete()
        
        XCTAssertEqual(ExampleStaticArray.__debug_swiftNRCZombies.count, 0)
        
        
        XCTAssertEqual(ExampleStaticStack.__debug_swiftNRCZombies.count, 0)
        XCTAssertEqual(ExampleStaticStack.myStackCapacity, 10)
        let exampleStaticStack = ExampleStaticStack()
        XCTAssertEqual(exampleStaticStack.myStackCount, 0)
        XCTAssertEqual(exampleStaticStack.myStack.count, 0)
        exampleStaticStack.myStack.push(10)
        XCTAssertEqual(exampleStaticStack.myStackCount, 1)
        XCTAssertEqual(exampleStaticStack.myStack.count, 1)
        exampleStaticStack.myStack.push(9)
        XCTAssertEqual(exampleStaticStack.myStackCount, 2)
        XCTAssertEqual(exampleStaticStack.myStack.count, 2)
        exampleStaticStack.myStack.push(8)
        XCTAssertEqual(exampleStaticStack.myStackCount, 3)
        XCTAssertEqual(exampleStaticStack.myStack.count, 3)
        XCTAssertEqual(exampleStaticStack.myStack.pop(), 8)
        XCTAssertEqual(exampleStaticStack.myStack.count, 2)
        XCTAssertEqual(exampleStaticStack.myStack.pop(), 9)
        XCTAssertEqual(exampleStaticStack.myStack.count, 1)
        XCTAssertEqual(exampleStaticStack.myStack.pop(), 10)
        XCTAssertEqual(exampleStaticStack.myStack.count, 0)
        exampleStaticStack.delete()
        XCTAssertEqual(ExampleStaticStack.__debug_swiftNRCZombies.count, 0)
        
        XCTAssertEqual(ExampleStaticStack2.__debug_swiftNRCZombies.count, 0)
        XCTAssertEqual(ExampleStaticStack2.myStackCapacity, 2)
        let exampleStaticStack2 = ExampleStaticStack2()
        XCTAssertEqual(exampleStaticStack2.myStackCount, 0)
        XCTAssertEqual(exampleStaticStack2.myStack.count, 0)
        exampleStaticStack2.myStack.push(10)
        XCTAssertEqual(exampleStaticStack2.myStackCount, 1)
        XCTAssertEqual(exampleStaticStack2.myStack.count, 1)
        XCTAssertTrue(exampleStaticStack2.myStack.push(9))
        XCTAssertEqual(exampleStaticStack2.myStackCount, 2)
        XCTAssertEqual(exampleStaticStack2.myStack.count, 2)
        XCTAssertFalse(exampleStaticStack2.myStack.push(8))
        XCTAssertEqual(exampleStaticStack2.myStackCount, 2)
        XCTAssertEqual(exampleStaticStack2.myStack.count, 2)
        XCTAssertEqual(exampleStaticStack2.before, "before string")
        XCTAssertEqual(exampleStaticStack2.after, "after string")
        XCTAssertEqual(exampleStaticStack2.myStack.pop(), 9)
        XCTAssertEqual(exampleStaticStack2.myStack.count, 1)
        XCTAssertEqual(exampleStaticStack2.myStack.pop(), 10)
        XCTAssertEqual(exampleStaticStack2.myStack.count, 0)
        exampleStaticStack2.delete()
        XCTAssertEqual(ExampleStaticStack2.__debug_swiftNRCZombies.count, 0)
    }
    
    func testExampleFakeProperty() {
        let example = ExampleFakeProperties()
        example.propA = 5
        example.propB = 10.05
        XCTAssertEqual(example.propA, 5)
        XCTAssertEqual(example.anotherView.propA, 5)
        XCTAssertEqual(example.anotherView.backToParent.propA, 5)
        XCTAssertEqual(example.propB, 10.05)
        XCTAssertEqual(example.anotherView.propB, 10.05)
        XCTAssertEqual(example.anotherView.backToParent.propB, 10.05)
        example.anotherView.propA = -5
        example.anotherView.propB = -510.0
        XCTAssertEqual(example.propA, -5)
        XCTAssertEqual(example.anotherView.propA, -5)
        XCTAssertEqual(example.anotherView.propUsingOffsetVar, -5)
        XCTAssertEqual(example.anotherView.backToParent.propA, -5)
        XCTAssertEqual(example.propB, -510.0)
        XCTAssertEqual(example.anotherView.propB, -510.0)
        XCTAssertEqual(example.anotherView.backToParent.propB, -510.0)
    }
}


@NRC(
    members: [
        "var y": Int.self,
        "fileprivate var x": Double.self,
        "internal fileprivate(set) var z": Bool.self,
        "let constant": String.self,
        "let closure" : (() -> Void).self
    ]
)
struct Example: SwiftNRCObject {
    
    init() {
        self = Self.allocate((
            y: 5,
            x: 4.3,
            z: true,
            constant: "can't change me!",
            closure: {}
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
        self.initialize_before(to: "before string")
        for (i, number) in numbers.enumerated() {
            self.myArray.initialize(index: i, to: number)
        }
        self.initialize_after(to: "after string")
    }
    func delete() {
        self.deallocate()
    }
    
}

@NRC(
    members: [
        "let before" : String.self,
        "var myStack": NRCStaticStack(Int.self, 10),
        "let after" : String.self,
    ]
)
struct ExampleStaticStack: SwiftNRCObject {
    
    init() {
        self = .allocate()
        self.initialize_before(to: "before string")
        self.myStack.initialize()
        self.initialize_after(to: "after string")
    }
    func delete() {
        self.deallocate()
    }
}

@NRC(
    members: [
        "let before" : String.self,
        "var myStack": NRCStaticStack(Int.self, 2),
        "let after" : String.self,
    ]
)
struct ExampleStaticStack2: SwiftNRCObject {
    
    init() {
        self = .allocate()
        self.initialize_before(to: "before string")
        self.myStack.initialize()
        self.initialize_after(to: "after string")
    }
    func delete() {
        self.deallocate()
    }
}


struct ExampleFakeProperties {
    private let storage: UnsafeMutableRawPointer
    
    @Prop(atOffset: 0)
    var propA: Int
    
    @Prop(atOffset: 8)
    var propB: Double
    
    @AltView(startOffset: 8)
    var anotherView: ExampleFakeProperty

    init() {
        self.storage = .allocate(byteCount: 16, alignment: 8)
    }
}

private let constantWithValue8 = 8
struct ExampleFakeProperty {
    private let storage: UnsafeMutableRawPointer
    
    @Prop(atOffset: 0)
    var propB: Double
    
    @Prop(atOffset: -8)
    var propA: Int
    
    @Prop(atOffset: -constantWithValue8)
    var propUsingOffsetVar: Int
    
    @AltView(startOffset: -8)
    var backToParent: ExampleFakeProperties
}
