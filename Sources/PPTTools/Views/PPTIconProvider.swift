import SwiftUI
import AppKit

enum PPTIconProvider {
    static let rawSVG = """
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
    <g clip-path="url(#clip0_837_979)">
    <mask id="mask0_837_979" style="mask-type:luminance" maskUnits="userSpaceOnUse" x="0" y="0" width="24" height="24">
    <path d="M24 0H0V24H24V0Z" fill="white"/>
    </mask>
    <g mask="url(#mask0_837_979)">
    <mask id="mask1_837_979" style="mask-type:luminance" maskUnits="userSpaceOnUse" x="0" y="0" width="24" height="24">
    <path d="M24 0H0V24H24V0Z" fill="white"/>
    </mask>
    <g mask="url(#mask1_837_979)">
    <mask id="mask2_837_979" style="mask-type:luminance" maskUnits="userSpaceOnUse" x="0" y="0" width="24" height="24">
    <path d="M24 0H0V24H24V0Z" fill="white"/>
    </mask>
    <g mask="url(#mask2_837_979)">
    <path d="M12 23.625C18.4197 23.625 23.6238 18.4203 23.6238 12C23.6238 5.57968 18.4197 0.375 12 0.375C5.5802 0.375 0.375977 5.57968 0.375977 12C0.375977 18.4203 5.5802 23.625 12 23.625Z" fill="url(#paint0_linear_837_979)"/>
    <path d="M12 23.625C18.4197 23.625 23.6238 18.4203 23.6238 12C23.6238 5.57968 18.4197 0.375 12 0.375C5.5802 0.375 0.375977 5.57968 0.375977 12C0.375977 18.4203 5.5802 23.625 12 23.625Z" fill="url(#paint1_radial_837_979)"/>
    <path d="M12 23.625C18.4197 23.625 23.6238 18.4203 23.6238 12C23.6238 5.57968 18.4197 0.375 12 0.375C5.5802 0.375 0.375977 5.57968 0.375977 12C0.375977 18.4203 5.5802 23.625 12 23.625Z" fill="url(#paint2_radial_837_979)" fill-opacity="0.5"/>
    <path d="M10.5 7.5H3C1.34314 7.5 0 8.84314 0 10.5V18C0 19.6569 1.34314 21 3 21H10.5C12.1569 21 13.5 19.6569 13.5 18V10.5C13.5 8.84314 12.1569 7.5 10.5 7.5Z" fill="url(#paint3_radial_837_979)"/>
    <path d="M10.5 7.5H3C1.34314 7.5 0 8.84314 0 10.5V18C0 19.6569 1.34314 21 3 21H10.5C12.1569 21 13.5 19.6569 13.5 18V10.5C13.5 8.84314 12.1569 7.5 10.5 7.5Z" fill="url(#paint4_radial_837_979)" fill-opacity="0.3"/>
    <path d="M5.69737 15.5576V18H4.00586V10.5H6.61904C7.55468 10.5 8.26688 10.704 8.75566 11.1119C9.24791 11.5199 9.49405 12.1248 9.49405 12.9268C9.49405 13.7531 9.21824 14.3982 8.66663 14.8619C8.11852 15.3257 7.38187 15.5576 6.4567 15.5576H5.69737ZM5.69737 11.7971V14.2605H6.40433C6.82328 14.2605 7.14622 14.1506 7.37314 13.931C7.60007 13.7113 7.71353 13.3957 7.71353 12.9843C7.71353 12.6043 7.60181 12.3114 7.37837 12.1056C7.15843 11.8999 6.84248 11.7971 6.43051 11.7971H5.69737Z" fill="white"/>
    <path d="M11.9985 0.375C18.4182 0.375 23.6235 5.57968 23.6235 12C23.6235 14.1285 23.0475 16.1214 22.0488 17.8374L22.232 17.4331C23.3819 14.88 21.5136 11.9912 18.7134 11.9912H14.0713C12.9212 11.9909 11.9888 11.0569 11.9897 9.90673L11.9941 5.28808C11.9966 2.48409 9.10142 0.612966 6.54639 1.76806L6.20801 1.92188C7.91324 0.939743 9.88947 0.375087 11.9985 0.375Z" fill="url(#paint5_linear_837_979)"/>
    <path d="M11.9985 0.375C18.4182 0.375 23.6235 5.57968 23.6235 12C23.6235 14.1285 23.0475 16.1214 22.0488 17.8374L22.232 17.4331C23.3819 14.88 21.5136 11.9912 18.7134 11.9912H14.0713C12.9212 11.9909 11.9888 11.0569 11.9897 9.90673L11.9941 5.28808C11.9966 2.48409 9.10142 0.612966 6.54639 1.76806L6.20801 1.92188C7.91324 0.939743 9.88947 0.375087 11.9985 0.375Z" fill="url(#paint6_radial_837_979)"/>
    <path d="M11.9985 0.375C18.4182 0.375 23.6235 5.57968 23.6235 12C23.6235 14.1285 23.0475 16.1214 22.0488 17.8374L22.232 17.4331C23.3819 14.88 21.5136 11.9912 18.7134 11.9912H14.0713C12.9212 11.9909 11.9888 11.0569 11.9897 9.90673L11.9941 5.28808C11.9966 2.48409 9.10142 0.612966 6.54639 1.76806L6.20801 1.92188C7.91324 0.939743 9.88947 0.375087 11.9985 0.375Z" fill="url(#paint7_radial_837_979)" fill-opacity="0.8"/>
    <path d="M11.9985 0.375C18.4182 0.375 23.6235 5.57968 23.6235 12C23.6235 14.1285 23.0475 16.1214 22.0488 17.8374L22.232 17.4331C23.3819 14.88 21.5136 11.9912 18.7134 11.9912H14.0713C12.9212 11.9909 11.9888 11.0569 11.9897 9.90673L11.9941 5.28808C11.9966 2.48409 9.10142 0.612966 6.54639 1.76806L6.20801 1.92188C7.91324 0.939743 9.88947 0.375087 11.9985 0.375Z" fill="url(#paint8_radial_837_979)"/>
    <path d="M11.9985 0.375C18.4182 0.375 23.6235 5.57968 23.6235 12C23.6235 14.1285 23.0475 16.1214 22.0488 17.8374L22.232 17.4331C23.3819 14.88 21.5136 11.9912 18.7134 11.9912H14.0713C12.9212 11.9909 11.9888 11.0569 11.9897 9.90673L11.9941 5.28808C11.9966 2.48409 9.10142 0.612966 6.54639 1.76806L6.20801 1.92188C7.91324 0.939743 9.88947 0.375087 11.9985 0.375Z" fill="url(#paint9_radial_837_979)"/>
    </g>
    </g>
    </g>
    </g>
    <defs>
    <linearGradient id="paint0_linear_837_979" x1="10.8205" y1="-0.365117" x2="-3.42241" y2="13.2604" gradientUnits="userSpaceOnUse">
    <stop offset="0.0582736" stop-color="#FF7F48"/>
    <stop offset="1" stop-color="#E5495B"/>
    </linearGradient>
    <radialGradient id="paint1_radial_837_979" cx="0" cy="0" r="1" gradientUnits="userSpaceOnUse" gradientTransform="translate(16.5948 7.12104) rotate(135) scale(23.3401 39.2845)">
    <stop offset="0.151523" stop-color="#AA1D2D"/>
    <stop offset="0.380855" stop-color="#D12B18" stop-opacity="0.44"/>
    <stop offset="0.601996" stop-color="#FF3C00" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="paint2_radial_837_979" cx="0" cy="0" r="1" gradientUnits="userSpaceOnUse" gradientTransform="translate(-3.68136 21.4495) rotate(-25.2832) scale(22.1253 40.0832)">
    <stop offset="0.4067" stop-color="#FF66FB"/>
    <stop offset="1" stop-color="#EA3D01" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="paint3_radial_837_979" cx="0" cy="0" r="1" gradientUnits="userSpaceOnUse" gradientTransform="translate(-0.00164794 7.5) rotate(45) scale(19.0918)">
    <stop stop-color="#F8193E"/>
    <stop offset="0.939062" stop-color="#920616"/>
    </radialGradient>
    <radialGradient id="paint4_radial_837_979" cx="0" cy="0" r="1" gradientUnits="userSpaceOnUse" gradientTransform="translate(6.74835 15.6) rotate(90) scale(9.45 10.7578)">
    <stop offset="0.575893" stop-color="#FFB055" stop-opacity="0"/>
    <stop offset="0.973806" stop-color="#FFF2BE"/>
    </radialGradient>
    <linearGradient id="paint5_linear_837_979" x1="14.2145" y1="14.5716" x2="26.7108" y2="5.31449" gradientUnits="userSpaceOnUse">
    <stop offset="0.310768" stop-color="#FF6E30"/>
    <stop offset="0.634576" stop-color="#FFA05C"/>
    </linearGradient>
    <radialGradient id="paint6_radial_837_979" cx="0" cy="0" r="1" gradientTransform="matrix(14.6856 3.07888 -3.95997 13.7924 10.0677 13.3762)" gradientUnits="userSpaceOnUse">
    <stop offset="0.78593" stop-color="#FFA05C" stop-opacity="0"/>
    <stop offset="0.904889" stop-color="#FFCE84"/>
    </radialGradient>
    <radialGradient id="paint7_radial_837_979" cx="0" cy="0" r="1" gradientUnits="userSpaceOnUse" gradientTransform="translate(12.4216 11.8133) rotate(-33.2109) scale(15.1533 14.4941)">
    <stop offset="0.295239" stop-color="#FF99E9"/>
    <stop offset="0.727968" stop-color="#FF99E9" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="paint8_radial_837_979" cx="0" cy="0" r="1" gradientTransform="matrix(10.6119 -12.1553 11.3259 9.43263 10.7203 13.5862)" gradientUnits="userSpaceOnUse">
    <stop stop-color="#FD6EF9"/>
    <stop offset="0.637205" stop-color="#FF9944"/>
    <stop offset="0.85186" stop-color="#FCC479"/>
    </radialGradient>
    <radialGradient id="paint9_radial_837_979" cx="0" cy="0" r="1" gradientTransform="matrix(-1.19868 8.12649 -18.3751 -2.58561 9.66452 1.90971)" gradientUnits="userSpaceOnUse">
    <stop offset="0.144283" stop-color="#FF8D13"/>
    <stop offset="0.537266" stop-color="#FF7F29" stop-opacity="0"/>
    </radialGradient>
    <clipPath id="clip0_837_979">
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
        if let url = Bundle.main.url(forResource: "ppt_icon", withExtension: "png") ?? Bundle.module.url(forResource: "ppt_icon", withExtension: "png"),
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

struct PPTIconView: View {
    var size: CGFloat = 24

    var body: some View {
        if let nsImage = PPTIconProvider.image(size: size) {
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
