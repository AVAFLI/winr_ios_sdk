//
//  WINRV2Claim.swift
//  WINRSDK
//
//  Winner prize-claim flow (Joe's stepped Figma design): winner splash →
//  4 form steps + review (WINRV2ClaimSteps/) → confirmation with the
//  OFFICIAL WINNER card. Shown when prizeClaim.status == "pending".
//  This file keeps the shared pieces: form model, photo/date helpers,
//  splash, confirmation, and the flow root.
//

import SwiftUI
import PhotosUI

// MARK: - Form model + validation

/// The claim form's field values. Kept as a plain value type so validation is
/// unit-testable without any view machinery.
struct WINRPrizeClaimForm {
    var firstName = ""
    var lastName = ""
    var phone = ""
    var street = ""
    var apt = ""
    var city = ""
    var state = ""
    var zip = ""
    /// Fixed — US-only sweepstakes.
    let country = "United States"
    /// JPEG base64 of the optional attached photo (already downscaled/capped).
    var photoBase64: String?
    /// Optional "please share a little" story (step 4). Sent trimmed; nil when empty.
    var story = ""

    /// Explicit consents (Joe's "review and agree" checkboxes). All three are
    /// REQUIRED — the likeness release in particular must be an affirmative
    /// user action for the publicity authorization to hold up.
    var confirmsAccuracy = false
    var authorizesLikeness = false
    var agreesToRules = false

    func trimmed(_ keyPath: KeyPath<WINRPrizeClaimForm, String>) -> String {
        self[keyPath: keyPath].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isValidZip(_ zip: String) -> Bool {
        let z = zip.trimmingCharacters(in: .whitespaces)
        return z.count == 5 && z.allSatisfy(\.isNumber)
    }

    // MARK: Per-step validity (stepped flow)

    /// Step 1 "TELL US ABOUT YOURSELF": first + last name (email is server-side,
    /// phone optional).
    var isStep1Valid: Bool {
        !trimmed(\.firstName).isEmpty && !trimmed(\.lastName).isEmpty
    }

    /// Step 2 "WHERE SHOULD WE SEND YOUR PRIZE?": full US shipping address.
    var isStep2Valid: Bool {
        !trimmed(\.street).isEmpty
            && !trimmed(\.city).isEmpty
            && !trimmed(\.state).isEmpty
            && Self.isValidZip(zip)
    }

    // Steps 3 (photo) and 4 (story) are fully optional — always advanceable.

    /// All three review-screen consents affirmed. The likeness release must be
    /// an affirmative user action for the publicity authorization to hold up.
    var hasAllConsents: Bool {
        confirmsAccuracy && authorizesLikeness && agreesToRules
    }

    /// SUBMIT enables when every required field across the steps is present,
    /// the zip is a 5-digit US code, and all three consents are affirmed.
    /// Phone, apartment, photo, and story are optional.
    var isValid: Bool {
        isStep1Valid && isStep2Valid && hasAllConsents
    }

    /// "First L." — the public display name on the winner card.
    var displayName: String {
        let first = trimmed(\.firstName)
        let lastInitial = trimmed(\.lastName).first.map { " \($0)." } ?? ""
        return "\(first)\(lastInitial)"
    }

    static let usStates = [
        "Alabama", "Alaska", "Arizona", "Arkansas", "California", "Colorado",
        "Connecticut", "Delaware", "Florida", "Georgia", "Hawaii", "Idaho",
        "Illinois", "Indiana", "Iowa", "Kansas", "Kentucky", "Louisiana",
        "Maine", "Maryland", "Massachusetts", "Michigan", "Minnesota",
        "Mississippi", "Missouri", "Montana", "Nebraska", "Nevada",
        "New Hampshire", "New Jersey", "New Mexico", "New York",
        "North Carolina", "North Dakota", "Ohio", "Oklahoma", "Oregon",
        "Pennsylvania", "Rhode Island", "South Carolina", "South Dakota",
        "Tennessee", "Texas", "Utah", "Vermont", "Virginia", "Washington",
        "West Virginia", "Wisconsin", "Wyoming",
    ]
}

// MARK: - Photo + date helpers

enum WINRClaimPhoto {
    static let maxBytes = 5 * 1024 * 1024

    /// Downscales so the long edge is ≤1200px, then JPEG-encodes, stepping the
    /// quality down until the payload fits the 5MB cap.
    static func base64Jpeg(from image: UIImage) -> String? {
        let scaled = downscaled(image, longEdge: 1200)
        var quality: CGFloat = 0.85
        var data = scaled.jpegData(compressionQuality: quality)
        while let d = data, d.count > maxBytes, quality > 0.25 {
            quality -= 0.15
            data = scaled.jpegData(compressionQuality: quality)
        }
        guard let d = data, d.count <= maxBytes else { return nil }
        return d.base64EncodedString()
    }

    static func downscaled(_ image: UIImage, longEdge: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > longEdge, longest > 0 else { return image }
        let scale = longEdge / longest
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

enum WINRClaimDates {
    /// "AUGUST, 2026" from an ISO date string (falls back to the current date)
    /// — the winner card's award line.
    static func monthYearDisplay(fromISO iso: String?, now: Date = Date()) -> String {
        let date = iso.flatMap(parseISO) ?? now
        let out = DateFormatter()
        out.dateFormat = "MMMM, yyyy"
        out.locale = Locale(identifier: "en_US_POSIX")
        return out.string(from: date).uppercased()
    }

    private static func parseISO(_ value: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFraction.date(from: value) { return d }
        let plain = ISO8601DateFormatter()
        if let d = plain.date(from: value) { return d }
        let dayOnly = DateFormatter()
        dayOnly.dateFormat = "yyyy-MM-dd"
        dayOnly.locale = Locale(identifier: "en_US_POSIX")
        return dayOnly.date(from: value)
    }
}

// MARK: - Flow root

struct WINRV2WinnerClaimFlow: View {
    @ObservedObject var viewModel: WINRExperienceViewModel
    let accent: Color
    let logoUrl: String?
    let claim: PrizeClaimBlock

    var body: some View {
        Group {
            switch viewModel.winnerClaimStep {
            case .splash:
                WINRV2WinnerSplashView(
                    accent: accent,
                    logoUrl: logoUrl,
                    prizeHeadline: WINRV2PrizeText.stripHeadline(
                        description: claim.prizeDescription,
                        value: Int(claim.prizeValue)
                    ),
                    onContinue: { viewModel.winnerClaimContinue() },
                    onClose: { viewModel.requestDismiss() }
                )
            case .form:
                WINRV2ClaimStepsFlow(
                    accent: accent,
                    logoUrl: logoUrl,
                    claim: claim,
                    viewModel: viewModel,
                    onClose: { viewModel.requestDismiss() }
                )
            case let .confirmation(claimNumber, submittedAt):
                WINRV2ClaimConfirmationView(
                    accent: accent,
                    logoUrl: logoUrl,
                    form: viewModel.submittedClaimForm,
                    claimNumber: claimNumber,
                    submittedAt: submittedAt,
                    onDone: { viewModel.requestDismiss() }
                )
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.winnerClaimStep)
    }
}

// MARK: - Shared chrome

/// Claim-flow header: publisher logo centered, X close only (no "?").
private struct WINRClaimHeader: View {
    let logoUrl: String?
    let onClose: () -> Void

    var body: some View {
        ZStack {
            logo
                .frame(height: 60)
                .frame(maxWidth: 210)
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image("winr-close", bundle: .module)
                        .resizable().scaledToFit()
                        .frame(width: 12, height: 12)
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(WINRV2Color.deepCharcoal))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder private var logo: some View {
        if let logoUrl, let url = URL(string: logoUrl) {
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFit()
                } else {
                    Color.clear
                }
            }
        } else {
            Text("WINR")
                .font(WINRV2Font.inter(28, .black))
                .foregroundColor(.white)
        }
    }
}

/// Dark info card with a leading icon (shield/mail) — splash + confirmation.
private struct WINRClaimInfoCard<Icon: View, Content: View>: View {
    @ViewBuilder let icon: Icon
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 14) {
            icon
            content
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
        )
        .padding(.horizontal, 22)
    }
}

// MARK: - Winner splash ("CONGRATULATIONS!")

struct WINRV2WinnerSplashView: View {
    let accent: Color
    let logoUrl: String?
    let prizeHeadline: String
    let onContinue: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            WINRV2Color.deepCharcoal

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    WINRClaimHeader(logoUrl: logoUrl, onClose: onClose)
                        .padding(.top, 18)

                    trophyArt
                        .padding(.top, 4)

                    Text("CONGRATULATIONS!")
                        .font(WINRV2Font.inter(34, .black))
                        .kerning(-1.0)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 20)
                        .padding(.top, 2)
                    Text("YOU’RE OUR LATEST WINNER!")
                        .font(WINRV2Font.inter(17, .black))
                        .kerning(-0.4)
                        .foregroundColor(accent)

                    Text("You’ve won:")
                        .font(WINRV2Font.inter(14))
                        .foregroundColor(.white)
                        .padding(.top, 18)
                        .padding(.bottom, 8)

                    // Full-width white strip with the prize-derived headline
                    // (same derivation as the Day-1 capture strip).
                    Text(prizeHeadline)
                        .font(WINRV2Font.inter(28, .black))
                        .kerning(-0.8)
                        .foregroundColor(WINRV2Color.gunmetal)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white)

                    Text("To process your prize, we just need a few details.")
                        .font(WINRV2Font.inter(15))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .padding(.top, 16)

                    WINRClaimInfoCard {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 26))
                            .foregroundColor(accent)
                    } content: {
                        Text("Your information is securely collected and only used to verify your prize and announce you as our winner.")
                            .font(WINRV2Font.inter(13))
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 14)

                    WINRV2PillButton(accent: accent, title: "CONTINUE") { onContinue() }
                        .padding(.horizontal, 30)
                        .padding(.top, 20)
                        .padding(.bottom, 30)
                }
            }
        }
    }

    /// Trophy over the gold-sparkle art (bundled winner-modal-bg + trophy).
    private var trophyArt: some View {
        ZStack {
            WINRV2Asset.winnerModalBg
                .resizable().scaledToFill()
                .frame(width: 300, height: 260)
                .clipped()
                .rotationEffect(.degrees(-2))
            WINRV2Asset.trophy
                .resizable().scaledToFit()
                .frame(height: 230)
        }
        .frame(height: 280)
    }
}

// MARK: - Confirmation ("YOUR PRIZE CLAIM HAS BEEN SUBMITTED")

struct WINRV2ClaimConfirmationView: View {
    let accent: Color
    let logoUrl: String?
    let form: WINRPrizeClaimForm?
    let claimNumber: String
    let submittedAt: String
    let onDone: () -> Void

    private enum Gold {
        static let text = Color(red: 0.72, green: 0.55, blue: 0.16)
        static let border = Color(red: 0.83, green: 0.68, blue: 0.28)
        static let creamTop = Color(red: 1.0, green: 0.98, blue: 0.92)
        static let creamBottom = Color(red: 0.95, green: 0.88, blue: 0.68)
    }

    var body: some View {
        ZStack {
            WINRV2Color.deepCharcoal

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    WINRClaimHeader(logoUrl: logoUrl, onClose: onDone)
                        .padding(.top, 18)

                    Text("YOUR PRIZE CLAIM HAS BEEN SUBMITTED")
                        .font(WINRV2Font.inter(26, .black))
                        .kerning(-0.7)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .padding(.top, 20)
                    Text("Our team is reviewing your information. You’ll receive a confirmation email shortly.")
                        .font(WINRV2Font.inter(15))
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 34)
                        .padding(.top, 8)

                    WINRClaimInfoCard {
                        Image("winr-mail", bundle: .module)
                            .resizable().scaledToFit()
                            .frame(width: 28, height: 22)
                            .foregroundColor(accent)
                    } content: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Expect to receive your prize within")
                                .font(WINRV2Font.inter(14))
                                .foregroundColor(.white)
                            Text("3-5 Business Days")
                                .font(WINRV2Font.inter(18, .black))
                                .foregroundColor(accent)
                        }
                    }
                    .padding(.top, 22)

                    winnerCard
                        .padding(.horizontal, 34)
                        .padding(.top, 40)

                    WINRV2PillButton(accent: accent, title: "RETURN TO APP") { onDone() }
                        .padding(.horizontal, 30)
                        .padding(.top, 30)
                        .padding(.bottom, 34)
                }
            }
        }
    }

    /// The gold OFFICIAL WINNER keepsake card: cream/gold gradient, small
    /// trophy breaking the top border, serif name, award month + claim number.
    private var winnerCard: some View {
        VStack(spacing: 4) {
            HStack {
                Text("OFFICIAL").kerning(0.5)
                Spacer()
                Text("WINNER").kerning(0.5)
            }
            .font(WINRV2Font.inter(16, .black))
            .foregroundColor(Gold.text)
            .padding(.horizontal, 26)
            .padding(.top, 18)

            Text(form?.displayName ?? "Our Winner")
                .font(.system(size: 30, weight: .black, design: .serif))
                .foregroundColor(Color(red: 0.1, green: 0.09, blue: 0.07))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 20)
                .padding(.top, 6)

            if let form, !form.trimmed(\.city).isEmpty {
                Text("\(form.trimmed(\.city)), \(form.trimmed(\.state))")
                    .font(WINRV2Font.inter(14))
                    .foregroundColor(Color(white: 0.45))
            }

            Text("\(WINRClaimDates.monthYearDisplay(fromISO: submittedAt)) • \(claimNumber)")
                .font(WINRV2Font.inter(11, .bold))
                .kerning(1.1)
                .foregroundColor(Gold.text)
                .padding(.top, 8)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [Gold.creamTop, Gold.creamBottom],
                        startPoint: .top, endPoint: .bottom
                    )
                )
        )
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Gold.border, lineWidth: 2))
        .overlay(alignment: .top) {
            // The little trophy sits centered ON the border, breaking it.
            WINRV2Asset.trophy
                .resizable().scaledToFit()
                .frame(height: 54)
                .offset(y: -27)
        }
    }
}

// MARK: - PHPicker wrapper

struct WINRPhotoPicker: UIViewControllerRepresentable {
    let onPick: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let controller = PHPickerViewController(configuration: config)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (UIImage?) -> Void
        init(onPick: @escaping (UIImage?) -> Void) { self.onPick = onPick }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                onPick(nil)
                return
            }
            provider.loadObject(ofClass: UIImage.self) { [onPick] object, _ in
                DispatchQueue.main.async {
                    onPick(object as? UIImage)
                }
            }
        }
    }
}
