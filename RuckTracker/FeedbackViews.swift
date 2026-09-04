
// FeedbackViews.swift
// Sentiment gate and in-app feedback form for unhappy users.

import SwiftUI

// MARK: - Sentiment Gate

struct SentimentGateView: View {
    @ObservedObject private var reviewManager = ReviewManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppColors.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "figure.walk")
                    .font(.system(size: 48))
                    .foregroundColor(AppColors.primary)

                VStack(spacing: 12) {
                    Text("Enjoying MARCH?")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)

                    Text("Your feedback helps us build a better rucking community.")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                VStack(spacing: 12) {
                    Button(action: {
                        reviewManager.userEnjoyingApp()
                        dismiss()
                    }) {
                        Text("Yes, loving it")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppColors.primary)
                            .foregroundColor(AppColors.textOnLight)
                            .cornerRadius(12)
                    }

                    Button(action: {
                        reviewManager.userNotEnjoyingApp()
                        dismiss()
                    }) {
                        Text("Not really")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppColors.surface)
                            .foregroundColor(AppColors.textPrimary)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppColors.textSecondary.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Feedback Form

enum FeedbackCategory: String, CaseIterable, Identifiable {
    case bug = "bug"
    case sync = "sync"
    case billing = "billing"
    case community = "community"
    case suggestion = "suggestion"
    case other = "other"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bug: return "Bug"
        case .sync: return "Sync / Data"
        case .billing: return "Billing"
        case .community: return "Clubs & Events"
        case .suggestion: return "Suggestion"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .bug: return "ladybug"
        case .sync: return "arrow.triangle.2.circlepath"
        case .billing: return "creditcard"
        case .community: return "person.3"
        case .suggestion: return "lightbulb"
        case .other: return "ellipsis.circle"
        }
    }
}

struct FeedbackView: View {
    let source: FeedbackSource

    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: FeedbackCategory = .other
    @State private var message = ""
    @State private var isSubmitting = false
    @State private var didSubmit = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundGradient
                    .ignoresSafeArea()

                if didSubmit {
                    successContent
                } else {
                    formContent
                }
            }
            .navigationTitle("Send Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(didSubmit ? "Done" : "Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.textPrimary)
                    .disabled(isSubmitting)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var formContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("We'll open your email app with a pre-filled message to hello@artless.app.")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)

                VStack(alignment: .leading, spacing: 12) {
                    Text("CATEGORY")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textSecondary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(FeedbackCategory.allCases) { category in
                            categoryButton(category)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("MESSAGE")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textSecondary)

                    TextEditor(text: $message)
                        .frame(minHeight: 140)
                        .padding(12)
                        .background(AppColors.surface)
                        .cornerRadius(12)
                        .foregroundColor(AppColors.textPrimary)
                        .scrollContentBackground(.hidden)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Button(action: submitFeedback) {
                    Group {
                        if isSubmitting {
                            ProgressView()
                                .tint(AppColors.textOnLight)
                        } else {
                            Text("Send Feedback")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canSubmit ? AppColors.primary : AppColors.surface)
                    .foregroundColor(canSubmit ? AppColors.textOnLight : AppColors.textSecondary)
                    .cornerRadius(12)
                }
                .disabled(!canSubmit)
            }
            .padding(20)
        }
    }

    private var successContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(AppColors.primary)

            Text("Thanks for your feedback")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)

            Text("Send the email when you're ready. We read every message and usually reply within 48 hours.")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding()
    }

    private func categoryButton(_ category: FeedbackCategory) -> some View {
        let isSelected = selectedCategory == category
        return Button(action: { selectedCategory = category }) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.caption)
                Text(category.label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? AppColors.primary.opacity(0.2) : AppColors.surface)
            .foregroundColor(isSelected ? AppColors.primary : AppColors.textPrimary)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? AppColors.primary : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func submitFeedback() {
        isSubmitting = true
        errorMessage = nil

        let sent = FeedbackMailer.send(
            category: selectedCategory.rawValue,
            message: message.trimmingCharacters(in: .whitespacesAndNewlines),
            source: source.rawValue
        )

        isSubmitting = false
        if sent {
            didSubmit = true
        } else {
            errorMessage = "Couldn't open your email app. Email us at hello@artless.app"
        }
    }
}
