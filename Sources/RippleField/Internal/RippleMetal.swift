import Foundation
#if canImport(Metal)
import Metal
#endif

enum RippleMetal {
    private final class BundleToken {}
    private static var hasLoggedBundlePath = false

    private static var candidateBundles: [Bundle] {
        var bundles: [Bundle] = []

        #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS)
        // Primary candidate: the bundle that defines RippleMetal itself (SwiftPM target bundle).
        bundles.append(Bundle(for: BundleToken.self))

        // Additional fallbacks that might host the metallib when linked into an app.
        bundles.append(contentsOf: Bundle.allBundles)
        bundles.append(contentsOf: Bundle.allFrameworks)
        #else
        bundles.append(contentsOf: Bundle.allBundles)
        #endif

        // Ensure the main bundle is considered even if duplicate removal occurs later.
        if !bundles.contains(where: { $0 === Bundle.main }) {
            bundles.append(Bundle.main)
        }

        // Deduplicate while preserving order.
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

    private static func defaultLibraryURL() -> URL? {
        for bundle in candidateBundles {
            if let url = bundle.url(forResource: "default", withExtension: "metallib") {
                #if DEBUG
                if !hasLoggedBundlePath {
                    print("RippleField: loading Metal library from \(bundle.bundleURL.lastPathComponent)")
                    hasLoggedBundlePath = true
                }
                #endif
                return url
            }

            if let resourceURL = bundle.resourceURL {
                let fallback = resourceURL.appendingPathComponent("default.metallib")
                if FileManager.default.fileExists(atPath: fallback.path) {
                    #if DEBUG
                    if !hasLoggedBundlePath {
                        print("RippleField: loading Metal library from \(bundle.bundleURL.lastPathComponent)")
                        hasLoggedBundlePath = true
                    }
                    #endif
                    return fallback
                }
            }
        }

        return nil
    }

    #if canImport(Metal)
    static func makeLibrary(on device: MTLDevice) throws -> MTLLibrary {
        if let url = defaultLibraryURL() {
            if let library = try? device.makeLibrary(URL: url) {
                return library
            }
        }

        if let lib = device.makeDefaultLibrary() {
            return lib
        }

        if let url = defaultLibraryURL() {
            throw NSError(domain: "RippleField",
                          code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "RippleField: Failed to load Metal library at \(url.path)"])
        }

        throw NSError(domain: "RippleField",
                      code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "RippleField: No Metal library found (bundle + default lookup failed)"])
    }
    #endif

    static func shaderLibraryURL() -> URL? {
        return defaultLibraryURL()
    }
}
