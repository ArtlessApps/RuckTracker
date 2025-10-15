import SwiftUI

struct WatchWorkoutWeightSelector: View {
    @ObservedObject private var userSettings = UserSettings.shared
    @Binding var selectedWeight: Double
    @Environment(\.dismiss) private var dismiss
    let recommendedWeight: Double?
    let onStart: () -> Void
    
    init(
        selectedWeight: Binding<Double>,
        recommendedWeight: Double? = nil,
        onStart: @escaping () -> Void
    ) {
        self._selectedWeight = selectedWeight
        self.recommendedWeight = recommendedWeight
        self.onStart = onStart
        
        // Initialize with recommended or default
        if selectedWeight.wrappedValue == 0 {
            selectedWeight.wrappedValue = recommendedWeight ?? UserSettings.shared.defaultRuckWeight
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Ruck Weight")
                .font(.headline)
            
            // Recommended hint
            if let recommended = recommendedWeight {
                Text("Rec: \(Int(recommended)) lbs")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            // Weight display
            Text("\(Int(selectedWeight)) lbs")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.blue)
            
            // Picker
            Picker("Weight", selection: $selectedWeight) {
                ForEach(weightOptions, id: \.self) { weight in
                    Text("\(Int(weight))").tag(weight)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 80)
            
            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.bordered)
                
                Button("Start") {
                    onStart()
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
    
    private var weightOptions: [Double] {
        Array(stride(from: 5.0, through: 100.0, by: 5.0))
    }
}
