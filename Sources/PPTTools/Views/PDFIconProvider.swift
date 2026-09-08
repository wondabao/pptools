import SwiftUI
import AppKit

enum PDFIconProvider {
    static let rawSVG = """
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<g clip-path="url(#clip0_837_1004)">
<path d="M2.19434 5.49109C2.19434 3.56903 2.19434 2.608 2.56839 1.87387C2.89742 1.22811 3.42244 0.703089 4.0682 0.374058C4.80233 0 5.76336 0 7.68545 0H13.4025C14.2419 0 14.6616 0 15.0565 0.0948247C15.4067 0.178896 15.7415 0.317561 16.0485 0.505729C16.3949 0.717966 16.6917 1.01474 17.2852 1.6083L20.1971 4.52015C20.7906 5.1137 21.0874 5.41048 21.2997 5.75683C21.4878 6.06388 21.6264 6.39866 21.7105 6.74884C21.8054 7.14381 21.8054 7.56353 21.8054 8.40293V18.5089C21.8054 20.431 21.8054 21.392 21.4313 22.1261C21.1023 22.7719 20.5773 23.2969 19.9315 23.626C19.1973 24 18.2364 24 16.3143 24H7.68545C5.76336 24 4.80233 24 4.0682 23.626C3.42244 23.2969 2.89742 22.7719 2.56839 22.1261C2.19434 21.392 2.19434 20.431 2.19434 18.5089V5.49109Z" fill="#E31B54"/>
<mask id="mask0_837_1004" style="mask-type:alpha" maskUnits="userSpaceOnUse" x="2" y="-1" width="20" height="24">
<path d="M5.6272 0.204346H14.2559C15.1119 0.204346 15.9328 0.544617 16.5381 1.1499L20.6565 5.26758C21.2618 5.87283 21.602 6.69385 21.6021 7.5498V19.4473C21.6021 21.2298 20.1568 22.675 18.3743 22.6751H5.6272C3.84461 22.6751 2.39941 21.2299 2.39941 19.4473V3.43213C2.39941 1.64954 3.84461 0.204346 5.6272 0.204346Z" fill="#F2F4F7" stroke="#E4E4E4" stroke-width="0.544751"/>
</mask>
<g mask="url(#mask0_837_1004)">
<path d="M15.6777 -0.817139L22.6233 6.12844H17.9657C16.7021 6.12844 15.6777 5.10409 15.6777 3.84049V-0.817139Z" fill="#FEA3B4"/>
<path d="M15.124 19.9439V13H18.0888V13.9363H16.1188V16.0428H17.8353V16.9791H16.1188V19.9439H15.124Z" fill="white"/>
<path d="M10.9717 19.9439V13H12.4443C13.0165 13 13.4489 13.156 13.7414 13.4681C14.0405 13.7802 14.1901 14.2223 14.1901 14.7945V18.0421C14.1901 18.6923 14.0308 19.1734 13.7122 19.4855C13.4001 19.7911 12.9482 19.9439 12.3566 19.9439H10.9717ZM11.9665 13.9363V19.0076H12.4248C12.7044 19.0076 12.9027 18.9394 13.0197 18.8028C13.1368 18.6598 13.1953 18.4387 13.1953 18.1397V14.7945C13.1953 14.5214 13.14 14.3101 13.0295 14.1606C12.919 14.011 12.7174 13.9363 12.4248 13.9363H11.9665Z" fill="white"/>
<path d="M7 19.9439V13H8.49216C8.76523 13 9.0058 13.0358 9.21386 13.1073C9.42191 13.1788 9.61047 13.3056 9.77951 13.4876C9.94856 13.6697 10.0656 13.8842 10.1306 14.1313C10.1956 14.3719 10.2281 14.7002 10.2281 15.1163C10.2281 15.4284 10.2086 15.6917 10.1696 15.9063C10.1371 16.1209 10.0623 16.3224 9.94531 16.511C9.80877 16.7385 9.62672 16.9173 9.39916 17.0474C9.1716 17.1709 8.87251 17.2327 8.50191 17.2327H7.99477V19.9439H7ZM7.99477 13.9363V16.2964H8.47265C8.67421 16.2964 8.83025 16.2671 8.94078 16.2086C9.05131 16.1501 9.13258 16.0688 9.1846 15.9648C9.23661 15.8673 9.26587 15.747 9.27237 15.604C9.28538 15.4609 9.29188 15.3016 9.29188 15.1261C9.29188 14.9635 9.28863 14.8107 9.28213 14.6677C9.27562 14.5182 9.24637 14.3881 9.19435 14.2776C9.14234 14.1671 9.06432 14.0825 8.96029 14.024C8.85626 13.9655 8.70672 13.9363 8.51166 13.9363H7.99477Z" fill="white"/>
</g>
</g>
<defs>
<clipPath id="clip0_837_1004">
<rect width="24" height="24" fill="white"/>
</clipPath>
</defs>
</svg>
"""

    private static var cachedImages: [CGFloat: NSImage] = [:]

    static func image(size: CGFloat = 24) -> NSImage? {
        if let cached = cachedImages[size] {
            return cached
        }

        // Try high-resolution PNG resource first
        if let url = Bundle.main.url(forResource: "pdf_icon", withExtension: "png") ?? Bundle.module.url(forResource: "pdf_icon", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            let scaled = img.copy() as! NSImage
            scaled.size = NSSize(width: size, height: size)
            cachedImages[size] = scaled
            return scaled
        }

        // Fallback to SVG rendering directly from AppKit
        if let data = rawSVG.data(using: .utf8), let img = NSImage(data: data) {
            img.size = NSSize(width: size, height: size)
            cachedImages[size] = img
            return img
        }

        return nil
    }
}

struct PDFIconView: View {
    var size: CGFloat = 24

    var body: some View {
        if let nsImage = PDFIconProvider.image(size: size) {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "doc.richtext")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        }
    }
}
