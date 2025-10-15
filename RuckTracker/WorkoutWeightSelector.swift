import SwiftUI

struct WorkoutWeightSelector: View {
    @ObservedObject private var userSettings = UserSettings.shared
    @Binding var selectedWeight: Double
    @Binding var isPresented: Bool
    let recommendedWeight: Double?  // Optional - from program/challenge
    let context: String  // "Free Ruck", "Program Workout", "Challenge Day X"
    let onStart: () -> Void
    
    init(
        selectedWeight: Binding<Double>,
        isPresented: Binding<Bool>,
        recommendedWeight: Double? = nil,
        context: String = "Free Ruck",
        onStart: @escaping () -> Void
    ) {
        self._selectedWeight = selectedWeight
        self._isPresented = isPresented
        self.recommendedWeight = recommendedWeight
        self.context = context
        self.onStart = onStart
        
        // Initialize with recommended weight if available, otherwise use default
        if selectedWeight.wrappedValue == 0 {
            selectedWeight.wrappedValue = recommendedWeight ?? UserSettings.shared.defaultRuckWeight
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Context header
                VStack(spacing: 8) {
                    Text(context)
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Set Ruck Weight")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .padding(.top)
                
                // Recommended weight hint (if available and different from selected)
                if let recommended = recommendedWeight, recommended != selectedWeight {
                    Button(action: {
                        selectedWeight = recommended
                    }) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                            Text("Recommended: \(Int(recommended)) lbs")
                            Spacer()
                            Text("Use")
                                .fontWeight(.semibold)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
                
                // Weight display
                Text("\(Int(selectedWeight)) lbs")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(.blue)
                    .padding(.vertical)
                
                // Slider
                VStack(spacing: 8) {
                    Slider(value: $selectedWeight, in: 5...100, step: 5)
                        .accentColor(.blue)
                    
                    HStack {
                        Text("5 lbs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("100 lbs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                // Quick weight buttons
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Select")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach([10, 15, 20, 25, 30, 35, 40, 45], id: \.self) { weight in
                            Button(action: {
                                selectedWeight = Double(weight)
                            }) {
                                Text("\(weight)")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(selectedWeight == Double(weight) ? .white : .blue)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedWeight == Double(weight) ? Color.blue : Color.blue.opacity(0.1))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                    
                    Button(action: {
                        onStart()
                        isPresented = false
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start Workout")
                        }
                        .font(.headline)
                        .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    WorkoutWeightSelector(
        selectedWeight: .constant(20),
        isPresented: .constant(true),
        recommendedWeight: 25,
        context: "GORUCK Selection - Week 1",
        onStart: { print("Start workout") }
    )
}
