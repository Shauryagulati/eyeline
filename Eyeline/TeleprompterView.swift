import SwiftUI

@MainActor
final class TeleprompterViewModel: ObservableObject {
    @Published var offset: Double = 0
    let script: String
    init(script: String) { self.script = script }
}

struct TeleprompterView: View {
    @ObservedObject var model: TeleprompterViewModel

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.black.opacity(0.85))

            Text(model.script)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.horizontal, 18)
                .offset(y: 12 - model.offset)   // scrolls upward as offset grows
                .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(width: 360, height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
