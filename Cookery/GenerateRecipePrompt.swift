import SwiftUI
import ComposableArchitecture

struct GenerateRecipePromptView: View {
  @Bindable var store: StoreOf<GenerateRecipePrompt>
  
  var body: some View {
    NavigationStack {
      List {
        Text("Please enter a name and description to create your new recipe!")
        TextField("Name", text: $store.name)
        TextField("Description", text: $store.description)
      }
      .navigationTitle("Generate Recipe")
      .navigationBarTitleDisplayMode(.large)
      .listStyle(.plain)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Cancel") {
            store.send(.cancelButtonTapped, animation: .default)
          }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button("Generate") {
            store.send(.generateButtonTapped, animation: .default)
          }
        }
      }
    }
  }
}

@Reducer
struct GenerateRecipePrompt {
  @ObservableState
  struct State: Equatable {
    var name: String = ""
    var description: String = ""
  }
  
  enum Action: Equatable, BindableAction {
    case generateButtonTapped
    case cancelButtonTapped
    case binding(BindingAction<State>)
  }
  
  @Dependency(\.dismiss) var dismiss
  
  var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .generateButtonTapped:
        return .run { _ in await dismiss() }
        
      case .cancelButtonTapped:
        return .run { _ in await dismiss() }
        
      case .binding:
        return .none
      }
    }
  }
}

#Preview {
  GenerateRecipePromptView(store: .init(
    initialState: GenerateRecipePrompt.State.init(),
    reducer: GenerateRecipePrompt.init
  ))
}

