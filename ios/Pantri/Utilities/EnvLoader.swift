import Foundation

enum EnvLoader {
    private static var cache: [String: String] = [:]
    
    /// Loads values from the bundled .env file
    static func value(for key: String) -> String? {
        if cache.isEmpty {
            loadEnvFile()
        }
        return cache[key]
    }
    
    private static func loadEnvFile() {
        guard let path = Bundle.main.path(forResource: "Env", ofType: "txt") else {
            print("[EnvLoader] Warning: .env file not found in bundle.")
            return
        }
        
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                    continue
                }
                
                let parts = trimmedLine.split(separator: "=", maxSplits: 1).map(String.init)
                if parts.count == 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\"")) // Remove quotes if present
                    
                    cache[key] = value
                }
            }
            print("[EnvLoader] Successfully loaded \(cache.count) variables from .env")
        } catch {
            print("[EnvLoader] Error reading .env file: \(error.localizedDescription)")
        }
    }
}
