import Quick
import Nimble
import Foundation
@testable import Frecency

final class FrecencySelectionSpec: QuickSpec {
    override func spec() {
        let defaultsKey = "com.frecency.defaults.emoji"
        var frecency: Frecency<Emoji>!
        beforeEach {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
            frecency = Frecency<Emoji>(key: "emoji", resultIdentifier: .keyPath(\.emoji))
        }
        
        describe("select") {
            it("saves to UserDefaults") {
                frecency.select("😄", for: "sm")
                frecency.synchronize()
                
                let savedData = UserDefaults.standard.data(forKey: defaultsKey)
                expect(savedData).toNot(beNil())
            }
            
            it("loads from UserDefaults") {
                frecency.select("😄", for: "sm")
                frecency.synchronize()
                
                let frecency2 = Frecency<Emoji>(key: "emoji", resultIdentifier: .keyPath(\.emoji))
                frecency2.synchronize()
                expect(frecency2.frecency).to(equal(frecency.frecency))
            }
            
            it("does not reload from UserDefaults after first load") {
                let frecency2 = Frecency<Emoji>(key: "emoji", resultIdentifier: .keyPath(\.emoji))
                frecency2.synchronize()
                
                frecency.select("😄", for: "sm")
                frecency.synchronize()
                
                expect(frecency2.frecency).toNot(equal(frecency.frecency))
            }
            
            it("stores multiple queries") {
                let time1: TimeInterval = 1589843274.5214009
                frecency.select("😄", for: "sm", time: time1)

                let time2: TimeInterval = 1589843421.4224958
                frecency.select("😁", for: "grin", time: time2)
                
                frecency.synchronize()
                expect(frecency.frecency).to(equal(FrecencyData(
                    queries: [
                        "sm": ["😄": Selection(timesSelected: 1, selectedAt: [time1])],
                        "grin": ["😁": Selection(timesSelected: 1, selectedAt: [time2])]
                    ],
                    selections: [
                        "😄": Selection(timesSelected: 1, selectedAt: [time1]),
                        "😁": Selection(timesSelected: 1, selectedAt: [time2])
                    ],
                    recentSelections: ["😁", "😄"])))
            }
            
            it("stores different selections for the same query") {
                let time1: TimeInterval = 1589843274.5214009
                frecency.select("😄", for: "sm", time: time1)
                
                let time2: TimeInterval = 1589843421.4224958
                frecency.select("😀", for: "sm", time: time2)
                
                frecency.synchronize()
                expect(frecency.frecency).to(equal(FrecencyData(
                    queries: [
                        "sm": [
                            "😄": Selection(timesSelected: 1, selectedAt: [time1]),
                            "😀": Selection(timesSelected: 1, selectedAt: [time2])
                        ],
                    ],
                    selections: [
                        "😄": Selection(timesSelected: 1, selectedAt: [time1]),
                        "😀": Selection(timesSelected: 1, selectedAt: [time2])
                    ],
                    recentSelections: ["😀", "😄"])))
            }
            
            it("stores selections multiple times") {
                let time1: TimeInterval = 1589843274.5214009
                frecency.select("😄", for: "sm", time: time1)

                let time2: TimeInterval = 1589843421.4224958
                frecency.select("😄", for: "sm", time: time2)

                let time3: TimeInterval = 1589844048.952414
                frecency.select("😄", for: "sm", time: time3)

                frecency.synchronize()
                expect(frecency.frecency).to(equal(FrecencyData(
                    queries: [
                        "sm": [
                            "😄": Selection(timesSelected: 3, selectedAt: [time1, time2, time3])
                        ],
                    ],
                    selections: [
                        "😄": Selection(timesSelected: 3, selectedAt: [time1, time2, time3])
                    ],
                    recentSelections: ["😄"])))
            }
            
            it("stores same selections with different queries") {
                let time1: TimeInterval = 1589843274.5214009
                frecency.select("😄", for: "sm", time: time1)
                
                let time2: TimeInterval = 1589843421.4224958
                frecency.select("😄", for: "sm", time: time2)
                
                let time3: TimeInterval = 1589844048.952414
                frecency.select("😄", for: "smi", time: time3)
                
                frecency.synchronize()
                expect(frecency.frecency).to(equal(FrecencyData(
                    queries: [
                        "sm": [
                            "😄": Selection(timesSelected: 2, selectedAt: [time1, time2])
                        ],
                        "smi": [
                            "😄": Selection(timesSelected: 1, selectedAt: [time3])
                        ],
                    ],
                    selections: [
                        "😄": Selection(timesSelected: 3, selectedAt: [time1, time2, time3])
                    ],
                    recentSelections: ["😄"])))
            }
            
            it("limits number of timestamps per query") {
                var storageLimits = Frecency<Emoji>.StorageLimits()
                storageLimits.timestamps = 3
                frecency = Frecency(key: "emoji", resultIdentifier: .keyPath(\.emoji), storageLimits: storageLimits)
                
                let time1: TimeInterval = 1589843274.5214009
                frecency.select("😄", for: "sm", time: time1)
                
                let time2: TimeInterval = 1589843421.4224958
                frecency.select("😄", for: "sm", time: time2)
                
                let time3: TimeInterval = 1589844048.952414
                frecency.select("😄", for: "sm", time: time3)
                
                let time4: TimeInterval = 1589844420.952584
                frecency.select("😄", for: "sm", time: time4)
                
                frecency.synchronize()
                expect(frecency.frecency).to(equal(FrecencyData(
                    queries: [
                        "sm": [
                            "😄": Selection(timesSelected: 4, selectedAt: [time2, time3, time4])
                        ],
                    ],
                    selections: [
                        "😄": Selection(timesSelected: 4, selectedAt: [time2, time3, time4])
                    ],
                    recentSelections: ["😄"])))
            }
            
            it("limits number of timestamps per selection") {
                var storageLimits = Frecency<Emoji>.StorageLimits()
                storageLimits.timestamps = 3
                frecency = Frecency(key: "emoji", resultIdentifier: .keyPath(\.emoji), storageLimits: storageLimits)
                
                let time1: TimeInterval = 1589843274.5214009
                frecency.select("😄", for: "sm", time: time1)
                
                let time2: TimeInterval = 1589843421.4224958
                frecency.select("😄", for: "smi", time: time2)
                
                let time3: TimeInterval = 1589844048.952414
                frecency.select("😄", for: "sm", time: time3)
                
                let time4: TimeInterval = 1589844420.952584
                frecency.select("😄", for: "smi", time: time4)
                
                frecency.synchronize()
                expect(frecency.frecency).to(equal(FrecencyData(
                    queries: [
                        "sm": [
                            "😄": Selection(timesSelected: 2, selectedAt: [time1, time3])
                        ],
                        "smi": [
                            "😄": Selection(timesSelected: 2, selectedAt: [time2, time4])
                        ],
                    ],
                    selections: [
                        "😄": Selection(timesSelected: 4, selectedAt: [time2, time3, time4])
                    ],
                    recentSelections: ["😄"])))
            }
            
            it("limits number of IDs saved") {
                var storageLimits = Frecency<Emoji>.StorageLimits()
                storageLimits.recentSelections = 2
                frecency = Frecency(key: "emoji", resultIdentifier: .keyPath(\.emoji), storageLimits: storageLimits)

                let time1: TimeInterval = 1589843274.5214009
                frecency.select("😄", for: "sm", time: time1)
                
                let time2: TimeInterval = 1589843421.4224958
                frecency.select("😀", for: "sm", time: time2)
                
                let time3: TimeInterval = 1589844048.952414
                frecency.select("😁", for: "grin", time: time3)
                
                let time4: TimeInterval = 1589844420.952584
                frecency.select("😁", for: "gri", time: time4)
                
                frecency.synchronize()
                expect(frecency.frecency).to(equal(FrecencyData(
                    queries: [
                        "sm": ["😀": Selection(timesSelected: 1, selectedAt: [time2])],
                        "grin": ["😁": Selection(timesSelected: 1, selectedAt: [time3])],
                        "gri": ["😁": Selection(timesSelected: 1, selectedAt: [time4])]
                    ],
                    selections: [
                        "😀": Selection(timesSelected: 1, selectedAt: [time2]),
                        "😁": Selection(timesSelected: 2, selectedAt: [time3, time4])
                    ],
                    recentSelections: ["😁", "😀"])))
            }
        }
    }
}
