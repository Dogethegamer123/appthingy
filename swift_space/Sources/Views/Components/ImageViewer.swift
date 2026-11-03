import SwiftUI

struct ImageViewer: View {
    let url: URL?
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                MagnifyGesture()
                                    .onChanged { val in
                                        scale = min(max(val.magnification, 1), 4)
                                    }
                                    .onEnded { _ in
                                        withAnimation { scale = max(scale, 1) }
                                    }
                            )
                            .gesture(
                                DragGesture()
                                    .onChanged { val in
                                        offset = val.translation
                                    }
                                    .onEnded { val in
                                        if val.translation.height > 100 {
                                            dismiss()
                                        } else {
                                            withAnimation { offset = .zero }
                                        }
                                    }
                            )
                            .onTapGesture(count: 2) {
                                withAnimation {
                                    scale = scale > 1 ? 1 : 2
                                }
                            }
                    case .failure:
                        VStack {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                            Text("Couldn't load image")
                        }
                        .foregroundStyle(Theme.secondaryText)
                    default:
                        ProgressView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding()
        }
    }
}
