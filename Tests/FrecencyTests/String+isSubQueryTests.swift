import Quick
import Nimble
@testable import Frecency

final class StringIsSubQuerySpec: QuickSpec {
    override func spec() {
        describe("String+isSubQuery") {
            it("should be case-insensitive") {
                expect("BRAD".isSubQuery(of: "bradford")).to(beTrue())
            }

            it("should match a full word") {
                expect("brad".isSubQuery(of: "brad")).to(beTrue())
            }
            
            it("should match multiple words") {
                expect("t d".isSubQuery(of: "team design")).to(beTrue())
                expect("tea des".isSubQuery(of: "team design")).to(beTrue())
                expect("Team Design".isSubQuery(of: "team design")).to(beTrue())
            }
            
            it("should match out of order") {
                expect("Design".isSubQuery(of: "team design")).to(beTrue())
                expect("bee and bir".isSubQuery(of: "birds and bees")).to(beTrue())
                expect("for form fort".isSubQuery(of: "formula fortitude fortuitous")).to(beTrue())
            }
            
            it("should ignore extra whitespace") {
                expect("  team    design  ".isSubQuery(of: "design team")).to(beTrue())
            }
            
            it("should not match if not a prefix") {
                expect("vogel".isSubQuery(of: "brad")).to(beFalse())
                expect("rad".isSubQuery(of: "brad")).to(beFalse())
            }
            
            it("should not match if search string is longer") {
                expect("bradford".isSubQuery(of: "brad")).to(beFalse())
            }
            
            it("should not match if one of the words in search string does not match") {
                expect("tear design".isSubQuery(of: "design team")).to(beFalse())
                expect("design team team".isSubQuery(of: "design team")).to(beFalse())
            }
        }
    }
}
