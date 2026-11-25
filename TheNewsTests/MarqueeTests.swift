import Foundation
import Testing
@testable import TheNews

@Suite("Marquee loop")
struct MarqueeTests {
    @Test("Does not move before the text has been measured")
    func zeroWidthStaysPut() {
        let shift = Marquee.shift(at: Date(timeIntervalSinceReferenceDate: 1_000), unitWidth: 0, speed: 40)
        #expect(shift == 0)
    }

    @Test("Moves at the given speed within one unit")
    func movesAtSpeed() {
        let shift = Marquee.shift(at: Date(timeIntervalSinceReferenceDate: 2), unitWidth: 200, speed: 40)
        #expect(shift == 80)
    }

    @Test("Wraps after one unit so the loop is seamless")
    func wrapsAfterOneUnit() {
        let shift = Marquee.shift(at: Date(timeIntervalSinceReferenceDate: 6), unitWidth: 200, speed: 40)
        #expect(shift == 40)
    }

    @Test("Keeps advancing as time passes")
    func advancesOverTime() {
        let earlier = Marquee.shift(at: Date(timeIntervalSinceReferenceDate: 10), unitWidth: 500, speed: 40)
        let later = Marquee.shift(at: Date(timeIntervalSinceReferenceDate: 11), unitWidth: 500, speed: 40)
        #expect(later - earlier == 40)
    }
}
