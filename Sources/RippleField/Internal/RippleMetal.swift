import Foundation
#if canImport(Metal)
import Metal
#endif

enum RippleMetal {
    private final class BundleToken {}

    private static func candidateBundles() -> [Bundle] {
        var bundles: [Bundle] = []

        #if SWIFT_PACKAGE
        bundles.append(Bundle.module)
        #else
        bundles.append(Bundle(for: BundleToken.self))
        #endif

        bundles.append(Bundle.main)
        bundles.append(contentsOf: Bundle.allBundles)

        #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS)
        bundles.append(contentsOf: Bundle.allFrameworks)
        #endif

        var seen = Set<ObjectIdentifier>()
        var unique: [Bundle] = []
        for bundle in bundles {
            let identifier = ObjectIdentifier(bundle)
            if !seen.contains(identifier) {
                seen.insert(identifier)
                unique.append(bundle)
            }
        }

        return unique
    }

    #if canImport(Metal)
    static func makeLibrary(on device: MTLDevice) throws -> MTLLibrary {
        if let lib = try? device.makeDefaultLibrary(bundle: .module) {
            return lib
        }

        if let lib = device.makeDefaultLibrary() {
            return lib
        }

        throw NSError(domain: "RippleField",
                      code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "RippleField: No Metal library found"])
    }
    #endif

    static func shaderLibraryURL() -> URL? {
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
