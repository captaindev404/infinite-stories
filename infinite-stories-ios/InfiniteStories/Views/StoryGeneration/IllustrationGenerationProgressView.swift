//
//  IllustrationGenerationProgressView.swift
//  InfiniteStories
//
//  Created by Captain Dev on 17/09/2025.
//

import SwiftUI
import SwiftData

struct IllustrationGenerationProgressView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: StoryViewModel
    let story: Story

    @State private var showPreview = false
    @State private var completedIllustrations: [StoryIllustration] = []

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 15) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 100, height: 100)

                        Image(systemName: "photo.artframe")
                            .font(.system(size: 45))
                            .foregroundColor(.white)
                    }
                    .rotationEffect(.degrees(viewModel.isGeneratingIllustrations ? 0 : 360))
                    .animation(
                        viewModel.isGeneratingIllustrations ?
                        Animation.linear(duration: 3).repeatForever(autoreverses: false) : .default,
                        value: viewModel.isGeneratingIllustrations
                    )

                    Text("story.illustration.progress.title")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(String(localized: "story.illustration.progress.subtitle", defaultValue: "For \"\(story.title)\""))
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Progress
                VStack(spacing: 15) {
                    if viewModel.isGeneratingIllustrations {
                        // Progress indicator
                        VStack(spacing: 10) {
                            ProgressView(value: viewModel.illustrationGenerationProgress) {
                                Text(String(localized: "story.illustration.progress.percent", defaultValue: "\(Int(viewModel.illustrationGenerationProgress * 100))% Complete"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .progressViewStyle(.linear)

                            Text(viewModel.illustrationGenerationStage)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal)

                        // Illustration count
                        let generatedCount = story.illustrations.filter { $0.isGenerated }.count
                        let totalCount = story.illustrations.count

                        if totalCount > 0 {
                            HStack(spacing: 5) {
                                ForEach(0..<totalCount, id: \.self) { index in
                                    Circle()
                                        .fill(index < generatedCount ? Color.purple : Color.gray.opacity(0.3))
                                        .frame(width: 12, height: 12)
                                }
                            }

                            Text(String(localized: "story.illustration.progress.count", defaultValue: "\(generatedCount) of \(totalCount) illustrations generated"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        // Completion state
                        VStack(spacing: 15) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.green)

                            Text("story.illustration.progress.complete")
                                .font(.title3)
                                .fontWeight(.semibold)

                            let successCount = story.illustrations.filter { $0.isGenerated }.count
                            let totalCount = story.illustrations.count

                            Text(String(localized: "story.illustration.progress.success", defaultValue: "\(successCount) of \(totalCount) illustrations created successfully"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            // Preview thumbnails
                            if successCount > 0 {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(story.sortedIllustrations.filter { $0.isGenerated }.prefix(4)) { illustration in
                                            if let image = loadThumbnail(for: illustration) {
                                                Image(uiImage: image)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 80, height: 80)
                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                            }
                                        }

                                        if successCount > 4 {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(Color.gray.opacity(0.3))
                                                    .frame(width: 80, height: 80)

                                                Text("+\(successCount - 4)")
                                                    .font(.headline)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                }

                // Errors
                if !viewModel.illustrationErrors.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("story.illustration.progress.error.title")
                                .font(.caption)
                                .fontWeight(.medium)
                        }

                        ForEach(Array(viewModel.illustrationErrors.prefix(3).enumerated()), id: \.offset) { index, error in
                            Text("• \(error)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }

                Spacer()

                // Actions
                VStack(spacing: 15) {
                    if !viewModel.isGeneratingIllustrations {
                        Button(action: {
                            showPreview = true
                        }) {
                            Label("story.illustration.progress.button.view", systemImage: "book.fill")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .cornerRadius(12)
                        }

                        Button(action: {
                            dismiss()
                        }) {
                            Text("common.done")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray5))
                                .cornerRadius(12)
                        }
                    } else {
                        Button(action: {
                            viewModel.cancelIllustrationGeneration()
                            dismiss()
                        }) {
                            Text("story.illustration.progress.button.skip")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showPreview) {
                // This would show the audio player view with illustrations
                if let audioFileName = story.audioFileName {
                    AudioPlayerView(story: story)
                        .glassSheet()
                }
            }
        }
    }

    private func loadThumbnail(for illustration: StoryIllustration) -> UIImage? {
        guard let url = illustration.imageURL,
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return nil
        }

        // Create thumbnail
        let size = CGSize(width: 160, height: 160) // 2x for retina
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return thumbnail
    }
}

struct FailedIllustrationRow: View {
    let illustration: StoryIllustration
    let onRetry: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)

            VStack(alignment: .leading) {
                Text(String(localized: "story.illustration.progress.error.number", defaultValue: "Illustration #\(illustration.displayOrder + 1)"))
                    .font(.caption)
                    .fontWeight(.medium)

                Text("story.illustration.progress.error.failed")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("common.retry") {
                onRetry()
            }
            .font(.caption)
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let story = Story(
        title: "Luna's Magical Adventure",
        content: "Once upon a time in a magical forest...",
        event: .bedtime,
        hero: Hero(name: "Luna", primaryTrait: .brave, secondaryTrait: .magical)
    )
    IllustrationGenerationProgressView(viewModel: StoryViewModel(), story: story)
}