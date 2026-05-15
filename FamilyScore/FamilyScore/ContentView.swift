import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "figure.2.and.child.holdinghands")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Family Score")
                .font(.title)
        }
        .padding()
        .onAppear {
            #if DEBUG
            verifyAppGroup()
            #endif
        }
        .task {
            #if DEBUG
            await verifySupabaseConnection()
            #endif
        }
    }
}
