import XCTest
import Quick

@testable import FrecencyTests

QCKMain([
    FrecencySelectionSpec.self,
    FrecencySortingSpec.self,
    StringIsSubQuerySpec.self
])
