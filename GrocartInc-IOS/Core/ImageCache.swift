//
//  ImageCache.swift
//  GrocartInc-IOS
//
//  Image loading that actually caches. The backend's S3 product images
//  send no Cache-Control header, so plain AsyncImage re-downloads a
//  multi-MB file every time a product cell appears — which is why product
//  photos look like they never load. This downloads once, keeps the image
//  in memory and on disk, and reuses it. It also trims stray whitespace
//  from the URL string: a few backend image URLs start with a space,
//  which makes URL(string:) return nil and the image never load.
//

import SwiftUI
import CryptoKit

/// Downloads an image once and keeps it in memory (NSCache) and on disk
/// (the caches directory), so a product photo appears instantly after the
/// first load instead of re-downloading every time its cell appears.
actor ImageCache {
    static let shared = ImageCache()

    /// Maximum total size of the on-disk image cache. Product images run
    /// 1–3 MB each across ~1,200 products, so without a cap the disk
    /// cache grows without bound.
    static let maxDiskBytes: Int64 = 200 * 1024 * 1024 // 200 MB

    private let memory = NSCache<NSURL, UIImage>()
    private let fileManager = FileManager.default

    private init() {
        memory.countLimit = 200
        memory.totalCostLimit = 150 * 1024 * 1024 // 150 MB
    }

    private var diskDirectory: URL? {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("product-images", isDirectory: true)
    }

    private func ensureDiskDirectory() {
        guard let dir = diskDirectory else { return }
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    /// A stable filename for a URL (SHA-256, so it is the same on every
    /// launch — Swift's hashValue is randomised per launch and would
    /// never hit the disk cache).
    private func cacheFileName(for url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
        return "\(hex).\(ext)"
    }

    private func cachedImage(for url: URL) -> UIImage? {
        if let image = memory.object(forKey: url as NSURL) { return image }
        guard let dir = diskDirectory else { return nil }
        let file = dir.appendingPathComponent(cacheFileName(for: url))
        guard let data = try? Data(contentsOf: file),
              let image = UIImage(data: data) else { return nil }
        // Touch the file so eviction treats it as recently used.
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: file.path)
        memory.setObject(image, forKey: url as NSURL)
        return image
    }

    private func store(_ image: UIImage, data: Data, for url: URL) {
        memory.setObject(image, forKey: url as NSURL)
        ensureDiskDirectory()
        guard let dir = diskDirectory else { return }
        try? data.write(to: dir.appendingPathComponent(cacheFileName(for: url)), options: .atomic)
        enforceDiskCap()
    }

    /// Evicts least-recently-used disk files when the on-disk cache is
    /// over the cap. Recency is the file's modification date, refreshed
    /// on every disk read, so files the user still sees survive.
    private func enforceDiskCap() {
        guard let dir = diskDirectory,
              let files = try? fileManager.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                options: .skipsHiddenFiles
              ) else { return }
        var entries: [(url: URL, size: Int64, date: Date)] = []
        var total: Int64 = 0
        for file in files {
            guard let values = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
                  let size = values.fileSize,
                  let date = values.contentModificationDate else { continue }
            entries.append((file, Int64(size), date))
            total += Int64(size)
        }
        guard total > Self.maxDiskBytes else { return }
        for entry in entries.sorted(by: { $0.date < $1.date }) {
            try? fileManager.removeItem(at: entry.url)
            total -= entry.size
            if total <= Self.maxDiskBytes { break }
        }
    }

    /// The image for `url`, from memory, disk, or the network (in that
    /// order). Returns nil when the image cannot be loaded.
    func load(url: URL) async -> UIImage? {
        if let cached = cachedImage(for: url) { return cached }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return nil }
            store(image, data: data, for: url)
            return image
        } catch {
            return nil
        }
    }
}

/// A drop-in replacement for AsyncImage that caches (see ImageCache).
/// Same phase-based API, so existing `switch phase` code works unchanged.
/// The URL string is trimmed first, so a leading space in the backend's
/// imageUrl does not break the load.
struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    let content: (AsyncImagePhase) -> Content

    @State private var phase: AsyncImagePhase = .empty

    init(url: URL?, @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url
        self.content = content
    }

    /// Builds the URL from a raw string, trimming stray whitespace first.
    init(urlString: String, @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        self.url = trimmed.isEmpty ? nil : URL(string: trimmed)
        self.content = content
    }

    var body: some View {
        content(phase)
            .task(id: url) {
                guard let url = url else {
                    phase = .failure(URLError(.badURL))
                    return
                }
                if let image = await ImageCache.shared.load(url: url) {
                    phase = .success(Image(uiImage: image))
                } else {
                    phase = .failure(URLError(.cannotLoadFromNetwork))
                }
            }
    }
}
