import LyricoKit
import SwiftUI

struct ContentView: View {
  var body: some View {
    Text("Lyrico \(Lyrico.version)")
      .font(.largeTitle)
      .padding()
      .frame(minWidth: 400, minHeight: 300)
  }
}

#Preview {
  ContentView()
}
