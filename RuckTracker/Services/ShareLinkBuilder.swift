import Foundation

/// Builds short universal links for sharing workouts.
struct ShareLinkBuilder {
    /// Base host for universal links. Update to match the deployed domain.
    static let host = "theruckworkout.com"
    
    /// Build a universal link pointing to a workout share code.
    /// The `workoutURI` should be the Core Data object URI; it will be base64 encoded.
    static func makeShareURL(workoutURI: URL?, channel: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        
        let code: String
        if let workoutURI = workoutURI,
           let encoded = workoutURI.absoluteString.data(using: .utf8)?.base64EncodedString() {
            code = encoded
        } else {
            code = UUID().uuidString.lowercased()
        }
        
        components.path = "/s/\(code)"
        components.queryItems = [
            URLQueryItem(name: "utm_source", value: "app_share"),
            URLQueryItem(name: "utm_medium", value: channel),
            URLQueryItem(name: "utm_campaign", value: "workout_share"),
            URLQueryItem(name: "src", value: "ios")
        ]
        return components.url
    }
    
    /// Attempt to decode a base64-encoded Core Data URI string back into a URL.
    static func decodeWorkoutURI(from code: String) -> URL? {
        if let data = Data(base64Encoded: code),
           let string = String(data: data, encoding: .utf8) {
            return URL(string: string)
        }
        return nil
    }
}

