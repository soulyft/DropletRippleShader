import Foundation
#if canImport(Metal)
import Metal
#endif

enum RippleMetal {
    private final class BundleToken {}

    #if canImport(Metal)
    struct SelectedLibrary {
        let library: MTLLibrary
        let url: URL?
        let originDescription: String
    }

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
        print("RippleField: functions = \(library.functionNames.sorted())")
    }

    private static func wrap(_ library: MTLLibrary, url: URL?, origin: String) -> SelectedLibrary {
        logSelection(for: library, origin: origin)
        return SelectedLibrary(library: library, url: url, originDescription: origin)
    }

    static func makeLibrary(on device: MTLDevice) throws -> SelectedLibrary {
        for bundle in orderedCandidateBundles() {
            if let metallibURL = bundle.url(forResource: "default", withExtension: "metallib"),
               let library = try? device.makeLibrary(URL: metallibURL),
               containsExpectedFunctions(library) {
                return wrap(library, url: metallibURL, origin: metallibURL.path)
            }

            if let library = try? device.makeDefaultLibrary(bundle: bundle),
               containsExpectedFunctions(library) {
                let url = bundle.url(forResource: "default", withExtension: "metallib")
                let path = url?.path ?? bundle.bundleURL.appendingPathComponent("default.metallib").path
                return wrap(library, url: url, origin: path)
            }
        }

        if let library = device.makeDefaultLibrary(),
           containsExpectedFunctions(library) {
            return wrap(library, url: nil, origin: "process default library")
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
    let selection = try RippleMetal.makeLibrary(on: device)
    let lib = selection.library

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
