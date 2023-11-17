import Foundation
import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics
import SwiftSyntaxBuilder

public struct Prop: AccessorMacro {
    public static func expansion(of node: AttributeSyntax, providingAccessorsOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [AccessorDeclSyntax] {
        // Extract the argument `atOffset` from `node`
        guard case let .argumentList(arguments) = node.arguments else {
            context.diagnose(NRCErrorMessage(id: "prop_no_arguments", message: "Prop requires an argument list.").diagnose(at: node))
            return []
        }
        guard let type = declaration.as(VariableDeclSyntax.self)?.bindings.first?.typeAnnotation?.type else {
            context.diagnose(NRCErrorMessage(id: "prop_only_variables", message: "Prop can only be applied to variables.").diagnose(at: declaration))
            return []
        }
        guard arguments.count == 1 else {
            context.diagnose(NRCErrorMessage(id: "prop_one_argument", message: "Prop requires exactly one argument.").diagnose(at: node))
            return []
        }
        let offset: Int
        if let atOffset = arguments.first?.expression.as(IntegerLiteralExprSyntax.self)?.literal {
            guard let theOffset: Int = Int(atOffset.trimmedDescription) else {
                context.diagnose(NRCErrorMessage(id: "prop_integer_argument", message: "Prop requires an integer argument.").diagnose(at: node))
                return []
            }
            offset = theOffset
        } else if let negativeOffset = arguments.first?.expression.as(PrefixOperatorExprSyntax.self)?.expression.as(IntegerLiteralExprSyntax.self)?.literal {
            guard let theOffset: Int = Int(negativeOffset.trimmedDescription) else {
                context.diagnose(NRCErrorMessage(id: "prop_integer_argument", message: "Prop requires an integer argument.").diagnose(at: node))
                return []
            }
            offset = -theOffset
        } else {
            context.diagnose(NRCErrorMessage(id: "prop_integer_argument", message: "Prop requires an integer argument.").diagnose(at: node))
            return []
        }
        
        return [
            """
            get {
                storage.advanced(by: \(offset)).assumingMemoryBound(to: \(type.trimmedDescription).self).pointee
            }
            nonmutating set {
                storage.advanced(by: \(offset)).assumingMemoryBound(to: \(type.trimmedDescription).self).pointee = newValue
            }
            """
        ]
    }
}

public struct AltView: AccessorMacro {
    public static func expansion(of node: AttributeSyntax, providingAccessorsOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [AccessorDeclSyntax] {
        // Extract the argument `startOffset` from `node`
        guard case let .argumentList(arguments) = node.arguments else {
            context.diagnose(NRCErrorMessage(id: "altview_no_arguments", message: "AltView requires an argument list.").diagnose(at: node))
            return []
        }
        guard let type = declaration.as(VariableDeclSyntax.self)?.bindings.first?.typeAnnotation?.type else {
            context.diagnose(NRCErrorMessage(id: "altview_only_variables", message: "AltView can only be applied to variables.").diagnose(at: declaration))
            return []
        }
        guard arguments.count == 1 else {
            context.diagnose(NRCErrorMessage(id: "altview_one_argument", message: "AltView requires exactly one argument.").diagnose(at: node))
            return []
        }
        let offset: Int
        if let atOffset = arguments.first?.expression.as(IntegerLiteralExprSyntax.self)?.literal {
            guard let theOffset: Int = Int(atOffset.trimmedDescription) else {
                context.diagnose(NRCErrorMessage(id: "prop_integer_argument", message: "Prop requires an integer argument.").diagnose(at: node))
                return []
            }
            offset = theOffset
        } else if let negativeOffset = arguments.first?.expression.as(PrefixOperatorExprSyntax.self)?.expression.as(IntegerLiteralExprSyntax.self)?.literal {
            guard let theOffset: Int = Int(negativeOffset.trimmedDescription) else {
                context.diagnose(NRCErrorMessage(id: "prop_integer_argument", message: "Prop requires an integer argument.").diagnose(at: node))
                return []
            }
            offset = -theOffset
        } else {
            context.diagnose(NRCErrorMessage(id: "prop_integer_argument", message: "Prop requires an integer argument.").diagnose(at: node))
            return []
        }
        
        return [
            """
            get {
                unsafeBitCast(Int(bitPattern: storage.advanced(by: \(offset))), to: \(type.trimmedDescription).self)
            }
            """
        ]
    }
}

public struct NRC: MemberMacro {
    public static func expansion(of node: AttributeSyntax, providingMembersOf declaration: some DeclGroupSyntax, in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            context.diagnose(NRCErrorMessage(id: "nrc_only_struct", message: "Only structs can an NRC (object with no reference count).").diagnose(at: declaration))
            return []
        }
        
        // Validate that our struct conforms to SwiftNRCObject
        guard structDecl.inheritanceClause?.inheritedTypes.contains(where: {
                $0.type.trimmedDescription == "SwiftNRCObject"
              }) == true else {
            context.diagnose(NRCErrorMessage(id: "nrc_only_struct", message: "You must add conformance to SwiftNRCObject.").diagnose(at: declaration))
            return []
        }
        
        // Validate our stored members model only has stored properties
        // Also make an array of all stored members names
        var allStoredMembersNamesAndTypes: [(name: String, type: String, isLet: Bool, accessModifier: String, commentText: String, isArrayWithCount: Int?)] = []
        
        var superNRCName: String? = nil
        
        switch node.arguments {
        case .argumentList(let arguments):
            if let superNRC = arguments.dropFirst().first {
                guard superNRC.label?.text == "superNRC" else {
                    context.diagnose(NRCErrorMessage(id: "fatal", message: "macro fatal error expected superNRC").diagnose(at: superNRC))
                    return []
                }
                superNRCName = superNRC.expression.cast(MemberAccessExprSyntax.self).base!.cast(DeclReferenceExprSyntax.self).baseName.text
            }
            guard let membersArgument = arguments.first, membersArgument.label?.text == "members" else {
                context.diagnose(NRCErrorMessage(id: "fatal", message: "macro fatal error expected members").diagnose(at: arguments))
                return []
            }
            for element in membersArgument.expression.cast(DictionaryExprSyntax.self).content.cast(DictionaryElementListSyntax.self) {
                // todo: add comment text
                var commentText = ""
                guard let key = element.key.as(StringLiteralExprSyntax.self)?.segments.trimmedDescription else {
                    context.diagnose(NRCErrorMessage(id: "fatal", message: "You must defined members keys with string literals").diagnose(at: element.key))
                    return []
                }
                let accessModifier = validAccessModifiers.first(where: {
                    key.hasPrefix($0)
                }) ?? ""
                let varNameWithLetOrVar = String(key.dropFirst(accessModifier.count))
                let isLet: Bool
                if varNameWithLetOrVar.hasPrefix("let ") {
                    isLet = true
                } else if varNameWithLetOrVar.hasPrefix("var ") {
                    isLet = false
                } else {
                    context.diagnose(NRCErrorMessage(id: "fatal", message: "You must defined members value with a name indicating if they are let or a var. i.e. \"let x\". Found \"\(varNameWithLetOrVar)\".").diagnose(at: element.key))
                    return []
                }
                let varName = String(varNameWithLetOrVar.dropFirst(4))
                if let value = element.value.as(MemberAccessExprSyntax.self),
                      let typeString = value.base?.trimmedDescription,
                      value.declName.argumentNames == nil,
                   value.declName.baseName.trimmedDescription == "self" {
                    allStoredMembersNamesAndTypes.append((name: varName, type: typeString, isLet: isLet, accessModifier: accessModifier, commentText: commentText, isArrayWithCount: nil))
                } else if let funcCall = element.value.as(FunctionCallExprSyntax.self),
                            let calledExpression = funcCall.calledExpression.as(DeclReferenceExprSyntax.self),
                          calledExpression.baseName.text == "NRCStaticArray" {
                    guard funcCall.arguments.count == 2,
                          let typeToArrayify = funcCall.arguments.first,
                          let numberOfElements = funcCall.arguments.last else {
                        context.diagnose(NRCErrorMessage(id: "fatal", message: "NRCStaticArray requires 2 arguments.").diagnose(at: funcCall))
                        return []
                    }
                    guard let value = typeToArrayify.expression.as(MemberAccessExprSyntax.self),
                          let typeString = value.base?.trimmedDescription,
                          value.declName.argumentNames == nil,
                       value.declName.baseName.trimmedDescription == "self" else {
                        context.diagnose(NRCErrorMessage(id: "fatal", message: "NRCStaticArray requires a type reference as its first argument.").diagnose(at: typeToArrayify))
                        return []
                    }
                    guard let numberOfElementsInt = numberOfElements.expression.as(IntegerLiteralExprSyntax.self),
                          let numberOfElementsIntValue = Int(numberOfElementsInt.literal.text) else {
                        context.diagnose(NRCErrorMessage(id: "fatal", message: "NRCStaticArray requires an integer literal as its second argument.").diagnose(at: numberOfElements))
                        return []
                    }
                    allStoredMembersNamesAndTypes.append((name: varName, type: typeString, isLet: isLet, accessModifier: accessModifier, commentText: commentText, isArrayWithCount: numberOfElementsIntValue))
                } else {
                    context.diagnose(NRCErrorMessage(id: "fatal", message: "You must defined members value with a type reference as i.e. Int.self").diagnose(at: element.value))
                    return []
                }
            }
        default:
            context.diagnose(NRCErrorMessage(id: "fatal", message: "macro fatal error").diagnose(at: node))
            return []
        }
        
        // Get scope
        var structIsPublic = false
        for modifier in structDecl.modifiers {
            if modifier.name.tokenKind == .keyword(.public) {
                structIsPublic = true
            }
        }
        
        // Name of the struct
        let structName = structDecl.name.trimmed.description
        
        // If it has a super
        let hasSuperNRC = superNRCName != nil
        
        // Where to increment zombie count
        let zombieCountTypeContainerName: String = superNRCName ?? structName
        
        // Make each stored member a computed property
        var computedProperties: [DeclSyntax] = []
        for (name, type, isLet, scopeText, commentText, isArrayWithCount) in allStoredMembersNamesAndTypes {
            // Arrays get different methods
            if let arrayCount = isArrayWithCount {
                computedProperties.append("""
                @inline(__always)
                @_alwaysEmitIntoClient
                /// \(name) is a static array with \(arrayCount) elements. You can access a pointer to the array's first element with this property.
                \(scopeText)var \(name)Pointer: UnsafeMutablePointer<\(type)> {
                    return UnsafeMutableRawPointer(mutating: self.pointer!.pointer(to: \\.\(name)))!.assumingMemoryBound(to: \(type).self)
                }
                @inline(__always)
                @_alwaysEmitIntoClient
                /// \(name) is a static array with \(arrayCount) elements. You can access an element's pointer at a specific index with this method.
                \(scopeText)func \(name)Pointer(at index: Int) -> UnsafeMutablePointer<\(type)> {
                    return self.\(name)Pointer.advanced(by: index)
                }
                @inline(__always)
                @_alwaysEmitIntoClient
                /// \(name) is a static array with \(arrayCount) elements. You can access the array through this property.
                \(scopeText)var \(name): NRCStaticArray<\(type)> {
                    return .createForSwiftNRCObject(self, \\.\(name)Pointer)
                }
                @inline(__always)
                @_alwaysEmitIntoClient
                /// The amount of elements in \(name) (which is a static array with \(arrayCount) elements).
                \(scopeText)static var \(name)Count: Int {
                    return \(arrayCount)
                }
                """)
            } else {
                let dotAccess: String = allStoredMembersNamesAndTypes.count == 1 ? "" : ".\(name)"
                computedProperties.append("""
                @inline(__always)
                @_alwaysEmitIntoClient
                \(commentText)
                \(scopeText)var \(name): \(type) {
                    get {
                        return pointer!.pointee\(dotAccess)
                    }
                \(isLet ? "" : """
                    nonmutating set {
                        pointer!.pointee\(dotAccess) = newValue
                    }
                """)
                }
                \(isLet ? """
                @inline(__always)
                @_alwaysEmitIntoClient
                /// \(name) is a let property. You can force set \(name) with this method.
                \(scopeText)func _force_set_\(name)(to newValue: \(type)) {
                    pointer!.pointee\(dotAccess) = newValue
                }
                """ : "")
                """)
            }
        }
        
        // Find collisions
        var foundCollision = false
        for el1I in allStoredMembersNamesAndTypes.indices {
            let el1 = allStoredMembersNamesAndTypes[el1I]
            for el2I in allStoredMembersNamesAndTypes.indices {
                if el1I == el2I {
                    continue
                }
                let el2 = allStoredMembersNamesAndTypes[el2I]
                if el1.name == el2.name {
                    foundCollision = true
                    context.diagnose(NRCErrorMessage(id: "nrc_collision", message: "Found collision in members names \"\(el1.name)\".").diagnose(at: node))
                }
            }
        }
        guard !foundCollision else {
            return []
        }
        
        // Make the stored members type
        var storedMembersTupleType: String = "("
        for (i, allStoredMembersNamesAndType) in allStoredMembersNamesAndTypes.enumerated() {
            if i != 0 {
                storedMembersTupleType += ", "
            }
            if let count = allStoredMembersNamesAndType.isArrayWithCount {
                for j in 0..<count {
                    if j == 0 {
                        storedMembersTupleType += allStoredMembersNamesAndType.name + ": " 
                    } else {
                        storedMembersTupleType += ", "
                    }
                    storedMembersTupleType += allStoredMembersNamesAndType.type
                }
            } else {
                if allStoredMembersNamesAndTypes.count == 1 {
                    storedMembersTupleType += allStoredMembersNamesAndType.type
                } else {
                    storedMembersTupleType += allStoredMembersNamesAndType.name + ": " + allStoredMembersNamesAndType.type
                }
            }
        }
        storedMembersTupleType += ")"

        let scopeText = structIsPublic ? "public " : ""

        return [
            """
            \(scopeText)typealias StoredMembers = \(storedMembersTupleType)
            @inline(__always) @_alwaysEmitIntoClient
            \(scopeText)init(fromRawPointer rawPointer: UnsafeMutableRawPointer) {
                self.init(fromPointer: rawPointer.assumingMemoryBound(to: StoredMembers.self))
            }
            @inline(__always) @_alwaysEmitIntoClient
            \(scopeText)init(fromPointer pointer: UnsafeMutablePointer<StoredMembers>) {
                self.pointer = pointer
            }
            @inline(__always) @_alwaysEmitIntoClient
            \(scopeText)init(fromStorage storage: inout StoredMembers) {
                self.pointer = .init(&storage)
            }
            @inline(__always) @_alwaysEmitIntoClient
            \(scopeText)mutating func nilOutWithoutDeallocate() {
                self.pointer = nil
            }
            @inline(__always) @_alwaysEmitIntoClient
            \(scopeText)var id: SwiftNRCObjectID {
                return SwiftNRCObjectID(.init(self.pointer!))
            }
            @inline(__always) @_alwaysEmitIntoClient
            \(scopeText)func assert_does_exist() {
                #if DEBUG
                __debug_os_unfair_lock_lock(&\(zombieCountTypeContainerName).__debug_swiftNRCZombiesLock)
                assert(\(zombieCountTypeContainerName).__debug_swiftNRCZombies.contains(self.pointer!), "Access on deallocated NRC object.")
                __debug_os_unfair_lock_unlock(&\(zombieCountTypeContainerName).__debug_swiftNRCZombiesLock)
                #endif
            }
            @inline(__always) @_alwaysEmitIntoClient
            \(scopeText)func assert_does_not_exist() {
                #if DEBUG
                __debug_os_unfair_lock_lock(&\(zombieCountTypeContainerName).__debug_swiftNRCZombiesLock)
                assert(self.pointer == nil || !\(zombieCountTypeContainerName).__debug_swiftNRCZombies.contains(self.pointer!), "NRC object still exists.")
                __debug_os_unfair_lock_unlock(&\(zombieCountTypeContainerName).__debug_swiftNRCZombiesLock)
                #endif
            }
            @inline(__always) @_alwaysEmitIntoClient
            public var pointer: UnsafeMutablePointer<StoredMembers>?
            @inline(__always) @_alwaysEmitIntoClient
            private static func allocate() -> Self {
                let pointer = UnsafeMutablePointer<StoredMembers>.allocate(capacity: 1)
                #if DEBUG
                if __debug_enableSwiftNRCZombies {
                    __debug_os_unfair_lock_lock(&\(zombieCountTypeContainerName).__debug_swiftNRCZombiesLock)
                    \(zombieCountTypeContainerName).__debug_swiftNRCZombies.insert(.init(pointer))
                    __debug_os_unfair_lock_unlock(&\(zombieCountTypeContainerName).__debug_swiftNRCZombiesLock)
                }
                #endif
                return Self(pointer: pointer)
            }
            @inline(__always) @_alwaysEmitIntoClient
            private static func allocate(_ storedMembers: StoredMembers) -> Self {
                let pointer = UnsafeMutablePointer<StoredMembers>.allocate(capacity: 1)
                pointer.initialize(to: storedMembers)
                #if DEBUG
                if __debug_enableSwiftNRCZombies {
                    __debug_os_unfair_lock_lock(&\(zombieCountTypeContainerName).__debug_swiftNRCZombiesLock)
                    \(zombieCountTypeContainerName).__debug_swiftNRCZombies.insert(.init(pointer))
                    __debug_os_unfair_lock_unlock(&\(zombieCountTypeContainerName).__debug_swiftNRCZombiesLock)
                }
                #endif
                return Self(pointer: pointer)
            }
            @inline(__always) @_alwaysEmitIntoClient
            private init(pointer: UnsafeMutablePointer<StoredMembers>) {
                self.pointer = pointer
            }
            @inline(__always) @_alwaysEmitIntoClient
            private func deallocate() {
                self.assert_does_exist()
                #if DEBUG
                if __debug_enableSwiftNRCZombies {
                    __debug_os_unfair_lock_lock(&\(zombieCountTypeContainerName).__debug_swiftNRCZombiesLock)
                    \(zombieCountTypeContainerName).__debug_swiftNRCZombies.remove(.init(self.pointer!))
                    __debug_os_unfair_lock_unlock(&\(zombieCountTypeContainerName).__debug_swiftNRCZombiesLock)
                }
                #endif
                pointer!.deallocate()
            }
            \(hasSuperNRC ? """
            @inline(__always) @_alwaysEmitIntoClient
            \(scopeText)func upcast() -> \(zombieCountTypeContainerName) {
                return \(zombieCountTypeContainerName)(fromRawPointer: .init(self.pointer!))
            }
            \(scopeText)init(downcastFrom superNRC: \(zombieCountTypeContainerName)) {
                self.init(fromRawPointer: .init(superNRC.pointer!))
            }
            """: """
            #if DEBUG
            /// This is to help catch memory errors in debug builds.
            \(scopeText) static var __debug_swiftNRCZombies: Set<UnsafeRawPointer> = []
            /// Ensures only one thread touches `__debug_swiftNRCZombies` as a time.
            \(scopeText) static var __debug_swiftNRCZombiesLock = __debug_os_unfair_lock()
            #endif
            """)
            """,
        ] + computedProperties
    }
}

let baseAccessModifiersWithoutPublic = ["private", "fileprivate", "internal"]
let baseAccessModifiers: [String] = baseAccessModifiersWithoutPublic + ["public"]
let validAccessModifiers: [String] = (baseAccessModifiers + {
    let baseAccessModifiersWithSpace = [""] + baseAccessModifiers.map {$0 + " "}
    let res: [[String]] = baseAccessModifiersWithSpace.map({ baseAccessModifier in
        let res = baseAccessModifiersWithoutPublic.map { (baseAccessModifierWithoutPublic: String) in
            return baseAccessModifier + baseAccessModifierWithoutPublic + "(set)" as String
        } as [String]
        return res
    })
    return res.reduce([], { (arr: [String], strs: [String]) in
        return arr + strs
    }) as [String]
}()).map { (str: String) in
    return str + " " as String
}.sorted { a, b in
    a.count > b.count
}

struct NRCErrorMessage: Error, DiagnosticMessage {
    
    func diagnose(at node: some SyntaxProtocol) -> Diagnostic {
        Diagnostic(node: Syntax(node), message: self)
    }
    var diagnosticID: SwiftDiagnostics.MessageID {
        .init(domain: "NRC", id: self.id)
    }
    
    var severity: SwiftDiagnostics.DiagnosticSeverity {
        return .error
    }
    
    let id: String
    let message: String
}

extension SyntaxStringInterpolation {
    
    mutating func appendInterpolation<T>(_ value: T) {
        self.appendInterpolation(raw: value)
    }
}

#if canImport(SwiftCompilerPlugin)
import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SwiftNRCMacrosPlugin: CompilerPlugin {
    
    let providingMacros: [Macro.Type] = [
        NRC.self,
        Prop.self,
        AltView.self,
    ]
}
#endif
