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
        try await __generateRecipePhotos(recipe: recipe, openAI: openAI)
      },
      generateRecipe: { name, description in
        let recipe = GeneratedRecipe(name: name, about: description, ingredients: [], steps: [])
        guard let data = try? JSONEncoder().encode(recipe),
              let json = String(data: data, encoding: .utf8)
        else { throw OpenAIError.error("Failed to generate recipe.") }
//        let message = """
//        Please generate a recipe given the following information:
//        - Do not number the steps
//        - Make the about a couple sentences long
//        - Make the steps a couple sentences long
//        - Return the modified recipe JSON: \(json)
//        """
//        let message = """
//        Please generate a recipe given the following JSON:
//        - Do not number the steps
//        - Make the about a couple sentences long
//        - Make the steps a couple sentences long
//        - Return the modified recipe JSON: \(json)
//        """
        let message = "Please generate a recipe given the following JSON: \(json)"
        let query = ChatQuery(messages: [.user(.init(content: .string(message)))], model: .gpt3_5Turbo)
        guard let result = try? await openAI.chats(query: query).choices.first?.message.content?.string,
              let data = result.data(using: .utf8),
              let recipe = try? JSONDecoder().decode(GeneratedRecipe.self, from: data)
        else { throw OpenAIError.error("Failed to generate recipe.") }
        let generatedRecipe = recipe.toRecipe()
        return try await __generateRecipePhotos(recipe: generatedRecipe, openAI: openAI)
                
        struct GeneratedRecipe: Codable {
          var name: String
          var about: String
          var ingredients: [String]
          var steps: [String]
          
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

@Sendable
private func __generateRecipePhotos(recipe: Database.Recipe, openAI: OpenAI) async throws -> Database.Recipe {
  async let _recipePhotos: [Database.Photo] = await {
    let prompt1 = "\(recipe.name), made from: \(recipe.ingredients.map(\.description)), presented nicely"
    async let photo1 = await generatePhoto(prompt: prompt1, count:1, openAI: openAI)
    
    let prompt2 = "\(recipe.name), made from: \(recipe.ingredients.map(\.description)), show a happy person or family feasting on this meal!"
    async let photo2 = await generatePhoto(prompt: prompt2, count:1, openAI: openAI)
    
    let photos = await [photo1, photo2]
    return photos.compactMap( { $0 })
  }()
  
  async let _stepPhotos = await withTaskGroup(
    of: (Database.Recipe.Step.ID, Database.Photo?).self,
    returning: [Database.Recipe.Step.ID : Database.Photo].self
  ) { group in
    for step in recipe.steps {
      group.addTask {
        let prompt = "Cooking a recipe\(recipe.name), made from: \(recipe.ingredients.map(\.description)). Currently cooking at this step in the recipe: \(step.description)"
        return await (step.id, generatePhoto(prompt: prompt, openAI: openAI))
      }
    }
    return await group.reduce(into: .init()) { partial, next in
      let stepID = next.0
      guard let stepPhoto = next.1 else { return }
      partial[stepID, default: stepPhoto] = stepPhoto
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
  func generatePhoto(prompt: String, count: Int = 1, openAI: OpenAI) async -> Database.Photo? {
    let query = ImagesQuery(
      prompt: prompt,
      model: .dall_e_2,
      n: count,
      quality: .standard,
      responseFormat: .url,
      size: ._1024
    )
    let result = try? await openAI.images(query: query).data.first
    guard
      let urlString = result?.url,
          let url  = URL(string: urlString),
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
