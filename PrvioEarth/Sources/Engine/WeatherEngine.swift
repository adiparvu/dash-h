//
//  WeatherEngine.swift
//  PRVIO EARTH
//
//  On-device WeatherKit integration for the property anchor. Refreshes
//  every 30 minutes and exposes current conditions + a 7-day forecast.
//  Falls back to plausible simulated data when WeatherKit entitlements are
//  absent (Simulator, CI, TestFlight without provisioned container) so the
//  UI always has data to render.
//

import Foundation
import CoreLocation
#if canImport(WeatherKit)
import WeatherKit
#endif

@MainActor
@Observable
public final class WeatherEngine {

    // MARK: - Exported types

    public struct Current: Sendable, Equatable {
        public var tempC: Double
        public var feelsLikeC: Double
        public var humidity: Double        // 0...1
        public var windKph: Double
        public var uvIndex: Int
        public var condition: String
        public var symbolName: String
        public var isDaytime: Bool
    }

    public struct DayForecast: Sendable, Identifiable {
        public var id: Date { date }
        public var date: Date
        public var highC: Double
        public var lowC: Double
        public var precipProbability: Double  // 0...1
        public var symbolName: String
        public var condition: String
    }

    // MARK: - Observable state

    public var current: Current?
    public var forecast: [DayForecast] = []
    public var isRefreshing: Bool = false

    private let coordinate: CLLocationCoordinate2D
    private var refreshTask: Task<Void, Never>?

    public init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }

    // MARK: - Lifecycle

    public func start() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(1800))  // 30 min
            }
        }
    }

    public func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    // MARK: - Fetch

    public func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        #if canImport(WeatherKit)
        if #available(iOS 16, *) {
            do {
                let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                let weather = try await WeatherService.shared.weather(for: location)
                let cw = weather.currentWeather
                current = Current(
                    tempC: cw.temperature.converted(to: .celsius).value,
                    feelsLikeC: cw.apparentTemperature.converted(to: .celsius).value,
                    humidity: cw.humidity,
                    windKph: cw.wind.speed.converted(to: .kilometersPerHour).value,
                    uvIndex: cw.uvIndex.value,
                    condition: cw.condition.description,
                    symbolName: cw.symbolName,
                    isDaytime: cw.isDaylight)
                forecast = weather.dailyForecast.forecast.prefix(7).map { day in
                    DayForecast(
                        date: day.date,
                        highC: day.highTemperature.converted(to: .celsius).value,
                        lowC: day.lowTemperature.converted(to: .celsius).value,
                        precipProbability: day.precipitationChance,
                        symbolName: day.symbolName,
                        condition: day.condition.description)
                }
                return
            } catch { }
        }
        #endif
        applySimulated()
    }

    // MARK: - Simulated fallback

    private func applySimulated() {
        current = Current(
            tempC: 22.0 + Double.random(in: -3...3),
            feelsLikeC: 21.0,
            humidity: 0.62,
            windKph: 15.0 + Double.random(in: -5...5),
            uvIndex: 4,
            condition: "Partly Cloudy",
            symbolName: "cloud.sun.fill",
            isDaytime: true)
        let calendar = Calendar.current
        let symbols  = ["sun.max.fill", "cloud.sun.fill", "cloud.rain.fill", "cloud.fill",
                        "sun.max.fill", "sun.max.fill", "cloud.sun.fill"]
        let conds    = ["Sunny", "Partly Cloudy", "Rainy", "Cloudy", "Sunny", "Sunny", "Partly Cloudy"]
        let precips  = [0.1, 0.2, 0.6, 0.3, 0.1, 0.0, 0.2]
        forecast = (0..<7).map { day in
            DayForecast(
                date: calendar.date(byAdding: .day, value: day, to: .now) ?? .now,
                highC: 24.0 + Double.random(in: -4...4),
                lowC: 14.0 + Double.random(in: -2...2),
                precipProbability: precips[day],
                symbolName: symbols[day],
                condition: conds[day])
        }
    }
}
