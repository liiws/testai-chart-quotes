# Currency Quotes - EUR/USD Candlestick Desktop App

A Flutter Windows desktop app for displaying EUR/USD candlestick charts using daily rates from the Alpha Vantage API.

## Features

- Enter the number of days of history to load (default: 50)
- Fetch latest daily EUR/USD rates from Alpha Vantage and plot as a candlestick chart
- Starts with no data; loads data only when Refresh is pressed

## Setup

**1. Get a (free) Alpha Vantage API Key:**
- Register at [https://www.alphavantage.co/support/#api-key](https://www.alphavantage.co/support/#api-key)

**2. Insert your API Key:**
- Open `lib/main.dart`
- Replace `'YOUR_ALPHA_VANTAGE_API_KEY'` in the `fetchForexCandles` function with your key

**3. Install dependencies:**
```bash
flutter pub get
```

**4. Run the app (Windows desktop):**
```bash
flutter run -d windows
```

## Usage

1. Enter the number of days to display (or keep the default).
2. Click Refresh.
3. The chart will display the most recent EUR/USD daily rates as candlesticks.

## Notes

- If you exceed Alpha Vantage's free tier limits, fetching may temporarily fail.
- Only supports daily ("1D") resolution for EUR/USD.
