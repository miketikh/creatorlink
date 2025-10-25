//
//  ProfileView.swift
//  CreatorLink
//
//  User profile view with editing and sign-out functionality
//

import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @State private var authService = AuthService.shared
    @State private var viewModel = ProfileViewModel()
    @State private var isSigningOut = false
    @State private var errorMessage: String?
    @State private var isEditingName = false
    @State private var isEditingPhoto = false
    @State private var editedDisplayName = ""
    @State private var editedPhotoURL = ""
    @State private var photoPreviewURL: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let user = authService.currentUser {
                        // Profile Photo Section
                        profilePhotoSection

                        // Display Name Section
                        displayNameSection

                        // Email Section (Read-only)
                        emailSection

                        // Online Status
                        onlineStatusSection

                        // AI Features Section
                        aiFeaturesSection

                        Spacer()

                        // Error Message
                        if let errorMessage = viewModel.errorMessage ?? errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding()
                        }

                        // Sign Out Button
                        Button(action: {
                            Task {
                                await signOut()
                            }
                        }) {
                            if isSigningOut {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else {
                                Text("Sign Out")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .foregroundColor(.white)
                            }
                        }
                        .background(Color.red)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .disabled(isSigningOut)
                    } else {
                        Text("No user signed in")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Profile")
            .overlay {
                if viewModel.isLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Saving...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(24)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 10)
                    }
                }
            }
            .task {
                viewModel.setupProfileListener()
                AnalyticsService.shared.trackScreenView(screenName: "Profile")
            }
            .onDisappear {
                viewModel.removeListener()
            }
        }
    }

    // MARK: - Subviews

    private var profilePhotoSection: some View {
        VStack(spacing: 12) {
            // Profile Photo - use preview URL during editing or actual URL
            let displayPhotoURL = photoPreviewURL ?? viewModel.userProfile?.photoURL
            if let photoURLString = displayPhotoURL, !photoURLString.isEmpty,
               let photoURL = URL(string: photoURLString) {
                AsyncImage(url: photoURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .onTapGesture {
                    // Initialize with current photo URL when starting to edit
                    editedPhotoURL = viewModel.userProfile?.photoURL ?? ""
                    isEditingPhoto.toggle()
                }
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                    )
                    .onTapGesture {
                        // Initialize with current photo URL when starting to edit
                        editedPhotoURL = viewModel.userProfile?.photoURL ?? ""
                        isEditingPhoto.toggle()
                    }
            }

            Text("Tap to edit photo")
                .font(.caption)
                .foregroundColor(.secondary)

            // Edit Photo URL Section
            if isEditingPhoto {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(spacing: 8) {
                        TextField("https://example.com/photo.jpg", text: $editedPhotoURL)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .keyboardType(.URL)
                            .onChange(of: editedPhotoURL) { _, newValue in
                                // Live preview of the photo URL
                                if !newValue.isEmpty {
                                    photoPreviewURL = newValue
                                } else {
                                    photoPreviewURL = nil
                                }
                            }

                        HStack(spacing: 12) {
                            Button("Cancel") {
                                isEditingPhoto = false
                                editedPhotoURL = ""
                                photoPreviewURL = nil
                            }
                            .foregroundColor(.secondary)

                            Spacer()

                            Button("Save") {
                                Task {
                                    await savePhotoURL()
                                }
                            }
                            .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var displayNameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Display Name")
                    .font(.headline)
                Spacer()
                if !isEditingName {
                    Button("Edit") {
                        editedDisplayName = viewModel.userProfile?.displayName ?? authService.currentUser?.displayName ?? ""
                        isEditingName = true
                    }
                    .font(.subheadline)
                }
            }

            if isEditingName {
                VStack(spacing: 8) {
                    TextField("Display Name", text: $editedDisplayName)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.words)

                    HStack(spacing: 12) {
                        Button("Cancel") {
                            isEditingName = false
                            editedDisplayName = ""
                        }
                        .foregroundColor(.secondary)

                        Spacer()

                        Button("Save") {
                            Task {
                                await saveDisplayName()
                            }
                        }
                        .fontWeight(.semibold)
                        .disabled(editedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .font(.subheadline)
                }
            } else {
                Text(viewModel.userProfile?.displayName ?? authService.currentUser?.displayName ?? "Unknown User")
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
    }

    private var emailSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Email")
                .font(.headline)

            Text(viewModel.userProfile?.email ?? authService.currentUser?.email ?? "")
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }

    private var onlineStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status")
                .font(.headline)

            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
                Text("Online")
                    .font(.body)
            }
            .foregroundColor(.primary)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }

    private var aiFeaturesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Features")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: Binding(
                    get: { viewModel.aiResponseModeEnabled },
                    set: { newValue in
                        Task {
                            do {
                                try await viewModel.updateAIResponseMode(enabled: newValue)
                            } catch {
                                // Error is shown via viewModel.errorMessage
                            }
                        }
                    }
                )) {
                    Text("AI Draft Responses")
                        .font(.body)
                }
                .tint(.indigo)

                Text("Automatically generate draft responses based on your communication style and knowledge")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Drafts appear in conversations when AI has enough context to respond")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }

    // MARK: - Methods

    private func saveDisplayName() async {
        do {
            try await viewModel.updateDisplayName(newName: editedDisplayName)
            isEditingName = false
            editedDisplayName = ""
        } catch {
            // Error is shown via viewModel.errorMessage
        }
    }

    private func savePhotoURL() async {
        do {
            try await viewModel.updatePhotoURL(newPhotoURL: editedPhotoURL)
            isEditingPhoto = false
            editedPhotoURL = ""
            photoPreviewURL = nil
        } catch {
            // Error is shown via viewModel.errorMessage
        }
    }

    private func signOut() async {
        isSigningOut = true
        errorMessage = nil

        do {
            try await authService.signOut()
        } catch {
            errorMessage = "Failed to sign out: \(error.localizedDescription)"
        }

        isSigningOut = false
    }
}

#Preview {
    ProfileView()
}
