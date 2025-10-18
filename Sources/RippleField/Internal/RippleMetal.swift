import Foundation
#if canImport(Metal)
import Metal
#endif

enum RippleMetal {
    private final class BundleToken {}

    #if canImport(Metal)
    private static let expectedFunctionNames: Set<String> = [
        "ripple",
        "rippleCluster",
        "rippleClusterPrismColor",
        "rippleClusterGlowColor"
    ]

    private static var didLogSelection = false
    #endif

    private static func orderedCandidateBundles() -> [Bundle] {
        var bundles: [Bundle] = []

        #if SWIFT_PACKAGE
        bundles.append(Bundle.module)
        #endif

        bundles.append(Bundle(for: BundleToken.self))
        bundles.append(Bundle.main)
        bundles.append(contentsOf: Bundle.allBundles)

        #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS)
        bundles.append(contentsOf: Bundle.allFrameworks)
        #endif

        var seen = Set<URL>()
        var unique: [Bundle] = []
        for bundle in bundles {
            let url = bundle.bundleURL
            if seen.insert(url).inserted {
                unique.append(bundle)
            }
        }

        return unique
    }

    #if canImport(Metal)
    private static func containsExpectedFunctions(_ library: MTLLibrary) -> Bool {
        !expectedFunctionNames.isDisjoint(with: Set(library.functionNames))
    }

    private static func logSelection(for library: MTLLibrary, origin: String) {
        guard !didLogSelection else { return }
        didLogSelection = true

        print("RippleField: using metallib from \(origin)")
        print("RippleField: picked names: \(library.functionNames.sorted())")
    }

    static func makeLibrary(on device: MTLDevice) throws -> MTLLibrary {
        #if SWIFT_PACKAGE
        if let moduleLibrary = try? device.makeDefaultLibrary(bundle: Bundle.module),
           containsExpectedFunctions(moduleLibrary) {
            let path = Bundle.module.url(forResource: "default", withExtension: "metallib")?.path ?? Bundle.module.bundleURL.appendingPathComponent("default.metallib").path
            logSelection(for: moduleLibrary, origin: path)
            return moduleLibrary
        }

        if let moduleURL = Bundle.module.url(forResource: "default", withExtension: "metallib"),
           let moduleLibrary = try? device.makeLibrary(URL: moduleURL),
           containsExpectedFunctions(moduleLibrary) {
            logSelection(for: moduleLibrary, origin: moduleURL.path)
            return moduleLibrary
        }
        #endif

        for bundle in orderedCandidateBundles() {
            if let metallibURL = bundle.url(forResource: "default", withExtension: "metallib"),
               let library = try? device.makeLibrary(URL: metallibURL),
               containsExpectedFunctions(library) {
                logSelection(for: library, origin: metallibURL.path)
                return library
            }

            if let library = try? device.makeDefaultLibrary(bundle: bundle),
               containsExpectedFunctions(library) {
                let path = bundle.bundleURL.appendingPathComponent("default.metallib").path
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

    #if DEBUG
    print("RippleField Metal functions:", lib.functionNames.sorted())
    #endif

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
