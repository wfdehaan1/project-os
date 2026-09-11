import Foundation

public struct ProviderQualification: Codable, Equatable, Sendable {
    public let providerID: ProviderID
    public let modelID: String
    public let configurationID: UUID
    public let executionVerified: Bool
    public let localExecutionVerified: Bool
    public let qualityVerified: Bool
    public let structuredOutputVerified: Bool
    public let cancellationVerified: Bool
    public let failureHandlingVerified: Bool
    public let recordedAt: Date
    public let limitations: String?

    public init(
        providerID: ProviderID,
        modelID: String,
        configurationID: UUID,
        executionVerified: Bool,
        localExecutionVerified: Bool,
        qualityVerified: Bool,
        structuredOutputVerified: Bool,
        cancellationVerified: Bool,
        failureHandlingVerified: Bool,
        recordedAt: Date = Date(),
        limitations: String? = nil
    ) {
        self.providerID = providerID
        self.modelID = modelID
        self.configurationID = configurationID
        self.executionVerified = executionVerified
        self.localExecutionVerified = localExecutionVerified
        self.qualityVerified = qualityVerified
        self.structuredOutputVerified = structuredOutputVerified
        self.cancellationVerified = cancellationVerified
        self.failureHandlingVerified = failureHandlingVerified
        self.recordedAt = recordedAt
        self.limitations = limitations
    }
}

public struct RegisteredProvider: Sendable {
    public let descriptor: ProviderDescriptor
    public let readiness: AIProviderReadiness
    public let health: ProviderHealth?
    public let qualification: ProviderQualification?
}

/// A deliberately small registry. Registration replaces the prior configuration for an adapter.
public actor ProviderRegistry {
    private var providers: [ProviderID: any AIProvider] = [:]
    private var health: [ProviderID: ProviderHealth] = [:]
    private var qualifications: [ProviderID: ProviderQualification] = [:]

    public init() {}

    public func register(_ provider: any AIProvider) {
        let id = provider.descriptor.id
        if providers[id]?.descriptor.configurationID != provider.descriptor.configurationID {
            health[id] = nil
            if qualifications[id]?.configurationID != provider.descriptor.configurationID {
                qualifications[id] = nil
            }
        }
        providers[id] = provider
    }

    public func remove(_ id: ProviderID) {
        providers[id] = nil
        health[id] = nil
        qualifications[id] = nil
    }

    public func provider(for id: ProviderID) throws -> any AIProvider {
        guard let provider = providers[id] else {
            throw AIProviderError.unavailable("Configure \(id.rawValue) in Settings, then retry.")
        }
        return provider
    }

    /// Must only be called for an explicit user-initiated connection test.
    public func testConnectivity(for id: ProviderID) async throws -> ProviderHealth {
        let provider = try provider(for: id)
        let result = await provider.checkConnectivity()
        health[id] = result
        return result
    }

    /// Connectivity never calls this. Qualification evidence must come from an explicit live test.
    public func recordQualification(_ qualification: ProviderQualification) throws {
        guard let descriptor = providers[qualification.providerID]?.descriptor,
              descriptor.modelID == qualification.modelID,
              descriptor.configurationID == qualification.configurationID,
              qualification.executionVerified,
              qualification.qualityVerified,
              qualification.structuredOutputVerified,
              qualification.cancellationVerified,
              qualification.failureHandlingVerified else {
            throw AIProviderError.invalidConfiguration("Qualification evidence does not match the active provider/model/configuration.")
        }
        if descriptor.executionBoundary == .local, !qualification.localExecutionVerified {
            throw AIProviderError.invalidConfiguration("A local provider cannot be qualified without verified offline local execution.")
        }
        qualifications[qualification.providerID] = qualification
    }

    public func registeredProviders() -> [RegisteredProvider] {
        providers.values.map { provider in
            let descriptor = provider.descriptor
            let currentHealth = health[descriptor.id]
            let qualification = qualifications[descriptor.id].flatMap {
                $0.configurationID == descriptor.configurationID && $0.modelID == descriptor.modelID ? $0 : nil
            }
            let readiness: AIProviderReadiness
            if currentHealth?.isConnected == false || currentHealth?.selectedModelIsAvailable == false { readiness = .unavailable }
            else if qualification != nil { readiness = .qualified }
            else if currentHealth?.isConnected == true { readiness = .connected }
            else if currentHealth == nil { readiness = .unverified }
            else { readiness = .unavailable }
            return RegisteredProvider(descriptor: descriptor, readiness: readiness, health: currentHealth, qualification: qualification)
        }.sorted { $0.descriptor.displayName < $1.descriptor.displayName }
    }
}
