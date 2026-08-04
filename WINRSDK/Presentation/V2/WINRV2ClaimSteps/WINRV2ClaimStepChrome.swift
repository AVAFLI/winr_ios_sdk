//
//  WINRV2ClaimStepChrome.swift
//  WINRSDK
//
//  Shared chrome for the stepped prize-claim flow (Joe's Figma frames):
//  field colors, the persistent header (back chevron / publisher logo / close),
//  the "STEP N OF 4" label, and the 4 connected progress dots.
//

import SwiftUI

/// Field styling from the claim-step frames: #212832 fill, #3D424B border, r10.
enum WINRClaimStepTheme {
    static let fieldFill = Color(red: 0x21 / 255, green: 0x28 / 255, blue: 0x32 / 255)
    static let fieldBorder = Color(red: 0x3D / 255, green: 0x42 / 255, blue: 0x4B / 255)

    static var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(fieldFill)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(fieldBorder, lineWidth: 1))
    }
}

/// Header shown on every step: centered publisher logo (210×60 per the frames)
/// with a back chevron on the left (steps 2+ / review) and the X close on the
/// right.
struct WINRClaimStepHeader: View {
    let logoUrl: String?
    let showsBack: Bool
    let onBack: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            logo
                .frame(height: 60)
                .frame(maxWidth: 210)
            HStack {
                if showsBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(WINRV2Color.deepCharcoal.opacity(0.85)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")
                }
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
                .accessibilityLabel("Close")
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

/// "STEP N OF 4" + the row of 4 dots connected by lines (143×14 in the
/// frames): filled with the accent up to the current step, outlined after it.
/// The fill animates as the flow advances.
struct WINRClaimStepIndicator: View {
    let accent: Color
    /// 1-based current step (1...4).
    let current: Int

    private let dotSize: CGFloat = 14
    private let lineWidth: CGFloat = 29

    var body: some View {
        VStack(spacing: 12) {
            Text("STEP \(current) OF 4")
                .font(WINRV2Font.inter(17, .semibold))
                .kerning(-0.85)
                .foregroundColor(.white)
            HStack(spacing: 0) {
                ForEach(1...4, id: \.self) { index in
                    dot(filled: index <= current)
                    if index < 4 {
                        Rectangle()
                            .fill(accent)
                            .frame(width: lineWidth, height: 1.5)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: current)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(current) of 4")
    }

    private func dot(filled: Bool) -> some View {
        Circle()
            .fill(filled ? accent : WINRV2Color.deepCharcoal.opacity(0.6))
            .overlay(Circle().stroke(accent, lineWidth: 1.5))
            .frame(width: dotSize, height: dotSize)
    }
}
