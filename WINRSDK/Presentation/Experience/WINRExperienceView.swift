//
//  WINRExperienceView.swift
//  WINRSDK
//
//  Created by Ryan Napolitano on 11/25/25.
//

import SwiftUI

struct WINRExperienceView: View {
    @ObservedObject var viewModel: WINRExperienceViewModel
    let theme: WINRBranding

    // V2 (Joe's WINR-High-V2 designs) is the shipping experience.
    var body: some View {
        WINRV2ExperienceRoot(viewModel: viewModel)
    }
}

extension Notification.Name {
    static let winrCloseRequested = Notification.Name("winrCloseRequested")
}
