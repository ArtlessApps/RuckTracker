import SwiftUI

struct PlanView: View {
    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                Text("Your scheduled workouts will appear here.")
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
            }
            .navigationTitle("My Training Plan")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Switch Goal") { }
                }
            }
        }
    }
}

#Preview {
    PlanView()
}

