import Foundation

extension Bundle {
    /// Load and decode a JSON file from the app bundle
    func decode<T: Decodable>(_ filename: String) -> T {
        guard let url = self.url(forResource: filename, withExtension: nil) else {
            fatalError("❌ Failed to locate \(filename) in bundle")
        }
        
        guard let data = try? Data(contentsOf: url) else {
            fatalError("❌ Failed to load \(filename) from bundle")
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        guard let decoded = try? decoder.decode(T.self, from: data) else {
            fatalError("❌ Failed to decode \(filename) from bundle")
        }
        
        return decoded
    }
    
    /// Load and decode a JSON file with error handling
    func decodeWithErrorHandling<T: Decodable>(_ filename: String) -> Result<T, Error> {
        guard let url = self.url(forResource: filename, withExtension: nil) else {
            return .failure(NSError(domain: "BundleDecoder", code: 1, 
                userInfo: [NSLocalizedDescriptionKey: "File not found: \(filename)"]))
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let decoded = try decoder.decode(T.self, from: data)
            return .success(decoded)
        } catch {
            return .failure(error)
        }
    }
    
    /// Load and decode a JSON file with custom decoder (no snake case conversion)
    func decodeWithCustomDecoder<T: Decodable>(_ filename: String) -> Result<T, Error> {
        guard let url = self.url(forResource: filename, withExtension: nil) else {
            return .failure(NSError(domain: "BundleDecoder", code: 1, 
                userInfo: [NSLocalizedDescriptionKey: "File not found: \(filename)"]))
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            // No key decoding strategy - use custom CodingKeys
            let decoded = try decoder.decode(T.self, from: data)
            return .success(decoded)
        } catch {
            return .failure(error)
        }
    }
}
