import Flutter
import UIKit
class SceneDelegate: FlutterSceneDelegate {
  private var privacyCover: UIView?
  override func sceneWillResignActive(_ scene: UIScene) {
    super.sceneWillResignActive(scene)
    guard let window = (scene as? UIWindowScene)?.windows.first else { return }
    let cover = UIView(frame: window.bounds)
    cover.backgroundColor = UIColor(red: 251/255, green: 249/255, blue: 245/255, alpha: 1)
    cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    let label = UILabel(frame: cover.bounds)
    label.text = "Calculator"
    label.textAlignment = .center
    label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    cover.addSubview(label)
    window.addSubview(cover)
    privacyCover = cover
  }
  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    privacyCover?.removeFromSuperview()
    privacyCover = nil
  }
}
