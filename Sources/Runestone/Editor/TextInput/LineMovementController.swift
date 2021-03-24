//
//  LineMovementController.swift
//  
//
//  Created by Simon on 21/03/2021.
//

import UIKit

protocol LineMovementControllerDelegate: AnyObject {
    func lineMovementController(_ controller: LineMovementController, numberOfLineFragmentsIn line: DocumentLineNode) -> Int
    func lineMovementController(_ controller: LineMovementController, lineFragmentNodeContainingCharacterAt location: Int, in line: DocumentLineNode) -> LineFragmentNode
    func lineMovementController(_ controller: LineMovementController, lineFragmentNodeAtIndex index: Int, in line: DocumentLineNode) -> LineFragmentNode
}

final class LineMovementController {
    weak var delegate: LineMovementControllerDelegate?
    var lineManager: LineManager
    var stringView: StringView

    private var currentDelegate: LineMovementControllerDelegate {
        if let delegate = delegate {
            return delegate
        } else {
            fatalError("Delegate of \(type(of: self)) is unavailable")
        }
    }

    init(lineManager: LineManager, stringView: StringView) {
        self.lineManager = lineManager
        self.stringView = stringView
    }

    func location(from location: Int, in direction: UITextLayoutDirection, offset: Int) -> Int? {
        let newLocation: Int?
        switch direction {
        case .left:
            newLocation = locationForMoving(fromLocation: location, by: offset * -1)
        case .right:
            newLocation = locationForMoving(fromLocation: location, by: offset)
        case .up:
            newLocation = locationForMoving(lineOffset: offset * -1, fromLineContainingCharacterAt: location)
        case .down:
            newLocation = locationForMoving(lineOffset: offset, fromLineContainingCharacterAt: location)
        @unknown default:
            newLocation = nil
        }
        if let newLocation = newLocation, newLocation >= 0 && newLocation <= stringView.string.length {
            return newLocation
        } else {
            return nil
        }
    }
}

private extension LineMovementController {
    private func locationForMoving(fromLocation location: Int, by offset: Int) -> Int {
        let naiveNewLocation = location + offset
        guard naiveNewLocation >= 0 && naiveNewLocation <= stringView.string.length else {
            return location
        }
        guard naiveNewLocation > 0 && naiveNewLocation < stringView.string.length else {
            return naiveNewLocation
        }
        let range = stringView.string.rangeOfComposedCharacterSequence(at: naiveNewLocation)
        guard naiveNewLocation > range.location && naiveNewLocation < range.location + range.length else {
            return naiveNewLocation
        }
        if offset < 0 {
            return location - range.length
        } else {
            return location + range.length
        }
    }

    private func locationForMoving(lineOffset: Int, fromLineContainingCharacterAt location: Int) -> Int {
        guard let line = lineManager.line(containingCharacterAt: location) else {
            return location
        }
        let lineLocalLocation = min(max(location - line.location, 0), line.data.totalLength - 1)
        let lineFragmentNode = currentDelegate.lineMovementController(self, lineFragmentNodeContainingCharacterAt: lineLocalLocation, in: line)
        let lineFragmentLocalLocation = lineLocalLocation - lineFragmentNode.location
        return locationForMoving(lineOffset: lineOffset, fromLocation: lineFragmentLocalLocation, inLineFragmentAt: lineFragmentNode.index, of: line)
    }

    private func locationForMoving(lineOffset: Int, fromLocation location: Int, inLineFragmentAt lineFragmentIndex: Int, of line: DocumentLineNode) -> Int {
        if lineOffset < 0 {
            return locationForMovingUpwards(lineOffset: abs(lineOffset), fromLocation: location, inLineFragmentAt: lineFragmentIndex, of: line)
        } else if lineOffset > 0 {
            return locationForMovingDownwards(lineOffset: lineOffset, fromLocation: location, inLineFragmentAt: lineFragmentIndex, of: line)
        } else {
            // lineOffset is 0 so we shouldn't change the line
            let destinationLineFragmentNode = currentDelegate.lineMovementController(self, lineFragmentNodeAtIndex: lineFragmentIndex, in: line)
            let lineLocation = line.location
            let preferredLocation = lineLocation + destinationLineFragmentNode.location + location
            let maximumLocation = lineLocation + line.data.length
            return min(preferredLocation, maximumLocation)
        }
    }

    private func locationForMovingUpwards(lineOffset: Int, fromLocation location: Int, inLineFragmentAt lineFragmentIndex: Int, of line: DocumentLineNode) -> Int {
        let takeLineCount = min(lineFragmentIndex, lineOffset)
        let remainingLineOffset = lineOffset - takeLineCount
        guard remainingLineOffset > 0 else {
            return locationForMoving(lineOffset: 0, fromLocation: location, inLineFragmentAt: lineFragmentIndex - takeLineCount, of: line)
        }
        let lineIndex = line.index
        guard lineIndex > 0 else {
            // We've reached the beginning of the document so we move to the first character.
            return 0
        }
        let previousLine = lineManager.line(atRow: lineIndex - 1)
        let numberOfLineFragments = currentDelegate.lineMovementController(self, numberOfLineFragmentsIn: previousLine)
        let newLineFragmentIndex = numberOfLineFragments - 1
        return locationForMovingUpwards(lineOffset: remainingLineOffset - 1, fromLocation: location, inLineFragmentAt: newLineFragmentIndex, of: previousLine)
    }

    private func locationForMovingDownwards(lineOffset: Int, fromLocation location: Int, inLineFragmentAt lineFragmentIndex: Int, of line: DocumentLineNode) -> Int {
        let numberOfLineFragments = currentDelegate.lineMovementController(self, numberOfLineFragmentsIn: line)
        let takeLineCount = min(numberOfLineFragments - lineFragmentIndex - 1, lineOffset)
        let remainingLineOffset = lineOffset - takeLineCount
        guard remainingLineOffset > 0 else {
            return locationForMoving(lineOffset: 0, fromLocation: location, inLineFragmentAt: lineFragmentIndex + takeLineCount, of: line)
        }
        let lineIndex = line.index
        guard lineIndex < lineManager.lineCount - 1 else {
            // We've reached the end of the document so we move to the last character.
            return line.location + line.data.totalLength
        }
        let nextLine = lineManager.line(atRow: lineIndex + 1)
        return locationForMovingDownwards(lineOffset: remainingLineOffset - 1, fromLocation: location, inLineFragmentAt: 0, of: nextLine)
    }
}