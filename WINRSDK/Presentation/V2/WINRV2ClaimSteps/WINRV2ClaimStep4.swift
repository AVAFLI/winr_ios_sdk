//
//  WINRV2ClaimStep4.swift
//  WINRSDK
//
//  Step 4 of 4 — "PLEASE SHARE A LITTLE": multiline story text area and the
//  "Share on Social Media:" glyph row (opens the system share sheet with a
//  generic winner line — best-effort, same sheet for every platform).
//

import SwiftUI

struct WINRClaimStep4View: View {
    let accent: Color
    @Binding var form: WINRPrizeClaimForm
    /// "I just won {prize} in {app}!" — built by the flow root.
    let shareLine: String
    let onContinue: () -> Void

    private static let placeholder =
        "Please share anything. What you\u{2019}re going to do with the prize, why you love our app, your favorite food, etc."

    var body: some View {
        WINRClaimStepPage(
            accent: accent,
            title: "PLEASE SHARE A LITTLE",
            subtitle: "This helps us show real people like you win!",
            onCTA: onContinue
        ) {
            storyEditor
                .padding(.top, 29)

            VStack(spacing: 15) {
                Text("Share on Social Media:")
                    .font(WINRV2Font.inter(18, .medium))
                    .kerning(-0.54)
                    .foregroundColor(.white)
                HStack(spacing: 26) {
                    ForEach(WINRSocialGlyph.Kind.allCases, id: \.self) { kind in
                        Button {
                            WINRShareSheet.present(text: shareLine)
                        } label: {
                            WINRSocialGlyph(kind: kind)
                                .frame(width: 48, height: 48)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Share on \(kind.displayName)")
                    }
                }
            }
            .padding(.top, 38)
            .padding(.bottom, 17)
        }
    }

    /// 199pt multiline text area in the Figma field styling, with the frame's
    /// placeholder while empty.
    private var storyEditor: some View {
        ZStack(alignment: .topLeading) {
            editor
                .font(WINRV2Font.inter(20))
                .foregroundColor(.white)
                .frame(height: 199)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            if form.story.isEmpty {
                Text(Self.placeholder)
                    .font(WINRV2Font.inter(20))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 25)
                    .padding(.top, 16)
                    .allowsHitTesting(false)
            }
        }
        .background(WINRClaimStepTheme.fieldBackground)
    }

    @ViewBuilder private var editor: some View {
        if #available(iOS 16.0, *) {
            TextEditor(text: $form.story)
                .scrollContentBackground(.hidden)
        } else {
            TextEditor(text: $form.story)
                .onAppear { UITextView.appearance().backgroundColor = .clear }
        }
    }
}

// MARK: - Share sheet

/// Presents the system share sheet from the top-most view controller.
enum WINRShareSheet {
    static func present(text: String) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        guard let root = window?.rootViewController else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        let sheet = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        // iPad popover anchor (defensive — the SDK sheet is iPhone-first).
        sheet.popoverPresentationController?.sourceView = top.view
        sheet.popoverPresentationController?.sourceRect = CGRect(
            x: top.view.bounds.midX, y: top.view.bounds.midY, width: 1, height: 1
        )
        top.present(sheet, animated: true)
    }
}
