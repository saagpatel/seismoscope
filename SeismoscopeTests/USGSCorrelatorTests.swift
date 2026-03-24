import Testing
@testable import Seismoscope
import Foundation

// MARK: - Helpers

private func makeFeature(
    id: String = "us7000test",
    mag: Double = 2.5,
    place: String = "Test Location",
    timeMsOffset: Int64 = 180_000,   // relative to a base epoch-ms
    baseTimeMs: Int64,
    latitude: Double = 37.44,        // ~120km from San Jose
    longitude: Double = -121.0
) -> USGSFeature {
    USGSFeature(
        id: id,
        properties: USGSProperties(mag: mag, place: place, time: baseTimeMs + timeMsOffset, url: nil),
        geometry: USGSGeometry(coordinates: [longitude, latitude, 10.0])
    )
}

private func makeEvent(onsetTime: Date) -> SeismicEvent {
    SeismicEvent(onsetTime: onsetTime, staLtaRatio: 5.0)
}

private let region = RegionPreset(name: "San Jose, CA", latitude: 37.33, longitude: -121.89)

// MARK: - USGSCorrelator Tests

@Suite("USGSCorrelator")
struct USGSCorrelatorTests {

    @Test("matches feature within time window, distance, and magnitude")
    func testMatchWithinCriteria() {
        let onsetDate = Date(timeIntervalSince1970: 1_705_320_000) // 2024-01-15 12:00:00 UTC
        let baseMs = Int64(onsetDate.timeIntervalSince1970 * 1000)
        let event = makeEvent(onsetTime: onsetDate)

        // Feature: +3 min, ~120 km from San Jose, M2.5
        let feature = makeFeature(timeMsOffset: 180_000, baseTimeMs: baseMs,
                                  latitude: 37.44, longitude: -121.0)

        let result = USGSCorrelator.bestMatch(in: [feature], for: event, near: region)
        #expect(result != nil)
        #expect(result?.id == feature.id)
    }

    @Test("no match when feature is outside 10-minute time window")
    func testNoMatchOutsideTimeWindow() {
        let onsetDate = Date(timeIntervalSince1970: 1_705_320_000)
        let baseMs = Int64(onsetDate.timeIntervalSince1970 * 1000)
        let event = makeEvent(onsetTime: onsetDate)

        // Feature: +15 min — exceeds 10-minute window
        let feature = makeFeature(timeMsOffset: 900_000, baseTimeMs: baseMs,
                                  latitude: 37.44, longitude: -121.0)

        let result = USGSCorrelator.bestMatch(in: [feature], for: event, near: region)
        #expect(result == nil)
    }

    @Test("no match when feature is beyond 500 km distance")
    func testNoMatchOutsideDistance() {
        let onsetDate = Date(timeIntervalSince1970: 1_705_320_000)
        let baseMs = Int64(onsetDate.timeIntervalSince1970 * 1000)
        let event = makeEvent(onsetTime: onsetDate)

        // Feature: +3 min but ~1,200 km away (Seattle area)
        let feature = makeFeature(timeMsOffset: 180_000, baseTimeMs: baseMs,
                                  latitude: 47.6, longitude: -122.3)

        let result = USGSCorrelator.bestMatch(in: [feature], for: event, near: region)
        #expect(result == nil)
    }

    @Test("no match when feature magnitude is below 1.5")
    func testNoMatchBelowMagnitude() {
        let onsetDate = Date(timeIntervalSince1970: 1_705_320_000)
        let baseMs = Int64(onsetDate.timeIntervalSince1970 * 1000)
        let event = makeEvent(onsetTime: onsetDate)

        // Feature: +3 min, nearby, but M1.0 — below threshold
        let feature = makeFeature(mag: 1.0, timeMsOffset: 180_000, baseTimeMs: baseMs,
                                  latitude: 37.44, longitude: -121.0)

        let result = USGSCorrelator.bestMatch(in: [feature], for: event, near: region)
        #expect(result == nil)
    }

    @Test("haversineKm returns expected distance for known coordinates")
    func testHaversine() {
        // San Jose → San Francisco: ~68 km
        let dist = USGSCorrelator.haversineKm(lat1: 37.33, lon1: -121.89, lat2: 37.77, lon2: -122.42)
        #expect(dist > 60 && dist < 80)

        // Same point → 0 km
        let zero = USGSCorrelator.haversineKm(lat1: 37.0, lon1: -122.0, lat2: 37.0, lon2: -122.0)
        #expect(zero < 0.001)
    }
}
