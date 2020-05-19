import Quick
import Nimble
import Foundation
@testable import Frecency

final class FrecencySortingSpec: QuickSpec {
    override func spec() {
        let hour: TimeInterval = 60 * 60
        let day: TimeInterval = 24 * hour
        
        let defaultsKey = "com.frecency.defaults.emoji"
        var frecency: Frecency<Emoji>!
        beforeEach {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
            frecency = Frecency<Emoji>(key: "emoji", resultIdentifier: .keyPath(\.emoji))
        }
        
        describe("sort") {
            it("should not sort if frecency is empty") {
                let results = frecency.sort(["😁", "😄", "😀"], for: "sm")
                let expectedResults: [Emoji] = ["😁", "😄", "😀"]
                expect(results).to(equal(expectedResults))
            }
            
            it("should sort if search query is empty") {
                expect { try frecency.select("😄", for: "sm") }.toNot(throwError())
                
                let results = frecency.sort(["😁", "😄", "😀"])
                let expectedResults: [Emoji] = ["😄", "😁", "😀"]
                expect(results).to(equal(expectedResults))
            }
            
            it("should sort higher if search query was recently selected") {
              expect { try frecency.select("😄", for: "sm") }.toNot(throwError())

              let results = frecency.sort(["😁", "😄", "😀"], for: "sm")
              let expectedResults: [Emoji] = ["😄", "😁", "😀"]
              expect(results).to(equal(expectedResults))
            }
            
            it("should sort higher if search query is a subquery of recently-selected query") {
                expect { try frecency.select("😄", for: "smil") }.toNot(throwError())
                
                let results = frecency.sort(["😁", "😄", "😀"], for: "sm")
                let expectedResults: [Emoji] = ["😄", "😁", "😀"]
                expect(results).to(equal(expectedResults))
            }
            
            it("should sort higher if an ID was recently selected") {
                expect { try frecency.select("😄", for: "smil") }.toNot(throwError())

                let results = frecency.sort(["😁", "😄", "😀"], for: "face")
                let expectedResults: [Emoji] = ["😄", "😁", "😀"]
                expect(results).to(equal(expectedResults))
            }
            
            it("should sort higher if selections are more recent") {
                let now = Date().timeIntervalSince1970

                // We select 😄 3 times, but many days earlier.
                for _ in 0..<3 {
                    let time = now - 7 * day
                    expect { try frecency.select("😄", for: "sm", time: time) }.toNot(throwError())
                }

                // We select 😊 2 times, but within the last hour.
                for _ in 0..<2 {
                    let time = now - hour
                    expect { try frecency.select("😊", for: "sm", time: time) }.toNot(throwError())
                }
                
                let results = frecency.sort(["😄", "😀", "😊"], for: "sm")
                let expectedResults: [Emoji] = ["😊", "😄", "😀"]
                expect(results).to(equal(expectedResults))
            }
            
            it("should give non-exact matches a reduced score") {
                // We'll use this as an exact match.
                expect { try frecency.select("😄", for: "sm") }.toNot(throwError())
                
                // We'll use this as a sub-query match.
                expect { try frecency.select("😀", for: "smil") }.toNot(throwError())
                
                // We'll use this as an ID match.
                expect { try frecency.select("😊", for: "face") }.toNot(throwError())
                
                let results = frecency.sort(["😊", "😄", "😀", "🎉"], for: "sm")
                let expectedResults: [Emoji] = ["😄", "😀", "😊", "🎉"]
                expect(results).to(equal(expectedResults))
            }
            
            it("supports functional identifier") {
                frecency = Frecency<Emoji>(key: "emoji", resultIdentifier: .function({ $0.emoji }))
                
                expect { try frecency.select("😄", for: "smi") }.toNot(throwError())
                
                
                let results = frecency.sort(["😊", "😄"], for: "smi")
                let expectedResults: [Emoji] = ["😄", "😊"]
                expect(results).to(equal(expectedResults))
            }
            
            it("falls back on subquery matching when query entry is too old (> 14 days)") {
                let now = Date().timeIntervalSince1970

                let tooOld = now - 15 * day
                expect { try frecency.select("😄", for: "sm", time: tooOld) }.toNot(throwError())

                let moreRecent = now - 2 * day
                expect { try frecency.select("😄", for: "smile", time: moreRecent) }.toNot(throwError())
                
                let results = frecency.sort(["😀", "😊", "😄"], for: "sm")
                let expectedResults: [Emoji] = ["😄", "😀", "😊"]
                expect(results).to(equal(expectedResults))
            }
            
            it("falls back on recent selection matching when queries/subqueries are too old (> 14 days)") {
                let now = Date().timeIntervalSince1970
                
                let tooOld = now - 15 * day
                expect { try frecency.select("😄", for: "smile", time: tooOld) }.toNot(throwError())
                
                let moreRecent = now - 2 * day
                expect { try frecency.select("😄", for: "smi", time: moreRecent) }.toNot(throwError())
                
                let results = frecency.sort(["😀", "😊", "😄"], for: "smile")
                let expectedResults: [Emoji] = ["😄", "😀", "😊"]
                expect(results).to(equal(expectedResults))
            }
        }
    }
}
