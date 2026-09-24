import SwiftUI

@main
struct BOTTTApp: App {
    @StateObject private var viewModel = PetViewModel()

    var body: some Scene {
        Window("BOTTT", id: "bottt") {
            PetView(viewModel: viewModel)
        }
        .windowStyle(.plain)
        .windowResizability(.contentSize)
        .windowLevel(.floating)
        .defaultSize(width: 80, height: 121)
        .defaultPosition(.bottomTrailing)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("宠物") {
                Button("设置…") {
                    viewModel.showSettings = true
                }
            }
        }
    }
}
