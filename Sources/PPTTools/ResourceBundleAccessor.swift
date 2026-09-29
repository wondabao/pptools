#if !SWIFT_PACKAGE
import Foundation

private class BundleFinder {}

extension Foundation.Bundle {
    /// Returns the resource bundle associated with the current Swift module.
    static let module: Bundle = {
        let bundleName = "PPTTools_PPTTools"

        let candidates = [
            // Bundle should be present here when running in .app
            Bundle.main.resourceURL,
            // Bundle should be present here when running tests
            Bundle(for: BundleFinder.self).resourceURL,
            // For command-line tools
            Bundle.main.bundleURL,
        ]

        for candidate in candidates {
            let bundlePath = candidate?.appendingPathComponent(bundleName + ".bundle")
            if let bundle = bundlePath.flatMap(Bundle.init(url:)) {
                return bundle
            }
        }
        return Bundle.main
    }()
}
#endif
