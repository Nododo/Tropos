import CoreLocation
import Foundation

private let TRCurrentConditionsKey = "TRCurrentConditions"
private let TRYesterdaysConditionsKey = "TRYesterdaysConditions"
private let TRPlacemarkKey = "TRPlacemark"
private let TRDateKey = "TRDateAt"

@objc(TRWeatherUpdate) public final class WeatherUpdate: NSObject, NSCoding {
    public let date: Date
    public let placemark: CLPlacemark
    private let currentConditionsJSON: [String: Any]
    fileprivate let yesterdaysConditionsJSON: [String: Any]

    public init?(placemark: CLPlacemark, currentConditionsJSON: [String: Any], yesterdaysConditionsJSON: [String: Any], date: Date) {
        self.date = date
        self.placemark = placemark
        self.currentConditionsJSON = currentConditionsJSON
        self.yesterdaysConditionsJSON = yesterdaysConditionsJSON
        super.init()
    }

    public convenience init?(placemark: CLPlacemark, currentConditionsJSON: [String: Any], yesterdaysConditionsJSON: [String: Any]) {
        self.init(placemark: placemark, currentConditionsJSON: currentConditionsJSON, yesterdaysConditionsJSON: yesterdaysConditionsJSON, date: Date())
    }

    fileprivate lazy var currentConditions: [String: Any] = {
        return self.currentConditionsJSON["currently"] as? [String: Any] ?? [:]
    }()

    fileprivate lazy var forecasts: [[String: Any]] = {
        let daily = self.currentConditionsJSON["daily"] as? [String: Any]
        return daily?["data"] as? [[String: Any]] ?? []
    }()

    fileprivate var todaysForecast: [String: Any] {
        return forecasts.first ?? [:]
    }

    public required init?(coder: NSCoder) {
        guard let currentConditions = coder.decodeObject(forKey: TRCurrentConditionsKey) as? [String: Any],
            let yesterdaysConditions = coder.decodeObject(forKey: TRYesterdaysConditionsKey) as? [String: Any],
            let placemark = coder.decodeObject(forKey: TRPlacemarkKey) as? CLPlacemark,
            let date = coder.decodeObject(forKey: TRDateKey) as? Date
            else {
                return nil
            }

        self.currentConditionsJSON = currentConditions
        self.yesterdaysConditionsJSON = yesterdaysConditions
        self.placemark = placemark
        self.date = date
    }

    public func encode(with coder: NSCoder) {
        coder.encode(currentConditionsJSON, forKey: TRCurrentConditionsKey)
        coder.encode(yesterdaysConditionsJSON, forKey: TRYesterdaysConditionsKey)
        coder.encode(placemark, forKey: TRPlacemarkKey)
        coder.encode(date, forKey: TRDateKey)
    }
}

public extension WeatherUpdate {
    var city: String? {
        return placemark.locality
    }

    var state: String? {
        return placemark.administrativeArea
    }

    var conditionsDescription: String? {
        return currentConditions["icon"] as? String
    }

    var precipitationType: String {
        return (todaysForecast["precipType"] as? String) ?? "rain"
    }

    var currentTemperature: Temperature {
        let rawTemperature = self.currentConditions["temperature"] as? Int ?? 0
        return Temperature(fahrenheitValue: rawTemperature)
    }

    var currentHigh: Temperature {
        if case let rawHigh = todaysForecast["temperatureMax"] as? Int ?? 0, rawHigh > currentTemperature.fahrenheitValue {
            return Temperature(fahrenheitValue: rawHigh)
        } else {
            return currentTemperature
        }
    }

    var currentLow: Temperature {
        if case let rawLow = todaysForecast["temperatureMin"] as? Int ?? 0, rawLow < currentTemperature.fahrenheitValue {
            return Temperature(fahrenheitValue: rawLow)
        } else {
            return currentTemperature
        }
    }

    var yesterdaysTemperature: Temperature? {
        let currently = yesterdaysConditionsJSON["currently"] as? [String: Any]
        let rawTemperature = currently?["temperature"]
        guard let fahrenheitValue = rawTemperature as? Int else {
            return .none
        }
        return Temperature(fahrenheitValue: fahrenheitValue)
    }

    var precipitationPercentage: Double {
        return Double(todaysForecast["precipProbability"] as? String ?? "") ?? 0
    }

    var windSpeed: Double {
        return currentConditions["windSpeed"] as? Double ?? 0
    }

    var windBearing: Double {
        return currentConditions["windBearing"] as? Double ?? 0
    }

    var dailyForecasts: [DailyForecast] {
        return (1...3).flatMap {
            if forecasts.indices.contains($0) {
                return DailyForecast(JSON: forecasts[$0])
            } else {
                return nil
            }
        }
    }
}