//
//  LottieLogoView.swift
//  WINRSDK
//
//  Created by Ryan Napolitano on 11/25/25.
//

import SwiftUI
internal import Lottie

struct LottieLogoView: UIViewRepresentable {
    let name: String

    func makeUIView(context: Context) -> LottieAnimationView {
        let view = LottieAnimationView(name: name)
        view.contentMode = .scaleAspectFit
        view.loopMode = .loop
        view.backgroundBehavior = .pauseAndRestore
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = false
        view.superview?.clipsToBounds = false
        view.play()
        return view
    }

    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        let animation = LottieAnimation.named(name)
        uiView.animation = animation
        if uiView.isAnimationPlaying == false {
            uiView.play()
        }
        // Ensure no ancestor clips the animation
        uiView.clipsToBounds = false
        var parent = uiView.superview
        while let p = parent {
            p.clipsToBounds = false
            parent = p.superview
        }
    }
}
