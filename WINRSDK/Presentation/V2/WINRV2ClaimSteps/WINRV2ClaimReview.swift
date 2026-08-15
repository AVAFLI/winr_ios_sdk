//
//  WINRV2ClaimReview.swift
//  WINRSDK
//
//  Review screen — "ALMOST DONE!" (2.9): ONE optional likeness/promo
//  checkbox (submit is always enabled), tappable Official Rules / Privacy
//  Policy links, SUBMIT PRIZE CLAIM, and the "secure and encrypted" lock
//  note. No step indicator (matches the SUBMIT frame).
//

import SwiftUI

struct WINRClaimReviewView: View {
    let accent: Color
    /// Official Rules destination for the tappable legal link (giveaway
    /// rulesUrl, falling back to the sdkConfig one — same as every screen).
    /// The Privacy Policy link goes to `WINRConstants.privacyURL`.
    let rulesUrl: String?
    @Binding var form: WINRPrizeClaimForm
    @ObservedObject var viewModel: WINRExperienceViewModel

    var body: some View {
        WINRClaimStepPage(
            accent: accent,
            title: "ALMOST DONE!",
            subtitle: "Please review and submit to claim your prize.",
            ctaTitle: "SUBMIT PRIZE CLAIM",
            // 2.9: the likeness/promo checkbox is OPTIONAL — SUBMIT is always
            // enabled (the steps already validated their required fields).
            ctaEnabled: true,
            ctaLoading: viewModel.isSubmittingClaim,
            onCTA: { viewModel.submitPrizeClaim(form) },
            footer: AnyView(lockNote)
        ) {
            VStack(alignment: .leading, spacing: 24) {
                WINRClaimConsentRow(
                    accent: accent,
                    isOn: $form.authorizesLikeness,
                    text: Text("I authorize this app's publisher and its promotional partners to use my name, city, profile photo, and likeness for winner announcements and promotional purposes. (Optional)")
                )

                // The rules/privacy links stay TAPPABLE (they were checkbox
                // copy before); by submitting the user agrees — no checkbox.
                VStack(alignment: .leading, spacing: 6) {
                    Text("By submitting, you agree to the")
                        .font(WINRV2Font.inter(14))
                        .foregroundColor(.white.opacity(0.85))
                    HStack(spacing: 14) {
                        legalLink("Official Rules", url: rulesUrl)
                        // 2.9.2: the actual privacy policy, not rulesUrl.
                        legalLink("Privacy Policy", url: WINRConstants.privacyURL)
                    }
                }
                .padding(.leading, 2)
            }
            .padding(.horizontal, 12)
            .padding(.top, 44)
            .padding(.bottom, 12)

            if let error = viewModel.claimSubmitError {
                Text(error)
                    .font(WINRV2Font.inter(13, .semibold))
                    .foregroundColor(Color(red: 1.0, green: 0.45, blue: 0.4))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
            }
        }
    }

    /// Underlined tappable legal link — opens the given destination.
    private func legalLink(_ title: String, url: String?) -> some View {
        Button {
            if let url, let u = URL(string: url) {
                UIApplication.shared.open(u)
            }
        } label: {
            Text(title)
                .font(WINRV2Font.inter(15, .bold))
                .underline()
                .foregroundColor(.white)
        }
        .buttonStyle(.plain)
    }

    /// Gunmetal rounded note under the CTA, accent lock + 14pt copy.
    private var lockNote: some View {
        HStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.system(size: 26))
                .foregroundColor(accent)
            Text("Your information is secure and encrypted.")
                .font(WINRV2Font.inter(14))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 25)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 10).fill(WINRV2Color.gunmetal))
        .padding(.horizontal, 12)
        .padding(.top, 30)
    }
}

/// A single consent checkbox row (accent square check + wrapping label) —
/// carried over unchanged in structure from the Light form, sized up to the
/// review frame's larger type.
struct WINRClaimConsentRow: View {
    let accent: Color
    @Binding var isOn: Bool
    let text: Text

    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(isOn ? accent : Color.white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(isOn ? accent : Color.white.opacity(0.4), lineWidth: 1.5)
                    )
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .opacity(isOn ? 1 : 0)
                    )
                    .frame(width: 24, height: 24)
                text
                    .font(WINRV2Font.inter(16))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}
