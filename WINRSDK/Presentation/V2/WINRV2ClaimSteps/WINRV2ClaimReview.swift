//
//  WINRV2ClaimReview.swift
//  WINRSDK
//
//  Review screen — "ALMOST DONE!": the three required consent checkboxes,
//  SUBMIT PRIZE CLAIM, and the "secure and encrypted" lock note. No step
//  indicator (matches the SUBMIT frame).
//

import SwiftUI

struct WINRClaimReviewView: View {
    let accent: Color
    @Binding var form: WINRPrizeClaimForm
    @ObservedObject var viewModel: WINRExperienceViewModel

    var body: some View {
        WINRClaimStepPage(
            accent: accent,
            title: "ALMOST DONE!",
            subtitle: "Please review and agree to claim your prize.",
            ctaTitle: "SUBMIT PRIZE CLAIM",
            ctaEnabled: form.isValid,
            ctaLoading: viewModel.isSubmittingClaim,
            onCTA: { viewModel.submitPrizeClaim(form) },
            footer: AnyView(lockNote)
        ) {
            VStack(alignment: .leading, spacing: 32) {
                WINRClaimConsentRow(
                    accent: accent,
                    isOn: $form.confirmsAccuracy,
                    text: Text("I confirm my information is accurate.")
                )
                WINRClaimConsentRow(
                    accent: accent,
                    isOn: $form.authorizesLikeness,
                    text: Text("I authorize this app's publisher and its promotional partners to use my name, city, profile photo, and likeness for winner announcements and promotional purposes.")
                )
                WINRClaimConsentRow(
                    accent: accent,
                    isOn: $form.agreesToRules,
                    text: Text("I agree to the ").font(WINRV2Font.inter(16))
                        + Text("Official Rules").underline().bold()
                        + Text(" and ")
                        + Text("Privacy Policy").underline().bold()
                        + Text(".")
                )
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
