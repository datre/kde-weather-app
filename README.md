# Skycast Weather

A Plasma 6 weather applet with current conditions, a 12-hour outlook, a 7-day forecast, and humidity, wind, precipitation, and sunrise details. Forecasts and city search are powered by the free Open-Meteo APIs; no API key is required.

## Install from Plasma

1. Open **Add Widgets** from the desktop or panel's context menu.
2. Open the widget browser menu and choose **Install Widget From Local File...**.
3. Select `skycast-weather.plasmoid` from this project folder.
4. Find **Skycast Weather** in the widget list and add it.

If the local-file option is under **Get New Widgets**, open that menu first.

You can also install it for your user from a terminal:

```sh
kpackagetool6 --type Plasma/Applet --install skycast-weather.plasmoid
```

Then add **Skycast Weather** from Plasma's widget explorer. Click its panel icon to open the full forecast. Search for a city in the forecast view to change the saved location, and use the °C/°F buttons to change units. Data refreshes automatically every 15 minutes.

To remove it:

```sh
kpackagetool6 --type Plasma/Applet --remove org.example.skycast
```