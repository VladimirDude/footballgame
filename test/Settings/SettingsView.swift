import SwiftUI

struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some View {
        // Use a ZStack with no hardcoded green background
        ZStack {
            // This pulls the system background color automatically
            Color(UIColor.systemBackground).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .font(.largeTitle.bold())
                    .padding(.top, 40)
                    .padding(.horizontal)
                
                // Liquid Glass Card
                List {
                    Section {
                        HStack {
                            Text("Dark Mode")
                                .font(.headline)
                            Spacer()
                            Toggle("", isOn: $isDarkMode)
                                .labelsHidden()
                        }
                    }
                }
                .scrollContentBackground(.hidden) // Makes the list background transparent
                .background(Color.clear)
                
                Spacer()
            }
        }
    }
}
