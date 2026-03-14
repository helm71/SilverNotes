import SwiftUI
import PencilKit

struct DrawingView: UIViewRepresentable {
    @Binding var drawingData: Data?

    func makeCoordinator() -> Coordinator {
        Coordinator(drawingData: $drawingData)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .systemBackground
        canvas.tool = PKInkingTool(.pen, color: .label, width: 3)

        if let data = drawingData, let drawing = try? PKDrawing(data: data) {
            canvas.drawing = drawing
        }
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if let data = drawingData,
           let drawing = try? PKDrawing(data: data),
           uiView.drawing.dataRepresentation() != data {
            uiView.drawing = drawing
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var drawingData: Data?

        init(drawingData: Binding<Data?>) {
            self._drawingData = drawingData
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            drawingData = canvasView.drawing.dataRepresentation()
        }
    }
}

struct DrawingEditorView: View {
    @Binding var drawingData: Data?
    @State private var selectedTool: DrawingTool = .pen
    @State private var selectedColor: Color = .primary
    @State private var strokeWidth: CGFloat = 3

    enum DrawingTool: String, CaseIterable {
        case pen, marker, eraser

        var systemImage: String {
            switch self {
            case .pen: "pencil"
            case .marker: "highlighter"
            case .eraser: "eraser"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 16) {
                ForEach(DrawingTool.allCases, id: \.self) { tool in
                    Button {
                        selectedTool = tool
                    } label: {
                        Image(systemName: tool.systemImage)
                            .font(.title3)
                            .foregroundStyle(selectedTool == tool ? .blue : .secondary)
                            .padding(8)
                            .background(selectedTool == tool ? Color.blue.opacity(0.1) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                Divider().frame(height: 24)
                ColorPicker("", selection: $selectedColor)
                    .labelsHidden()
                    .frame(width: 40)
                Slider(value: $strokeWidth, in: 1...20, step: 1)
                    .frame(width: 80)
                Spacer()
                Button {
                    drawingData = PKDrawing().dataRepresentation()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .overlay(alignment: .bottom) {
                Divider()
            }

            DrawingView(drawingData: $drawingData)
        }
    }
}
