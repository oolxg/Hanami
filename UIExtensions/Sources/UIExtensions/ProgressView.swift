//
//  ProgressView.swift
//
//
//  Created by Oleg on 23.10.23.
//

import Foundation
import SwiftUI
import UIComponents

public extension ProgressView {
    func defaultWithProgress() -> some View {
        self.progressViewStyle(GaugeProgressStyle(strokeColor: .theme.accent))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .tint(.theme.accent)
    }
}
