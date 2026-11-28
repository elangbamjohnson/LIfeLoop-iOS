//
//  GooglePresentationAnchor.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 17/11/26.
//

import SwiftUI
import UIKit

/// Resolve the controller in this window, rather than choosing an arbitrary app window.
struct GooglePresentationAnchor: UIViewControllerRepresentable {
    let onResolve: (UIViewController) -> Void

    func makeUIViewController(context: Context) -> AnchorController {
        let controller = AnchorController()
        controller.onResolve = onResolve
        return controller
    }

    func updateUIViewController(_ controller: AnchorController, context: Context) {
        controller.onResolve = onResolve
    }

    final class AnchorController: UIViewController {
        var onResolve: ((UIViewController) -> Void)?
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            onResolve?(self)
        }
    }
}
