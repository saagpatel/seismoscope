import Foundation

/// Pure matching logic — no state, no side effects.
/// Matches a detected `SeismicEvent` against USGS catalog features.
enum USGSCorrelator {

    // MARK: - Public API

    /// Returns the best-matching USGS feature, or nil if none qualify.
    ///
    /// All three criteria must be satisfied:
    ///   (a) Time window:  |feature.time − event.onsetTime| < 10 minutes
    ///   (b) Magnitude:    feature.mag >= 1.5
    ///   (c) Distance:     Haversine(region → feature) < 500 km
    ///
    /// When multiple features qualify, returns the one closest in time.
    static func bestMatch(
        in features: [USGSFeature],
        for event: SeismicEvent,
        near region: RegionPreset
    ) -> USGSFeature? {
        let onsetMs = Int64(event.onsetTime.timeIntervalSince1970 * 1000)

        return features
            .filter { feature in
                guard let mag = feature.properties.mag, mag >= 1.5 else { return false }

                let timeDeltaMs = abs(feature.properties.time - onsetMs)
                guard timeDeltaMs < 600_000 else { return false }   // 10 minutes

                let coords = feature.geometry.coordinates
                guard coords.count >= 2 else { return false }
                let featureLon = coords[0]
                let featureLat = coords[1]

                let distKm = haversineKm(
                    lat1: region.latitude, lon1: region.longitude,
                    lat2: featureLat,      lon2: featureLon
                )
                return distKm < 500
            }
            .min { a, b in
                abs(a.properties.time - onsetMs) < abs(b.properties.time - onsetMs)
            }
    }

    // MARK: - Geometry

    /// Haversine distance in km between two lat/lng points (WGS84).
    ///
    ///   a = sin²(Δlat/2) + cos(lat1) · cos(lat2) · sin²(Δlon/2)
    ///   c = 2 · atan2(√a, √(1−a))
    ///   d = R · c   where R = 6371 km
    static func haversineKm(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let r = 6371.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180)
            * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return r * c
    }
}
