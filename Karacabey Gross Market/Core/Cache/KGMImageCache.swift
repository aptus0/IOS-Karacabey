import SwiftUI
import Combine
import Foundation

actor ImageCache {
    static let shared = ImageCache()
    private var memoryCache = NSCache<NSString, UIImage>()

    private init() {
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 1024 * 1024 * 100 // 100 MB
    }

    func image(for url: URL) -> UIImage? {
        if let img = memoryCache.object(forKey: url.absoluteString as NSString) {
            return img
        }
        return nil
    }

    func insertImage(_ image: UIImage?, for url: URL) {
        guard let image = image else { return }
        memoryCache.setObject(image, forKey: url.absoluteString as NSString)
    }
}

class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    private var url: URL?
    private var cancellable: AnyCancellable?

    func load(url: URL?) {
        guard let url = url else {
            cancellable?.cancel()
            self.url = nil
            image = nil
            return
        }

        if self.url == url, image != nil { return }

        cancellable?.cancel()
        self.url = url
        image = nil

        Task {
            if let cached = await ImageCache.shared.image(for: url) {
                await MainActor.run { self.image = cached }
                return
            }

            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
            cancellable = URLSession.shared.dataTaskPublisher(for: request)
                .map { UIImage(data: $0.data) }
                .replaceError(with: nil)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] downloadedImage in
                    guard self?.url == url else { return }
                    self?.image = downloadedImage
                    if let downloadedImage = downloadedImage {
                        Task { await ImageCache.shared.insertImage(downloadedImage, for: url) }
                    }
                }
        }
    }
    
    func cancel() {
        cancellable?.cancel()
    }
}

struct KGMCachedImage<Placeholder: View>: View {
    @StateObject private var loader = ImageLoader()
    let url: URL?
    let placeholder: Placeholder
    
    init(url: URL?, @ViewBuilder placeholder: () -> Placeholder) {
        self.url = url
        self.placeholder = placeholder()
    }
    
    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
            } else {
                placeholder
            }
        }
        .onAppear { loader.load(url: url) }
        .onChange(of: url) { _, newUrl in loader.load(url: newUrl) }
    }
}
