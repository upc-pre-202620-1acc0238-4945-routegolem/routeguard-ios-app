import SwiftUI

struct LoginView: View {
    @State private var strings = AppStrings.shared
    @State private var email = "parent@routeguard.pe"
    @State private var password = "parent123"
    @State private var showPassword = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var showForgotSheet = false
    @State private var showRegisterSheet = false
    @State private var bannerMessage: String?

    var body: some View {
        let _ = strings.currentLanguage
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header branding
                    VStack(spacing: 8) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 54))
                            .foregroundStyle(AppTheme.primaryNavy)
                            .padding(.top, 18)
                        Text(AppStrings.tr("app_title"))
                            .font(.largeTitle.bold())
                            .foregroundStyle(AppTheme.primaryNavy)
                        Text(AppStrings.tr("login_portal_subtitle"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Quick demo role chips
                    VStack(alignment: .leading, spacing: 10) {
                        Text(AppStrings.tr("login_demo_title"))
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.primaryNavy)
                        HStack(spacing: 8) {
                            demoChip(AppStrings.tr("role_parent"), email: "parent@routeguard.pe", pass: "parent123", id: "demo_parent")
                            demoChip(AppStrings.tr("role_driver"), email: "driver@routeguard.pe", pass: "driver123", id: "demo_driver")
                            demoChip(AppStrings.tr("role_admin"), email: "admin@routeguard.pe", pass: "admin123", id: "demo_admin")
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.primaryNavy.opacity(0.06))
                    .clipShape(RoundedRectangleBorderShape(radius: 16))

                    if let banner = bannerMessage {
                        Text(banner)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(AppTheme.emerald)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Sign In Card
                    VStack(alignment: .leading, spacing: 14) {
                        Text(AppStrings.tr("login_heading"))
                            .font(.title3.bold())
                            .foregroundStyle(AppTheme.primaryNavy)

                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(AppTheme.errorRed)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppTheme.errorRed.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        TextField(AppStrings.tr("login_email_label"), text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .accessibilityIdentifier("login_email_field")

                        HStack {
                            if showPassword {
                                TextField(AppStrings.tr("login_password_label"), text: $password)
                            } else {
                                SecureField(AppStrings.tr("login_password_label"), text: $password)
                            }
                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .accessibilityIdentifier("login_password_field")

                        HStack {
                            Spacer()
                            Button(AppStrings.tr("login_forgot_btn")) {
                                showForgotSheet = true
                            }
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.primaryNavy)
                        }

                        Button {
                            Task { await performSignIn() }
                        } label: {
                            Group {
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(AppStrings.tr("login_signin_btn")).bold()
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.primaryNavy)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isLoading)
                        .accessibilityIdentifier("login_signin_button")

                        Button(AppStrings.tr("login_create_account_btn")) {
                            showRegisterSheet = true
                        }
                        .font(.footnote.bold())
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(AppTheme.primaryTeal)
                    }
                    .padding(18)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
                }
                .padding(18)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showForgotSheet) {
                ForgotPasswordSheet(initialEmail: email) { msg in
                    bannerMessage = msg
                }
            }
            .sheet(isPresented: $showRegisterSheet) {
                RegisterAccountSheet()
            }
        }
    }

    private func demoChip(_ title: String, email: String, pass: String, id: String) -> some View {
        Button {
            self.email = email
            self.password = pass
            self.errorMessage = nil
        } label: {
            Text(title)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .foregroundStyle(AppTheme.primaryNavy)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppTheme.primaryNavy.opacity(0.25), lineWidth: 1))
        }
        .accessibilityIdentifier(id)
    }

    private func performSignIn() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let account = try await RouteGuardRepository.shared.signIn(email: email, password: password)
            SessionStore.shared.saveSession(
                token: account.token,
                userId: account.id,
                fullName: account.fullName,
                email: account.email,
                role: UserRole.normalize(account.role),
                organizationId: account.organizationId
            )
            if let lang = account.preferredLanguage, !lang.isEmpty {
                AppStrings.shared.setLanguage(lang.lowercased().hasPrefix("en") ? .english : .spanish)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct RoundedRectangleBorderShape: InsettableShape {
    let radius: CGFloat
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        RoundedRectangle(cornerRadius: radius).path(in: rect.insetBy(dx: insetAmount, dy: insetAmount))
    }

    func inset(by amount: CGFloat) -> RoundedRectangleBorderShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

struct ForgotPasswordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email: String
    @State private var showResetCodeFields = false
    @State private var resetCode = ""
    @State private var newPassword = ""
    @State private var feedback: String?
    let onCompleted: (String) -> Void

    init(initialEmail: String, onCompleted: @escaping (String) -> Void) {
        _email = State(initialValue: initialEmail)
        self.onCompleted = onCompleted
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(AppStrings.tr("login_forgot_title"))) {
                    Text(AppStrings.tr("login_forgot_msg"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(AppStrings.tr("login_email_label"), text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    Button(AppStrings.tr("login_forgot_send")) {
                        Task {
                            let devCode = await RouteGuardRepository.shared.requestPasswordReset(email: email)
                            if let devCode { resetCode = devCode }
                            showResetCodeFields = true
                            feedback = AppStrings.trf("login_forgot_sent", ["email": email])
                        }
                    }
                    .foregroundStyle(AppTheme.primaryNavy)
                }

                if showResetCodeFields || feedback != nil {
                    Section(header: Text(AppStrings.tr("login_have_code_btn"))) {
                        if let feedback {
                            Text(feedback).font(.caption.bold()).foregroundStyle(AppTheme.emerald)
                        }
                        TextField(AppStrings.tr("login_reset_code_label"), text: $resetCode)
                        SecureField(AppStrings.tr("login_reset_new_pass"), text: $newPassword)
                        Button(AppStrings.tr("login_reset_confirm")) {
                            Task {
                                let ok = await RouteGuardRepository.shared.confirmPasswordReset(email: email, code: resetCode, newPassword: newPassword)
                                if ok {
                                    onCompleted(AppStrings.tr("login_reset_ok"))
                                    dismiss()
                                } else {
                                    feedback = AppStrings.tr("login_reset_err")
                                }
                            }
                        }
                    }
                } else {
                    Button(AppStrings.tr("login_have_code_btn")) {
                        showResetCodeFields = true
                    }
                }
            }
            .navigationTitle(AppStrings.tr("login_forgot_title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppStrings.tr("common_close")) { dismiss() }
                }
            }
        }
    }
}

struct RegisterAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var role: UserRole = .parent

    var body: some View {
        NavigationStack {
            Form {
                TextField(AppStrings.tr("login_fullname_label"), text: $fullName)
                TextField(AppStrings.tr("login_email_label"), text: $email)
                    .textInputAutocapitalization(.never)
                SecureField(AppStrings.tr("login_password_label"), text: $password)
                Picker("Rol", selection: $role) {
                    Text(AppStrings.tr("role_parent")).tag(UserRole.parent)
                    Text(AppStrings.tr("role_driver")).tag(UserRole.driver)
                    Text(AppStrings.tr("role_admin")).tag(UserRole.administrator)
                }
                Button(AppStrings.tr("login_create_account_btn")) {
                    guard !fullName.trimmingCharacters(in: .whitespaces).isEmpty,
                          email.contains("@"),
                          password.count >= 6 else { return }
                    SessionStore.shared.saveSession(
                        token: "ios_local_\(role.rawValue.lowercased())",
                        userId: UUID().uuidString,
                        fullName: fullName.trimmingCharacters(in: .whitespaces),
                        email: email.trimmingCharacters(in: .whitespaces),
                        role: role,
                        organizationId: "org_school_01"
                    )
                    dismiss()
                }
                .foregroundStyle(AppTheme.primaryNavy)
            }
            .navigationTitle(AppStrings.tr("login_register_title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppStrings.tr("common_cancel")) { dismiss() }
                }
            }
        }
    }
}
