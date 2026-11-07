import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as Controls
import org.kde.plasma.plasmoid 2.0
import org.kde.kirigami 2.20 as Kirigami

PlasmoidItem {
    id: root

    property var currentWeather: ({})
    property var hourlyForecast: []
    property var dailyForecast: []
    property var historicalAverage: null
    property var historicalCache: ({})
    property int historicalSampleYears: 0
    property bool historicalLoading: false
    property var airQuality: ({})
    property var searchResults: []
    property string errorMessage: ""
    property string searchMessage: ""
    property string searchDraft: ""
    property bool searchOpen: false
    property bool loading: false
    property int searchRequestId: 0
    property int historicalRequestId: 0
    property string forecastMetric: "temperature"
    readonly property string unit: Plasmoid.configuration.temperatureUnit || "celsius"
    readonly property string degree: unit === "fahrenheit" ? "°F" : "°C"

    function weatherIcon(code, isDay) {
        if (code === 0) return isDay ? "weather-clear" : "weather-clear-night"
        if (code <= 2) return isDay ? "weather-few-clouds" : "weather-few-clouds-night"
        if (code === 3) return "weather-overcast"
        if (code === 45 || code === 48) return "weather-fog"
        if (code >= 51 && code <= 57) return "weather-showers-scattered"
        if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) return "weather-showers"
        if (code >= 71 && code <= 77) return "weather-snow"
        if (code >= 85 && code <= 86) return "weather-snow-scattered"
        if (code >= 95) return "weather-storm"
        return "weather-clouds"
    }

    function weatherDescription(code) {
        if (code === 0) return "Clear sky"
        if (code === 1) return "Mainly clear"
        if (code === 2) return "Partly cloudy"
        if (code === 3) return "Overcast"
        if (code === 45 || code === 48) return "Foggy"
        if (code >= 51 && code <= 57) return "Drizzle"
        if (code >= 61 && code <= 67) return "Rain"
        if (code >= 71 && code <= 77) return "Snow"
        if (code >= 80 && code <= 82) return "Rain showers"
        if (code >= 85 && code <= 86) return "Snow showers"
        if (code >= 95) return "Thunderstorms"
        return "Cloudy"
    }

    function shortTime(value) {
        var localTime = String(value).match(/T(\d{2}:\d{2})/)
        return localTime ? localTime[1] : "--:--"
    }

    function dayName(value, index) {
        if (index === 0) return "Today"
        if (index === 1) return "Tomorrow"
        var dateParts = String(value).split("-")
        if (dateParts.length < 3)
            return String(value)
        var weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        var utcDate = new Date(Date.UTC(Number(dateParts[0]), Number(dateParts[1]) - 1, Number(dateParts[2])))
        return weekdayNames[utcDate.getUTCDay()]
    }

    function windDirection(degrees) {
        if (degrees === undefined)
            return "--"
        var directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        return directions[Math.round(Number(degrees) / 45) % 8]
    }

    function uvDescription(value) {
        if (value === undefined) return "Unavailable"
        if (value < 3) return "Low"
        if (value < 6) return "Moderate"
        if (value < 8) return "High"
        if (value < 11) return "Very high"
        return "Extreme"
    }

    function airQualityDescription(value) {
        if (value < 20) return "Good"
        if (value < 40) return "Fair"
        if (value < 60) return "Moderate"
        if (value < 80) return "Poor"
        if (value < 100) return "Very poor"
        return "Extremely poor"
    }

    function metricValue(hour) {
        if (forecastMetric === "precipitation")
            return Number(hour.precipitationAmount).toFixed(1) + " mm"
        if (forecastMetric === "wind")
            return Math.round(hour.windSpeed) + " km/h"
        return Math.round(hour.temperature) + degree
    }

    function hoursForDay(date) {
        return hourlyForecast.filter(function(hour) { return hour.time.slice(0, 10) === date })
    }

    function maxHourlyPrecipitation(date) {
        var values = hoursForDay(date).map(function(hour) { return hour.precipitationAmount })
        return values.length ? Math.max.apply(null, values) : 0
    }

    function forecastTemperatureMin() {
        return dailyForecast.length ? Math.min.apply(null, dailyForecast.map(function(day) { return day.low })) : 0
    }

    function forecastTemperatureMax() {
        return dailyForecast.length ? Math.max.apply(null, dailyForecast.map(function(day) { return day.high })) : 1
    }

    function temperatureRangePosition(value) {
        var minimum = temperatureCelsius(forecastTemperatureMin())
        var maximum = temperatureCelsius(forecastTemperatureMax())
        var range = maximum - minimum
        return range > 0 ? (temperatureCelsius(value) - minimum) / range : 0.5
    }

    function temperatureCelsius(value) {
        var temperature = Number(value)
        return unit === "fahrenheit" ? (temperature - 32) * 5 / 9 : temperature
    }

    function temperatureColorCelsius(value) {
        var stops = [
            { value: 0, red: 98, green: 182, blue: 232 },
            { value: 10, red: 83, green: 199, blue: 137 },
            { value: 15, red: 164, green: 211, blue: 91 },
            { value: 20, red: 239, green: 214, blue: 78 },
            { value: 30, red: 235, green: 143, blue: 63 },
            { value: 40, red: 222, green: 77, blue: 75 }
        ]
        var temperature = Number(value)
        if (temperature <= stops[0].value)
            return Qt.rgba(stops[0].red / 255, stops[0].green / 255, stops[0].blue / 255, 1)
        for (var index = 1; index < stops.length; index++) {
            var upper = stops[index]
            if (temperature <= upper.value) {
                var lower = stops[index - 1]
                var ratio = (temperature - lower.value) / (upper.value - lower.value)
                return Qt.rgba(
                    (lower.red + (upper.red - lower.red) * ratio) / 255,
                    (lower.green + (upper.green - lower.green) * ratio) / 255,
                    (lower.blue + (upper.blue - lower.blue) * ratio) / 255,
                    1
                )
            }
        }
        var hottest = stops[stops.length - 1]
        return Qt.rgba(hottest.red / 255, hottest.green / 255, hottest.blue / 255, 1)
    }

    function loadHistoricalAverage(targetDate) {
        historicalAverage = null
        historicalSampleYears = 0
        historicalLoading = false
        var parts = String(targetDate).split("-")
        if (parts.length !== 3)
            return

        var currentYear = Number(parts[0])
        var startDate = (currentYear - 10) + "-01-01"
        var endDate = (currentYear - 1) + "-12-31"
        var monthAndDay = parts[1] + "-" + parts[2]
        var latitude = Number(Plasmoid.configuration.latitude)
        var longitude = Number(Plasmoid.configuration.longitude)
        var cacheKey = latitude.toFixed(3) + ":" + longitude.toFixed(3) + ":" + monthAndDay + ":" + unit
        var cachedAverage = historicalCache[cacheKey]
        if (cachedAverage) {
            historicalAverage = cachedAverage.average
            historicalSampleYears = cachedAverage.samples
            return
        }
        var requestId = ++historicalRequestId
        historicalLoading = true
        var url = "https://archive-api.open-meteo.com/v1/archive?latitude="
            + latitude
            + "&longitude=" + longitude
                + "&start_date=" + startDate
                + "&end_date=" + endDate
                + "&daily=temperature_2m_mean&temperature_unit=" + unit
                + "&timezone=auto"
        var request = new XMLHttpRequest()
        request.onreadystatechange = function() {
            if (request.readyState !== 4 || requestId !== historicalRequestId)
                return
            historicalLoading = false
            if (request.status !== 200)
                return
            try {
                var daily = JSON.parse(request.responseText).daily
                var sum = 0
                var samples = 0
                for (var index = 0; index < daily.time.length; index++) {
                    if (daily.time[index].slice(5) === monthAndDay
                            && daily.temperature_2m_mean[index] !== null) {
                        sum += Number(daily.temperature_2m_mean[index])
                        samples++
                    }
                }
                if (samples > 0) {
                    var average = sum / samples
                    var updatedCache = Object.assign({}, historicalCache)
                    updatedCache[cacheKey] = { average: average, samples: samples }
                    historicalCache = updatedCache
                    historicalAverage = average
                    historicalSampleYears = samples
                }
            } catch (error) {
                historicalAverage = null
            }
        }
        request.onerror = function() {
            if (requestId === historicalRequestId) {
                historicalLoading = false
                historicalAverage = null
            }
        }
        request.open("GET", url)
        request.send()
    }

    function temperatureAnomaly() {
        if (!dailyForecast.length)
            return "Waiting for today's forecast..."
        if (historicalLoading)
            return "Loading historical average..."
        if (historicalAverage === null)
            return "Historical average unavailable"
        var difference = dailyForecast[0].mean - historicalAverage
        if (Math.abs(difference) < 0.5)
            return "Near the historical average"
        return Math.abs(difference).toFixed(1) + degree
                + (difference > 0 ? " warmer than average" : " cooler than average")
    }

    function loadWeather() {
        loading = true
        errorMessage = ""
        historicalAverage = null
        historicalSampleYears = 0
        historicalRequestId++
        var latitude = Number(Plasmoid.configuration.latitude)
        var longitude = Number(Plasmoid.configuration.longitude)
        var unitName = unit === "fahrenheit" ? "fahrenheit" : "celsius"
        var url = "https://api.open-meteo.com/v1/forecast?latitude=" + latitude
                + "&longitude=" + longitude
            + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m,wind_direction_10m,wind_gusts_10m,surface_pressure,dew_point_2m,visibility,uv_index"
                + "&hourly=temperature_2m,precipitation,precipitation_probability,weather_code,wind_speed_10m"
                + "&daily=weather_code,temperature_2m_mean,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max,precipitation_sum,uv_index_max,wind_speed_10m_max"
                + "&temperature_unit=" + unitName
                + "&wind_speed_unit=kmh&timezone=auto&forecast_days=7"
        var request = new XMLHttpRequest()
        request.onreadystatechange = function() {
            if (request.readyState !== 4)
                return
            loading = false
            if (request.status !== 200) {
                errorMessage = "Weather is unavailable right now. Check your connection and try again."
                return
            }
            try {
                var result = JSON.parse(request.responseText)
                currentWeather = result.current
                hourlyForecast = result.hourly.time.map(function(time, index) {
                    return {
                        time: time,
                        temperature: result.hourly.temperature_2m[index],
                        precipitation: result.hourly.precipitation_probability[index],
                        precipitationAmount: result.hourly.precipitation[index],
                        windSpeed: result.hourly.wind_speed_10m[index],
                        code: result.hourly.weather_code[index]
                    }
                })
                dailyForecast = result.daily.time.map(function(date, index) {
                    return {
                        date: date,
                        code: result.daily.weather_code[index],
                        high: result.daily.temperature_2m_max[index],
                        low: result.daily.temperature_2m_min[index],
                        mean: result.daily.temperature_2m_mean[index],
                        precipitation: result.daily.precipitation_probability_max[index],
                        precipitationTotal: result.daily.precipitation_sum[index],
                        windSpeed: result.daily.wind_speed_10m_max[index],
                        sunrise: result.daily.sunrise[index],
                        sunset: result.daily.sunset[index]
                    }
                })
                loadHistoricalAverage(result.daily.time[0])
                loadAirQuality()
            } catch (error) {
                errorMessage = "The forecast could not be read. Please try again."
            }
        }
        request.onerror = function() {
            loading = false
            errorMessage = "Weather is unavailable right now. Check your connection and try again."
        }
        request.open("GET", url)
        request.send()
    }

    function loadAirQuality() {
        var latitude = Number(Plasmoid.configuration.latitude)
        var longitude = Number(Plasmoid.configuration.longitude)
        var request = new XMLHttpRequest()
        request.onreadystatechange = function() {
            if (request.readyState !== 4)
                return
            if (request.status !== 200) {
                airQuality = ({})
                return
            }
            try {
                airQuality = JSON.parse(request.responseText).current || ({})
            } catch (error) {
                airQuality = ({})
            }
        }
        request.onerror = function() { airQuality = ({}) }
        request.open("GET", "https://air-quality-api.open-meteo.com/v1/air-quality?latitude="
                     + latitude + "&longitude=" + longitude
                     + "&current=european_aqi,pm2_5&timezone=auto")
        request.send()
    }

    function searchCities(name) {
        var query = name.trim()
        if (query.length < 2) {
            searchResults = []
            searchMessage = query.length ? "Type at least 2 characters" : ""
            return
        }
        var requestId = ++searchRequestId
        searchResults = []
        searchMessage = "Searching..."
        var request = new XMLHttpRequest()
        request.onreadystatechange = function() {
            if (request.readyState !== 4)
                return
            if (requestId !== searchRequestId)
                return
            if (request.status !== 200) {
                searchMessage = "Search failed. Try again."
                return
            }
            try {
                var places = JSON.parse(request.responseText).results || []
                if (places.length === 0) {
                    searchMessage = "No matching places found."
                    return
                }
                searchMessage = ""
                searchResults = places
            } catch (error) {
                searchMessage = "Search failed. Try again."
            }
        }
        request.onerror = function() {
            if (requestId === searchRequestId)
                searchMessage = "Search failed. Try again."
        }
        request.open("GET", "https://geocoding-api.open-meteo.com/v1/search?name="
                     + encodeURIComponent(query) + "&count=6&language=en&format=json")
        request.send()
    }

    function selectCity(place) {
        searchRequestId++
        Plasmoid.configuration.locationName = place.name
        Plasmoid.configuration.latitude = place.latitude
        Plasmoid.configuration.longitude = place.longitude
        searchResults = []
        searchMessage = ""
        searchOpen = false
        searchDraft = ""
        airQuality = ({})
        loadWeather()
    }

    Timer {
        interval: 15 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.loadWeather()
    }

    Timer {
        id: searchDebounce
        interval: 400
        repeat: false
        onTriggered: root.searchCities(root.searchDraft)
    }

    Component.onCompleted: loadWeather()

    compactRepresentation: Item {
        implicitWidth: compactRow.implicitWidth + 20
        implicitHeight: 36

        RowLayout {
            id: compactRow
            anchors.centerIn: parent
            spacing: 6

            Kirigami.Icon {
                source: root.weatherIcon(root.currentWeather.weather_code || 0,
                                         root.currentWeather.is_day !== 0)
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
            }
            Text {
                text: root.currentWeather.temperature_2m === undefined ? "--°" : Math.round(root.currentWeather.temperature_2m) + root.degree
                color: Kirigami.Theme.textColor
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
        }
    }

    fullRepresentation: Item {
        Layout.minimumWidth: 390
        Layout.minimumHeight: 540
        Layout.preferredWidth: 430
        Layout.preferredHeight: 700

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#167eae" }
                GradientStop { position: 0.52; color: "#2469a1" }
                GradientStop { position: 1.0; color: "#234f79" }
            }
        }

        Flickable {
            id: forecastScroll
            anchors.fill: parent
            contentWidth: width
            contentHeight: forecastContent.implicitHeight + 36
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: forecastContent
                x: 20
                y: 18
                width: forecastScroll.width - 40
                spacing: 18

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: Math.max(100, parent.width - 96)
                        spacing: 1
                        Text {
                            text: Plasmoid.configuration.locationName || "Weather"
                            color: "white"
                            font.pixelSize: 22
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            Layout.fillWidth: true
                        }
                        Text {
                            text: root.currentWeather.time ? "Updated " + root.shortTime(root.currentWeather.time) : "Local forecast"
                            color: "#cbe7f3"
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                            Layout.fillWidth: true
                        }
                    }
                    RowLayout {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0
                        Controls.ToolButton {
                            icon.name: "search"
                            onClicked: {
                                root.searchOpen = !root.searchOpen
                                root.searchMessage = ""
                                if (root.searchOpen) {
                                    Qt.callLater(function() { citySearch.forceActiveFocus() })
                                } else {
                                    root.searchRequestId++
                                    root.searchResults = []
                                    root.searchDraft = ""
                                    root.searchMessage = ""
                                    citySearch.text = ""
                                    searchDebounce.stop()
                                }
                            }
                            Accessible.name: "Search for a city"
                            Controls.ToolTip.visible: hovered
                            Controls.ToolTip.text: "Search for a city"
                        }
                        Controls.ToolButton {
                            icon.name: "view-refresh"
                            onClicked: root.loadWeather()
                            Accessible.name: "Refresh forecast"
                            Controls.ToolTip.visible: hovered
                            Controls.ToolTip.text: "Refresh forecast"
                        }
                    }
                }

                RowLayout {
                    visible: root.searchOpen
                    Layout.fillWidth: true
                    spacing: 8
                    Controls.TextField {
                        id: citySearch
                        Layout.fillWidth: true
                        placeholderText: "Search city"
                        placeholderTextColor: "#617584"
                        color: "#182735"
                        selectionColor: "#287db0"
                        selectedTextColor: "white"
                        onAccepted: root.searchCities(text)
                        onTextEdited: {
                            root.searchDraft = text
                            root.searchRequestId++
                            root.searchResults = []
                            var queryLength = text.trim().length
                            root.searchMessage = queryLength > 0 && queryLength < 2 ? "Type at least 2 characters" : ""
                            if (queryLength >= 2) {
                                root.searchMessage = "Searching..."
                                searchDebounce.restart()
                            } else {
                                searchDebounce.stop()
                            }
                        }
                        background: Rectangle { radius: 9; color: "#eaf6fb" }
                    }
                    Controls.Button {
                        text: "Go"
                        onClicked: root.searchCities(citySearch.text)
                    }
                }
                Text {
                    visible: root.searchOpen && root.searchMessage.length > 0
                    text: root.searchMessage
                    color: "#d8edf7"
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }
                ColumnLayout {
                    visible: root.searchOpen && root.searchResults.length > 0
                    Layout.fillWidth: true
                    spacing: 2
                    Repeater {
                        model: root.searchResults
                        delegate: Controls.ItemDelegate {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                            onClicked: root.selectCity(modelData)
                            Accessible.name: modelData.name + (modelData.country ? ", " + modelData.country : "")
                            background: Rectangle {
                                radius: 8
                                color: parent.hovered ? "#3dffffff" : "#20ffffff"
                            }
                            contentItem: RowLayout {
                                spacing: 10
                                Kirigami.Icon {
                                    source: "mark-location"
                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: 20
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Text {
                                        text: modelData.name
                                        color: "white"
                                        font.pixelSize: 14
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: modelData.admin1 ? modelData.admin1 + (modelData.country ? ", " + modelData.country : "") : (modelData.country || "")
                                        color: "#cbe7f3"
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                                Kirigami.Icon {
                                    source: "go-next"
                                    Layout.preferredWidth: 16
                                    Layout.preferredHeight: 16
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Kirigami.Icon {
                        source: root.weatherIcon(root.currentWeather.weather_code || 0,
                                                 root.currentWeather.is_day !== 0)
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                    }
                    Text {
                        text: root.currentWeather.weather_code === undefined ? "" : root.weatherDescription(root.currentWeather.weather_code)
                        color: "#d6ecf5"
                        font.pixelSize: 17
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }
                    Text {
                        text: root.currentWeather.temperature_2m === undefined ? "--°" : Math.round(root.currentWeather.temperature_2m) + root.degree
                        color: "white"
                        font.pixelSize: 72
                        font.weight: Font.Light
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }
                    Text {
                        text: root.currentWeather.apparent_temperature === undefined ? "Feels like --°" : "Feels like " + Math.round(root.currentWeather.apparent_temperature) + root.degree
                        color: "#cbe7f3"
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }
                }

                Text {
                    visible: root.errorMessage.length > 0
                    text: root.errorMessage
                    color: "#ffe2bf"
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 190
                    radius: 16
                    color: "#20ffffff"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "HOURLY FORECAST"; color: "#cbe7f3"; font.pixelSize: 11; font.weight: Font.DemiBold }
                            Item { Layout.fillWidth: true }
                            Text { text: "Next 24 hours"; color: "#cbe7f3"; font.pixelSize: 11 }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Controls.Button {
                                text: "Temp"
                                checkable: true
                                checked: root.forecastMetric === "temperature"
                                onClicked: root.forecastMetric = "temperature"
                                Accessible.name: "Show hourly temperatures and daily temperature ranges"
                            }
                            Controls.Button {
                                text: "Rain"
                                checkable: true
                                checked: root.forecastMetric === "precipitation"
                                onClicked: root.forecastMetric = "precipitation"
                                Accessible.name: "Show hourly and daily precipitation"
                            }
                            Controls.Button {
                                text: "Wind"
                                checkable: true
                                checked: root.forecastMetric === "wind"
                                onClicked: root.forecastMetric = "wind"
                                Accessible.name: "Show hourly wind speeds and the seven-day wind chart"
                            }
                        }
                        Flickable {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            contentWidth: hourlyRow.implicitWidth
                            contentHeight: height
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            Row {
                                id: hourlyRow
                                height: parent.height
                                spacing: 8
                                Repeater {
                                    model: root.hourlyForecast.filter(function(item) {
                                        return root.currentWeather.time && item.time >= root.currentWeather.time
                                    }).slice(0, 24)
                                    delegate: Column {
                                        required property var modelData
                                        width: 52
                                        height: parent.height
                                        spacing: 4
                                        Text {
                                            width: parent.width
                                            text: root.shortTime(modelData.time)
                                            color: "#d6ecf5"
                                            font.pixelSize: 11
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                        Kirigami.Icon {
                                            source: root.weatherIcon(modelData.code, true)
                                            width: 24
                                            height: 24
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                        Text {
                                            width: parent.width
                                            text: root.metricValue(modelData)
                                            color: "white"
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                        Text {
                                            width: parent.width
                                            text: modelData.precipitation > 0 ? modelData.precipitation + "% rain chance" : " "
                                            color: "#aee6f2"
                                            font.pixelSize: 9
                                            elide: Text.ElideRight
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 292
                    radius: 16
                    color: "#20ffffff"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 0
                        Text {
                            text: root.forecastMetric === "wind" ? "7-DAY WIND SPEED" : root.forecastMetric === "precipitation" ? "7-DAY PRECIPITATION" : "7-DAY TEMPERATURE RANGE"
                            color: "#cbe7f3"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            Layout.bottomMargin: 8
                        }
                        Repeater {
                            model: root.forecastMetric === "wind" ? [] : root.dailyForecast
                            delegate: RowLayout {
                                id: dayRow
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.preferredHeight: 32
                                spacing: 6
                                Text {
                                    text: root.dayName(modelData.date, index)
                                    color: "white"
                                    font.pixelSize: 13
                                    Layout.preferredWidth: 66
                                }
                                ColumnLayout {
                                    Layout.preferredWidth: 30
                                    spacing: 0
                                    Kirigami.Icon {
                                        source: root.weatherIcon(modelData.code, true)
                                        Layout.preferredWidth: 20
                                        Layout.preferredHeight: 20
                                    }
                                    Text {
                                        text: modelData.precipitation > 0 ? Math.round(modelData.precipitation) + "%" : ""
                                        color: "#aee6f2"
                                        font.pixelSize: 9
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }
                                Text {
                                    visible: root.forecastMetric === "temperature"
                                    text: Math.round(modelData.low) + "°"
                                    color: "#cbe7f3"
                                    font.pixelSize: 13
                                    horizontalAlignment: Text.AlignRight
                                }
                                Item {
                                    visible: root.forecastMetric === "temperature"
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 18
                                    Canvas {
                                        id: temperatureRangeChart
                                        anchors.fill: parent
                                        onWidthChanged: requestPaint()
                                        onHeightChanged: requestPaint()
                                        onPaint: {
                                            var context = getContext("2d")
                                            context.clearRect(0, 0, width, height)
                                            if (width < 1 || height < 1)
                                                return
                                            var trackLeft = 3
                                            var trackRight = width - 3
                                            var centerY = height / 2
                                            context.beginPath()
                                            context.moveTo(trackLeft, centerY)
                                            context.lineTo(trackRight, centerY)
                                            context.lineWidth = 3
                                            context.lineCap = "round"
                                            context.strokeStyle = "#35ffffff"
                                            context.stroke()

                                            var minimum = root.forecastTemperatureMin()
                                            var maximum = root.forecastTemperatureMax()
                                            var range = maximum - minimum
                                            if (range <= 0)
                                                return
                                            var minimumCelsius = root.temperatureCelsius(minimum)
                                            var maximumCelsius = root.temperatureCelsius(maximum)
                                            var celsiusRange = maximumCelsius - minimumCelsius
                                            if (celsiusRange <= 0)
                                                return

                                            var gradient = context.createLinearGradient(trackLeft, 0, trackRight, 0)
                                            gradient.addColorStop(0, root.temperatureColorCelsius(minimumCelsius))
                                            var colorStops = [0, 10, 15, 20, 30, 40]
                                            for (var stopIndex = 0; stopIndex < colorStops.length; stopIndex++) {
                                                var stopTemperature = colorStops[stopIndex]
                                                if (stopTemperature > minimumCelsius && stopTemperature < maximumCelsius)
                                                        gradient.addColorStop((stopTemperature - minimumCelsius) / celsiusRange, root.temperatureColorCelsius(stopTemperature))
                                            }
                                                    gradient.addColorStop(1, root.temperatureColorCelsius(maximumCelsius))

                                            var left = trackLeft + (trackRight - trackLeft) * root.temperatureRangePosition(dayRow.modelData.low)
                                            var right = trackLeft + (trackRight - trackLeft) * root.temperatureRangePosition(dayRow.modelData.high)
                                            context.beginPath()
                                            context.moveTo(left, centerY)
                                            context.lineTo(Math.max(right, left + 0.1), centerY)
                                            context.lineWidth = 5
                                            context.lineCap = "round"
                                            context.strokeStyle = gradient
                                            context.stroke()
                                        }
                                        Connections {
                                            target: root
                                            function onDailyForecastChanged() { temperatureRangeChart.requestPaint() }
                                        }
                                    }
                                }
                                Text {
                                    visible: root.forecastMetric === "temperature"
                                    text: Math.round(modelData.high) + "°"
                                    color: "white"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    horizontalAlignment: Text.AlignRight
                                }
                                Text {
                                    visible: root.forecastMetric === "precipitation"
                                    text: Number(modelData.precipitationTotal).toFixed(1) + " mm"
                                    color: "white"
                                    font.pixelSize: 12
                                    Layout.preferredWidth: 44
                                    horizontalAlignment: Text.AlignRight
                                }
                                Row {
                                    visible: root.forecastMetric === "precipitation"
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 22
                                    spacing: 1
                                    Repeater {
                                        model: root.hoursForDay(dayRow.modelData.date)
                                        delegate: Item {
                                            required property var modelData
                                            width: Math.max(2, (parent.width - 23) / 24)
                                            height: parent.height
                                            Rectangle {
                                                anchors.fill: parent
                                                anchors.topMargin: 2
                                                anchors.bottomMargin: 2
                                                radius: 1
                                                color: "#35aee6f2"
                                            }
                                            Rectangle {
                                                width: parent.width
                                                height: root.maxHourlyPrecipitation(dayRow.modelData.date) > 0 ? Math.max(2, (parent.height - 4) * modelData.precipitationAmount / root.maxHourlyPrecipitation(dayRow.modelData.date)) : 0
                                                anchors.bottom: parent.bottom
                                                anchors.bottomMargin: 2
                                                radius: 1
                                                color: "#8bd7ed"
                                                visible: modelData.precipitationAmount > 0
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        Repeater {
                            model: root.forecastMetric === "wind" ? root.dailyForecast : []
                            delegate: RowLayout {
                                id: windDayRow
                                required property var modelData
                                required property int index
                                property var hourlySamples: root.hoursForDay(modelData.date)
                                Layout.fillWidth: true
                                Layout.preferredHeight: 32
                                spacing: 6
                                Text {
                                    text: root.dayName(windDayRow.modelData.date, windDayRow.index)
                                    color: "white"
                                    font.pixelSize: 12
                                    Layout.preferredWidth: 66
                                }
                                Kirigami.Icon {
                                    source: root.weatherIcon(windDayRow.modelData.code, true)
                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: 20
                                }
                                Canvas {
                                    id: dailyWindChart
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 24
                                    onWidthChanged: requestPaint()
                                    onHeightChanged: requestPaint()
                                    onPaint: {
                                        var context = getContext("2d")
                                        context.clearRect(0, 0, width, height)
                                        var samples = windDayRow.hourlySamples
                                        if (samples.length < 2 || width < 2 || height < 2)
                                            return
                                        var speeds = samples.map(function(hour) { return Number(hour.windSpeed) })
                                        var allSpeeds = root.hourlyForecast.map(function(hour) { return Number(hour.windSpeed) })
                                        var minimum = Math.min.apply(null, allSpeeds)
                                        var maximum = Math.max.apply(null, allSpeeds)
                                        var spread = maximum - minimum
                                        var left = 2
                                        var right = width - 2
                                        var top = 3
                                        var bottom = height - 3
                                        context.beginPath()
                                        for (var point = 0; point < speeds.length; point++) {
                                            var x = left + (right - left) * point / (speeds.length - 1)
                                            var y = top + (spread > 0 ? (maximum - speeds[point]) / spread : 0.5) * (bottom - top)
                                            if (point === 0)
                                                context.moveTo(x, y)
                                            else
                                                context.lineTo(x, y)
                                        }
                                        context.lineWidth = 2
                                        context.lineJoin = "round"
                                        context.lineCap = "round"
                                        context.strokeStyle = "#91d8e6"
                                        context.stroke()
                                    }
                                    Connections {
                                        target: root
                                        function onHourlyForecastChanged() { dailyWindChart.requestPaint() }
                                    }
                                }
                                Text {
                                    text: Math.round(windDayRow.modelData.windSpeed) + " km/h"
                                    color: "white"
                                    font.pixelSize: 10
                                    horizontalAlignment: Text.AlignRight
                                    Layout.preferredWidth: 48
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 94
                    radius: 12
                    color: "#20ffffff"
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 3
                        Text {
                            text: "TODAY VS HISTORIC AVERAGE"
                            color: "#cbe7f3"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: root.temperatureAnomaly()
                            color: "white"
                            font.pixelSize: 20
                            font.weight: Font.Medium
                        }
                        Text {
                            text: root.dailyForecast.length && root.historicalAverage !== null
                                  ? "Forecast mean " + Math.round(root.dailyForecast[0].mean) + root.degree
                                    + " / " + root.historicalSampleYears + "-year average " + Math.round(root.historicalAverage) + root.degree
                                  : "Compared with the same date in previous years"
                            color: "#d6ecf5"
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 340
                    radius: 16
                    color: "#20ffffff"

                    GridLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        columns: 2
                        columnSpacing: 16
                        rowSpacing: 10
                        Repeater {
                            model: [
                                { label: "HUMIDITY", value: root.currentWeather.relative_humidity_2m === undefined ? "--" : root.currentWeather.relative_humidity_2m + "%" },
                                { label: "WIND", value: root.currentWeather.wind_speed_10m === undefined ? "--" : Math.round(root.currentWeather.wind_speed_10m) + " km/h", note: "From " + root.windDirection(root.currentWeather.wind_direction_10m) + " / gusts " + Math.round(root.currentWeather.wind_gusts_10m || 0) + " km/h" },
                                { label: "AIR QUALITY", value: root.airQuality.european_aqi === undefined ? "No data" : root.airQualityDescription(root.airQuality.european_aqi), note: root.airQuality.european_aqi === undefined ? "European air quality index" : "AQI " + Math.round(root.airQuality.european_aqi) + " / PM2.5 " + Math.round(root.airQuality.pm2_5) + " ug/m3" },
                                { label: "UV INDEX", value: root.currentWeather.uv_index === undefined ? "--" : Math.round(root.currentWeather.uv_index).toString(), note: root.uvDescription(root.currentWeather.uv_index) },
                                { label: "PRECIPITATION", value: root.currentWeather.precipitation === undefined ? "--" : root.currentWeather.precipitation + " mm", note: root.dailyForecast.length ? "Today's chance: " + Math.round(root.dailyForecast[0].precipitation) + "%" : "Current amount" },
                                { label: "VISIBILITY", value: root.currentWeather.visibility === undefined ? "--" : (root.currentWeather.visibility / 1000).toFixed(1) + " km", note: root.currentWeather.visibility >= 10000 ? "Clear view" : "Reduced visibility" },
                                { label: "SUNRISE", value: root.dailyForecast.length ? root.shortTime(root.dailyForecast[0].sunrise) : "--", note: root.dailyForecast.length ? "Sunset " + root.shortTime(root.dailyForecast[0].sunset) : "Sun times" },
                                { label: "PRESSURE", value: root.currentWeather.surface_pressure === undefined ? "--" : Math.round(root.currentWeather.surface_pressure) + " hPa", note: "At ground level" },
                                { label: "DEW POINT", value: root.currentWeather.dew_point_2m === undefined ? "--" : Math.round(root.currentWeather.dew_point_2m) + root.degree, note: "Moisture in the air" },
                                { label: "TODAY'S RANGE", value: root.dailyForecast.length ? Math.round(root.dailyForecast[0].high) + root.degree : "--", note: root.dailyForecast.length ? "Low " + Math.round(root.dailyForecast[0].low) + root.degree : "Daily high" }
                            ]
                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 52
                                spacing: 1
                                Text { text: modelData.label; color: "#cbe7f3"; font.pixelSize: 10; font.weight: Font.DemiBold }
                                Text { text: modelData.value; color: "white"; font.pixelSize: 16; elide: Text.ElideRight; Layout.fillWidth: true }
                                Text { text: modelData.note || ""; color: "#d6ecf5"; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
                            }
                        }
                    }
                }

                Text {
                    text: "Weather data by Open-Meteo"
                    color: "#b8d5e4"
                    font.pixelSize: 10
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: 4
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: 12
                    spacing: 8
                    Text { text: "Units"; color: "#cbe7f3"; font.pixelSize: 12 }
                    Controls.Button {
                        text: "°C"
                        checkable: true
                        checked: root.unit === "celsius"
                        onClicked: {
                            Plasmoid.configuration.temperatureUnit = "celsius"
                            root.loadWeather()
                        }
                    }
                    Controls.Button {
                        text: "°F"
                        checkable: true
                        checked: root.unit === "fahrenheit"
                        onClicked: {
                            Plasmoid.configuration.temperatureUnit = "fahrenheit"
                            root.loadWeather()
                        }
                    }
                }
            }
        }
    }
}