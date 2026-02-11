// WorkoutWeightSelector.swift
// Premium weight selector matching the workout view aesthetic
import SwiftUI

struct WorkoutWeightSelector: View {
    @ObservedObject private var userSettings = UserSettings.shared
    @Binding var selectedWeight: Double
    @Binding var isPresented: Bool
    let recommendedWeight: Double?
    let context: String
    let subtitle: String?
    let instructions: String?
    let onStart: () -> Void
    
    @State private var showingGuidelines = false
    
    init(
        selectedWeight: Binding<Double>,
        isPresented: Binding<Bool>,
        recommendedWeight: Double? = nil,
        context: String = "Free Ruck",
        subtitle: String? = nil,
        instructions: String? = nil,
        onStart: @escaping () -> Void
    ) {
        self._selectedWeight = selectedWeight
        self._isPresented = isPresented
        self.recommendedWeight = recommendedWeight
        self.context = context
        self.subtitle = subtitle
        self.instructions = instructions
        self.onStart = onStart
        
        // Initialize with recommended weight if available
        if selectedWeight.wrappedValue == 0 {
            selectedWeight.wrappedValue = recommendedWeight ?? UserSettings.shared.defaultRuckWeight
        }
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            AppColors.backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top section with context
                VStack(spacing: 4) {
                    Text(context)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .padding(.top, 60)
                .padding(.bottom, 24)
                
                HStack {
                    Spacer()
                    
                    Text("Set Ruck Weight")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(AppColors.textSecondary)
                    
                    Spacer()
                    
                    Button {
                        showingGuidelines = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 18))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.trailing, 24)
                }
                .padding(.bottom, 20)
                
                // HERO - Selected Weight
                (Text("\(Int(selectedWeight))")
                    .font(.system(size: 100, weight: .medium))
                 + Text(" lbs")
                    .font(.system(size: 36, weight: .regular)))
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                    .frame(height: 60)
                
                // Slider
                VStack(spacing: 16) {
                    Slider(value: $selectedWeight, in: 0...100, step: 1)
                        .tint(AppColors.primary)
                    
                    HStack {
                        Text("0 lbs")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(AppColors.textSecondary)
                        
                        Spacer()
                        
                        Text("100 lbs")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer()
                    .frame(minHeight: 20)
                
                // Instructions (if provided)
                if let instructions = instructions {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "list.bullet.clipboard")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.primary)
                            
                            Text("Instructions")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppColors.textPrimary)
                        }
                        
                        Text(instructions)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(AppColors.textSecondary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.surfaceAlt.opacity(0.5))
                    )
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 16) {
                    // Cancel Button
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("Cancel")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(AppColors.overlayWhite)
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
                                .fill(AppColors.primary)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showingGuidelines) {
            RuckingGuidelinesSheet()
        }
    }
}

// MARK: - Rucking Guidelines Sheet
struct RuckingGuidelinesSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rucking Guidelines")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(AppColors.textOnLight)
                        
                        Text("Safe weight recommendations based on experience level")
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.top, 8)
                    
                    // Guidelines
                    VStack(spacing: 16) {
                        GuidelineRow(
                            title: "Beginner",
                            weight: "10-15% body weight",
                            description: "Start light and focus on form",
                            color: AppColors.accentGreen
                        )
                        
                        GuidelineRow(
                            title: "Intermediate",
                            weight: "15-20% body weight",
                            description: "Build endurance and distance",
                            color: AppColors.primary
                        )
                        
                        GuidelineRow(
                            title: "Advanced",
                            weight: "20-25% body weight",
                            description: "Experienced ruckers only",
                            color: .orange
                        )
                        
                        GuidelineRow(
                            title: "Military Standard",
                            weight: "35+ lbs",
                            description: "Tactical and event training",
                            color: .red
                        )
                    }
                    
                    // Safety Note
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 16))
                            Text("Important")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        
                        Text("Always start lighter than you think you need. Gradually increase weight as your body adapts. Listen to your body and prioritize proper form over heavier loads.")
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.orange.opacity(0.1))
                    )
                }
                .padding(24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
        }
    }
}

// MARK: - Guideline Row
struct GuidelineRow: View {
    let title: String
    let weight: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Color indicator
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .padding(.top, 4)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppColors.textOnLight)
                    
                    Spacer()
                    
                    Text(weight)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(color)
                }
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.05))
        )
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
