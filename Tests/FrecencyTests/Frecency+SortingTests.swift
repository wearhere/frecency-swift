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
            
            it("should not sort after reset") {
                frecency.select("😄", for: "sm")
                frecency.reset()
                
                let results = frecency.sort(["😁", "😄", "😀"])
                let expectedResults: [Emoji] = ["😁", "😄", "😀"]
                expect(results).to(equal(expectedResults))
            }
            
            it("should sort when search query is empty") {
                frecency.select("😄", for: "sm")
                
                let results = frecency.sort(["😁", "😄", "😀"])
                let expectedResults: [Emoji] = ["😄", "😁", "😀"]
                expect(results).to(equal(expectedResults))
            }
            
            it("should sort asynchronously when search query is empty") {
                frecency.select("😄", for: "sm")
                
                waitUntil { done in
                    frecency.sort(["😁", "😄", "😀"]) { results in
                        let expectedResults: [Emoji] = ["😄", "😁", "😀"]
                        expect(results).to(equal(expectedResults))
                        done()
                    }
                }
            }
            
            it("should preserve sort order of non-recent selections") {
                frecency.select("😄", for: "sm")
                
                let results = frecency.sort(["😁", "🎉", "😄", "😀"])
                let expectedResults: [Emoji] = ["😄", "😁", "🎉", "😀"]
                expect(results).to(equal(expectedResults))
            }
            
            it("should preserve sort order of non-recent selections when sorting asynchronously") {
                frecency.select("😄", for: "sm")

                waitUntil { done in
                    frecency.sort(["😁", "🎉", "😄", "😀"], chunkSize: 2) { results in
                        let expectedResults: [Emoji] = ["😄", "😁", "🎉", "😀"]
                        expect(results).to(equal(expectedResults))
                        done()
                    }
                }
            }
            
            it("should guard against a chunk size of 0") {
                frecency.select("😄", for: "sm")

                waitUntil { done in
                    frecency.sort(["😁", "🎉", "😄", "😀"], chunkSize: 0) { results in
                        let expectedResults: [Emoji] = ["😄", "😁", "🎉", "😀"]
                        expect(results).to(equal(expectedResults))
                        done()
                    }
                }
            }
            
            it("can return only recent selections") {
                frecency.select("😄", for: "sm")
                
                let results = frecency.sort(["😁", "🎉", "😄", "😀"], limitToRecents: true)
                let expectedResults: [Emoji] = ["😄"]
                expect(results).to(equal(expectedResults))
            }
            
            it("can return only recent selections when sorting asynchronously") {
                frecency.select("😄", for: "sm")
                
                waitUntil { done in
                    frecency.sort(["😁", "🎉", "😄", "😀"], limitToRecents: true) { results in
                        let expectedResults: [Emoji] = ["😄"]
                        expect(results).to(equal(expectedResults))
                        done()
                    }
                }
            }
            
            it("should sort higher if search query was recently selected") {
                frecency.select("😄", for: "sm")
                
                let results = frecency.sort(["😁", "😄", "😀"], for: "sm")
                let expectedResults: [Emoji] = ["😄", "😁", "😀"]
                expect(results).to(equal(expectedResults))
            }
            
            it("should asynchronously sort higher if search query was recently selected") {
                frecency.select("😄", for: "sm")

                waitUntil { done in
                    frecency.sort(["😁", "😄", "😀"], for: "sm") { results in
                        let expectedResults: [Emoji] = ["😄", "😁", "😀"]
                        expect(results).to(equal(expectedResults))
                        done()
                    }
                }
            }
            
            it("should sort higher if search query is a subquery of recently-selected query") {
                frecency.select("😄", for: "smil")
                
                let results = frecency.sort(["😁", "😄", "😀"], for: "sm")
                let expectedResults: [Emoji] = ["😄", "😁", "😀"]
                expect(results).to(equal(expectedResults))
            }
            
            it("should sort higher if an ID was recently selected (with different query)") {
                frecency.select("😄", for: "smil")

                let results = frecency.sort(["😁", "😄", "😀"], for: "face")
                let expectedResults: [Emoji] = ["😄", "😁", "😀"]
                expect(results).to(equal(expectedResults))
            }
            
            it("should sort higher if an ID was recently selected (with no query)") {
                frecency.select("😄")

                let results = frecency.sort(["😁", "😄", "😀"], for: "face")
                let expectedResults: [Emoji] = ["😄", "😁", "😀"]
                expect(results).to(equal(expectedResults))
            }
            
            it("should sort higher if selections are more recent") {
                let now = Date().timeIntervalSince1970

                // We select 😄 3 times, but many days earlier.
                for _ in 0..<3 {
                    let time = now - 7 * day
                    frecency.select("😄", for: "sm", time: time)
                }

                // We select 😊 2 times, but within the last hour.
                for _ in 0..<2 {
                    let time = now - hour
                    frecency.select("😊", for: "sm", time: time)
                }
                
                let results = frecency.sort(["😄", "😀", "😊"], for: "sm")
                let expectedResults: [Emoji] = ["😊", "😄", "😀"]
                expect(results).to(equal(expectedResults))
            }
            
            it("should give non-exact matches a reduced score") {
                // We'll use this as an exact match.
                frecency.select("😄", for: "sm")
                
                // We'll use this as a sub-query match.
                frecency.select("😀", for: "smil")
                
                // We'll use this as an ID match.
                frecency.select("😊", for: "face")
                
                let results = frecency.sort(["😊", "😄", "😀", "🎉"], for: "sm")
                let expectedResults: [Emoji] = ["😄", "😀", "😊", "🎉"]
                expect(results).to(equal(expectedResults))
            }
            
            it("supports functional identifier") {
                frecency = Frecency<Emoji>(key: "emoji", resultIdentifier: .function({ $0.emoji }))
                
                frecency.select("😄", for: "smi")
                
                
                let results = frecency.sort(["😊", "😄"], for: "smi")
                let expectedResults: [Emoji] = ["😄", "😊"]
                expect(results).to(equal(expectedResults))
            }
            
            it("falls back on subquery matching when query entry is too old (> 14 days)") {
                let now = Date().timeIntervalSince1970

                let tooOld = now - 15 * day
                frecency.select("😄", for: "sm", time: tooOld)

                let moreRecent = now - 2 * day
                frecency.select("😄", for: "smile", time: moreRecent)
                
                let results = frecency.sort(["😀", "😊", "😄"], for: "sm")
                let expectedResults: [Emoji] = ["😄", "😀", "😊"]
                expect(results).to(equal(expectedResults))
            }
            
            it("falls back on recent selection matching when queries/subqueries are too old (> 14 days)") {
                let now = Date().timeIntervalSince1970
                
                let tooOld = now - 15 * day
                frecency.select("😄", for: "smile", time: tooOld)
                
                let moreRecent = now - 2 * day
                frecency.select("😄", for: "smi", time: moreRecent)
                
                let results = frecency.sort(["😀", "😊", "😄"], for: "smile")
                let expectedResults: [Emoji] = ["😄", "😀", "😊"]
                expect(results).to(equal(expectedResults))
            }
            
            it("is thread-safe") {
                frecency.select("😄", for: "sm")
                
                var results: [Emoji]!
                DispatchQueue.global(qos: .userInteractive).sync {
                    results = frecency.sort(["😁", "😄", "😀"], for: "sm")
                }
                let expectedResults: [Emoji] = ["😄", "😁", "😀"]
                expect(results).to(equal(expectedResults))
            }
        }
    }
}
