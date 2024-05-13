import SwiftUI

@main
struct Main: SwiftUI.App {
  var body: some Scene {
    WindowGroup {
      AppView(store: .init(
        initialState: App.State.init(),
        reducer: App.init
      ))
    }
  }
}

