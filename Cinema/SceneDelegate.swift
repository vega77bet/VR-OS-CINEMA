import UIKit

/// Bind the window to its scene so UIKit owns landscape sizing and rotation.
/// A legacy screen-sized window can retain portrait geometry at launch.
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = .black
        window.overrideUserInterfaceStyle = .dark
        window.rootViewController = CinemaViewController()
        self.window = window
        window.makeKeyAndVisible()
    }
}
