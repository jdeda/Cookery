import SwiftUI
import ComposableArchitecture

@ViewAction(for: App.self)
struct AppView: View {
  @Bindable var store: StoreOf<App>
  
  var body: some View {
    NavigationStack {
      List {
        ForEach(store.recipes) { recipe in
          HStack(alignment: .top) {
            PhotosView(photos: .init(recipe.photos.prefix(1)))
              .frame(width: 75, height: 75)
              .clipShape(RoundedRectangle(cornerRadius: 12.5))
            VStack(alignment: .leading) {
              Text(recipe.name)
                .font(.headline)
                .fontWeight(.medium)
                .lineLimit(1)
              Text(recipe.about.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2, reservesSpace: true)
              Spacer()
            }
          }
          .listRowSeparator(.hidden, edges: .top)
          .onTapGesture {
            send(.recipeTapped(recipe.id), animation: .default)
          }
        }
      }
      .navigationTitle("Recipes")
      .listStyle(.plain)
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button("", systemImage: "wand.and.stars") {
            send(.magicButtonTapped, animation: .default)
          }
        }
      }
      .sheet(item: $store.scope(state: \.destination?.generateRecipePrompt, action: \.destination.generateRecipePrompt)) { store in
        GenerateRecipePromptView(store: store)
      }
      .sheet(isPresented: $store.generatingInFlight) {
        NavigationStack {
          ProgressView("Generating Recipe...")
            .toolbar {
              ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                  send(.cancelGeneratingButtonTapped)
                }
              }
            }
        }
        .presentationDetents([.fraction(0.50)])
      }
      .navigationDestination(item: $store.scope(state: \.destination?.recipe, action: \.destination.recipe)) { store in
        RecipeView(store: store)
      }

    }
  }
}

@Reducer
struct App {
  
  @Reducer(state: .equatable, action: .equatable)
  enum Destination {
    case recipe(Recipe)
    case generateRecipePrompt(GenerateRecipePrompt)
    case generatingRecipe
  }
  
  @ObservableState
  struct State: Equatable {
    var recipes: IdentifiedArrayOf<Database.Recipe> = [.mock]
    @Presents var destination: Destination.State?
    var generatingInFlight: Bool = false
  }
  
  enum Action: Equatable, ViewAction, BindableAction {
    case view(ViewAction)
    enum ViewAction: Equatable {
      case magicButtonTapped
      case cancelGeneratingButtonTapped
      case recipeTapped(Database.Recipe.ID)
    }
    case binding(BindingAction<State>)
    case recieveGeneratedRecipe(Database.Recipe)
    case navigateToRecipe(Database.Recipe.ID)
    case destination(PresentationAction<Destination.Action>)
  }
  
  @Dependency(\.openAIClient) var openAIClient
  @Dependency(\.continuousClock) var clock

  enum CancelID: Hashable { case cancel }
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .view(.magicButtonTapped):
        state.destination = .generateRecipePrompt(.init())
        return .none
        
      case .view(.cancelGeneratingButtonTapped):
        state.generatingInFlight = false
        return .cancel(id: CancelID.cancel)
        
      case let .view(.recipeTapped(id)):
        guard let recipe = state.recipes[id: id]
        else { return .none }
        state.destination = .recipe(.init(recipe: recipe))
        return .none
        
      case let .recieveGeneratedRecipe(recipe):
        state.recipes.append(recipe)
        state.generatingInFlight = false
        return .run { [id = recipe.id] send in
          try await clock.sleep(for: .seconds(1))
          await send(.navigateToRecipe(id), animation: .default)
        }
      
      case let .navigateToRecipe(id):
        guard let recipe = state.recipes[id: id]
        else { return .none }
        state.destination = .recipe(.init(recipe: recipe))
        return .none
        
      case .destination(.presented(.generateRecipePrompt(.generateButtonTapped))):
        guard let prompt = state.destination?.generateRecipePrompt
        else { return .none }
        state.generatingInFlight = true
        return .run { send in
          let recipe = try await openAIClient.generateRecipe(name: prompt.name, description: prompt.description)
          await send(.recieveGeneratedRecipe(recipe), animation: .default)
        }
        .cancellable(id: CancelID.cancel, cancelInFlight: true)
        
      case .view, .destination, .binding:
        return .none
      }
    }
    .ifLet(\.$destination, action: \.destination)
  }
}

#Preview {
  AppView(store: .init(
    initialState: App.State.init(),
    reducer: App.init
  ))
}


