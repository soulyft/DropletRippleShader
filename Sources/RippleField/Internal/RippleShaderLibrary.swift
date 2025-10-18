import SwiftUI
import Foundation
#if canImport(Metal)
import Metal
#endif

enum RippleShaderLibrary {
    private static let lock = NSLock()
    private static var cachedLibrary: ShaderLibrary?

    #if canImport(Metal)
    private static var didLogShaderNames = false
    #endif

    private static func loadLibrary() -> ShaderLibrary? {
        lock.lock()
        defer { lock.unlock() }

        if let cachedLibrary {
            return cachedLibrary
        }

        #if canImport(Metal)
        guard let device = MTLCreateSystemDefaultDevice() else {
            return nil
        }

        do {
            let selection = try RippleMetal.makeLibrary(on: device)

            if let url = selection.url {
                do {
                    let shaderLibrary = try ShaderLibrary(url: url)
                    cachedLibrary = shaderLibrary

                    #if DEBUG
                    if !didLogShaderNames {
                        didLogShaderNames = true
                        print("RippleField: ShaderLibrary names: \(selection.library.functionNames.sorted()) from \(selection.originDescription)")
                    }
                    #endif

                    return shaderLibrary
                } catch {
                    #if DEBUG
                    print("RippleField: Failed to create ShaderLibrary from URL \(url): \(error)")
                    #endif
                }
            } else {
                #if DEBUG
                if !didLogShaderNames {
                    didLogShaderNames = true
                    print("RippleField: selected Metal library lacks file URL; names: \(selection.library.functionNames.sorted()) from \(selection.originDescription)")
                }
                #endif
            }
        } catch {
            #if DEBUG
            print("RippleField: Failed to create ShaderLibrary from Metal library: \(error)")
            #endif
            return nil
        }

        return nil
        #else
        return nil
        #endif
    }

    private static func shaderFunction(named name: String) -> ShaderFunction? {
        if let library = loadLibrary() {
            return ShaderFunction(library: library, name: name)
        }
        return nil
    }

    private static func makeShader(named name: String, arguments: [Shader.Argument]) -> Shader {
        if let function = shaderFunction(named: name) {
            return Shader(function: function, arguments: arguments)
        }

        // Fallback to SwiftUI's default lookup so the effect still attempts to run
        return Shader(function: ShaderFunction(library: .default, name: name), arguments: arguments)
    }

    static func ripple(_ arguments: Shader.Argument...) -> Shader {
        makeShader(named: "ripple", arguments: arguments)
    }

    static func rippleCluster(_ arguments: Shader.Argument...) -> Shader {
        makeShader(named: "rippleCluster", arguments: arguments)
    }

    static func rippleClusterPrismColor(_ arguments: Shader.Argument...) -> Shader {
        makeShader(named: "rippleClusterPrismColor", arguments: arguments)
    }

    static func rippleClusterGlowColor(_ arguments: Shader.Argument...) -> Shader {
        makeShader(named: "rippleClusterGlowColor", arguments: arguments)
    }
}

// In package (RippleField target)
#if canImport(Metal)
import Metal
#endif

public enum RippleDiagnostics {
    public static func ping(_ note: String = "hi") {
        print("RippleField.ping:", note)
    }

    public static func verifyMetal() {
        guard let dev = MTLCreateSystemDefaultDevice() else {
            print("RippleField: no Metal device"); return
        }
        do {
            let selection = try RippleMetal.makeLibrary(on: dev)
            print("RippleField metallib symbols:", selection.library.functionNames.sorted())
        } catch {
            print("RippleField: makeLibrary failed ->", error)
        }
    }
}
