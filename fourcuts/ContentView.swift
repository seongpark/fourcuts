import SwiftUI
import PhotosUI
import UIKit

struct ContentView: View {
    @State private var images: [UIImage] = []
    @State private var isImagePickerPresented = false
    @State private var overlayImages: [UIImage?] = Array(repeating: nil, count: 4) // 각 컷에 대한 오버레이 이미지 배열
    @State private var showSaveAlert = false
    @State private var isOverlayPickerPresented = false // 오버레이 이미지 선택을 위한 상태 변수
    @State private var selectedOverlayIndex: Int? // 선택된 오버레이 이미지의 인덱스

    var body: some View {
        GeometryReader { geometry in
            VStack {
                if images.isEmpty {
                    Text("Tap to take 4 photos")
                        .padding()
                }
                
                // 네컷 사진을 위한 그리드 레이아웃
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(0..<4, id: \.self) { index in
                        if index < images.count {
                            ZStack {
                                Image(uiImage: images[index])
                                    .resizable()
                                    .scaledToFill() // 원본 비율 유지
                                    .frame(width: (geometry.size.width / 2) - 15, height: (geometry.size.width / 2) - 15)
                                    .clipped()

                                // 각각의 오버레이 이미지 적용
                                if let overlayImage = overlayImages[index] {
                                    Image(uiImage: overlayImage)
                                        .resizable()
                                        .scaledToFill() // 비율을 유지하며 꽉 차게 조정
                                        .frame(width: (geometry.size.width / 2) - 15, height: (geometry.size.width / 2) - 15)
                                        .clipped()
                                }
                            }
                            .onTapGesture {
                                selectedOverlayIndex = index // 현재 인덱스를 저장
                                isOverlayPickerPresented = true // 오버레이 이미지 선택 UI 표시
                            }
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.5))
                                .frame(width: (geometry.size.width / 2) - 15, height: (geometry.size.width / 2) - 15)
                        }
                    }
                }
                .padding()
                
                Spacer()
                
                // 카메라 버튼
                Button(action: {
                    isImagePickerPresented = true
                }) {
                    Text("Take Photo")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .sheet(isPresented: $isImagePickerPresented) {
                    PhotoPicker(images: $images, showSaveAlert: $showSaveAlert, overlayImages: $overlayImages) // overlayImages 추가
                }
                .padding()
                
                // 오버레이 이미지 선택 버튼 추가
                Button(action: {
                    isOverlayPickerPresented = true // 오버레이 이미지 선택 UI 표시
                }) {
                    Text("Select Overlay Image")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(10)
                }
                .sheet(isPresented: $isOverlayPickerPresented) {
                    if let selectedIndex = selectedOverlayIndex {
                        OverlayPicker(overlayImage: $overlayImages[selectedIndex])
                    }
                }
            }
            .alert(isPresented: $showSaveAlert) {
                Alert(title: Text("Photo Saved"), message: Text("Your photo has been saved to the photo library."), dismissButton: .default(Text("OK")))
            }
        }
    }
}

// 오버레이 이미지를 선택하는 뷰
struct OverlayPicker: UIViewControllerRepresentable {
    @Binding var overlayImage: UIImage?

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images // 이미지 필터 설정
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: OverlayPicker
        
        init(_ parent: OverlayPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            if let result = results.first {
                if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    result.itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                        if let image = object as? UIImage {
                            DispatchQueue.main.async {
                                self.parent.overlayImage = image // 선택한 이미지를 overlayImage에 저장
                            }
                        }
                    }
                }
            }
            picker.dismiss(animated: true)
        }
    }
}

struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var images: [UIImage]
    @Binding var showSaveAlert: Bool
    @Binding var overlayImages: [UIImage?] // 각 컷에 대한 오버레이 이미지 배열
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraDevice = .front
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: PhotoPicker
        
        init(_ parent: PhotoPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                if parent.images.count < 4 {
                    parent.images.append(image)
                }
            }
            picker.dismiss(animated: true)
            if parent.images.count == 4 {
                createAndSaveCollage() // 모든 사진을 찍으면 콜라주 생성
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
        
        // 네컷 사진을 2x2로 합쳐서 사진첩에 저장하는 함수
        func createAndSaveCollage() {
            guard parent.images.count == 4 else { return }
            let collageSize = CGSize(width: 600, height: 700)
            UIGraphicsBeginImageContextWithOptions(collageSize, false, 0.0)
            
            let frameWidth: CGFloat = 10
            
            // 각각의 이미지를 2x2로 배치
            for i in 0..<4 {
                let row = i / 2
                let col = i % 2
                let x = CGFloat(col) * (collageSize.width / 2) + frameWidth / 2
                let y = CGFloat(row) * (collageSize.height / 2) + frameWidth / 2
                let imageRect = CGRect(x: x, y: y, width: (collageSize.width / 2) - frameWidth, height: (collageSize.height / 2) - frameWidth)
                parent.images[i].draw(in: imageRect)
                
                // 오버레이 이미지가 있을 경우
                if let overlayImage = parent.overlayImages[i] {
                    overlayImage.draw(in: imageRect) // 오버레이 이미지를 네컷 이미지에 그리기
                }
            }
            
            // 문구 추가
            let text = "Graceful Memories"
            let textFont = UIFont.systemFont(ofSize: 24, weight: .bold)
            let textStyle = NSMutableParagraphStyle()
            textStyle.alignment = .center
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: textFont,
                .paragraphStyle: textStyle,
                .foregroundColor: UIColor.black
            ]
            let textRect = CGRect(x: 0, y: 650, width: collageSize.width, height: 50)
            text.draw(in: textRect, withAttributes: textAttributes)
            
            // 최종 이미지를 가져오기
            let collageImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            // 최종 이미지를 사진첩에 저장
            if let finalImage = collageImage {
                UIImageWriteToSavedPhotosAlbum(finalImage, nil, nil, nil)
                parent.showSaveAlert = true
            }
        }
    }
}
