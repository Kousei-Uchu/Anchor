//
//  AnchorWidgetBundle.swift
//  AnchorWidgetExtension
//

import WidgetKit
import SwiftUI

@main
struct AnchorWidgetBundle: WidgetBundle {
    var body: some Widget {
        AnchorWidget()
        AnchorDeEscalationWidget()
        AnchorNextWindowWidget()
        AnchorAffirmationWidget()
        AnchorCounterWidget()
    }
}
