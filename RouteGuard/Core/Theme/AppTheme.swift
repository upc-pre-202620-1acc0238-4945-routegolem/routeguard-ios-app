import SwiftUI

enum AppTheme {
    static let primaryNavy = Color(red: 0.106, green: 0.212, blue: 0.365) // #1B365D
    static let primaryTeal = Color(red: 0.0, green: 0.545, blue: 0.545)   // #008B8B
    static let emerald     = Color(red: 0.063, green: 0.725, blue: 0.506) // #10B981
    static let errorRed    = Color(red: 0.827, green: 0.184, blue: 0.184) // #D32F2F
    static let warningAmber = Color(red: 0.961, green: 0.620, blue: 0.043)
}

enum ApiConstants {
    static let baseUrl = "https://routeguard-web-services.onrender.com/api/v1"
    static let requestTimeout: TimeInterval = 8.0
}
