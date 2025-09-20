import UIKit
import SwiftUI
import FirebaseCore

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // Configure Firebase
        FirebaseManager.shared.configure()
        
        // Setup window and initial view controller
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = createRootViewController()
        self.window = window
        window.makeKeyAndVisible()
    }
    
    private func createRootViewController() -> UIViewController {
        let mainTabScaffold = MainTabScaffold(authViewModel: AuthViewModel())
        return UIHostingController(rootView: mainTabScaffold)
    }
}
