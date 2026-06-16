//
//  PrvioEarthApp.swift
//  PRVIO EARTH
//
//  Application entry point. A single immersive scene presenting the live
//  Digital Twin. Architected to extend to a visionOS ImmersiveSpace and
//  WidgetKit/Live Activity targets sharing the same engines.
//

import SwiftUI
import PrvioEarthCore   // Xcode: RootView and the engines live in the shared framework

@main
struct PrvioEarthApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
