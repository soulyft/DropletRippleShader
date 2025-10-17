import Metal
import Foundation

enum RippleMetal {
    private static var hasLoggedBundlePath = false

    static func makeLibrary(on device: MTLDevice) throws -> MTLLibrary {
        #if DEBUG
        if !hasLoggedBundlePath {
            let bundleURL = Bundle.module.bundleURL
            hasLoggedBundlePath = true
            print("RippleField: loading Metal library from \(bundleURL.lastPathComponent)")
        }
        #endif

        if let lib = try? device.makeDefaultLibrary(bundle: .module) {
            return lib
        }
        if let lib = device.makeDefaultLibrary() {
            return lib
        }
        throw NSError(domain: "RippleField",
                      code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "RippleField: No Metal library found (Bundle.module + default lookup failed)"])
    }
}
