import SwiftUI
import AVFoundation

struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) private var presentationMode
    @Binding var selectedImageData: Data?
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker
        
        init(_ parent: CameraPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                // Resize for memory efficiency
                let resizedImage = resizeImage(image, targetWidth: 1024)
                
                // Compress heavily (quality 0.5)
                parent.selectedImageData = resizedImage.jpegData(compressionQuality: 0.5)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        private func resizeImage(_ image: UIImage, targetWidth: CGFloat) -> UIImage {
            let size = image.size
            let widthRatio  = targetWidth  / size.width
            
            if widthRatio >= 1.0 { return image }
            
            let heightRatio = widthRatio
            let newSize = CGSize(width: size.width * widthRatio, height: size.height * heightRatio)
            
            let rect = CGRect(origin: .zero, size: newSize)
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: rect)
            let newImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return newImage ?? image
        }
    }
}
