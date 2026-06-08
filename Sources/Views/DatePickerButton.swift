import SwiftUI

struct DatePickerButton: View {
    @Binding var selection: Date
    var format: Date.FormatStyle = .dateTime.month(.wide).day().year()

    @State private var showingPicker = false

    var body: some View {
        Button(selection.formatted(format)) {
            showingPicker.toggle()
        }
        .buttonStyle(.bordered)
        .popover(isPresented: $showingPicker) {
            GraphicalDatePicker(selection: $selection)
                .padding()
        }
    }
}

// NSViewRepresentable wrapper so we can set focusRingType = .none, which
// SwiftUI's .focusEffectDisabled() cannot reach on the AppKit layer.
private struct GraphicalDatePicker: NSViewRepresentable {
    @Binding var selection: Date

    func makeNSView(context: Context) -> NSDatePicker {
        let picker = NSDatePicker()
        picker.datePickerStyle = .clockAndCalendar
        picker.datePickerElements = .yearMonthDay
        picker.focusRingType = .none
        picker.isBordered = false
        picker.target = context.coordinator
        picker.action = #selector(Coordinator.dateChanged(_:))
        return picker
    }

    func updateNSView(_ picker: NSDatePicker, context: Context) {
        picker.dateValue = selection
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    @MainActor
    final class Coordinator: NSObject {
        var selection: Binding<Date>

        init(selection: Binding<Date>) {
            self.selection = selection
        }

        @objc func dateChanged(_ sender: NSDatePicker) {
            selection.wrappedValue = sender.dateValue
        }
    }
}
