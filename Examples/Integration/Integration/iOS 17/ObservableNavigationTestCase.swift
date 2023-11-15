@_spi(Logging) import ComposableArchitecture
import Perception
import SwiftUI

struct ObservableNavigationTestCaseView: View {
  @State var store = Store(initialState: Feature.State()) {
    Feature()
  }

  var body: some View {
    NavigationStack(store: self.store.scope(state: \.path, action: \.path)) {
      NavigationLink(state: ObservableBasicsView.Feature.State()) {
        Text("Push feature")
      }
    } destination: { store in
      Form {
        Section {
          ObservableBasicsView(store: store)
        }
        Section {
          NavigationLink(state: ObservableBasicsView.Feature.State()) {
            Text("Push feature")
          }
        }
      }
    }
  }

  @Reducer
  struct Feature {
    @ObservableState
    struct State: Equatable {
      var path = StackState<ObservableBasicsView.Feature.State>()
    }
    enum Action {
      case path(
        StackAction<ObservableBasicsView.Feature.State, ObservableBasicsView.Feature.Action>
      )
    }
    var body: some ReducerOf<Self> {
      Reduce { state, action in
        .none
      }
      .forEach(\.path, action: \.path) {
        ObservableBasicsView.Feature()
      }
    }
  }
}
