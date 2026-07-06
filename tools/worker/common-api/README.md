# darkrio Common API Worker

`common-api` is the shared Cloudflare Worker planned for darkrio personal apps. It exposes public, read-only contracts:

- `GET /health`
- `GET /v1/manifest`
- `GET /v1/locations/catalog`
- `GET /v1/locations/countries?locale=zh-Hans`
- `GET /v1/locations/cities?country=JP&locale=zh-Hans` returns localized city records with `latitude`, `longitude`, and `timezone`
- `GET /v1/currencies/catalog`
- `GET /v1/currencies?locale=zh-Hans`
- `GET /v1/exchange-rates/rate?base=USD&quote=CNY&date=2026-07-01`
- `GET /v1/release-notes?app=autoledger&version=1.5.0&locale=zh-Hans`
- `GET /v1/weather/current?lat=35.68&lon=139.76&locale=ja&timezone=Asia/Tokyo`
- `GET /v1/weather/forecast?lat=35.68&lon=139.76&locale=ja&timezone=Asia/Tokyo`
- `GET /v1/weather/hotel-stay-summary?lat=35.68&lon=139.76&checkIn=2026-07-01&checkOut=2026-07-03&locale=ja&timezone=Asia/Tokyo`

The places catalog is intentionally curated, not exhaustive. It covers common countries, large cities, and hotel or travel-heavy cities with five display locales:

- `zh-Hans`
- `zh-Hant`
- `en`
- `ja`
- `ko`

For country and city selection, client UI should label the first level as `Country/Region` in English and `国家和地区` in Simplified Chinese unless a jurisdiction-specific requirement calls for different wording. Hong Kong, Macau, and Taiwan must be displayed at the country/region level as `香港（中国）` / `Hong Kong (China)`, `澳门（中国）` / `Macau (China)`, and `台湾（中国）` / `Taiwan (China)`; city records remain plain city names such as `香港`, `澳门`, and `台北`.

The Worker does not receive receipts, folio PDFs, hotel names, merchant names, transaction amounts, inbox content, or user ledger data. Exchange-rate endpoints receive only base currency, quote currency, and optional rate date. Weather endpoints receive coordinates, locale, timezone, and, for hotel stay summaries, stay dates and units only.

The currency catalog is also curated for app UI and conversion preparation. It publishes supported currency codes, symbols, localized names, and minor-unit digits so client apps can keep manual currency pickers and future exchange-rate flows aligned.

Exchange rates are read-only and intended for local client-side conversion preparation. Production and staging use the public Frankfurter API by default and require no secret. The Worker caches normalized `base + quote + date + provider` responses with the Cloudflare Cache API; clients may inspect `x-common-api-cache` for `hit`, `miss`, or `bypass`. App clients should still persist the provider, rate date, source currency, target currency, and rate alongside any converted amount when conversion is implemented.

Release notes are stored in Cloudflare D1, not embedded in Worker code. The lookup key is `app_id + app_version + locale`, so multiple apps, languages, and public versions can coexist behind the same endpoint. The AutoLedger seed currently keeps `1.5.0` for the ASC 1.5.0 release line and `1.6.0` for the internal v1.7.0 / ASC 1.6.0 development line. The endpoint receives only app id, app version, and locale; it does not receive ledger data, receipt text, hotel folios, subscriptions, or account identifiers.

Hotel stay weather summaries use WeatherKit Daily Summary when the weather provider is configured. The first contract supports historical stays from `2021-08-01`, caps each request at 31 nights, and returns one record per stay night with high / low temperature, precipitation, snowfall, and a provider-neutral summary field. Future stay weather and non-metric units are intentionally rejected in this slice so historical hotel bills are not shown as current or upcoming weather.

## Local Commands

```bash
npm install
npm run check
npm run d1:migrate:staging
npm run d1:seed:staging
npm run d1:migrate:production
npm run d1:seed:production
npm run dev
```

## Deployment Notes

Exchange rates do not require secrets. `wrangler.jsonc` contains public origins, the public Frankfurter base URL, and weather provider configuration:

- staging: `https://staging-api.darkrio326.top`
- production: `https://api.darkrio326.top`

Release notes use separate D1 databases per environment:

- staging: `darkrio-common-api-staging`
- production: `darkrio-common-api-production`

To add or update release notes, insert or update rows in `release_notes` with `app_id`, `app_version`, `locale`, `current_*`, `upcoming_*`, `resource_version`, and `status='published'`. For the current AutoLedger seed, run:

```bash
npm run d1:migrate:staging
npm run d1:seed:staging
npm run d1:migrate:production
npm run d1:seed:production
```

The legacy `MyWeatherLine/Api` current and forecast weather provider structure has been migrated into this Worker. Staging is configured with WeatherKit secrets and `WEATHER_PROVIDER=weatherkit`; production is intentionally deployed with `WEATHER_PROVIDER=disabled` until the App integration and quota policy are ready.

WeatherKit secrets:

```bash
wrangler secret put WEATHERKIT_TEAM_ID --env staging
wrangler secret put WEATHERKIT_SERVICE_ID --env staging
wrangler secret put WEATHERKIT_KEY_ID --env staging
wrangler secret put WEATHERKIT_PRIVATE_KEY --env staging

wrangler secret put WEATHERKIT_TEAM_ID --env production
wrangler secret put WEATHERKIT_SERVICE_ID --env production
wrangler secret put WEATHERKIT_KEY_ID --env production
wrangler secret put WEATHERKIT_PRIVATE_KEY --env production
```

Then set `WEATHER_PROVIDER` to `weatherkit` in the environment vars and redeploy.

R2 static assets and service-to-service auth should be added in later slices behind the same public response contracts.
