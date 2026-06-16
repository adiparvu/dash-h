//
//  PrvioWidgetBundle.swift
//  PRVIO EARTH — Widget Extension
//
//  Entry point for the Widget Extension target. Bundles the home/lock-screen
//  property widget together with the irrigation Live Activity so they ship in
//  one extension.
//

import WidgetKit
import SwiftUI

@main
struct PrvioWidgetBundle: WidgetBundle {
    var body: some Widget {
        PropertyWidget()
        IrrigationLiveActivity()
    }
}
