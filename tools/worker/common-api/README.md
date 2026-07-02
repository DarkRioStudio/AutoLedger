# darkrio Common API Worker

`common-api` is the shared Cloudflare Worker planned for darkrio personal apps. This first slice exposes only public, read-only contracts:

- `GET /health`
- `GET /v1/manifest`
- `GET /v1/locations/catalog`
- `GET /v1/locations/countries?locale=zh-Hans`
- `GET /v1/locations/cities?country=JP&locale=zh-Hans`
- `GET /v1/currencies/catalog`
- `GET /v1/currencies?locale=zh-Hans`
- `GET /v1/weather/current?lat=35.68&lon=139.76&locale=ja&timezone=Asia/Tokyo`
- `GET /v1/weather/forecast?lat=35.68&lon=139.76&locale=ja&timezone=Asia/Tokyo`
- `GET /v1/exchange-rates/rate` returns a structured `501` planned response.
- `GET /v1/weather/hotel-stay-summary` returns a structured `501` planned response.

The places catalog is intentionally curated, not exhaustive. It covers common countries, large cities, and hotel or travel-heavy cities with five display locales:

- `zh-Hans`
- `zh-Hant`
- `en`
- `ja`
- `ko`

The Worker does not receive receipts, folio PDFs, hotel names, merchant names, transaction amounts, inbox content, or user ledger data. Weather endpoints receive coordinates, locale, and timezone only.

The currency catalog is also curated for app UI and conversion preparation. It publishes supported currency codes, symbols, localized names, and minor-unit digits so client apps can keep manual currency pickers and future exchange-rate flows aligned.

## Local Commands

```bash
npm install
npm run check
npm run dev
```

## Deployment Notes

Secrets are not required for this first slice. `wrangler.jsonc` only contains public origins and route placeholders:

- staging: `https://staging-api.darkrio326.top`
- production: `https://api.darkrio326.top`

The legacy `MyWeatherLine/Api` current and forecast weather provider structure has been migrated into this Worker. Production is intentionally deployed with `WEATHER_PROVIDER=disabled` until a new WeatherKit key is issued.

Future WeatherKit secrets:

```bash
wrangler secret put WEATHERKIT_TEAM_ID --env production
wrangler secret put WEATHERKIT_SERVICE_ID --env production
wrangler secret put WEATHERKIT_KEY_ID --env production
wrangler secret put WEATHERKIT_PRIVATE_KEY --env production
```

Then set `WEATHER_PROVIDER` to `weatherkit` in the environment vars and redeploy.

Exchange-rate providers, R2 static assets, and service-to-service auth should be added in later slices behind the same public response contracts.
