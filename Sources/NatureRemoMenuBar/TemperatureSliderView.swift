import AppKit

@MainActor
final class TemperatureSliderView: NSView {
    private let temperatures: [String]
    private let onCommit: (String) -> Void
    private let valueLabel = NSTextField(labelWithString: "")
    private let slider = CommitSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)
    private var committedTemperature: String?

    init(temperatures: [String], currentTemperature: String, onChange: @escaping (String) -> Void) {
        let sortedTemperatures = temperatures.sorted { (Double($0) ?? 0) < (Double($1) ?? 0) }
        self.temperatures = sortedTemperatures.isEmpty ? (16...30).map(String.init) : sortedTemperatures
        self.onCommit = onChange
        super.init(frame: NSRect(x: 0, y: 0, width: 220, height: 54))
        buildUI(currentTemperature: currentTemperature)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildUI(currentTemperature: String) {
        let titleLabel = NSTextField(labelWithString: "温度")
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)

        valueLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        valueLabel.alignment = .right

        let headerStack = NSStackView(views: [titleLabel, valueLabel])
        headerStack.orientation = .horizontal
        headerStack.distribution = .fillEqually
        headerStack.alignment = .centerY

        slider.minValue = 0
        slider.maxValue = Double(max(temperatures.count - 1, 0))
        slider.numberOfTickMarks = temperatures.count
        slider.allowsTickMarkValuesOnly = true
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(sliderChanged)
        slider.doubleValue = Double(index(for: currentTemperature))
        slider.onMouseUp = { [weak self] in
            self?.commitSelectedTemperature()
        }
        committedTemperature = selectedTemperature()

        let stack = NSStackView(views: [headerStack, slider])
        stack.orientation = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            headerStack.widthAnchor.constraint(equalTo: stack.widthAnchor),
            slider.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])

        updateValueLabel()
    }

    private func index(for temperature: String) -> Int {
        if let exactIndex = temperatures.firstIndex(of: temperature) {
            return exactIndex
        }

        let currentValue = Double(temperature) ?? Double(temperatures.first ?? "25") ?? 25
        return temperatures.indices.min {
            abs((Double(temperatures[$0]) ?? 0) - currentValue) < abs((Double(temperatures[$1]) ?? 0) - currentValue)
        } ?? 0
    }

    private func selectedTemperature() -> String {
        let index = min(max(Int(slider.doubleValue.rounded()), 0), temperatures.count - 1)
        return temperatures[index]
    }

    private func updateValueLabel() {
        valueLabel.stringValue = "\(selectedTemperature())℃"
    }

    @objc private func sliderChanged() {
        updateValueLabel()

        switch NSApp.currentEvent?.type {
        case .leftMouseDragged:
            return
        default:
            commitSelectedTemperature()
        }
    }

    private func commitSelectedTemperature() {
        let temperature = selectedTemperature()
        guard temperature != committedTemperature else { return }
        committedTemperature = temperature
        onCommit(temperature)
    }
}

private final class CommitSlider: NSSlider {
    var onMouseUp: (() -> Void)?

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        onMouseUp?()
    }
}
