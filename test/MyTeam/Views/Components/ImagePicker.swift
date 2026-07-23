import SwiftUI
import PhotosUI

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { image, _ in
                DispatchQueue.main.async { self.parent.image = image as? UIImage }
            }
        }
    }
}

/// Reusable avatar/photo view with optional edit button.
struct PlayerAvatarView: View {
    let image: UIImage?
    let name: String
    let role: PlayerRole
    var size: CGFloat = 44

    var body: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            ZStack {
                Circle()
                    .fill(roleTint.opacity(0.15))
                    .frame(width: size, height: size)
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                    .foregroundStyle(roleTint)
            }
        }
    }

    private var roleTint: Color {
        switch role {
        case .player:     return TeamTheme.blue
        case .goalkeeper: return TeamTheme.orange
        case .coach:      return TeamTheme.purple
        }
    }
}
