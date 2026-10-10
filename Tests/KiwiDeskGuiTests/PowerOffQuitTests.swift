import AppKit
import Foundation
import Testing

@testable import KiwiDesk

/// A logout, restart or shut down never waits for the unsaved-edits
/// question (#2135): macOS asks a menu-bar app only past its point
/// of no return, so the draft is discarded — on the power-off
/// notice, and again on the quit event's own reason.
@Suite("Power-off quit discards the draft (#2135)")
@MainActor
struct PowerOffQuitTests {
    private func quitEvent(reason: OSType?) -> NSAppleEventDescriptor {
        let event = NSAppleEventDescriptor(
            eventClass: AEEventClass(kCoreEventClass),
            eventID: AEEventID(kAEQuitApplication),
            targetDescriptor: nil,
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        if let reason {
            event.setParam(
                NSAppleEventDescriptor(enumCode: reason),
                forKeyword: AEKeyword(kAEQuitReason)
            )
        }
        return event
    }

    @Test("every power-off reason reads as one")
    func powerOffReasons() {
        let reasons = [
            kAELogOut, kAEReallyLogOut, kAEShowRestartDialog,
            kAEShowShutdownDialog, kAERestart, kAEShutDown,
        ]
        for reason in reasons {
            #expect(
                QuitReason.isPowerOff(quitEvent(reason: OSType(reason)))
            )
        }
    }

    @Test("a plain quit, Quit All or no event is not one")
    func otherQuits() {
        #expect(!QuitReason.isPowerOff(nil))
        #expect(!QuitReason.isPowerOff(quitEvent(reason: nil)))
        #expect(
            !QuitReason.isPowerOff(quitEvent(reason: OSType(kAEQuitAll)))
        )
        // Each half of the event's identity is checked on its own.
        let core = AEEventClass(kCoreEventClass)
        let misc = AEEventClass(kAEMiscStandards)
        let pairs = [
            (core, AEEventID(kAEOpenApplication)),
            (misc, AEEventID(kAEQuitApplication)),
        ]
        for (eventClass, eventID) in pairs {
            let other = NSAppleEventDescriptor(
                eventClass: eventClass,
                eventID: eventID,
                targetDescriptor: nil,
                returnID: AEReturnID(kAutoGenerateReturnID),
                transactionID: AETransactionID(kAnyTransactionID)
            )
            other.setParam(
                NSAppleEventDescriptor(enumCode: OSType(kAELogOut)),
                forKeyword: AEKeyword(kAEQuitReason)
            )
            #expect(!QuitReason.isPowerOff(other))
        }
    }

    private func source(_ file: String) throws -> String {
        try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent("Sources/KiwiDesk")
                .appendingPathComponent(file)
        )
    }

    @Test("the quit asks the reason before it would ask the user")
    func shouldTerminateDiscardsOnPowerOff() throws {
        let quit = try source("AppDelegate+Quit.swift")
        let reason = try #require(
            quit.range(of: "QuitReason.isPowerOff(")
        )
        let drop = try #require(
            quit.range(
                of: "dashboard.dropDraftForQuit()",
                range: reason.upperBound..<quit.endIndex
            )
        )
        let ask = try #require(quit.range(of: "dashboard.takeQuitAnswer()"))
        #expect(reason.lowerBound < drop.lowerBound)
        #expect(drop.lowerBound < ask.lowerBound)
    }

    @Test("the power-off notice drops the draft with the sheets")
    func noticeDropsTheDraft() throws {
        let quit = try source("AppDelegate+Quit.swift")
        let notice = try #require(
            quit.range(of: "NSWorkspace.willPowerOffNotification")
        )
        let clear = try #require(
            quit.range(of: "QuitSheets.clearOwnWindows()")
        )
        let observer = quit[notice.upperBound..<clear.lowerBound]
        #expect(observer.contains("dashboardIfCreated?.dropDraftForQuit()"))
    }
}
