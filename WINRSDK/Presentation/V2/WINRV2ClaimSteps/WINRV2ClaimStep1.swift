//
//  WINRV2ClaimStep1.swift
//  WINRSDK
//
//  Step 1 of 4 — "TELL US ABOUT YOURSELF": first/last name, the locked
//  winning-email field (masked address from the backend), optional phone.
//

import SwiftUI

struct WINRClaimStep1View: View {
    let accent: Color
    @Binding var form: WINRPrizeClaimForm
    /// Backend-masked winning email ("d********r@winr.example.com"); nil for
    /// older backends → generic locked copy.
    let maskedEmail: String?
    let onContinue: () -> Void

    /// CONTINUE is always tappable on this step; a tap with invalid fields
    /// flips this on and the inline errors render (and live-clear as the
    /// user fixes each field).
    @State private var attemptedContinue = false

    private var firstNameError: String? {
        attemptedContinue && !WINRV2FieldValidation.isValidName(form.firstName)
            ? WINRV2Strings.invalidFirstName : nil
    }
    private var lastNameError: String? {
        attemptedContinue && !WINRV2FieldValidation.isValidName(form.lastName)
            ? WINRV2Strings.invalidLastName : nil
    }
    private var phoneError: String? {
        attemptedContinue && !form.isPhoneEmptyOrValid
            ? WINRV2Strings.invalidPhone : nil
    }

    var body: some View {
        WINRClaimStepPage(
            accent: accent,
            title: "TELL US ABOUT YOURSELF",
            subtitle: "We'll use this information to verify your prize and personalize your winner announcement.",
            ctaEnabled: true,
            onCTA: attemptContinue
        ) {
            VStack(spacing: 21) {
                WINRClaimStepField(
                    label: "First Name",
                    text: $form.firstName,
                    contentType: .givenName,
                    error: firstNameError
                )
                WINRClaimStepField(
                    label: "Last Name (we will only show your last initial)",
                    text: $form.lastName,
                    contentType: .familyName,
                    error: lastNameError
                )
                // The winning email lives server-side (the SDK never stores the
                // raw address) and the claim is keyed to the account — shown
                // locked, masked by the backend for recognition.
                WINRClaimStepLockedField(
                    label: "Winning Email Address (cannot be changed)",
                    value: maskedEmail ?? "On file with your winning entry"
                )
                WINRClaimStepField(
                    label: "Phone Number (optional)",
                    text: $form.phone,
                    keyboard: .phonePad,
                    contentType: .telephoneNumber,
                    error: phoneError
                )
            }
            .padding(.horizontal, 12)
            .padding(.top, 34)
        }
    }

    private func attemptContinue() {
        withAnimation(.easeInOut(duration: 0.2)) { attemptedContinue = true }
        guard form.isStep1Valid else { return }
        onContinue()
    }
}
