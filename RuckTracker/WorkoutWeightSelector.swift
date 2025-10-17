
// WorkoutWeightSelector.swift
// Premium weight selector matching the workout view aesthetic
import SwiftUI

struct WorkoutWeightSelector: View {
    @ObservedObject private var userSettings = UserSettings.shared
    @Binding var selectedWeight: Double
    @Binding var isPresented: Bool
    let recommendedWeight: Double?
    let context: String
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
        
        // Initialize with recommended weight if available
        if selectedWeight.wrappedValue == 0 {
            selectedWeight.wrappedValue = recommendedWeight ?? UserSettings.shared.defaultRuckWeight
        }
    }
    
    var body: some View {
        ZStack {
            // Clean white background
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top section with context
                VStack(spacing: 8) {
                    Text(context)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color("TextSecondary"))
                    
                    Text("Set Ruck Weight")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color("BackgroundDark"))
                }
                .padding(.top, 60)
                .padding(.bottom, 40)
                
                // HERO - Selected Weight
                Text("\(Int(selectedWeight))")
                    .font(.system(size: 100, weight: .medium))
                    .foregroundColor(Color("BackgroundDark"))
                + Text(" lbs")
                    .font(.system(size: 36, weight: .regular))
                    .foregroundColor(Color("BackgroundDark"))
                
                Spacer()
                    .frame(height: 60)
                
                // Slider
                VStack(spacing: 16) {
                    Slider(value: $selectedWeight, in: 0...100, step: 1)
                        .tint(Color("BackgroundDark"))
                    
                    HStack {
                        Text("0 lbs")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(Color("TextSecondary"))
                        
                        Spacer()
                        
                        Text("100 lbs")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(Color("TextSecondary"))
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 16) {
                    // Cancel Button
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("Cancel")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color("BackgroundDark"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color("BackgroundDark").opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)
                    
                    // Start Button
                    Button(action: {
                        onStart()
                        isPresented = false
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 16))
                            Text("Start Workout")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color("PrimaryMain"))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    WorkoutWeightSelector(
        selectedWeight: .constant(20),
        isPresented: .constant(true),
        recommendedWeight: 25,
        context: "Free Ruck",
        onStart: { print("Start workout") }
    )
}
