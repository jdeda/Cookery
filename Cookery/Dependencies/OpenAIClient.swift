import Foundation
import ComposableArchitecture
import OpenAI

@DependencyClient
struct OpenAIClient: DependencyKey {
  static let liveValue = Self.live
  var generateRecipePhotos: (_ recipe: Recipe) async throws -> Recipe
  
  enum OpenAIError: Error, Equatable {
    case error(String)
  }
}

///
/// We tap a button to generate images
/// We generate an image for the recipe
/// We generate an image for each step
/// If an image fails, we just use the default
/// Otherwise we replace the image.
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
        async let _recipePhotos = await {
          let prompt = "\(recipe.name), made from: \(recipe.ingredients.map(\.description)), presented nicely"
          return await generatePhoto(prompt: prompt, count:2, openAI: openAI)
        }()
        
        async let _stepPhotos = await withTaskGroup(of: (Recipe.Step.ID, Photo?).self, returning: [Recipe.Step.ID : Photo].self) { group in
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
        if let recipePhotos = recipePhotos {
          recipe.photos = [recipePhotos]
        }
        if !stepPhotos.isEmpty {
          stepPhotos.forEach { (stepID, photo) in
            recipe.steps[id: stepID]?.photos = [photo]
          }
        }
        return recipe
      }
    )
  }()
}

fileprivate func generatePhoto(prompt: String, count: Int = 1, openAI: OpenAI) async -> Photo? {
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
    let photo = Photo(id: .init(), data: data)
  else { return nil  }
  return photo

}

//import Foundation
//import ComposableArchitecture
//import OpenAI
//import AsyncAlgorithms
//
//@DependencyClient
//struct OpenAIClient: DependencyKey {
//  static let liveValue = Self.live
//  var generateRecipePhotos: (_ recipe: Recipe) async throws -> Recipe
//
//  enum OpenAIError: Error, Equatable {
//    case error(String)
//  }
//}
//
//extension DependencyValues {
//  var openAIClient: OpenAIClient {
//    get { self[OpenAIClient.self] }
//    set { self[OpenAIClient.self] = newValue }
//  }
//}
//
//extension OpenAIClient {
//  static let live: OpenAIClient = {
//    let openAI = OpenAI(apiToken: Secrets.apiToken)
//    return Self(
//      generateRecipePhotos: { recipe in
//        let prompt = "\(recipe.name), made from: \(recipe.ingredients.map(\.description))"
//        let query = ImagesQuery(
//          prompt: prompt,
//          model: .dall_e_3,
//          n: 1,
//          quality: .standard,
//          responseFormat: .url,
//          size: ._1024,
//          style: .natural
//        )
//
//        let results = try! await openAI.images(query: query)
//        guard let results = try? await openAI.images(query: query)
//        else {
//          throw OpenAIError.error("Failed to generate images ")
//        }
//
//        var recipe = recipe
//        recipe.photos = try await results.data.async.reduce(into: []) { partial, image in
//          guard let urlString = image.url,
//          let url  = URL(string: urlString),
//          let (data, response) = try? await URLSession.shared.data(from: url),
//          let response = response as? HTTPURLResponse,
//          response.statusCode == 200,
//          let photo = Photo.init(id: .init(), data: data)
//          else { throw OpenAIError.error("Failed to load image") }
//          partial.append(photo)
//        }
//        return recipe
//      }
//    )
//  }()
//}
