@testable import Kickstarter_Framework
@testable import KsApi
import Library
import Prelude
import SnapshotTesting
import XCTest

internal final class SettingsPrivacyViewControllerTests: TestCase {
  override func setUp() {
    super.setUp()
    AppEnvironment.pushEnvironment(mainBundle: Bundle.framework)
    UIView.setAnimationsEnabled(false)
  }

  override func tearDown() {
    AppEnvironment.popEnvironment()
    UIView.setAnimationsEnabled(true)
    super.tearDown()
  }

  func testSocialOptedOut_And_DownloadDataCopy() {
    let currentUser = User.template
      |> \.social .~ false
    let exportData = ExportDataEnvelope.template

    let mockService = MockService(
      fetchExportStateResponse: exportData,
      fetchUserSelfResponse: currentUser
    )

    combos(Language.allLanguages, [Device.phone4_7inch, Device.phone5_8inch, Device.pad]).forEach {
      language, device in
      withEnvironment(
        apiService: mockService,
        currentUser: currentUser,
        language: language
      ) {
        let vc = Storyboard.SettingsPrivacy.instantiate(SettingsPrivacyViewController.self)

        let (parent, _) = traitControllers(device: device, orientation: .portrait, child: vc)

        self.scheduler.run()

        assertSnapshot(
          matching: parent.view,
          as: .image(perceptualPrecision: 0.98),
          named: "lang_\(language)_device_\(device)"
        )
      }
    }
  }

  func testSocialOptedIn_And_RequestDataCopy() {
    let currentUser = User.template
      |> \.social .~ true

    let exportData = .template
      |> ExportDataEnvelope.lens.state .~ .expired
      |> ExportDataEnvelope.lens.dataUrl .~ nil
      |> ExportDataEnvelope.lens.expiresAt .~ nil

    let mockService = MockService(
      fetchExportStateResponse: exportData,
      fetchUserSelfResponse: currentUser
    )

    combos(Language.allLanguages, [Device.phone4_7inch, Device.phone5_8inch, Device.pad]).forEach {
      language, device in
      withEnvironment(
        apiService: mockService,
        currentUser: currentUser,
        language: language
      ) {
        let vc = Storyboard.SettingsPrivacy.instantiate(SettingsPrivacyViewController.self)

        let (parent, _) = traitControllers(device: device, orientation: .portrait, child: vc)

        self.scheduler.run()

        assertSnapshot(
          matching: parent.view,
          as: .image(perceptualPrecision: 0.98),
          named: "lang_\(language)_device_\(device)"
        )
      }
    }
  }
}
