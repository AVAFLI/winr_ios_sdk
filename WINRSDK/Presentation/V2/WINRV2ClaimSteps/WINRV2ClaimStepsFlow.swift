//
//  WINRV2ClaimStepsFlow.swift
//  WINRSDK
//
//  Root of the stepped prize-claim form (Joe's Figma design): a persistent
//  gold-sparkle backdrop + header + animated step indicator, with the four
//  form steps and the review screen sliding horizontally beneath them
//  (push left on advance, push right on back).
//

import SwiftUI

/// The five screens of the stepped form. Raw value is the 1-based step number
/// (review has no "STEP N OF 4" row, matching the SUBMIT frame).
enum WINRClaimFlowStep: Int, CaseIterable {
    case one = 1, two, three, four, review

    var indicatorStep: Int? { self == .review ? nil : rawValue }
}

struct WINRV2ClaimStepsFlow: View {
    let accent: Color
    let logoUrl: String?
    let claim: PrizeClaimBlock
    @ObservedObject var viewModel: WINRExperienceViewModel
    let onClose: () -> Void

    @State private var form: WINRPrizeClaimForm
    /// The picked/taken photo, held at flow level so step 3 keeps its preview
    /// when the user navigates back and forth.
    @State private var photo: UIImage?
    @State private var step: WINRClaimFlowStep = .one
    /// Direction of the last navigation — drives the slide edges.
    @State private var advancing = true

    init(
        accent: Color,
        logoUrl: String?,
        claim: PrizeClaimBlock,
        viewModel: WINRExperienceViewModel,
        onClose: @escaping () -> Void
    ) {
        self.accent = accent
        self.logoUrl = logoUrl
        self.claim = claim
        self.viewModel = viewModel
        self.onClose = onClose
        _form = State(initialValue: viewModel.claimFormPrefill)
    }

    var body: some View {
        ZStack(alignment: .top) {
            WINRV2Color.deepCharcoal.ignoresSafeArea()
            backdrop

            VStack(spacing: 0) {
                WINRClaimStepHeader(
                    logoUrl: logoUrl,
                    showsBack: step != .one,
                    onBack: goBack,
                    onClose: onClose
                )
                .padding(.top, 18)

                if let indicatorStep = step.indicatorStep {
                    WINRClaimStepIndicator(accent: accent, current: indicatorStep)
                        .padding(.top, 8)
                        .transition(.opacity)
                }

                ZStack {
                    stepContent
                        .id(step)
                        .transition(slide)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
        }
    }

    // MARK: - Steps

    @ViewBuilder private var stepContent: some View {
        switch step {
        case .one:
            WINRClaimStep1View(
                accent: accent,
                form: $form,
                maskedEmail: claim.maskedEmail,
                onContinue: { go(to: .two) }
            )
        case .two:
            WINRClaimStep2View(accent: accent, form: $form, onContinue: { go(to: .three) })
        case .three:
            WINRClaimStep3View(
                accent: accent,
                form: $form,
                photo: $photo,
                onContinue: { go(to: .four) }
            )
        case .four:
            WINRClaimStep4View(
                accent: accent,
                form: $form,
                shareLine: shareLine,
                onContinue: { go(to: .review) }
            )
        case .review:
            WINRClaimReviewView(accent: accent, form: $form, viewModel: viewModel)
        }
    }

    // MARK: - Navigation

    private func go(to next: WINRClaimFlowStep) {
        advancing = next.rawValue > step.rawValue
        withAnimation(.easeInOut(duration: 0.3)) { step = next }
    }

    private func goBack() {
        guard let previous = WINRClaimFlowStep(rawValue: step.rawValue - 1) else { return }
        go(to: previous)
    }

    /// Steps push left when advancing and right when going back.
    private var slide: AnyTransition {
        .asymmetric(
            insertion: .move(edge: advancing ? .trailing : .leading),
            removal: .move(edge: advancing ? .leading : .trailing)
        )
    }

    /// Generic share-sheet line for the step-4 social buttons.
    private var shareLine: String {
        let prize = WINRV2PrizeText.stripHeadline(
            description: claim.prizeDescription,
            value: Int(claim.prizeValue)
        )
        let app = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        if let app { return "I just won \(prize) in \(app)!" }
        return "I just won \(prize)!"
    }

    // MARK: - Backdrop

    /// Gold-sparkle full-bleed backdrop fading into the dark body, per the
    /// frames (406pt tall, transparent → deepCharcoal). The art lives in the
    /// .background of a clear frame so scaledToFill's oversized width can't
    /// leak into the ZStack's layout.
    private var backdrop: some View {
        Color.clear
            .frame(height: 406)
            .frame(maxWidth: .infinity)
            .background(WINRV2Asset.winnerModalBg.resizable().scaledToFill())
            .clipped()
            .overlay(
                LinearGradient(
                    stops: [
                        .init(color: WINRV2Color.deepCharcoal.opacity(0.1), location: 0.05),
                        .init(color: WINRV2Color.deepCharcoal.opacity(0.6), location: 0.6),
                        .init(color: WINRV2Color.deepCharcoal, location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .frame(maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea(edges: .top)
    }
}
