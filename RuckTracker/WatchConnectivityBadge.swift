import SwiftUI

struct WatchConnectivityBadge: View {
    @EnvironmentObject var watchConnectivityManager: WatchConnectivityManager
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "applewatch")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(watchConnectivityManager.isWatchReachable ? 
                    Color("AccentGreen") : Color("WarmGray"))
            
            // Optional: small dot indicator when connected
            if watchConnectivityManager.isWatchReachable {
                Circle()
                    .fill(Color("AccentGreen"))
                    .frame(width: 6, height: 6)
            }
        }
    }
}
