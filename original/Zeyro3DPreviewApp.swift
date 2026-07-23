import SwiftUI

@main
struct Zeyro3DPreviewApp: App {
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                NavigationStack {
                    TeamStartView()
                }

                if showSplash {
                    SplashView {
                        withAnimation(.easeOut(duration: 0.4)) {
                            showSplash = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}

// MARK: - 3D Character Viewer

struct CharacterViewerScreen: View {
    @State private var selectedModel = 0

    private let models = [
        ("Player", "marek"),
        ("Coach", "vahag"),
        ("Goalkeeper", "goalkeeper"),
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Text(models[selectedModel].0)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 16)

                GLBSceneView(glbName: models[selectedModel].1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(selectedModel)

                HStack(spacing: 16) {
                    ForEach(0..<models.count, id: \.self) { i in
                        Button {
                            selectedModel = i
                        } label: {
                            Text(models[i].0)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(selectedModel == i ? .black : .white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    selectedModel == i
                                        ? Color.white
                                        : Color.white.opacity(0.15),
                                    in: Capsule()
                                )
                        }
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .navigationBarBackButtonHidden(false)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .animation(.easeOut(duration: 0.3), value: selectedModel)
    }
}
