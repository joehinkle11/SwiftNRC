import Foundation
import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics

public struct NRC: MemberMacro {
    public static func expansion(of node: AttributeSyntax, providingMembersOf declaration: some DeclGroupSyntax, in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            context.diagnose(NRCErrorMessage(id: "nrc_only_struct", message: "Only structs can an NRC (object with no reference count).").diagnose(at: declaration))
            return []
        }
        
        // Validate our stored members model only has stored properties
        // Also make an array of all stored members names
        var allStoredMembersNamesAndTypes: [(name: String, type: String, isLet: Bool, accessModifier: String)] = []
        
        switch node.arguments {
        case .argumentList(let arguments):
            guard let membersArgument = arguments.first, membersArgument.label?.text == "members" else {
                context.diagnose(NRCErrorMessage(id: "fatal", message: "macro fatal error expected members").diagnose(at: node))
                return []
            }
            for element in membersArgument.expression.cast(DictionaryExprSyntax.self).content.cast(DictionaryElementListSyntax.self) {
                guard let key = element.key.as(StringLiteralExprSyntax.self)?.segments.trimmedDescription else {
                    context.diagnose(NRCErrorMessage(id: "fatal", message: "You must defined members keys with string literals").diagnose(at: node))
                    return []
                }
                let accessModifier: String
                let baseAccessModifiers = ["private", "fileprivate", "internal", "public"]
                let validAccessModifiers = ["private", "fileprivate", "internal", "public"]
                let accessModifier = validAccessModifiers.first(where: {
                    key.hasPrefix($0)
                }) ?? ""
                let varNameWithLetOrVar = String(key.dropFirst(accessModifier.count))
                let isLet: Bool
                if key.hasPrefix("let ") {
                    isLet = true
                } else if key.hasPrefix("var ") {
                    isLet = false
                } else {
                    context.diagnose(NRCErrorMessage(id: "fatal", message: "You must defined members value with a name indicating if they are let or a var. i.e. \"let x\"").diagnose(at: node))
                    return []
                }
                let varName = String(key.dropFirst(4))
                guard let value = element.value.as(MemberAccessExprSyntax.self),
                      let typeString = value.base?.trimmedDescription,
                      value.declName.argumentNames == nil,
                      value.declName.baseName.trimmedDescription == "self" else {
                    context.diagnose(NRCErrorMessage(id: "fatal", message: "You must defined members value with a type reference as i.e. Int.self").diagnose(at: node))
                    return []
                }
                allStoredMembersNamesAndTypes.append((name: varName, type: typeString, isLet: isLet, accessModifier: accessModifier))
            }
        default:
            context.diagnose(NRCErrorMessage(id: "fatal", message: "macro fatal error").diagnose(at: node))
            return []
        }
        
        // Get scope
        var structIsPublic = false
        if let modifiers = structDecl.modifiers {
            for modifier in modifiers {
                if modifier.name.tokenKind == .keyword(.public) {
                    structIsPublic = true
                }
            }
        }
        
        // Make each stored member a computed property
        var computedProperties: [DeclSyntax] = []
        for (name, type, isLet, isPrivate) in allStoredMembersNamesAndTypes {
            let scopeText = isPrivate ? "private " : (structIsPublic ? "public " : "")
            let dotAccess: String = allStoredMembersNamesAndTypes.count == 1 ? "" : ".\(name)"
            computedProperties.append("""
            @inline(__always)
            @_alwaysEmitIntoClient
            \(raw: scopeText)var \(raw: name): \(raw: type) {
                get {
                    #if DEBUG
                    if __debug_enableSwiftNRCZombies {
                        __debug_os_unfair_lock_lock(&Self.__debug_swiftNRCZombiesLock)
                        assert(Self.__debug_swiftNRCZombies[self.pointer] == true, "Access on deallocated NRC object.")
                        __debug_os_unfair_lock_unlock(&Self.__debug_swiftNRCZombiesLock)
                    }
                    #endif
                    return pointer.pointee\(raw: dotAccess)
                }
            \(raw: isLet ? "" : """
                nonmutating set {
                    #if DEBUG
                    if __debug_enableSwiftNRCZombies {
                        __debug_os_unfair_lock_lock(&Self.__debug_swiftNRCZombiesLock)
                        assert(Self.__debug_swiftNRCZombies[self.pointer] == true, "Modification on deallocated NRC object.")
                        __debug_os_unfair_lock_unlock(&Self.__debug_swiftNRCZombiesLock)
                    }
                    #endif
                    pointer.pointee.\(name) = newValue
                }
            """)
            }
            """)
        }
        
        // Make the stored members type
        let storedMembersTupleType: String
        if allStoredMembersNamesAndTypes.count == 1, let first = allStoredMembersNamesAndTypes.first {
            storedMembersTupleType = first.type
        } else {
            storedMembersTupleType = "(" + allStoredMembersNamesAndTypes.map({
                $0.name + ": " + $0.type
            }).joined(separator: ",") + ")"
        }
         
        // Name of the struct
        let structName = structDecl.name.trimmed.description

        let scopeText = structIsPublic ? "public " : ""
        
        return [
            """
            private typealias StoredMembers = \(raw: storedMembersTupleType)
            @inline(__always) @_alwaysEmitIntoClient
            private let pointer: UnsafeMutablePointer<StoredMembers>
            @inline(__always) @_alwaysEmitIntoClient
            private static func allocate(_ storedMembers: StoredMembers) -> Self {
                let pointer = UnsafeMutablePointer<StoredMembers>.allocate(capacity: 1)
                pointer.initialize(to: storedMembers)
                #if DEBUG
                if __debug_enableSwiftNRCZombies {
                    __debug_os_unfair_lock_lock(&Self.__debug_swiftNRCZombiesLock)
                    Self.__debug_swiftNRCZombies[.init(pointer)] = true
                    __debug_os_unfair_lock_unlock(&Self.__debug_swiftNRCZombiesLock)
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
                #if DEBUG
                if __debug_enableSwiftNRCZombies {
                    __debug_os_unfair_lock_lock(&Self.__debug_swiftNRCZombiesLock)
                    assert(Self.__debug_swiftNRCZombies[self.pointer] == true, "You have already deallocated this NRC object")
                    Self.__debug_swiftNRCZombies[self.pointer] = false
                    __debug_os_unfair_lock_unlock(&Self.__debug_swiftNRCZombiesLock)
                }
                #endif
                pointer.deallocate()
            }
            \(raw: scopeText)struct ID: Equatable, Hashable {
                private let pointer: UnsafeMutablePointer<StoredMembers>
                @inline(__always) @_alwaysEmitIntoClient
                \(raw: scopeText)init(_ object: \(raw: structName)) {
                    self.pointer = object.pointer
                    #if DEBUG
                    if __debug_enableSwiftNRCZombies {
                        __debug_os_unfair_lock_lock(&\(raw: structName).__debug_swiftNRCZombiesLock)
                        assert(\(raw: structName).__debug_swiftNRCZombies[self.pointer] == true, "Access on deallocated NRC object.")
                        __debug_os_unfair_lock_unlock(&\(raw: structName).__debug_swiftNRCZombiesLock)
                    }
                    #endif
                }
                
                @inline(__always) @_alwaysEmitIntoClient
                \(raw: scopeText)func uncheckedLoadObject() -> \(raw: structName) {
                    #if DEBUG
                    if __debug_enableSwiftNRCZombies {
                        __debug_os_unfair_lock_lock(&\(raw: structName).__debug_swiftNRCZombiesLock)
                        assert(\(raw: structName).__debug_swiftNRCZombies[self.pointer] == true, "Access on deallocated NRC object.")
                        __debug_os_unfair_lock_unlock(&\(raw: structName).__debug_swiftNRCZombiesLock)
                    }
                    #endif
                    return \(raw: structName)(pointer: self.pointer)
                }
            }
            @inline(__always) @_alwaysEmitIntoClient
            \(raw: scopeText)var id: ID {
                return ID(self)
            }
            @inline(__always) @_alwaysEmitIntoClient
            \(raw: scopeText)func assert_does_exist() {
                #if DEBUG
                __debug_os_unfair_lock_lock(&\(raw: structName).__debug_swiftNRCZombiesLock)
                assert(\(raw: structName).__debug_swiftNRCZombies[self.pointer] == true, "Access on deallocated NRC object.")
                __debug_os_unfair_lock_unlock(&\(raw: structName).__debug_swiftNRCZombiesLock)
                #endif
            }
            #if DEBUG
            // This is to help catch memory errors in debug builds.
            /// A dictionary where true mean it exists and false means it has been deallocated
            private static var __debug_swiftNRCZombies: [UnsafePointer<StoredMembers> : Bool] = [:]
            /// Ensures only one thread touches `__debug_swiftNRCZombies` as a time.
            private static var __debug_swiftNRCZombiesLock = __debug_os_unfair_lock()
            #endif
            """,
        ] + computedProperties
    }
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

#if canImport(SwiftCompilerPlugin)
import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SwiftNRCMacrosPlugin: CompilerPlugin {
    
    let providingMacros: [Macro.Type] = [
        NRC.self,
    ]
}
#endif
