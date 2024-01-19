import ComposableArchitecture
import XCTest

@testable import SyncUps

@MainActor
final class AppFeatureTests: XCTestCase {
  func testDelete() async throws {
    let syncUp = SyncUp.mock

    let store = TestStore(
      initialState: AppFeature.State(syncUpsList: SyncUpsList.State(syncUps: [syncUp]))
    ) {
      AppFeature()
    }

    await store.send(.syncUpsList(.syncUpTapped(id: syncUp.id))) {
      let syncUp = try XCTUnwrap($0.syncUpsList.$syncUps[id: syncUp.id])
      $0.path[id: 0] = .detail(SyncUpDetail.State(syncUp: syncUp))
    }

    await store.send(.path(.element(id: 0, action: .detail(.deleteButtonTapped)))) {
      $0.path[id: 0, case: \.detail]?.destination = .alert(.deleteSyncUp)
    }

    await store.send(
      .path(.element(id: 0, action: .detail(.destination(.presented(.alert(.confirmDeletion))))))
    ) {
      $0.path[id: 0, case: \.detail]?.destination = nil
    }

    await store.receive(\.path[id:0].detail.delegate.deleteSyncUp) {
      $0.syncUpsList.syncUps = []
    }
    await store.receive(\.path.popFrom) {
      $0.path = StackState()
    }
  }

  func testDetailEdit() async throws {
    var syncUp = SyncUp.mock
    let savedData = LockIsolated(Data?.none)

    let store = TestStore(
      initialState: AppFeature.State(syncUpsList: SyncUpsList.State(syncUps: [syncUp]))
    ) {
      AppFeature()
    }

    await store.send(.syncUpsList(.syncUpTapped(id: syncUp.id))) {
      $0.path[id: 0] = .detail(SyncUpDetail.State(syncUp: $0.syncUpsList.$syncUps[id: syncUp.id]!))
    }

    await store.send(.path(.element(id: 0, action: .detail(.editButtonTapped)))) {
      $0.path[id: 0, case: \.detail]?.destination = .edit(
        SyncUpForm.State(syncUp: syncUp)
      )
    }

    syncUp.title = "Blob"
    await store.send(
      .path(
        .element(
          id: 0,
          action: .detail(.destination(.presented(.edit(.set(\.syncUp, syncUp)))))
        )
      )
    ) {
      $0.path[id: 0, case: \.detail]?.$destination[case: \.edit]?.syncUp.title = "Blob"
    }

    await store.send(.path(.element(id: 0, action: .detail(.doneEditingButtonTapped)))) {
      $0.path[id: 0, case: \.detail]?.destination = nil
      $0.path[id: 0, case: \.detail]?.syncUp.title = "Blob"
    }
    .finish()
  }

  func testRecording() async {
    let speechResult = SpeechRecognitionResult(
      bestTranscription: Transcription(formattedString: "I completed the project"),
      isFinal: true
    )
    let syncUp = SyncUp(
      id: SyncUp.ID(),
      attendees: [
        Attendee(id: Attendee.ID()),
        Attendee(id: Attendee.ID()),
        Attendee(id: Attendee.ID()),
      ],
      duration: .seconds(6)
    )

    let store = TestStore(
      initialState: AppFeature.State(
        path: StackState([
          .detail(SyncUpDetail.State(syncUp: Shared(syncUp))),
          .record(RecordMeeting.State(syncUp: syncUp)),
        ])
      )
    ) {
      AppFeature()
    } withDependencies: {
      $0.date.now = Date(timeIntervalSince1970: 1_234_567_890)
      $0.continuousClock = ImmediateClock()
      $0.speechClient.authorizationStatus = { .authorized }
      $0.speechClient.startTask = { @Sendable _ in
        AsyncThrowingStream { continuation in
          continuation.yield(speechResult)
          continuation.finish()
        }
      }
      $0.uuid = .incrementing
    }
    store.exhaustivity = .off

    await store.send(.path(.element(id: 1, action: .record(.onTask))))
    await store.receive(\.path[id:1].record.delegate.save) {
      $0.path[id: 0, case: \.detail]?.syncUp.meetings = [
        Meeting(
          id: Meeting.ID(UUID(0)),
          date: Date(timeIntervalSince1970: 1_234_567_890),
          transcript: "I completed the project"
        )
      ]
    }
    await store.receive(\.path.popFrom) {
      XCTAssertEqual($0.path.count, 1)
    }
  }
}
