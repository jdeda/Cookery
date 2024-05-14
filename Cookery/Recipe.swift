import SwiftUI
import ComposableArchitecture

@ViewAction(for: Recipe.self)
struct RecipeView: View {
  @Bindable var store: StoreOf<Recipe>
  
  var body: some View {
    NavigationStack {
      List {
        HStack {
          Spacer()
          PhotosView(photos: store.recipe.photos)
            .frame(width: 350, height: 350)
            .clipShape(RoundedRectangle(cornerRadius: 15))
          Spacer()
        }
        
        Section {
          Text(store.recipe.about)
        } header: {
          Text("About")
            .font(.title3)
            .fontWeight(.bold)
            .foregroundStyle(.black)
        }
        
        Section {
          ForEach(store.recipe.ingredients) { ingredient in
            Text(ingredient.description)
          }
        } header: {
          Text("Ingredients")
            .font(.title3)
            .fontWeight(.bold)
            .foregroundStyle(.black)
        }
        
        Section {
          ForEach(store.recipe.steps) { step in
            VStack(alignment: .leading) {
              HStack(alignment: .top) {
                Text("\((store.recipe.steps.index(id: step.id) ?? 0) + 1)")
                  .fontWeight(.bold)
                Text(step.description)
              }
              HStack {
                Spacer()
                PhotosView(photos: step.photos)
                  .frame(width: 350, height: 350)
                  .clipShape(RoundedRectangle(cornerRadius: 15))
                Spacer()
              }
            }
          }
        } header: {
          Text("About")
            .font(.title3)
            .fontWeight(.bold)
            .foregroundStyle(.black)
        }
      }
      .listStyle(.plain)
      .navigationTitle(store.recipe.name)
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button("", systemImage: "wand.and.stars") {
            send(.magicButtonTapped, animation: .default)
          }
          .disabled(store.fetchInFlight)
        }
      }
      .sheet(isPresented: $store.fetchInFlight) {
        NavigationStack {
          ProgressView("Generating Images...")
            .toolbar {
              ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                  send(.cancelButtonTapped)
                }
              }
            }
        }
        .presentationDetents([.fraction(0.50)])
      }
    }
  }
}

@Reducer
struct Recipe {
  @ObservableState
  struct State: Equatable {
    var recipe: Database.Recipe = .mock
    var fetchInFlight: Bool = false
  }
  
  enum Action: Equatable, ViewAction, BindableAction {
    case view(ViewAction)
    enum ViewAction: Equatable {
      case magicButtonTapped
      case cancelButtonTapped
    }
    case binding(BindingAction<State>)
    case recieveGeneratedRecipePhotos(Database.Recipe)
  }
  
  @Dependency(\.openAIClient) var openAIClient
  
  enum CancelID: Hashable { case cancel }
  
  var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .view(.magicButtonTapped):
        state.fetchInFlight = true
        return .run { [recipe = state.recipe] send in
          let recipe = (try? await openAIClient.generateRecipePhotos(recipe)) ?? recipe
          await send(.recieveGeneratedRecipePhotos(recipe), animation: .default)
        }
        .cancellable(id: CancelID.cancel, cancelInFlight: true)
        
      case .view(.cancelButtonTapped):
        state.fetchInFlight = false
        return .cancel(id: CancelID.cancel)
        
      case let .recieveGeneratedRecipePhotos(recipe):
        state.fetchInFlight = false
        state.recipe = recipe
        return .none
        
      case .view, .binding:
        return .none
      }
    }
  }
}

struct PhotosView: View {
  let photos: IdentifiedArrayOf<Database.Photo>
  @State private var selection: Database.Photo.ID?
  
  var body: some View {
    TabView(selection: $selection) {
      ForEach(photos) { photo  in
        Rectangle()
          .fill(.clear)
          .aspectRatio(1, contentMode: .fit)
          .overlay(
            photo.image
              .resizable()
          )
          .tag(Optional(photo.id))
      }
    }
    .tabViewStyle(.page)
    .indexViewStyle(.page(backgroundDisplayMode: .always))
  }
}

#Preview {
  RecipeView(store: .init(
    initialState: Recipe.State.init(),
    reducer: Recipe.init
  ))
}


