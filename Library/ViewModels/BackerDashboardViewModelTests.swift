@testable import KsApi
@testable import Library
import Prelude
import ReactiveExtensions_TestHelpers
import ReactiveSwift
import XCTest

internal final class BackerDashboardViewModelTests: TestCase {
  private let vm: BackerDashboardViewModelType = BackerDashboardViewModel()

  private let avatarURL = TestObserver<String, Never>()
  private let backedButtonTitleText = TestObserver<String, Never>()
  private let backerNameText = TestObserver<String, Never>()
  private let configurePagesDataSourceTab = TestObserver<BackerDashboardTab, Never>()
  private let configurePagesDataSourceSort = TestObserver<DiscoveryParams.Sort, Never>()
  private let embeddedViewTopConstraintConstant = TestObserver<CGFloat, Never>()
  private let goToMessages = TestObserver<(), Never>()
  private let goToProject = TestObserver<Project, Never>()
  private let goToSettings = TestObserver<(), Never>()
  private let navigateToTab = TestObserver<BackerDashboardTab, Never>()
  private let pinSelectedIndicatorToTab = TestObserver<BackerDashboardTab, Never>()
  private let pinSelectedIndicatorToTabAnimated = TestObserver<Bool, Never>()
  private let postNotification = TestObserver<Notification, Never>()
  private let savedButtonTitleText = TestObserver<String, Never>()
  private let setSelectedButton = TestObserver<BackerDashboardTab, Never>()
  private let sortBarIsHidden = TestObserver<Bool, Never>()
  private let updateCurrentUserInEnvironment = TestObserver<User, Never>()

  override func setUp() {
    super.setUp()

    self.vm.outputs.avatarURL.map { $0?.absoluteString ?? "" }.observe(self.avatarURL.observer)
    self.vm.outputs.backedButtonTitleText.observe(self.backedButtonTitleText.observer)
    self.vm.outputs.backerNameText.observe(self.backerNameText.observer)
    self.vm.outputs.configurePagesDataSource.map(first).observe(self.configurePagesDataSourceTab.observer)
    self.vm.outputs.configurePagesDataSource.map(second).observe(self.configurePagesDataSourceSort.observer)
    self.vm.outputs.embeddedViewTopConstraintConstant.observe(self.embeddedViewTopConstraintConstant.observer)
    self.vm.outputs.goToMessages.observe(self.goToMessages.observer)
    self.vm.outputs.goToSettings.observe(self.goToSettings.observer)
    self.vm.outputs.navigateToTab.observe(self.navigateToTab.observer)
    self.vm.outputs.pinSelectedIndicatorToTab.map(first).observe(self.pinSelectedIndicatorToTab.observer)
    self.vm.outputs.pinSelectedIndicatorToTab.map(second)
      .observe(self.pinSelectedIndicatorToTabAnimated.observer)
    self.vm.outputs.savedButtonTitleText.observe(self.savedButtonTitleText.observer)
    self.vm.outputs.setSelectedButton.observe(self.setSelectedButton.observer)
    self.vm.outputs.sortBarIsHidden.observe(self.sortBarIsHidden.observer)
    self.vm.outputs.updateCurrentUserInEnvironment.observe(self.updateCurrentUserInEnvironment.observer)
    self.vm.outputs.postNotification.observe(self.postNotification.observer)
  }

  func testUserAndHeaderDisplayData() {
    let location = Location.template
      |> Location.lens.displayableName .~ "Siberia"

    let user = User.template
      |> \.name .~ "Princess Vespa"
      |> \.location .~ location
      |> \.stats.backedProjectsCount .~ 45
      |> \.stats.starredProjectsCount .~ 58
      |> \.avatar.large .~ "http://cats.com/furball.jpg"

    let userEnvelope = UserEnvelope(me: user)

    withEnvironment(apiService: MockService(fetchGraphUserSelfResult: .success(userEnvelope))) {
      AppEnvironment.login(AccessTokenEnvelope(accessToken: "deadbeef", user: user))

      self.avatarURL.assertValueCount(0)
      self.backedButtonTitleText.assertValueCount(0)
      self.backerNameText.assertValueCount(0)
      self.pinSelectedIndicatorToTab.assertValueCount(0)
      self.pinSelectedIndicatorToTabAnimated.assertValueCount(0)
      self.savedButtonTitleText.assertValueCount(0)
      self.setSelectedButton.assertValueCount(0)
      self.sortBarIsHidden.assertValueCount(0)
      self.postNotification.assertValueCount(0)
      self.updateCurrentUserInEnvironment.assertValueCount(0)

      self.vm.inputs.viewDidLoad()
      self.vm.inputs.viewWillAppear(false)

      self.scheduler.advance()

      // Signals emit twice as they are prefixed with the current user data.
      self.avatarURL.assertValues(["http://cats.com/furball.jpg", "http://cats.com/furball.jpg"])
      self.backedButtonTitleText.assertValues(["45\nbacked", "45\nbacked"])
      self.backerNameText.assertValues(["Princess Vespa", "Princess Vespa"])
      self.savedButtonTitleText.assertValues(["58\nsaved", "58\nsaved"])
      self.setSelectedButton.assertValues([.backed])
      self.sortBarIsHidden.assertValues([true])
      self.embeddedViewTopConstraintConstant.assertValues([0.0])
      self.postNotification.assertValueCount(0)
      self.updateCurrentUserInEnvironment.assertValues([user])

      self.vm.inputs.currentUserUpdatedInEnvironment()

      self.postNotification.assertValueCount(1)

      // Signals that emit just once because they rely on the datasource tab index to exist first.
      self.pinSelectedIndicatorToTab.assertValues([.backed])
      self.pinSelectedIndicatorToTabAnimated.assertValues([false])
    }
  }

  func testUserUpdatesInEnvironment_AfterSavingProject() {
    let user = User.template
      |> \.name .~ "user"
      |> \.stats.starredProjectsCount .~ 60

    let userEnvelope = UserEnvelope(me: user)

    withEnvironment(apiService: MockService(fetchGraphUserSelfResult: .success(userEnvelope))) {
      AppEnvironment.login(AccessTokenEnvelope(accessToken: "deadbeef", user: user))
      self.vm.inputs.viewWillAppear(false)

      self.scheduler.advance()

      self.updateCurrentUserInEnvironment.assertValues([user])

      let user2 = user
        |> \.name .~ "Updated user"

      let user2Envelope = UserEnvelope(me: user2)

      withEnvironment(apiService: MockService(fetchGraphUserSelfResult: .success(user2Envelope))) {
        self.vm.inputs.projectSaved()

        self.scheduler.advance()

        self.updateCurrentUserInEnvironment.assertValues([user, user, user2])
      }
    }
  }

  func testConfigurePagesData() {
    self.configurePagesDataSourceTab.assertValueCount(0)
    self.configurePagesDataSourceSort.assertValueCount(0)

    self.vm.inputs.viewDidLoad()

    self.configurePagesDataSourceTab.assertValues([.backed])
    self.configurePagesDataSourceSort.assertValues([.endingSoon])
  }

  func testTabNavigation() {
    let userEnvelope = UserEnvelope(me: User.template)

    withEnvironment(apiService: MockService(fetchGraphUserSelfResult: .success(userEnvelope))) {
      AppEnvironment.login(AccessTokenEnvelope(accessToken: "deadbeef", user: .template))

      self.vm.inputs.viewDidLoad()
      self.vm.inputs.viewWillAppear(false)

      self.setSelectedButton.assertValueCount(0)
      self.pinSelectedIndicatorToTab.assertValueCount(0)
      self.pinSelectedIndicatorToTabAnimated.assertValueCount(0)
      XCTAssertEqual(.backed, self.vm.outputs.currentSelectedTab)

      self.scheduler.advance()

      self.navigateToTab.assertValueCount(0)
      self.setSelectedButton.assertValues([.backed])
      self.pinSelectedIndicatorToTab.assertValues([.backed])
      self.pinSelectedIndicatorToTabAnimated.assertValues([false])
      XCTAssertEqual(.backed, self.vm.outputs.currentSelectedTab)

      self.vm.inputs.savedProjectsButtonTapped()

      self.navigateToTab.assertValues([.saved])
      self.setSelectedButton.assertValues([.backed, .saved])
      self.pinSelectedIndicatorToTab.assertValues([.backed, .saved])
      self.pinSelectedIndicatorToTabAnimated.assertValues([false, true])
      XCTAssertEqual(.saved, self.vm.outputs.currentSelectedTab)

      XCTAssertEqual("discover", self.segmentTrackingClient.properties.last?["context_page"] as? String)
      XCTAssertEqual("watched", self.segmentTrackingClient.properties.last?["context_type"] as? String)
      XCTAssertEqual(
        "account_menu",
        self.segmentTrackingClient.properties.last?["context_location"] as? String
      )

      self.vm.inputs.backedProjectsButtonTapped()

      self.navigateToTab.assertValues([.saved, .backed])
      self.setSelectedButton.assertValues([.backed, .saved, .backed])
      self.pinSelectedIndicatorToTab.assertValues([.backed, .saved, .backed])
      self.pinSelectedIndicatorToTabAnimated.assertValues([false, true, true])
      XCTAssertEqual(.backed, self.vm.outputs.currentSelectedTab)

      // Swiping.
      self.vm.inputs.willTransition(toPage: 1)
      self.vm.inputs.pageTransition(completed: false)

      self.navigateToTab.assertValues([.saved, .backed], "Tab switch does not complete.")
      self.setSelectedButton.assertValues([.backed, .saved, .backed], "Selection does not emit.")
      self.pinSelectedIndicatorToTab.assertValues([.backed, .saved, .backed], "Selection does not emit.")
      XCTAssertEqual(.backed, self.vm.outputs.currentSelectedTab)

      self.vm.inputs.willTransition(toPage: 1)
      self.vm.inputs.pageTransition(completed: true)

      self.navigateToTab.assertValues([.saved, .backed, .saved])
      self.setSelectedButton.assertValues([.backed, .saved, .backed, .saved])
      self.pinSelectedIndicatorToTab.assertValues([.backed, .saved, .backed, .saved])
      self.pinSelectedIndicatorToTabAnimated.assertValues([false, true, true, true])
      XCTAssertEqual(.saved, self.vm.outputs.currentSelectedTab)

      XCTAssertEqual("discover", self.segmentTrackingClient.properties.last?["context_page"] as? String)
      XCTAssertEqual("watched", self.segmentTrackingClient.properties.last?["context_type"] as? String)
      XCTAssertEqual(
        "account_menu",
        self.segmentTrackingClient.properties.last?["context_location"] as? String
      )
    }
  }

  func testGoPlaces() {
    self.vm.inputs.viewDidLoad()
    self.vm.inputs.viewWillAppear(false)

    self.goToSettings.assertValueCount(0)

    self.vm.inputs.settingsButtonTapped()

    self.goToSettings.assertValueCount(1)
    self.goToMessages.assertValueCount(0)

    self.vm.inputs.messagesButtonTapped()

    self.goToMessages.assertValueCount(1)
  }

  func testHeaderPanning() {
    self.vm.inputs.viewDidLoad()
    self.vm.inputs.viewWillAppear(false)

    // Panning on the header view.
    self.vm.inputs.beganPanGestureWith(headerTopConstant: -101.0, scrollViewYOffset: 0.0)

    XCTAssertEqual(-101.0, self.vm.outputs.initialTopConstant)

    // Panning on the projects table view.
    self.vm.inputs.beganPanGestureWith(headerTopConstant: -101.0, scrollViewYOffset: 500.0)

    XCTAssertEqual(-500, self.vm.outputs.initialTopConstant)
  }
}
