import SwiftUI
import Foundation
import Tagged
import ComposableArchitecture

extension Database {
  struct Photo: Equatable, Codable, Identifiable {
    let id: Tagged<Self, UUID>
    let data: Data
    let image: Image
    
    init?(id: ID, data: Data) {
      guard let uiImage = UIImage(data: data) else { return nil }
      self.image = Image(uiImage: uiImage)
      self.data = data
      self.id = id
    }
    
    enum CodingKeys: CodingKey {
      case id
      case data
    }
    
    enum ParseError: Error { case failure }
    
    init(from decoder: Decoder) throws {
      enum ParseError: Error { case failure }
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.id = try container.decode(ID.self, forKey: .id)
      self.data = try container.decode(Data.self, forKey: .data)
      guard let uiImage = UIImage(data: data) else { throw ParseError.failure  }
      self.image = Image(uiImage: uiImage)
    }
    
    func encode(to encoder: Encoder) throws {
      enum ParseError: Error { case failure }
      guard let _ = UIImage(data: self.data) else { throw ParseError.failure  }
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(id, forKey: .id)
      try container.encode(data, forKey: .data)
    }
  }
  
}
private extension Data {
  init(bundleJPEG: String) {
    try! self.init(contentsOf: Bundle.main.url(forResource: bundleJPEG, withExtension: "jpeg")!)
  }
}

extension IdentifiedArrayOf<Database.Photo> {
  static let mock: Self = [
    .init(id: .init(), data: .init(bundleJPEG: "recipe_00_step_01"))!,
    .init(id: .init(), data: .init(bundleJPEG: "recipe_00_step_02"))!,
    .init(id: .init(), data: .init(bundleJPEG: "recipe_00_step_03"))!
  ]
  
  static let mockLong: Self = [
    .init(id: .init(), data: .init(bundleJPEG: "recipe_00_root_01"))!,
    .init(id: .init(), data: .init(bundleJPEG: "recipe_00_root_02"))!,
    .init(id: .init(), data: .init(bundleJPEG: "recipe_00_step_01"))!,
    .init(id: .init(), data: .init(bundleJPEG: "recipe_00_step_01"))!,
    .init(id: .init(), data: .init(bundleJPEG: "recipe_00_step_02"))!,
    .init(id: .init(), data: .init(bundleJPEG: "recipe_00_step_03"))!,
    .init(id: .init(), data: .init(bundleJPEG: "recipe_00_root_01"))!,
    .init(id: .init(), data: .init(bundleJPEG: "recipe_00_root_02"))!,
    .init(id: .init(), data: .init(bundleJPEG: "recipe_00_step_01"))!,
    .init(id: .init(), data: .init(bundleJPEG: "recipe_00_step_01"))!,
    .init(id: .init(), data: .init(bundleJPEG: "recipe_00_step_02"))!,
    .init(id: .init(), data: .init(bundleJPEG: "recipe_00_step_03"))!
  ]
}
