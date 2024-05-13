import Foundation
import Tagged
import ComposableArchitecture

struct Recipe: Equatable, Identifiable, Codable {
  let id: Tagged<Self, UUID>
  var name: String = ""
  var photos: IdentifiedArrayOf<Photo> = []
  var about: String = ""
  
  var ingredients: IdentifiedArrayOf<Ingredient> = []
  struct Ingredient: Equatable, Identifiable, Codable {
    let id: Tagged<Self, UUID>
    var description: String = ""
  }
  
  var steps: IdentifiedArrayOf<Step> = []
  struct Step: Equatable, Identifiable, Codable {
    let id: Tagged<Self, UUID>
    var photos: IdentifiedArrayOf<Photo> = []
    var description: String = ""
  }
}

extension Recipe {
  static let empty = Recipe(id: .init())
  
  static let mock = Recipe(
    id: .init(),
    name: "Double Cheese Burger",
    photos: [
      .init(bundleJPEG: "recipe_00_root_01"),
      .init(bundleJPEG: "recipe_00_root_02")
    ],
    about: """
Who doesn't love a big fat juicy burger with that secret sauce. \
This is a party pleaser and a guilty pleasure. \
Join me in how to craft the perfect burger!
""",
    ingredients: [
      .init(id: .init(), description: "Buns"),
      .init(id: .init(), description: "Patties"),
      .init(id: .init(), description: "Cheese"),
      .init(id: .init(), description: "Secret Sauce"),
      .init(id: .init(), description: "Toppings"),
    ],
    steps: [
      .init(
        id: .init(),
        photos: [.init(bundleJPEG: "recipe_00_step_01")],
        description: "Grill the patties up on the grill. Toast your buns too!"
      ),
      .init(
        id: .init(),
        photos: [.init(bundleJPEG: "recipe_00_step_02")],
        description: "When your burgers are done, add a slice of cheese on top and cover them to steam and melt the cheese."
      ),
      .init(
        id: .init(),
        photos: [.init(bundleJPEG: "recipe_00_step_03")],
        description: "Assembly your burger by layering a generous amount of your secret sauce, toppings, and stack as many patties as you like. Enjoy!"
      )
    ]
  )
}

private extension Data {
  init(bundleJPEG: String) {
    try! self.init(contentsOf: Bundle.main.url(forResource: bundleJPEG, withExtension: "jpeg")!)
  }
}

private extension Photo {
  init(bundleJPEG: String) {
    self.init(id: .init(), data: .init(bundleJPEG: bundleJPEG))!
  }
}
