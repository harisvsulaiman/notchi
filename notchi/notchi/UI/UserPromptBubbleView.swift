import SwiftUI

struct IMBubbleShape: Shape {
    static let tailWidth: CGFloat = 6
    static let tailRadius: CGFloat = 4
    static let cornerRadius: CGFloat = 18

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let r = Self.cornerRadius
        let tailW = Self.tailWidth
        let tailR = Self.tailRadius

        var path = Path()

        path.move(to: CGPoint(x: r, y: 0))

        // Top edge to top-right corner
        path.addLine(to: CGPoint(x: w - tailW - r, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: w - tailW, y: r),
            control: CGPoint(x: w - tailW, y: 0)
        )

        // Right edge down to tail
        path.addLine(to: CGPoint(x: w - tailW, y: h - tailR))

        // Tail curve
        path.addQuadCurve(
            to: CGPoint(x: w, y: h),
            control: CGPoint(x: w - tailW, y: h)
        )
        path.addQuadCurve(
            to: CGPoint(x: w - tailW - tailR, y: h - tailR),
            control: CGPoint(x: w - tailW - tailR, y: h)
        )

        // Bottom edge to bottom-left
        path.addLine(to: CGPoint(x: r, y: h - tailR))
        path.addQuadCurve(
            to: CGPoint(x: 0, y: h - tailR - r),
            control: CGPoint(x: 0, y: h - tailR)
        )

        // Left edge to top-left
        path.addLine(to: CGPoint(x: 0, y: r))
        path.addQuadCurve(
            to: CGPoint(x: r, y: 0),
            control: CGPoint(x: 0, y: 0)
        )

        path.closeSubpath()
        return path
    }
}

struct UserPromptBubbleView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundColor(.white)
            .padding(.leading, 14)
            .padding(.trailing, 14 + IMBubbleShape.tailWidth)
            .padding(.top, 10)
            .padding(.bottom, 10 + IMBubbleShape.tailRadius)
            .background(
                IMBubbleShape()
                    .fill(TerminalColors.iMessageBlue)
            )
    }
}
