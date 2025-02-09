import KsApi
import Prelude
import ReactiveExtensions
import ReactiveSwift

public enum DrawerState {
  case open
  case closed

  public var toggled: DrawerState {
    return self == .open ? .closed : .open
  }
}

public struct DashboardTitleViewData {
  public let drawerState: DrawerState
  public let isArrowHidden: Bool
  public let currentProjectIndex: Int
}

public struct ProjectsDrawerData {
  public let project: Project
  public let indexNum: Int
  public let isChecked: Bool
}

public protocol DashboardViewModelInputs {
  /// Call to navigate to activities for project with id
  func activitiesNavigated(projectId: Param)

  /// Call to switch display to another project from the drawer.
  func `switch`(toProject param: Param)

  /// Call when the projects drawer has animated out.
  func dashboardProjectsDrawerDidAnimateOut()

  /// Call to open project messages thread
  func messagesCellTapped()

  /// Call to open message thread for specific project
  func messageThreadNavigated(projectId: Param, messageThread: MessageThread)

  /// Call when the project context cell is tapped.
  func projectContextCellTapped()

  /// Call when to show or hide the projects drawer.
  func showHideProjectsDrawer()

  /// Call when Post Update is clicked
  func trackPostUpdateClicked()

  /// Call when the view loads.
  func viewDidLoad()

  /// Call when the view will appear.
  func viewWillAppear(animated: Bool)

  /// Call when the view will disappear
  func viewWillDisappear()
}

public protocol DashboardViewModelOutputs {
  /// Emits when should animate out projects drawer.
  var animateOutProjectsDrawer: Signal<(), Never> { get }

  /// Emits when should dismiss projects drawer.
  var dismissProjectsDrawer: Signal<(), Never> { get }

  /// Emits when to focus the screen reader on the titleView.
  var focusScreenReaderOnTitleView: Signal<(), Never> { get }

  /// Emits the funding stats and project to be displayed in the funding cell.
  var fundingData: Signal<
    (
      funding: [ProjectStatsEnvelope.FundingDateStats],
      project: Project
    ), Never
  > { get }

  /// Emits when navigating to project activities
  var goToActivities: Signal<Project, Never> { get }

  /// Emits when to go to project messages thread
  var goToMessages: Signal<Project, Never> { get }

  /// Emits when opening specific project message thread
  var goToMessageThread: Signal<(Project, MessageThread), Never> { get }

  /// Emits when to go to the project page.
  var goToProject: Signal<(Project, RefTag), Never> { get }

  /// Emits when should present projects drawer with data to populate it.
  var presentProjectsDrawer: Signal<[ProjectsDrawerData], Never> { get }

  /// Emits the currently selected project to display in the context and action cells.
  var project: Signal<Project, Never> { get }

  /// Emits a boolean that determines if projects are currently loading.
  var loaderIsAnimating: Signal<Bool, Never> { get }

  /// Emits the cumulative, project, and referreral distribution data to display in the referrers cell.
  var referrerData: Signal<
    (
      cumulative: ProjectStatsEnvelope.CumulativeStats,
      project: Project, aggregates: ProjectStatsEnvelope.ReferralAggregateStats,
      stats: [ProjectStatsEnvelope.ReferrerStats]
    ), Never
  > { get }

  /// Emits the project, reward stats, and cumulative pledges to display in the rewards cell.
  var rewardData: Signal<(stats: [ProjectStatsEnvelope.RewardStats], project: Project), Never> { get }

  /// Emits the video stats to display in the video cell.
  var videoStats: Signal<ProjectStatsEnvelope.VideoStats, Never> { get }

  /// Emits data for the title view.
  var updateTitleViewData: Signal<DashboardTitleViewData, Never> { get }
}

public protocol DashboardViewModelType {
  var inputs: DashboardViewModelInputs { get }
  var outputs: DashboardViewModelOutputs { get }
}

public final class DashboardViewModel: DashboardViewModelInputs, DashboardViewModelOutputs,
  DashboardViewModelType {
  public init() {
    let projects = self.viewWillAppearAnimatedProperty.signal.ignoreValues()
      .switchMap {
        AppEnvironment.current.apiService.fetchProjects(member: true)
          .ksr_delay(AppEnvironment.current.apiDelayInterval, on: AppEnvironment.current.scheduler)
          .demoteErrors()
          .map { $0.projects }
          .prefix(value: [])
      }

    let selectedProjectProducer = SignalProducer.merge(
      self.switchToProjectProperty.producer,
      self.activitiesNavigatedProperty.producer,
      self.messageThreadNavigatedProperty.producer.skipNil().map(first)
    )

    /* Interim MutableProperty used to default to first project on viewWillAppear
     * and to subsequently switch to the selected project.
     */
    let selectProjectPropertyOrFirst = MutableProperty<Param?>(nil)

    selectProjectPropertyOrFirst <~ SignalProducer.combineLatest(
      selectedProjectProducer,
      self.viewWillAppearAnimatedProperty.producer.ignoreValues()
    )
    .map(first)
    .skipRepeats { lhs, rhs in lhs == rhs }

    let projectsAndSelected = projects
      .switchMap { projects in
        selectProjectPropertyOrFirst.producer
          .map { param -> Project? in
            param.flatMap { find(projectForParam: $0, in: projects) } ?? projects.first
          }
          .skipNil()
          .map { (projects, $0) }
      }

    self.project = projectsAndSelected.map(second)

    self.loaderIsAnimating = Signal.merge(
      self.viewDidLoadProperty.signal.map(const(true)),
      projects.filter { !$0.isEmpty }.map(const(false))
    ).skipRepeats()

    /* Interim MutableProperty used to inject nil on viewWillDisappear
     * in order to ensure that same MessageThread is not navigated to again
     * on viewWillAppear as projects will refresh each time.
     */
    let messageThreadReceived = MutableProperty<(Param, MessageThread)?>(nil)

    messageThreadReceived <~ Signal.merge(
      self.viewWillDisappearProperty.signal.mapConst(nil),
      self.messageThreadNavigatedProperty.signal
    )

    self.goToMessageThread = self.project
      .switchMap { project in
        messageThreadReceived.producer
          .skipNil()
          .filter { $0.0 == .id(project.id) }
          .map { (project, $1) }
      }

    /* Interim MutableProperty used to inject nil on viewWillDisappear
     * in order to ensure that same navigateToActivities is not navigated to again
     * on viewWillAppear as projects will refresh each time.
     */
    let navigateToActivitiesReceived = MutableProperty<Param?>(nil)

    navigateToActivitiesReceived <~ Signal.merge(
      self.viewWillDisappearProperty.signal.mapConst(nil),
      self.activitiesNavigatedProperty.signal
    )

    self.goToActivities = self.project
      .switchMap { project in
        navigateToActivitiesReceived.producer
          .skipNil()
          .filter { $0 == .id(project.id) }
          .map { _ in project }
      }

    let selectedProjectAndStatsEvent = self.project
      .switchMap { project in
        AppEnvironment.current.apiService.fetchProjectStats(projectId: project.id)
          .ksr_delay(AppEnvironment.current.apiDelayInterval, on: AppEnvironment.current.scheduler)
          .map { (project, $0) }
          .materialize()
      }

    let selectedProjectAndStats = selectedProjectAndStatsEvent.values()

    self.fundingData = selectedProjectAndStats
      .map { project, stats in
        (funding: stats.fundingDistribution, project: project)
      }

    self.referrerData = selectedProjectAndStats
      .map { project, stats in
        (
          cumulative: stats.cumulativeStats, project: project,
          aggregates: stats.referralAggregateStats, stats: stats.referralDistribution
        )
      }

    self.videoStats = selectedProjectAndStats.map { _, stats in stats.videoStats }.skipNil()

    self.rewardData = selectedProjectAndStats
      .map { project, stats in
        (stats: stats.rewardDistribution, project: project)
      }

    let drawerStateProjectsAndSelectedProject = Signal.merge(
      projectsAndSelected.map { ($0, $1, false) },
      projectsAndSelected
        .takeWhen(self.showHideProjectsDrawerProperty.signal).map { ($0, $1, true) }
    )
    .scan(nil) { (data, projectsProjectToggle) -> (DrawerState, [Project], Project)? in
      let (projects, project, toggle) = projectsProjectToggle

      return (
        toggle ? (data?.0.toggled ?? DrawerState.closed) : DrawerState.closed,
        projects,
        project
      )
    }
    .skipNil()

    self.updateTitleViewData = drawerStateProjectsAndSelectedProject
      .map { drawerState, projects, selectedProject in
        DashboardTitleViewData(
          drawerState: drawerState,
          isArrowHidden: projects.count <= 1,
          currentProjectIndex: projects.firstIndex(of: selectedProject) ?? 0
        )
      }

    let updateDrawerStateToOpen = self.updateTitleViewData
      .map { $0.drawerState == .open }
      .skip(first: 1)

    self.presentProjectsDrawer = drawerStateProjectsAndSelectedProject
      .filter { drawerState, _, _ in drawerState == .open }
      .map { _, projects, selectedProject in
        projects.map { project in
          ProjectsDrawerData(
            project: project,
            indexNum: projects.firstIndex(of: project) ?? 0,
            isChecked: project == selectedProject
          )
        }
      }

    self.animateOutProjectsDrawer = updateDrawerStateToOpen
      .filter(isFalse)
      .ignoreValues()

    self.dismissProjectsDrawer = self.projectsDrawerDidAnimateOutProperty.signal

    self.goToProject = self.project
      .takeWhen(self.projectContextCellTappedProperty.signal)
      .map { ($0, RefTag.dashboard) }

    self.goToMessages = self.project
      .takeWhen(self.messagesCellTappedProperty.signal)

    self.focusScreenReaderOnTitleView = self.viewWillAppearAnimatedProperty.signal.ignoreValues()
      .filter { AppEnvironment.current.isVoiceOverRunning() }

    // MARK: - Tracking

    self.viewWillAppearAnimatedProperty.signal.observeValues { _ in
      AppEnvironment.current.ksrAnalytics.trackCreatorDashboardPageViewed()
    }

    _ = projects
      .takePairWhen(self.switchToProjectProperty.signal)
      .map { allProjects, param -> Project? in
        param.flatMap { find(projectForParam: $0, in: allProjects) }
      }
      .skipNil()
      .observeValues { switchedToProject in
        AppEnvironment.current.ksrAnalytics
          .trackCreatorDashboardSwitchProjectClicked(project: switchedToProject, refTag: RefTag.dashboard)
      }

    _ = self.project
      .takePairWhen(self.trackPostUpdateClickedProperty.signal)
      .observeValues { project, _ in
        AppEnvironment.current.ksrAnalytics.trackCreatorDashboardPostUpdateClicked(
          project: project,
          refTag: RefTag.dashboard
        )
      }
  }

  fileprivate let showHideProjectsDrawerProperty = MutableProperty(())
  public func showHideProjectsDrawer() {
    self.showHideProjectsDrawerProperty.value = ()
  }

  fileprivate let projectContextCellTappedProperty = MutableProperty(())
  public func projectContextCellTapped() {
    self.projectContextCellTappedProperty.value = ()
  }

  fileprivate let switchToProjectProperty = MutableProperty<Param?>(nil)
  public func `switch`(toProject param: Param) {
    self.switchToProjectProperty.value = param
  }

  fileprivate let activitiesNavigatedProperty = MutableProperty<Param?>(nil)
  public func activitiesNavigated(projectId: Param) {
    self.activitiesNavigatedProperty.value = projectId
  }

  fileprivate let messageThreadNavigatedProperty = MutableProperty<(Param, MessageThread)?>(nil)
  public func messageThreadNavigated(projectId: Param, messageThread: MessageThread) {
    self.messageThreadNavigatedProperty.value = (projectId, messageThread)
  }

  fileprivate let projectsDrawerDidAnimateOutProperty = MutableProperty(())
  public func dashboardProjectsDrawerDidAnimateOut() {
    self.projectsDrawerDidAnimateOutProperty.value = ()
  }

  fileprivate let trackPostUpdateClickedProperty = MutableProperty(())
  public func trackPostUpdateClicked() {
    self.trackPostUpdateClickedProperty.value = ()
  }

  fileprivate let viewDidLoadProperty = MutableProperty(())
  public func viewDidLoad() {
    self.viewDidLoadProperty.value = ()
  }

  fileprivate let viewWillAppearAnimatedProperty = MutableProperty(false)
  public func viewWillAppear(animated: Bool) {
    self.viewWillAppearAnimatedProperty.value = animated
  }

  fileprivate let viewWillDisappearProperty = MutableProperty(())
  public func viewWillDisappear() {
    self.viewWillDisappearProperty.value = ()
  }

  fileprivate let messagesCellTappedProperty = MutableProperty(())
  public func messagesCellTapped() {
    self.messagesCellTappedProperty.value = ()
  }

  public let animateOutProjectsDrawer: Signal<(), Never>
  public let dismissProjectsDrawer: Signal<(), Never>
  public let focusScreenReaderOnTitleView: Signal<(), Never>
  public let fundingData: Signal<
    (
      funding: [ProjectStatsEnvelope.FundingDateStats],
      project: Project
    ), Never
  >
  public let goToActivities: Signal<Project, Never>
  public let goToMessages: Signal<Project, Never>
  public let goToMessageThread: Signal<(Project, MessageThread), Never>
  public let goToProject: Signal<(Project, RefTag), Never>
  public let project: Signal<Project, Never>
  public let loaderIsAnimating: Signal<Bool, Never>
  public let presentProjectsDrawer: Signal<[ProjectsDrawerData], Never>
  public let referrerData: Signal<
    (
      cumulative: ProjectStatsEnvelope.CumulativeStats,
      project: Project, aggregates: ProjectStatsEnvelope.ReferralAggregateStats,
      stats: [ProjectStatsEnvelope.ReferrerStats]
    ), Never
  >
  public let rewardData: Signal<(stats: [ProjectStatsEnvelope.RewardStats], project: Project), Never>
  public let videoStats: Signal<ProjectStatsEnvelope.VideoStats, Never>
  public let updateTitleViewData: Signal<DashboardTitleViewData, Never>

  public var inputs: DashboardViewModelInputs { return self }
  public var outputs: DashboardViewModelOutputs { return self }
}

extension ProjectsDrawerData: Equatable {}
public func == (lhs: ProjectsDrawerData, rhs: ProjectsDrawerData) -> Bool {
  return lhs.project.id == rhs.project.id
}

extension DashboardTitleViewData: Equatable {}
public func == (lhs: DashboardTitleViewData, rhs: DashboardTitleViewData) -> Bool {
  return lhs.drawerState == rhs.drawerState &&
    lhs.currentProjectIndex == rhs.currentProjectIndex &&
    lhs.isArrowHidden == rhs.isArrowHidden
}

private func find(projectForParam param: Param?, in projects: [Project]) -> Project? {
  guard let param = param else { return nil }

  return projects.first { project in
    if case .id(project.id) = param { return true }
    if case .slug(project.slug) = param { return true }
    return false
  }
}
