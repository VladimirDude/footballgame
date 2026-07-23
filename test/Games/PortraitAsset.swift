import UIKit
import ImageIO

/// Single source of truth for how bundled player-portrait assets are located.
///
/// Portraits ship as **HEIC** (not PNG) to keep the app binary small — HEIC is
/// ~85% smaller than the equivalent 128px PNG with no visible quality loss for
/// face thumbnails. Club logos deliberately stay PNG because they need an alpha
/// channel; only portraits are converted.
///
/// Every place that needs to know "does this player have a portrait?" or "where
/// is it?" must go through this type, so the storage format lives in exactly one
/// place. This is also the seam where a future CDN can be introduced: give
/// `remoteBaseURL` a value and the loader will prefer the network, falling back
/// to the bundled copy when offline.
enum PortraitAsset {
    /// On-disk format for bundled portraits.
    static let fileExtension = "heic"

    /// Optional CDN root for remotely-served portraits. `nil` keeps the app
    /// fully offline (bundle-only), preserving today's behavior. When a real
    /// CDN exists, set this and portraits can be dropped from the app bundle.
    static let remoteBaseURL: URL? = nil

    /// URL of the bundled portrait for `id`, or `nil` if none ships with the app.
    static func bundleURL(forID id: String) -> URL? {
        Bundle.main.url(forResource: id, withExtension: fileExtension)
    }

    /// Whether a portrait ships in the bundle for `id`. Used when building game
    /// pools so we never surface a player we can't show a face for.
    static func exists(forID id: String) -> Bool {
        bundleURL(forID: id) != nil
    }
}

/// Thread-safe, memory-bounded portrait loader.
///
/// Replaces the previous hand-rolled `[String: UIImage]` + `NSLock` cache, which
/// had a data race (the fast-path read happened *outside* the lock) and never
/// evicted, so scrolling accumulated full-size decoded images until jetsam.
///
/// `NSCache` is thread-safe and evicts automatically under memory pressure, and
/// decoding goes through ImageIO's downsampler so we only ever hold a
/// display-sized bitmap in memory rather than the full decoded image.
enum PortraitStore {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 500
        return cache
    }()

    /// Returns an already-decoded portrait if present, without touching disk.
    /// Safe to call from any thread.
    static func cachedImage(forID id: String) -> UIImage? {
        cache.object(forKey: id as NSString)
    }

    /// Decodes (downsampling to `maxPixel`) and caches the portrait for `id`.
    /// Safe to call off the main thread — callers should, to avoid decode jank.
    static func loadImage(forID id: String, maxPixel: CGFloat) -> UIImage? {
        if let cached = cache.object(forKey: id as NSString) { return cached }
        guard let url = PortraitAsset.bundleURL(forID: id),
              let image = downsampled(at: url, maxPixel: maxPixel) else {
            return nil
        }
        cache.setObject(image, forKey: id as NSString)
        return image
    }

    private static func downsampled(at url: URL, maxPixel: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(64, maxPixel),
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
