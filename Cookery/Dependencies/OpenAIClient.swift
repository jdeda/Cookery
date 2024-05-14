import Foundation
import ComposableArchitecture
import OpenAI

@DependencyClient
struct OpenAIClient: DependencyKey {
  static let liveValue = Self.live
  var generateRecipePhotos: @Sendable (_ recipe: Database.Recipe) async throws -> Database.Recipe
  var generateRecipe: @Sendable (_ name: String, _ description: String) async throws -> Database.Recipe
  
  enum OpenAIError: Error, Equatable {
    case error(String)
    case failedToGenerateRecipe
  }
}

extension DependencyValues {
  var openAIClient: OpenAIClient {
    get { self[OpenAIClient.self] }
    set { self[OpenAIClient.self] = newValue }
  }
}

extension OpenAIClient {
  static let live: OpenAIClient = {
    let openAI = OpenAI(apiToken: Secrets.apiToken)
    
    return Self(
      generateRecipePhotos: { recipe in
        try await openAI.generateRecipePhotos(recipe: recipe)
      },
      generateRecipe: { name, description in
        let data = try JSONEncoder().encode(GeneratedRecipe(name: name, about: description))
        let json = try String(data: data, encoding: .utf8) ?? { throw OpenAIError.failedToGenerateRecipe }()
        
        let message = """
        Please modify the given recipe as JSON: \(json). \n
        Please make sure every description is at least 1-2 sentences long, don't number the steps,
        only have 3 steps max, and the last step should always be about enjoying the meal.
        """
        
        let query = ChatQuery(messages: [.user(.init(content: .string(message)))], model: .gpt3_5Turbo)
        let result = try await openAI.chats(query: query).choices.first?.message.content?.string ?? ""
        let resultData = try result.data(using: .utf8) ?? { throw OpenAIError.failedToGenerateRecipe }()
        let recipe = try JSONDecoder().decode(GeneratedRecipe.self, from: data)
        let generatedRecipe = recipe.toRecipe()
        return try await openAI.generateRecipePhotos(recipe: generatedRecipe)
        
        struct GeneratedRecipe: Codable {
          var name: String
          var about: String
          var ingredients = [String]()
          var steps = [String]()
          
          static func convert(recipe: Database.Recipe) -> GeneratedRecipe {
            .init(
              name: recipe.name,
              about: recipe.about,
              ingredients: recipe.ingredients.map(\.description),
              steps: recipe.ingredients.map(\.description))
          }
          
          func toRecipe() -> Database.Recipe {
            .init(
              id: .init(),
              name: self.name,
              about: self.about,
              ingredients: .init(uniqueElements: self.ingredients.map({
                .init(id: .init(), description: $0.description)
              })),
              steps: .init(uniqueElements: self.steps.map({
                .init(id: .init(), description: $0.description)
              }))
            )
          }
        }
        
      }
    )
  }()
}

fileprivate extension OpenAI {
  @Sendable
  func generateRecipePhotos(recipe: Database.Recipe) async throws -> Database.Recipe {
    async let _recipePhotos: [Database.Photo] = await {
      let prompt = "\(recipe.name), made from: \(recipe.ingredients.map(\.description)). "
      async let photo1 = await generatePhoto(prompt + "presented nicely")
      async let photo2 = await generatePhoto(prompt + "show a happy person feasting on this meal!")
      return await [photo1, photo2].compactMap({ $0 })
    }()
    
    async let _stepPhotos = await withTaskGroup(
      of: (Database.Recipe.Step.ID, Database.Photo?).self,
      returning: [Database.Recipe.Step.ID : Database.Photo].self
    ) { group in
      for step in recipe.steps {
        group.addTask {
          var prompt = "Cooking a recipe\(recipe.name), made from: \(recipe.ingredients.map(\.description)). "
          prompt += "Currently cooking at this step in the recipe: \(step.description)"
          return await (step.id, generatePhoto(prompt))
        }
      }
      return await group.reduce(into: .init()) { partial, next in
        next.1.flatMap({ partial[next.0, default: $0] = $0 })
      }
    }
    
    let (recipePhotos, stepPhotos) = await (_recipePhotos, _stepPhotos)
    
    var recipe = recipe
    if !recipePhotos.isEmpty {
      recipe.photos = .init(uniqueElements: recipePhotos)
    }
    if !stepPhotos.isEmpty {
      stepPhotos.forEach { (stepID, photo) in
        recipe.steps[id: stepID]?.photos = [photo]
      }
    }
    return recipe
    
    @Sendable
    func generatePhoto(_ prompt: String) async -> Database.Photo? {
      let query = ImagesQuery(
        prompt: prompt,
        model: .dall_e_2,
        n: 1,
        quality: .standard,
        responseFormat: .url,
        size: ._1024
      )
      
      guard
        let result = try? await self.images(query: query).data.first,
        let urlString = result.url,
        let url = URL(string: urlString),
        let (data, response) = try? await URLSession.shared.data(from: url),
        let response = response as? HTTPURLResponse,
        response.statusCode == 200,
        let photo = Database.Photo(id: .init(), data: data)
      else {
        return nil
      }
      return photo
      
    }
  }
}
