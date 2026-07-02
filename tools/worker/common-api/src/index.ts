import {
  cities,
  countries,
  placesCatalog,
  placeCatalogResourceVersion,
  supportedLocales,
  type CityRecord,
  type CountryRecord,
  type LocalizedText,
  type SupportedLocale
} from "./places-catalog";

type APIError = {
  error: {
    code: string;
    message: string;
  };
};

type LocalizedCountry = CountryRecord & {
  displayName: string;
};

type LocalizedCity = CityRecord & {
  displayName: string;
};

const supportedLocaleSet = new Set<string>(supportedLocales);
const jsonContentType = "application/json; charset=utf-8";

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    return routeFetch(request, env);
  }
} satisfies ExportedHandler<Env>;

export async function routeFetch(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);

  if (request.method === "OPTIONS") {
    return withCommonHeaders(new Response(null, { status: 204 }));
  }

  if (request.method === "GET" && url.pathname === "/health") {
    return json({
      ok: true,
      service: "autoledger-common-api",
      version: placeCatalogResourceVersion,
      checkedAt: new Date().toISOString()
    });
  }

  if (request.method === "GET" && url.pathname === "/v1/manifest") {
    return manifestResponse(request, env);
  }

  if (request.method === "GET" && url.pathname === "/v1/locations/catalog") {
    return catalogResponse(request);
  }

  if (request.method === "GET" && url.pathname === "/v1/locations/countries") {
    const locale = normalizeLocale(url.searchParams.get("locale"));
    return json({ countries: localizedCountries(locale), locale }, 200, "public, max-age=300");
  }

  if (request.method === "GET" && url.pathname === "/v1/locations/cities") {
    const locale = normalizeLocale(url.searchParams.get("locale"));
    const countryCode = normalizeCountryCode(url.searchParams.get("country"));
    return json({ cities: localizedCities(locale, countryCode), countryCode, locale }, 200, "public, max-age=300");
  }

  if (request.method === "GET" && url.pathname === "/v1/exchange-rates/rate") {
    return plannedEndpoint("exchange_rates_not_implemented", "Exchange rate provider integration is planned for v1.7.0.");
  }

  if (request.method === "GET" && url.pathname === "/v1/weather/hotel-stay-summary") {
    return plannedEndpoint("hotel_weather_not_implemented", "Hotel stay weather provider integration is planned for v1.7.0.");
  }

  if (["POST", "PUT", "PATCH", "DELETE"].includes(request.method)) {
    return json(error("method_not_allowed", "This endpoint currently accepts read-only GET requests."), 405);
  }

  return json(error("not_found", "The requested endpoint does not exist."), 404);
}

async function manifestResponse(request: Request, env: Env): Promise<Response> {
  const catalogBody = JSON.stringify(placesCatalog);
  const sha256 = await sha256Hex(catalogBody);
  const etag = weakETag(sha256);
  const baseURL = publicAPIOrigin(request, env);

  return json(
    {
      schemaVersion: 1,
      resourceVersion: placeCatalogResourceVersion,
      generatedAt: placesCatalog.generatedAt,
      minSupportedAppVersion: "1.6.0",
      supportedLocales,
      capabilities: {
        placesCatalog: {
          status: "available",
          schemaVersion: placesCatalog.schemaVersion,
          resourceVersion: placesCatalog.resourceVersion,
          url: `${baseURL}/v1/locations/catalog`,
          sha256,
          etag,
          countryCount: countries.length,
          cityCount: cities.length,
          fallback: "Use the bundled App catalog when manifest or catalog download fails."
        },
        exchangeRates: {
          status: "planned",
          endpoint: `${baseURL}/v1/exchange-rates/rate`,
          privacy: "The App should send base currency, quote currency, and date only; transaction amounts stay on device."
        },
        hotelWeather: {
          status: "planned",
          endpoint: `${baseURL}/v1/weather/hotel-stay-summary`,
          privacy: "The App should send coordinates, stay dates, locale, and units only; hotel names and folio contents stay on device."
        }
      }
    },
    200,
    "public, max-age=300"
  );
}

async function catalogResponse(request: Request): Promise<Response> {
  const body = JSON.stringify(placesCatalog);
  const sha256 = await sha256Hex(body);
  const etag = weakETag(sha256);
  if (request.headers.get("if-none-match") === etag) {
    return withCommonHeaders(new Response(null, { status: 304, headers: { etag } }));
  }

  return withCommonHeaders(
    new Response(body, {
      status: 200,
      headers: {
        "content-type": jsonContentType,
        "cache-control": "public, max-age=300",
        etag,
        "x-content-sha256": sha256
      }
    })
  );
}

function localizedCountries(locale: SupportedLocale): LocalizedCountry[] {
  return countries.map((record) => ({
    ...record,
    displayName: displayName(record.names, locale)
  }));
}

function localizedCities(locale: SupportedLocale, countryCode: string | null): LocalizedCity[] {
  const candidates = countryCode ? cities.filter((record) => record.countryCode === countryCode) : cities;
  return candidates.map((record) => ({
    ...record,
    displayName: displayName(record.names, locale)
  }));
}

function displayName(names: LocalizedText, locale: SupportedLocale): string {
  return names[locale] || names.en || names["zh-Hans"];
}

function normalizeLocale(rawLocale: string | null): SupportedLocale {
  if (!rawLocale) {
    return "en";
  }
  const normalized = rawLocale.trim();
  if (supportedLocaleSet.has(normalized)) {
    return normalized as SupportedLocale;
  }
  const lowercased = normalized.toLowerCase();
  if (lowercased === "zh" || lowercased === "zh-cn" || lowercased === "zh-hans") {
    return "zh-Hans";
  }
  if (lowercased === "zh-tw" || lowercased === "zh-hk" || lowercased === "zh-hant") {
    return "zh-Hant";
  }
  if (lowercased.startsWith("ja")) {
    return "ja";
  }
  if (lowercased.startsWith("ko")) {
    return "ko";
  }
  return "en";
}

function normalizeCountryCode(rawCountryCode: string | null): string | null {
  const normalized = rawCountryCode?.trim().toUpperCase();
  return normalized && /^[A-Z]{2}$/.test(normalized) ? normalized : null;
}

async function sha256Hex(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function weakETag(sha256: string): string {
  return `W/"sha256-${sha256}"`;
}

function publicAPIOrigin(request: Request, env: Env): string {
  const configuredOrigin = env.PUBLIC_API_ORIGIN?.trim();
  if (configuredOrigin) {
    return configuredOrigin.replace(/\/+$/, "");
  }
  return new URL(request.url).origin;
}

function plannedEndpoint(code: string, message: string): Response {
  return json(error(code, message), 501, "no-store");
}

function error(code: string, message: string): APIError {
  return { error: { code, message } };
}

function json(body: unknown, status = 200, cacheControl = "no-store"): Response {
  return withCommonHeaders(
    new Response(JSON.stringify(body), {
      status,
      headers: {
        "content-type": jsonContentType,
        "cache-control": cacheControl
      }
    })
  );
}

function withCommonHeaders(response: Response): Response {
  const headers = new Headers(response.headers);
  headers.set("access-control-allow-origin", "*");
  headers.set("access-control-allow-methods", "GET, OPTIONS");
  headers.set("access-control-allow-headers", "content-type, if-none-match");
  headers.set("x-content-type-options", "nosniff");
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers
  });
}

function validateCatalogLocales(): string[] {
  const failures: string[] = [];
  const allRecords = [...countries, ...cities];
  for (const record of allRecords) {
    for (const locale of supportedLocales) {
      const value = record.names[locale]?.trim();
      if (!value) {
        failures.push(`${record.id}:${locale}`);
      }
    }
  }
  return failures;
}

export const testInternals = {
  normalizeLocale,
  normalizeCountryCode,
  localizedCountries,
  localizedCities,
  displayName,
  validateCatalogLocales,
  sha256Hex,
  weakETag
};
