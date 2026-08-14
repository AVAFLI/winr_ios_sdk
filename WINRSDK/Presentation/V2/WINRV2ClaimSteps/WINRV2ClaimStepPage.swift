//
//  WINRV2ClaimStepPage.swift
//  WINRSDK
//
//  Scrollable page scaffold shared by the claim steps (title / subtitle /
//  content / CONTINUE pill / optional footer) plus the Figma-spec form
//  fields: labeled text field, menu (State) field, and locked field.
//

import SwiftUI

/// One step's scrollable page: Inter-Black 27 title, Inter-Medium 18 subtitle,
/// the step's content, and the accent CONTINUE/SUBMIT pill (disabled at 50%
/// opacity until the step validates). `footer` renders below the CTA (the
/// review screen's lock note).
struct WINRClaimStepPage<Content: View>: View {
    let accent: Color
    let title: String
    var subtitle: String? = nil
    var ctaTitle = "CONTINUE"
    var ctaEnabled = true
    var ctaLoading = false
    let onCTA: () -> Void
    var footer: AnyView? = nil
    @ViewBuilder let content: Content

    var body: some View {
        // Keyboard-aware page: the scroll CONTENT is padded by the keyboard
        // overlap (the drawer root ignores the keyboard safe area, so SwiftUI's
        // automatic avoidance never fires here), keeping every field and the
        // CONTINUE/SUBMIT pill reachable with the keyboard up; focused fields
        // scroll themselves into view via the environment scroll action.
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Text(title)
                        .font(WINRV2Font.inter(27, .black))
                        .kerning(-0.81)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.top, 24)
                    if let subtitle {
                        Text(subtitle)
                            .font(WINRV2Font.inter(18, .medium))
                            .kerning(-0.54)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.top, 7)
                    }

                    content

                    WINRV2PillButton(accent: accent, title: ctaTitle, isLoading: ctaLoading) {
                        onCTA()
                    }
                    .opacity(ctaEnabled ? 1 : 0.5)
                    .disabled(!ctaEnabled || ctaLoading)
                    .padding(.horizontal, 12)
                    .padding(.top, 21)

                    if let footer {
                        footer
                    }
                    Spacer(minLength: 34)
                }
                .padding(.horizontal, 28)
                .winrKeyboardAvoiding()
            }
            .environment(\.winrScrollToField, WINRKeyboardScroll.scrollAction(proxy))
        }
    }
}

/// A labeled claim-step text field per the frames: 12pt label, 59pt box,
/// #212832 fill / #3D424B 1pt border / r10, 20pt input text.
struct WINRClaimStepField: View {
    let label: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    /// Inline validation error rendered under the field (nil = none). Copy
    /// comes from WINRV2Strings; shown by the steps on a continue attempt.
    var error: String? = nil

    @FocusState private var isFocused: Bool
    @Environment(\.winrScrollToField) private var scrollToField

    private var anchorID: String { "winr-claim-field-\(label)" }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            WINRClaimStepFieldLabel(label)
            TextField("", text: $text)
                .font(WINRV2Font.inter(20))
                .foregroundColor(.white)
                .keyboardType(keyboard)
                .textContentType(contentType)
                .autocorrectionDisabled()
                .focused($isFocused)
                .padding(.horizontal, 25)
                .frame(height: 59)
                .background(WINRClaimStepTheme.fieldBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(WINRV2Color.errorRed.opacity(error == nil ? 0 : 0.8), lineWidth: 1)
                )
            if let error {
                Text(error)
                    .font(WINRV2Font.inter(13))
                    .foregroundColor(WINRV2Color.errorRed)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 8)
                    .transition(.opacity)
            }
        }
        .id(anchorID)
        .onChange(of: isFocused) { focused in
            if focused { scrollToField(anchorID) }
        }
    }
}

/// A locked (non-editable) field — the winning email and Country rows. Shows
/// dimmed text; `showsChevron` mimics the Country dropdown from the frame.
struct WINRClaimStepLockedField: View {
    let label: String
    let value: String
    var dimmed = true
    var showsChevron = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            WINRClaimStepFieldLabel(label)
            HStack {
                Text(value)
                    .font(WINRV2Font.inter(20))
                    .foregroundColor(dimmed ? Color.white.opacity(0.3) : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                if showsChevron {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 25)
            .frame(height: 59)
            .background(WINRClaimStepTheme.fieldBackground)
        }
    }
}

/// The State dropdown: same box styling, Menu of the 50 states + DC, chevron down.
struct WINRClaimStepMenuField: View {
    let label: String
    let options: [String]
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            WINRClaimStepFieldLabel(label)
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option) { selection = option }
                }
            } label: {
                HStack {
                    Text(selection.isEmpty ? "Select" : selection)
                        .font(WINRV2Font.inter(20))
                        .foregroundColor(selection.isEmpty ? Color.white.opacity(0.3) : .white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 25)
                .frame(height: 59)
                .background(WINRClaimStepTheme.fieldBackground)
            }
        }
    }
}

struct WINRClaimStepFieldLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(WINRV2Font.inter(12))
            .foregroundColor(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.leading, 8)
    }
}
