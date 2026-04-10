import SwiftUI

struct LoginView: View {
    @Bindable var vm: AuthViewModel
    var onSwitchToSignUp: () -> Void

    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 40)

                // Logo
                Image(systemName: "leaf.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.pantriGreen)

                Text("Welcome back")
                    .font(.title.bold())
                    .foregroundStyle(Color.pantriText)

                Text("Sign in to your Pantri account")
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
                    .textContentType(.password)
                    .submitLabel(.go)
                    .onSubmit { Task { await vm.signIn() } }
                }

                // Error
                if let err = vm.errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }

                // Sign In button
                Button {
                    focusedField = nil
                    Task { await vm.signIn() }
                } label: {
                    Group {
                        if vm.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Sign In")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.pantriGreen)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .disabled(!vm.isLoginValid || vm.isLoading)

                // Forgot password
                Button("Forgot password?") {
                    vm.resetEmail = vm.email
                    vm.showResetAlert = true
                }
                .font(.footnote)
                .foregroundStyle(Color.pantriGreen)

                Spacer()

                // Switch to Sign Up
                HStack(spacing: 4) {
                    Text("Don't have an account?")
                        .foregroundStyle(Color.pantriSecondaryText)
                    Button("Sign Up") { onSwitchToSignUp() }
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
        .alert("Reset Password", isPresented: $vm.showResetAlert) {
            TextField("Email", text: $vm.resetEmail)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
            Button("Send Link") { Task { await vm.sendPasswordReset() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("We'll send a password reset link to your email.")
        }
    }
}
