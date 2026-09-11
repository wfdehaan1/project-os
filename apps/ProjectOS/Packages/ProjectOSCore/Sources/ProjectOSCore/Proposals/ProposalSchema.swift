import Foundation

public enum ProposalSchemaError: Error, Equatable, LocalizedError {
  case resourceMissing

  public var errorDescription: String? {
    "The bundled proposal schema is missing. Reinstall or rebuild ProjectOS."
  }
}

public enum ProposalSchema {
  public static let version = 1

  public static func data() throws -> Data {
    guard let url = Bundle.module.url(forResource: "proposal.schema", withExtension: "json") else {
      throw ProposalSchemaError.resourceMissing
    }
    return try Data(contentsOf: url)
  }
}
