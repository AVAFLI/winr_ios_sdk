//
//  WINRV2ClaimStep2.swift
//  WINRSDK
//
//  Step 2 of 4 — "WHERE SHOULD WE SEND YOUR PRIZE?": street, apt, city,
//  State picker + 5-digit zip side by side, Country locked to United States.
//

import SwiftUI

struct WINRClaimStep2View: View {
    let accent: Color
    @Binding var form: WINRPrizeClaimForm
    let onContinue: () -> Void

    var body: some View {
        WINRClaimStepPage(
            accent: accent,
            title: "WHERE SHOULD WE\nSEND YOUR PRIZE?",
            ctaEnabled: form.isStep2Valid,
            onCTA: onContinue
        ) {
            VStack(spacing: 21) {
                WINRClaimStepField(
                    label: "Street Address",
                    text: $form.street,
                    contentType: .streetAddressLine1
                )
                WINRClaimStepField(
                    label: "Apartment, Suite, etc. (optional)",
                    text: $form.apt,
                    contentType: .streetAddressLine2
                )
                WINRClaimStepField(
                    label: "City",
                    text: $form.city,
                    contentType: .addressCity
                )
                HStack(alignment: .top, spacing: 13) {
                    WINRClaimStepMenuField(
                        label: "State",
                        options: WINRPrizeClaimForm.usStates,
                        selection: $form.state
                    )
                    WINRClaimStepField(
                        label: "Zip Code",
                        text: $form.zip,
                        keyboard: .numberPad,
                        contentType: .postalCode
                    )
                    .frame(width: 101)
                    .onChange(of: form.zip) { newValue in
                        let digits = String(newValue.filter(\.isNumber).prefix(5))
                        if digits != newValue { form.zip = digits }
                    }
                }
                // US-only sweepstakes — the country row renders like the frame's
                // dropdown but is fixed.
                WINRClaimStepLockedField(
                    label: "Country",
                    value: form.country,
                    dimmed: false,
                    showsChevron: true
                )
            }
            .padding(.horizontal, 12)
            .padding(.top, 28)
        }
    }
}
