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
            if let url = RippleMetal.metallibURLInModuleBundle() {
                let shaderLibrary = try ShaderLibrary(url: url)
                cachedLibrary = shaderLibrary

                #if DEBUG
                if !didLogShaderNames, let lib = try? device.makeDefaultLibrary(bundle: .module) {
                    didLogShaderNames = true
                    print("RippleField: ShaderLibrary names: \(lib.functionNames.sorted()) from Bundle.module")
                }
                #endif

                return shaderLibrary
            }

            let lib = try RippleMetal.makeLibrary(on: device)

            #if DEBUG
            if !didLogShaderNames {
                didLogShaderNames = true
                print("RippleField: ShaderLibrary names (fallback MTLLibrary): \(lib.functionNames.sorted())")
            }
            #endif
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
            if let url = RippleMetal.metallibURLInModuleBundle() {
                print("RippleField: module metallib URL ->", url.path)
            } else {
                print("RippleField: module metallib URL -> NOT FOUND")
            }

            let lib = try RippleMetal.makeLibrary(on: dev)
            print("RippleField metallib symbols:", lib.functionNames.sorted())
        } catch {
            print("RippleField: makeLibrary failed ->", error)
        }
    }
}
