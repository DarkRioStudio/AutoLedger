# AutoLedger Common API Worker

`common-api` is the shared Cloudflare Worker planned for AutoLedger and other personal apps. This first slice exposes only public, read-only contracts:

- `GET /health`
- `GET /v1/manifest`
- `GET /v1/locations/catalog`
- `GET /v1/locations/countries?locale=zh-Hans`
- `GET /v1/locations/cities?country=JP&locale=zh-Hans`
- `GET /v1/exchange-rates/rate` returns a structured `501` planned response.
- `GET /v1/weather/hotel-stay-summary` returns a structured `501` planned response.

The places catalog is intentionally curated, not exhaustive. It covers common countries, large cities, and hotel or travel-heavy cities with five display locales:

- `zh-Hans`
- `zh-Hant`
- `en`
- `ja`
- `ko`

The Worker does not receive receipts, folio PDFs, hotel names, merchant names, transaction amounts, inbox content, or user ledger data.

## Local Commands

```bash
npm install
npm run check
npm run dev
```

## Deployment Notes

Secrets are not required for this first slice. `wrangler.jsonc` only contains public origins and route placeholders:

- staging: `https://staging-common.getautoledger.app`
- production: `https://common.getautoledger.app`

WeatherKit, exchange-rate providers, R2 static assets, and service-to-service auth should be added in later slices behind the same public response contracts.
