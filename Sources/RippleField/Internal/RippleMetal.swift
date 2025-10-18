import Foundation
#if canImport(Metal)
import Metal
#endif

enum RippleMetal {
    private final class BundleToken {}

    private static func candidateBundles() -> [Bundle] {
        var bundles: [Bundle] = []

        bundles.append(Bundle(for: BundleToken.self))
        bundles.append(Bundle.main)
        bundles.append(contentsOf: Bundle.allBundles)

        #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS)
        bundles.append(contentsOf: Bundle.allFrameworks)
        #endif

        var seen = Set<ObjectIdentifier>()
        var unique: [Bundle] = []
        for bundle in bundles {
            let identifier = ObjectIdentifier(bundle)
            if seen.insert(identifier).inserted {
                unique.append(bundle)
            }
        }

        return unique
    }

    /// URL to the SwiftPM-compiled metallib inside this package's resource bundle.
    static func metallibURLInModuleBundle() -> URL? {
        #if canImport(Metal)
        return Bundle.module.url(forResource: "default", withExtension: "metallib")
        #else
        return nil
        #endif
    }

    #if canImport(Metal)
    private static let expectedFunctionNames: Set<String> = [
        "ripple",
        "rippleCluster",
        "rippleClusterPrismColor",
        "rippleClusterGlowColor"
    ]

    private static var didLogSelection = false

    private static func containsExpectedFunctions(_ library: MTLLibrary) -> Bool {
        !expectedFunctionNames.isDisjoint(with: Set(library.functionNames))
    }

    private static func logSelection(for library: MTLLibrary, origin: String) {
        guard !didLogSelection else { return }
        didLogSelection = true

        print("RippleField: using metallib from \(origin)")
        print("RippleField: functions = \(library.functionNames.sorted())")
    }

    static func makeLibrary(on device: MTLDevice) throws -> MTLLibrary {
        if let moduleLib = try? device.makeDefaultLibrary(bundle: .module),
           containsExpectedFunctions(moduleLib) {
            logSelection(for: moduleLib, origin: Bundle.module.bundleURL.path)
            return moduleLib
        }

        if let moduleURL = metallibURLInModuleBundle(),
           let moduleURLLib = try? device.makeLibrary(URL: moduleURL),
           containsExpectedFunctions(moduleURLLib) {
            logSelection(for: moduleURLLib, origin: moduleURL.path)
            return moduleURLLib
        }

        for bundle in candidateBundles() {
            if let metallibURL = bundle.url(forResource: "default", withExtension: "metallib"),
               let library = try? device.makeLibrary(URL: metallibURL),
               containsExpectedFunctions(library) {
                logSelection(for: library, origin: metallibURL.path)
                return library
            }

            if let library = try? device.makeDefaultLibrary(bundle: bundle),
               containsExpectedFunctions(library) {
                let url = bundle.url(forResource: "default", withExtension: "metallib")
                let path = url?.path ?? bundle.bundleURL.appendingPathComponent("default.metallib").path
                logSelection(for: library, origin: path)
                return library
            }
        }

        if let library = device.makeDefaultLibrary(),
           containsExpectedFunctions(library) {
            logSelection(for: library, origin: "process default library")
            return library
        }

        throw NSError(domain: "RippleField",
                      code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "No metallib with ripple shaders found"])
    }
    #endif

    static func shaderLibraryURL() -> URL? {
        if let url = metallibURLInModuleBundle() {
            return url
        }

        for bundle in candidateBundles() {
            if let url = bundle.url(forResource: "default", withExtension: "metallib") {
                return url
            }
        }
        return nil
    }
}

#if canImport(Metal)
enum RippleShaderProgram {
    case cluster
    case clusterPrismColor
    case clusterGlowColor
}

func makeFunction(for program: RippleShaderProgram,
                  device: MTLDevice) throws -> MTLFunction {
    let lib = try RippleMetal.makeLibrary(on: device)

    let functionName: String = {
        switch program {
        case .cluster:
            return "rippleCluster"
        case .clusterPrismColor:
            return "rippleClusterPrismColor"
        case .clusterGlowColor:
            return "rippleClusterGlowColor"
        }
    }()

    guard let fn = lib.makeFunction(name: functionName) else {
        throw NSError(domain: "RippleField",
                      code: -2,
                      userInfo: [NSLocalizedDescriptionKey:
                        "Missing Metal function \(functionName). Available: \(lib.functionNames.sorted())"])
    }
    return fn
}
#endif
