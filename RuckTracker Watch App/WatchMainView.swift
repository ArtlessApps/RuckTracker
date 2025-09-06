import SwiftUI

struct WatchMainView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // App Title
                Text("RuckTracker")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                // Current Weight Display
                VStack(spacing: 8) {
                    Text("Ruck Weight")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 4) {
                        Text("\(Int(workoutManager.ruckWeight))")
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text("LBS")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Text("Use Digital Crown to adjust")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                // Start Workout Button
                NavigationLink(destination: WorkoutView()) {
                    HStack {
                        Image(systemName: "figure.hiking")
                            .font(.title2)
                        Text("Start Rucking")
                            .font(.headline)
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .cornerRadius(25)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
            .padding()
            .background(Color.black)
            .focusable()
            .digitalCrownRotation(
                $workoutManager.ruckWeight,
                from: 0,
                through: 100,
                by: 1,
                sensitivity: .medium,
                isContinuous: false
            )
        }
        .navigationBarHidden(true)
    }
}

#Preview {
    WatchMainView()
}
