import PhotosUI
import SwiftUI
import UIKit

struct ProfileView: View {
    @State private var session = SessionStore.shared
    @State private var strings = AppStrings.shared

    @State private var pickedPhoto: PhotosPickerItem?
    @State private var photoBase64: String?
    @State private var caregivers: [CaregiverItem] = []
    @State private var tickets: [SupportTicketItem] = []

    @State private var showAddCaregiver = false
    @State private var showFaq = false
    @State private var showSupportTicket = false
    @State private var showSubscriptions = false
    @State private var showTutorial = false
    @State private var showSignOutConfirm = false

    @State private var cgName = ""
    @State private var cgRel = ""
    @State private var cgPhone = ""
    @State private var ticketSubject = ""
    @State private var ticketMessage = ""

    private var avatarUIImage: UIImage? {
        guard let photoBase64, !photoBase64.isEmpty else { return nil }
        let pure = photoBase64.components(separatedBy: ",").last ?? photoBase64
        guard let data = Data(base64Encoded: pure) else { return nil }
        return UIImage(data: data)
    }

    var body: some View {
        let _ = strings.currentLanguage
        NavigationStack {
            List {
                // Avatar & Identity Section
                Section {
                    HStack(spacing: 14) {
                        if let uiImg = avatarUIImage {
                            Image(uiImage: uiImg)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 64)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(AppTheme.primaryNavy.opacity(0.14))
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Text(String((session.fullName.isEmpty ? "RG" : session.fullName).prefix(2)).uppercased())
                                        .font(.title3.bold())
                                        .foregroundStyle(AppTheme.primaryNavy)
                                )
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(session.fullName.isEmpty ? "Usuario RouteGuard" : session.fullName).font(.headline)
                            Text(session.email.isEmpty ? "parent@routeguard.pe" : session.email)
                                .font(.caption).foregroundStyle(.secondary)
                            Text(session.role.rawValue)
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(AppTheme.primaryNavy.opacity(0.1))
                                .foregroundStyle(AppTheme.primaryNavy)
                                .clipShape(Capsule())
                        }
                    }

                    PhotosPicker(selection: $pickedPhoto, matching: .images) {
                        Label(AppStrings.tr("profile_change_photo"), systemImage: "photo.on.rectangle.angled")
                    }
                    if photoBase64 != nil {
                        Button(AppStrings.tr("profile_remove_photo"), role: .destructive) {
                            photoBase64 = nil
                            Task { await RouteGuardRepository.shared.saveMyPhoto(nil) }
                        }
                    }
                }

                // Authorized Caregivers (Parent)
                if session.role == .parent {
                    Section(header: Text(AppStrings.tr("profile_caregivers_title"))) {
                        if caregivers.isEmpty {
                            Text(AppStrings.tr("profile_caregivers_empty")).font(.caption).foregroundStyle(.secondary)
                        } else {
                            ForEach(caregivers) { c in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(c.fullName).font(.subheadline.bold())
                                        Text("\(c.relationship) · \(c.phoneNumber)").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button(role: .destructive) {
                                        Task {
                                            await RouteGuardRepository.shared.deleteCaregiver(id: c.id)
                                            caregivers = await RouteGuardRepository.shared.getCaregivers()
                                        }
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                }
                            }
                        }
                        Button(AppStrings.tr("profile_caregiver_add")) { showAddCaregiver = true }
                    }
                }

                // Role Switcher + Theme + Language
                Section(header: Text(AppStrings.tr("profile_role_switcher"))) {
                    Picker("Rol", selection: Binding(
                        get: { session.role },
                        set: { session.switchRole($0) }
                    )) {
                        Text(AppStrings.tr("role_parent")).tag(UserRole.parent)
                        Text(AppStrings.tr("role_driver")).tag(UserRole.driver)
                        Text(AppStrings.tr("role_admin")).tag(UserRole.administrator)
                    }
                    .pickerStyle(.segmented)

                    Toggle(AppStrings.tr("profile_dark_mode"), isOn: Binding(
                        get: { session.isDarkMode },
                        set: { session.setDarkMode($0) }
                    ))

                    Picker(AppStrings.tr("profile_language"), selection: Binding(
                        get: { strings.currentLanguage },
                        set: { newLang in
                            strings.setLanguage(newLang)
                            Task { await RouteGuardRepository.shared.syncLanguage(newLang.rawValue) }
                        }
                    )) {
                        Text("ES").tag(AppLanguage.spanish)
                        Text("EN").tag(AppLanguage.english)
                    }
                    .pickerStyle(.segmented)
                }

                // Help & Support (US-18, US-23, US-25) & Subscription
                Section {
                    Button(AppStrings.tr("profile_tutorial_btn")) { showTutorial = true }
                    Button(AppStrings.tr("profile_faq_btn")) { showFaq = true }
                    Button(AppStrings.tr("profile_ticket_btn")) { showSupportTicket = true }
                    ForEach(tickets.prefix(3)) { t in
                        HStack {
                            Text(t.ticketCode).font(.caption.bold()).foregroundStyle(AppTheme.emerald)
                            Text(t.subject).font(.caption)
                        }
                    }
                    Button(AppStrings.tr("profile_subscription_btn")) { showSubscriptions = true }
                }

                Section {
                    Button(AppStrings.tr("profile_sign_out"), role: .destructive) {
                        showSignOutConfirm = true
                    }
                }
            }
            .navigationTitle(AppStrings.tr("profile_title"))
            .task {
                photoBase64 = await RouteGuardRepository.shared.loadMyPhoto()
                caregivers = await RouteGuardRepository.shared.getCaregivers()
                tickets = await RouteGuardRepository.shared.getSupportTickets()
            }
            .onChange(of: pickedPhoto) { _, item in
                Task {
                    guard let data = try? await item?.loadTransferable(type: Data.self) else { return }
                    let uri = "data:image/jpeg;base64,\(data.base64EncodedString())"
                    photoBase64 = uri
                    await RouteGuardRepository.shared.saveMyPhoto(uri)
                }
            }
            .alert(AppStrings.tr("profile_sign_out"), isPresented: $showSignOutConfirm) {
                Button(AppStrings.tr("common_cancel"), role: .cancel) {}
                Button(AppStrings.tr("profile_sign_out"), role: .destructive) {
                    session.clearSession()
                }
            } message: {
                Text(AppStrings.tr("profile_sign_out_msg"))
            }
            .sheet(isPresented: $showAddCaregiver) {
                NavigationStack {
                    Form {
                        TextField(AppStrings.tr("profile_caregiver_name"), text: $cgName)
                        TextField(AppStrings.tr("profile_caregiver_rel"), text: $cgRel)
                        TextField(AppStrings.tr("profile_caregiver_phone"), text: $cgPhone).keyboardType(.phonePad)
                        Button(AppStrings.tr("common_save")) {
                            guard !cgName.isEmpty else { return }
                            Task {
                                await RouteGuardRepository.shared.addCaregiver(fullName: cgName, relationship: cgRel, phone: cgPhone)
                                caregivers = await RouteGuardRepository.shared.getCaregivers()
                                cgName = ""; cgRel = ""; cgPhone = ""
                                showAddCaregiver = false
                            }
                        }
                    }
                    .navigationTitle(AppStrings.tr("profile_caregiver_add"))
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button(AppStrings.tr("common_cancel")) { showAddCaregiver = false } }
                    }
                }
            }
            .sheet(isPresented: $showFaq) {
                FaqHelpSheet()
            }
            .sheet(isPresented: $showSupportTicket) {
                NavigationStack {
                    Form {
                        TextField(AppStrings.tr("profile_ticket_subject"), text: $ticketSubject)
                        TextField(AppStrings.tr("profile_ticket_message"), text: $ticketMessage, axis: .vertical)
                        Button(AppStrings.tr("common_send")) {
                            guard !ticketSubject.isEmpty else { return }
                            Task {
                                let created = await RouteGuardRepository.shared.createSupportTicket(category: "GPS", subject: ticketSubject, message: ticketMessage)
                                tickets.insert(created, at: 0)
                                ticketSubject = ""; ticketMessage = ""
                                showSupportTicket = false
                            }
                        }
                    }
                    .navigationTitle(AppStrings.tr("profile_ticket_btn"))
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button(AppStrings.tr("common_cancel")) { showSupportTicket = false } }
                    }
                }
            }
            .sheet(isPresented: $showSubscriptions) { SubscriptionPlansSheet() }
            .sheet(isPresented: $showTutorial) {
                OnboardingTutorialSheet()
            }
        }
    }
}

private struct FaqHelpSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let faqs = [
        ("¿Cómo funciona el seguimiento GPS en vivo?", "La unidad transmite su ubicación cada pocos segundos durante la ruta escolar activa."),
        ("¿Qué sucede si no hay conexión a internet?", "La app guarda el progreso en SwiftData / SQLite y sincroniza automáticamente al reconectar."),
        ("¿Cómo reporto una ausencia temprana?", "Desde Seguimiento toca Reportar ausencia antes del horario de recojo."),
        ("¿Cómo verifico el SOAT y licencia?", "Presiona Ver / Verificar Docs en la tarjeta del vehículo para revisar vigencias."),
        ("¿Puedo autorizar a un familiar adicional?", "En Mi Perfil puedes agregar cuidadores autorizados para recibir notificaciones.")
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(faqs, id: \.0) { q, a in
                    DisclosureGroup(q) {
                        Text(a).font(.caption).foregroundStyle(.secondary).padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle(AppStrings.tr("profile_faq_btn"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(AppStrings.tr("common_close")) { dismiss() } }
            }
        }
    }
}

private struct OnboardingTutorialSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "bus.fill").font(.system(size: 56)).foregroundStyle(AppTheme.primaryNavy)
                Text("Asistente RouteGuard iOS").font(.title2.bold())
                Text("Monitorea el bus escolar en vivo, verifica documentos SOAT, reporta ausencias tempranas y chatea directamente con el conductor.")
                    .multilineTextAlignment(.center)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                Button(AppStrings.tr("common_close")) { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.primaryNavy)
            }
            .padding()
        }
    }
}
