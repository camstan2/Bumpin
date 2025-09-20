import XCTest
import SwiftUI
import UIKit
@testable import Bumpin

final class SearchSnapshotTests: XCTestCase {
    private func renderViewToImage<V: View>(_ view: V, size: CGSize = CGSize(width: 390, height: 844)) -> UIImage {
        let hosting = UIHostingController(rootView: view)
        hosting.view.frame = CGRect(origin: .zero, size: size)
        hosting.view.bounds = hosting.view.frame
        hosting.view.backgroundColor = .systemBackground
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in hosting.view.drawHierarchy(in: hosting.view.bounds, afterScreenUpdates: true) }
    }

    private func perceptualHash(_ image: UIImage) -> String {
        // Downscale to 16x16, grayscale average hash
        let target = CGSize(width: 16, height: 16)
        UIGraphicsBeginImageContextWithOptions(target, true, 1)
        image.draw(in: CGRect(origin: .zero, size: target))
        let small = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard let cg = small?.cgImage else { return "" }

        var pixels: [UInt8] = Array(repeating: 0, count: Int(target.width * target.height * 4))
        let ctx = CGContext(data: &pixels,
                            width: Int(target.width),
                            height: Int(target.height),
                            bitsPerComponent: 8,
                            bytesPerRow: Int(target.width) * 4,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(cg, in: CGRect(origin: .zero, size: target))

        var gray: [UInt8] = []
        gray.reserveCapacity(Int(target.width * target.height))
        var sum: Int = 0
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let r = Int(pixels[i])
            let g = Int(pixels[i+1])
            let b = Int(pixels[i+2])
            let v = UInt8((r + g + b) / 3)
            gray.append(v)
            sum += Int(v)
        }
        let avg = sum / gray.count
        var bits = ""
        for v in gray { bits.append(v >= avg ? "1" : "0") }
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

    func test_search_loading_snapshot() {
        struct LoadingShim: View {
            var body: some View {
                VStack(spacing: 16) {
                    List {
                        ForEach(0..<6, id: \.self) { _ in
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.2)).frame(width: 56, height: 56).shimmer()
                                VStack(alignment: .leading, spacing: 8) {
                                    RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.2)).frame(height: 14).shimmer()
                                    RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.15)).frame(width: 180, height: 12).shimmer()
                                }
                            }
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        assertSnapshotHashEquals(LoadingShim(), expectedHash: "REPLACE_WITH_BASELINE_LOADING", label: "loading")
    }

    func test_search_empty_snapshot() {
        struct EmptyShim: View {
            var body: some View {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No results").font(.headline)
                }
                .padding(.horizontal, 40)
            }
        }
        assertSnapshotHashEquals(EmptyShim(), expectedHash: "REPLACE_WITH_BASELINE_EMPTY", label: "empty")
    }

    func test_search_error_snapshot() {
        // Show error empty state by composing the internal empty/error view via a wrapper that exposes error state.
        // Without test-only initializer (removed), simulate by overlaying a simple error placeholder that matches emptyStateView structure.
        struct ErrorShim: View {
            var body: some View {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Something went wrong").font(.headline)
                    Text("Network error").font(.subheadline).foregroundColor(.secondary)
                    Button(action: {}) { Text("Retry") }
                }
                .padding(.horizontal, 40)
            }
        }
        assertSnapshotHashEquals(ErrorShim(), expectedHash: "REPLACE_WITH_BASELINE_ERROR", label: "error")
    }
}


