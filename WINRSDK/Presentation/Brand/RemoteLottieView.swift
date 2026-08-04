//
//  RemoteLottieView.swift
//  WINRSDK
//
//  Loads and plays a Lottie animation from a remote URL.
//

import SwiftUI
internal import Lottie

struct RemoteLottieView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> LottieAnimationView {
        let view = LottieAnimationView()
        view.contentMode = .scaleAspectFit
        view.loopMode = .loop
        view.backgroundBehavior = .pauseAndRestore
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = false

        // Load animation from remote URL
        LottieAnimation.loadedFrom(url: url) { animation in
            DispatchQueue.main.async {
                view.animation = animation
                view.play()
            }
        }

        return view
    }

    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        uiView.clipsToBounds = false
        if !uiView.isAnimationPlaying, uiView.animation != nil {
            uiView.play()
        }
    }
}
