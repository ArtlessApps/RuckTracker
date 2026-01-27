import Foundation

class LocalChallengeLoader {
    static let shared = LocalChallengeLoader()
    
    private var cachedChallenges: [Challenge] = []
    private var challengesById: [UUID: Challenge] = [:]
    
    private init() {
        loadChallenges()
    }
    
    // MARK: - Loading
    
    func loadChallenges() {
        let result: Result<[LocalChallenge], Error> = Bundle.main.decodeWithCustomDecoder("Challenges.json")
        
        switch result {
        case .success(let challengesData):
            // Convert JSON to Challenge models
            cachedChallenges = challengesData.map { $0.toChallenge() }
            
            // Index by ID for fast lookup
            challengesById = Dictionary(uniqueKeysWithValues: cachedChallenges.map { ($0.id, $0) })
            
            print("✅ Loaded \(cachedChallenges.count) challenges from bundle")
            
        case .failure(let error):
            print("❌ Failed to load challenges: \(error)")
            cachedChallenges = []
            challengesById = [:]
        }
    }
    
    // MARK: - Querying
    
    func getChallenge(byId challengeId: UUID) -> Challenge? {
        return challengesById[challengeId]
    }
    
    func getAllChallenges() -> [Challenge] {
        return cachedChallenges
    }
    
    func getActiveChallenges() -> [Challenge] {
        return cachedChallenges.filter { $0.isActive }
    }
    
    func getChallengesByType(_ type: Challenge.ChallengeType) -> [Challenge] {
        return cachedChallenges.filter { $0.challengeType == type }
    }
    
    func getChallengesByFocusArea(_ focusArea: Challenge.FocusArea) -> [Challenge] {
        return cachedChallenges.filter { $0.focusArea == focusArea }
    }
}
