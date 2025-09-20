import XCTest
import SwiftUI
import UIKit
@testable import Bumpin

final class SocialSnapshotTests: XCTestCase {
    private func renderViewToImage<V: View>(_ view: V, size: CGSize = CGSize(width: 390, height: 844)) -> UIImage {
        let hosting = UIHostingController(rootView: view)
        hosting.view.frame = CGRect(origin: .zero, size: size)
        hosting.view.bounds = hosting.view.frame
        hosting.view.backgroundColor = .systemBackground
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in hosting.view.drawHierarchy(in: hosting.view.bounds, afterScreenUpdates: true) }
    }

    private func perceptualHash(_ image: UIImage) -> String {
        let target = CGSize(width: 16, height: 16)
        UIGraphicsBeginImageContextWithOptions(target, true, 1)
        image.draw(in: CGRect(origin: .zero, size: target))
        let small = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard let cg = small?.cgImage else { return "" }
        var pixels: [UInt8] = Array(repeating: 0, count: Int(target.width * target.height * 4))
        let ctx = CGContext(data: &pixels, width: Int(target.width), height: Int(target.height), bitsPerComponent: 8, bytesPerRow: Int(target.width) * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(cg, in: CGRect(origin: .zero, size: target))
        var gray: [UInt8] = []
        gray.reserveCapacity(Int(target.width * target.height))
        var sum: Int = 0
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let r = Int(pixels[i]); let g = Int(pixels[i+1]); let b = Int(pixels[i+2])
            let v = UInt8((r + g + b) / 3)
            gray.append(v); sum += Int(v)
        }
        let avg = sum / gray.count
        var bits = ""; for v in gray { bits.append(v >= avg ? "1" : "0") }
        return bits
    }

    private func assertSnapshotHashEquals(_ view: some View, expectedHash: String, label: String, file: StaticString = #filePath, line: UInt = #line) {
        let img = renderViewToImage(view)
        let hash = perceptualHash(img)
        if expectedHash.hasPrefix("REPLACE_WITH_BASELINE") {
            print("SNAPSHOT_BASELINE_\(label)=\(hash)")
        } else {
            XCTAssertEqual(hash, expectedHash, "Snapshot hash mismatch for \(label)", file: file, line: line)
        }
    }

    func test_social_all_mock_snapshot() {
        struct Shim: View {
            var body: some View {
                SocialFeedView()
                    .onAppear {
                        UserDefaults.standard.set(true, forKey: "feed.mockData")
                    }
            }
        }
        assertSnapshotHashEquals(Shim(), expectedHash: "REPLACE_WITH_BASELINE_SOCIAL_ALL", label: "social_all_mock")
    }

    func test_followers_mock_snapshot() {
        struct Shim: View { var body: some View { FollowersTabView() } }
        assertSnapshotHashEquals(Shim(), expectedHash: "REPLACE_WITH_BASELINE_FOLLOWERS", label: "followers_mock")
    }

    func test_live_djs_empty_snapshot() {
        struct Shim: View {
            var body: some View {
                LiveDJSessionsListView()
            }
        }
        assertSnapshotHashEquals(Shim(), expectedHash: "REPLACE_WITH_BASELINE_LIVE_DJS_EMPTY", label: "live_djs_empty")
    }
}


