import XCTest
import Quick

@testable import FrecencyTests

QCKMain([
    FrecencySelectionTests.self
    FrecencySortingTests.self,
    StringIsSubQueryTests.self
])
