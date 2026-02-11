import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var healthManager: HealthManager
    @EnvironmentObject var workoutManager: WorkoutManager
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @EnvironmentObject var premiumManager: PremiumManager
    @EnvironmentObject var tabSelection: MainTabSelection
    
    @State private var showingSettings = false
    
    init() {
        // Centralize tab appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppColors.surface)
        
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(AppColors.primary)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(AppColors.primary)]
        
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(AppColors.textSecondary)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(AppColors.textSecondary)]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().tintColor = UIColor(AppColors.primary)
        UITabBar.appearance().unselectedItemTintColor = UIColor(AppColors.textSecondary)
    }
    
    var body: some View {
        TabView(selection: $tabSelection.selectedTab) {
            ImprovedPhoneMainView()
                .tabItem {
                    Label {
                        Text("")
                    } icon: {
                        if let img = UIImage(named: "MarchV5White")?
                            .trimmed()
                            .scaledToFit(size: CGSize(width: 28, height: 28))
                            .withRenderingMode(.alwaysTemplate) {
                            Image(uiImage: img)
                        }
                    }
                }
                .tag(MainTabSelection.Tab.ruck)
            
            PlanView()
                .tabItem {
                    Label("", systemImage: "calendar")
                }
                .tag(MainTabSelection.Tab.coach)
            
            CommunityTribeView()
                .tabItem {
                    Label("", systemImage: "person.3.fill")
                }
                .tag(MainTabSelection.Tab.tribe)
            
            RankingsTabView()
                .tabItem {
                    Label("", systemImage: "trophy.fill")
                }
                .tag(MainTabSelection.Tab.rankings)
            
            ActivityContainer(showSettings: $showingSettings)
                .tabItem {
                    Label("", systemImage: "person.crop.circle")
                }
                .tag(MainTabSelection.Tab.you)
        }
        .accentColor(AppColors.primary)
        .preferredColorScheme(.dark)
        .background(AppColors.backgroundGradient.ignoresSafeArea())
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(HealthManager.shared)
        .environmentObject(WorkoutManager())
        .environmentObject(WorkoutDataManager.shared)
        .environmentObject(PremiumManager.shared)
        .environmentObject(MainTabSelection())
}

private struct ActivityContainer: View {
    @EnvironmentObject var workoutDataManager: WorkoutDataManager
    @EnvironmentObject var premiumManager: PremiumManager
    @Binding var showSettings: Bool
    
    var body: some View {
        NavigationView {
            AnalyticsView(showAllWorkouts: .constant(false))
                .environmentObject(workoutDataManager)
                .environmentObject(premiumManager)
                .navigationTitle("Activity")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                        }
                    }
                }
        }
    }
}

// MARK: - UIImage Helpers

private extension UIImage {
    /// Trims transparent pixels from all edges.
    func trimmed() -> UIImage {
        guard let cgImage = self.cgImage,
              let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else { return self }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        
        var minX = width, minY = height, maxX = 0, maxY = 0
        
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let alpha = bytes[offset + 3] // RGBA — alpha is last byte
                if alpha > 0 {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }
        
        guard maxX > minX, maxY > minY else { return self }
        
        let cropRect = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        guard let cropped = cgImage.cropping(to: cropRect) else { return self }
        return UIImage(cgImage: cropped, scale: self.scale, orientation: self.imageOrientation)
    }
    
    /// Scales image to fit within the target size, preserving aspect ratio.
    func scaledToFit(size targetSize: CGSize) -> UIImage {
        let widthRatio = targetSize.width / self.size.width
        let heightRatio = targetSize.height / self.size.height
        let ratio = min(widthRatio, heightRatio)
        let newSize = CGSize(width: self.size.width * ratio, height: self.size.height * ratio)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
