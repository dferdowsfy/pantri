import SwiftUI

struct SignUpView: View {
    @Bindable var vm: AuthViewModel
    var onSwitchToLogin: () -> Void

    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case email, password, confirm }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 40)

                // Logo
                Image(systemName: "leaf.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.pantriGreen)

                Text("Create Account")
                    .font(.title.bold())
                    .foregroundStyle(Color.pantriText)

                Text("Start tracking your pantry today")
                    .font(.subheadline)
                    .foregroundStyle(Color.pantriSecondaryText)

                // Fields
                VStack(spacing: 14) {
                    AuthTextField(
                        icon: "envelope.fill",
                        placeholder: "Email",
                        text: $vm.email,
                        keyboardType: .emailAddress
                    )
                    .focused($focusedField, equals: .email)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }

                    AuthSecureField(
                        icon: "lock.fill",
                        placeholder: "Password",
                        text: $vm.password
                    )
                    .focused($focusedField, equals: .password)
                    .textContentType(.newPassword)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .confirm }

                    AuthSecureField(
                        icon: "lock.fill",
                        placeholder: "Confirm Password",
                        text: $vm.confirmPassword
                    )
                    .focused($focusedField, equals: .confirm)
                    .textContentType(.newPassword)
                    .submitLabel(.go)
                    .onSubmit { Task { await vm.signUp() } }
                }

                // Password mismatch hint
                if !vm.confirmPassword.isEmpty && vm.password != vm.confirmPassword {
                    Text("Passwords don't match")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .transition(.opacity)
                }

                // Error
                if let err = vm.errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }

                // Sign Up button
                Button {
                    focusedField = nil
                    Task { await vm.signUp() }
                } label: {
                    Group {
                        if vm.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Create Account")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.pantriGreen)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .disabled(!vm.isSignUpValid || vm.isLoading)

                Spacer()

                // Switch to Login
                HStack(spacing: 4) {
                    Text("Already have an account?")
                        .foregroundStyle(Color.pantriSecondaryText)
                    Button("Sign In") { onSwitchToLogin() }
                        .foregroundStyle(Color.pantriGreen)
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 28)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.pantriBackground.ignoresSafeArea())
    }
}
