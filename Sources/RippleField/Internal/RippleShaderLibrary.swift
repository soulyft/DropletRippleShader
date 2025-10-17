import SwiftUI
import Foundation

enum RippleShaderLibrary {
    private static let lock = NSLock()
    private static var cachedLibrary: ShaderLibrary?

    private static func loadLibrary() -> ShaderLibrary? {
        lock.lock()
        defer { lock.unlock() }

        if let cachedLibrary {
            return cachedLibrary
        }

        guard let libraryURL = RippleMetal.shaderLibraryURL() else {
            return nil
        }

        do {
            let shaderLibrary = try ShaderLibrary(libraryURL)
            cachedLibrary = shaderLibrary
            return shaderLibrary
        } catch {
            #if DEBUG
            print("RippleField: Failed to load Metal library at \(libraryURL): \(error)")
            #endif
            return nil
        }
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
