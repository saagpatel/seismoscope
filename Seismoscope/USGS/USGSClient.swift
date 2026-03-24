import Foundation

/// Live URLSession implementation of the USGS FDSN Event API.
/// Queries `https://earthquake.usgs.gov/fdsnws/event/1/query` for earthquakes
/// within a ±10-minute window centered on `date`, within 500km of `region`.
final class USGSClient: USGSClientProtocol {
    private static let baseURL = "https://earthquake.usgs.gov/fdsnws/event/1/query"
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 10
        self.session = URLSession(configuration: config)
    }

    func queryEvents(near region: RegionPreset, around date: Date) async throws -> [USGSFeature] {
        let url = try buildURL(region: region, date: date)
        return try await fetchOnce(url: url, retryOn429: true)
    }

    // MARK: - Private

    private func fetchOnce(url: URL, retryOn429: Bool) async throws -> [USGSFeature] {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(from: url)
        } catch let urlError as URLError {
            throw USGSError.networkError(urlError)
        }

        guard let http = response as? HTTPURLResponse else {
            throw USGSError.networkError(URLError(.badServerResponse))
        }

        switch http.statusCode {
        case 200:
            break
        case 400:
            throw USGSError.httpError(400)
        case 429:
            if retryOn429 {
                try await Task.sleep(for: .seconds(60))
                return try await fetchOnce(url: url, retryOn429: false)
            }
            throw USGSError.rateLimited
        default:
            throw USGSError.httpError(http.statusCode)
        }

        do {
            let collection = try JSONDecoder().decode(USGSFeatureCollection.self, from: data)
            return collection.features
        } catch {
            throw USGSError.decodingError
        }
    }

    private func buildURL(region: RegionPreset, date: Date) throws -> URL {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let starttime = formatter.string(from: date.addingTimeInterval(-600))
        let endtime   = formatter.string(from: date.addingTimeInterval(1800))

        var components = URLComponents(string: Self.baseURL)!
        components.queryItems = [
            URLQueryItem(name: "format",         value: "geojson"),
            URLQueryItem(name: "starttime",      value: starttime),
            URLQueryItem(name: "endtime",        value: endtime),
            URLQueryItem(name: "latitude",       value: String(region.latitude)),
            URLQueryItem(name: "longitude",      value: String(region.longitude)),
            URLQueryItem(name: "maxradiuskm",    value: "500"),
            URLQueryItem(name: "minmagnitude",   value: "1.5"),
            URLQueryItem(name: "orderby",        value: "time"),
            URLQueryItem(name: "limit",          value: "20"),
        ]

        guard let url = components.url else {
            throw USGSError.httpError(0)
        }
        return url
    }
}
