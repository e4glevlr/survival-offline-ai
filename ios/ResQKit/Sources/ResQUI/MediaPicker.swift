import SwiftUI
#if canImport(UIKit)
import UIKit

/// System camera. Returns a downscaled JPEG, or nil on cancel.
struct CameraPicker: UIViewControllerRepresentable {
    let onDone: (Data?) -> Void

    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let c = UIImagePickerController()
        c.sourceType = .camera
        c.delegate = context.coordinator
        return c
    }

    func updateUIViewController(_ c: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onDone: (Data?) -> Void
        init(onDone: @escaping (Data?) -> Void) { self.onDone = onDone }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onDone((info[.originalImage] as? UIImage).flatMap(ImageData.jpeg))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onDone(nil) }
    }
}
#endif

enum ImageData {
    /// Longest side 1280 px, JPEG 0.8: enough for a vision model, small enough to keep in history.
    #if canImport(UIKit)
    static func jpeg(_ image: UIImage) -> Data? {
        let maxSide: CGFloat = 1280
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return resized.jpegData(compressionQuality: 0.8)
    }

    static func jpeg(_ data: Data) -> Data? { UIImage(data: data).flatMap(jpeg) }
    #else
    static func jpeg(_ data: Data) -> Data? { data }
    #endif
}

/// Renders stored image data.
struct PhotoView: View {
    let data: Data

    var body: some View {
        #if canImport(UIKit)
        if let img = UIImage(data: data) {
            Image(uiImage: img).resizable().scaledToFill()
        }
        #else
        if let img = NSImage(data: data) {
            Image(nsImage: img).resizable().scaledToFill()
        }
        #endif
    }
}
