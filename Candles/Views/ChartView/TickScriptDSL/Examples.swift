//
//  Examples.swift
//  Candles
//
//  Created by Jaspreet Malak on 6/12/25.
//

import Foundation

// MARK: - PineScript DSL Examples
struct PineScriptExamples {

    // MARK: - Basic Examples
    static let simpleMovingAverage = """
        study("Simple Moving Average", shorttitle="SMA", overlay=true)
        length = input("Length", 20)
        sma_line = sma(close(), length)
        plot(sma_line)
        """

    static let exponentialMovingAverage = """
        study("Exponential Moving Average", shorttitle="EMA", overlay=true)
        length = input("Length", 21)
        ema_line = ema(close(), length)
        plot(ema_line)
        """

    static let relativeStrengthIndex = """
        study("Relative Strength Index", shorttitle="RSI", overlay=false)
        length = input("Length", 14)
        rsi_value = rsi(close(), length)
        plot(rsi_value)
        """

    // MARK: - Intermediate Examples
    static let bollingerBands = """
        study("Bollinger Bands", shorttitle="BB", overlay=true)
        length = input("Length", 20)
        mult = input("Multiplier", 2.0)
        basis = sma(close(), length)
        dev = stdev(close(), length)
        upper = basis + dev * mult
        lower = basis - dev * mult
        plot(upper)
        plot(basis)
        plot(lower)
        """

    static let macdIndicator = """
        study("MACD", shorttitle="MACD", overlay=false)
        fast_length = input("Fast Length", 12)
        slow_length = input("Slow Length", 26)
        signal_length = input("Signal Length", 9)
        macd_line = macd(close(), fast_length, slow_length)
        signal_line = ema(macd_line, signal_length)
        histogram = macd_line - signal_line
        plot(macd_line)
        plot(signal_line)
        plot(histogram)
        """

    static let stochasticOscillator = """
        study("Stochastic Oscillator", shorttitle="Stoch", overlay=false)
        k_period = input("K Period", 14)
        d_period = input("D Period", 3)
        highest_high = highest(high(), k_period)
        lowest_low = lowest(low(), k_period)
        k_percent = (close() - lowest_low) / (highest_high - lowest_low) * 100
        d_percent = sma(k_percent, d_period)
        plot(k_percent)
        plot(d_percent)
        """

    // MARK: - Advanced Examples
    static let ichimokuCloud = """
        study("Ichimoku Cloud", shorttitle="Ichimoku", overlay=true)
        conversion_periods = input("Conversion Line Periods", 9)
        base_periods = input("Base Line Periods", 26)
        lagging_span_periods = input("Lagging Span Periods", 52)
        displacement = input("Displacement", 26)

        conversion_line = (highest(high(), conversion_periods) + lowest(low(), conversion_periods)) / 2
        base_line = (highest(high(), base_periods) + lowest(low(), base_periods)) / 2
        lead_line_a = (conversion_line + base_line) / 2
        lead_line_b = (highest(high(), lagging_span_periods) + lowest(low(), lagging_span_periods)) / 2

        plot(conversion_line)
        plot(base_line)
        plot(lead_line_a)
        plot(lead_line_b)
        """

    static let volumeWeightedAveragePrice = """
        study("Volume Weighted Average Price", shorttitle="VWAP", overlay=true)
        typical_price = hlc3()
        volume_price = typical_price * volume()
        cumulative_volume_price = sma(volume_price, 20)
        cumulative_volume = sma(volume(), 20)
        vwap_value = cumulative_volume_price / cumulative_volume
        plot(vwap_value)
        """

    static let averageTrueRange = """
        study("Average True Range", shorttitle="ATR", overlay=false)
        length = input("Length", 14)
        tr1 = high() - low()
        tr2 = abs(high() - close())
        tr3 = abs(low() - close())
        true_range = max(tr1, max(tr2, tr3))
        atr_value = ema(true_range, length)
        plot(atr_value)
        """

    // MARK: - Custom Oscillators
    static let williamsR = """
        study("Williams %R", shorttitle="%R", overlay=false)
        length = input("Length", 14)
        highest_high = highest(high(), length)
        lowest_low = lowest(low(), length)
        williams_r = (highest_high - close()) / (highest_high - lowest_low) * -100
        plot(williams_r)
        """

    static let commodityChannelIndex = """
        study("Commodity Channel Index", shorttitle="CCI", overlay=false)
        length = input("Length", 20)
        typical_price = hlc3()
        sma_tp = sma(typical_price, length)
        mean_deviation = stdev(typical_price, length)
        cci_value = (typical_price - sma_tp) / (0.015 * mean_deviation)
        plot(cci_value)
        """

    // MARK: - Price Action Indicators
    static let pivotPoints = """
        study("Pivot Points", shorttitle="PP", overlay=true)
        pivot = (high() + low() + close()) / 3
        r1 = 2 * pivot - low()
        s1 = 2 * pivot - high()
        r2 = pivot + (high() - low())
        s2 = pivot - (high() - low())
        plot(pivot)
        plot(r1)
        plot(s1)
        plot(r2)
        plot(s2)
        """

    static let donchianChannels = """
        study("Donchian Channels", shorttitle="DC", overlay=true)
        length = input("Length", 20)
        upper_channel = highest(high(), length)
        lower_channel = lowest(low(), length)
        middle_channel = (upper_channel + lower_channel) / 2
        plot(upper_channel)
        plot(lower_channel)
        plot(middle_channel)
        """

    // MARK: - Volume Indicators
    static let onBalanceVolume = """
        study("On Balance Volume", shorttitle="OBV", overlay=false)
        price_change = close() - close()
        volume_direction = volume() * (price_change > 0 ? 1 : (price_change < 0 ? -1 : 0))
        obv_value = sma(volume_direction, 1)
        plot(obv_value)
        """

    static let volumeOscillator = """
        study("Volume Oscillator", shorttitle="VO", overlay=false)
        short_period = input("Short Period", 5)
        long_period = input("Long Period", 10)
        short_volume_ma = sma(volume(), short_period)
        long_volume_ma = sma(volume(), long_period)
        volume_oscillator = (short_volume_ma - long_volume_ma) / long_volume_ma * 100
        plot(volume_oscillator)
        """

    // MARK: - All Examples Array
    static let allExamples: [(name: String, code: String)] = [
        ("Simple Moving Average", simpleMovingAverage),
        ("Exponential Moving Average", exponentialMovingAverage),
        ("Relative Strength Index", relativeStrengthIndex),
        ("Bollinger Bands", bollingerBands),
        ("MACD", macdIndicator),
        ("Stochastic Oscillator", stochasticOscillator),
        ("Ichimoku Cloud", ichimokuCloud),
        ("Volume Weighted Average Price", volumeWeightedAveragePrice),
        ("Average True Range", averageTrueRange),
        ("Williams %R", williamsR),
        ("Commodity Channel Index", commodityChannelIndex),
        ("Pivot Points", pivotPoints),
        ("Donchian Channels", donchianChannels),
        ("On Balance Volume", onBalanceVolume),
        ("Volume Oscillator", volumeOscillator),
    ]

    // MARK: - Helper Methods
    static func getExample(named name: String) -> String? {
        return allExamples.first { $0.name == name }?.code
    }

    static func getRandomExample() -> (name: String, code: String) {
        return allExamples.randomElement() ?? ("Simple Moving Average", simpleMovingAverage)
    }
}
