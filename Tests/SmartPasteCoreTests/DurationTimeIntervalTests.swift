import SmartPasteCore
import Testing

struct DurationTimeIntervalTests {
    @Test(arguments: [
        (Duration.zero, 0.0),
        (.milliseconds(150), 0.15),
        (.milliseconds(2500), 2.5),
        (.seconds(5), 5.0),
    ])
    func convertsToSecondsForFoundationTimers(duration: Duration, seconds: Double) {
        #expect(abs(duration.timeInterval - seconds) < 1e-12)
    }
}
