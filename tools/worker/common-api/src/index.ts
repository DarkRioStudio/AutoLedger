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
import {
  currencies,
  currenciesCatalog,
  currencyCodes,
  defaultCurrencyCode,
  type CurrencyRecord
} from "./currencies-catalog";
import { exchangeRateEndpoint, exchangeRateTestInternals } from "./exchange-rates/routes";
import {
  releaseNotesSchemaVersion,
  releaseNotesFor,
  releaseNotesManifest,
  supportedReleaseNoteVersions,
} from "./release-notes-store";
import { currentWeatherEndpoint, forecastWeatherEndpoint, hotelStayWeatherEndpoint } from "./weather/routes";

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

type LocalizedCurrency = CurrencyRecord & {
  displayName: string;
};

const serviceResourceVersion = "2026.07.06.1";
const serviceGeneratedAt = "2026-07-06T00:00:00.000Z";
const supportedLocaleSet = new Set<string>(supportedLocales);
const jsonContentType = "application/json; charset=utf-8";
const readMethods = new Set(["GET", "HEAD"]);

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    return routeFetch(request, env, ctx);
  }
} satisfies ExportedHandler<Env>;

export async function routeFetch(request: Request, env: Env, ctx?: ExecutionContext): Promise<Response> {
  const url = new URL(request.url);

  if (request.method === "OPTIONS") {
    return withCommonHeaders(new Response(null, { status: 204 }));
  }

  if (isReadRequest(request) && url.pathname === "/health") {
    return responseForMethod(request, json({
      ok: true,
      service: "darkrio-common-api",
      version: serviceResourceVersion,
      checkedAt: new Date().toISOString()
    }));
  }

  if (isReadRequest(request) && url.pathname === "/v1/manifest") {
    return responseForMethod(request, await manifestResponse(request, env));
  }

  if (isReadRequest(request) && url.pathname === "/v1/locations/catalog") {
    return catalogResponse(request);
  }

  if (isReadRequest(request) && url.pathname === "/v1/locations/countries") {
    const locale = normalizeLocale(url.searchParams.get("locale"));
    return responseForMethod(request, json({ countries: localizedCountries(locale), locale }, 200, "public, max-age=300"));
  }

  if (isReadRequest(request) && url.pathname === "/v1/locations/cities") {
    const locale = normalizeLocale(url.searchParams.get("locale"));
    const countryCode = normalizeCountryCode(url.searchParams.get("country"));
    return responseForMethod(request, json({ cities: localizedCities(locale, countryCode), countryCode, locale }, 200, "public, max-age=300"));
  }

  if (isReadRequest(request) && url.pathname === "/v1/currencies/catalog") {
    return currencyCatalogResponse(request);
  }

  if (isReadRequest(request) && url.pathname === "/v1/currencies") {
    const locale = normalizeLocale(url.searchParams.get("locale"));
    return responseForMethod(request, json({ currencies: localizedCurrencies(locale), defaultCurrencyCode, locale }, 200, "public, max-age=300"));
  }

  if (isReadRequest(request) && url.pathname === "/v1/release-notes") {
    return responseForMethod(request, await releaseNotesResponse(request, env));
  }

  if (isReadRequest(request) && url.pathname === "/v1/exchange-rates/rate") {
    const result = await exchangeRateEndpoint(request, env, { ctx });
    return responseForMethod(request, json(result.body, result.status, result.cacheControl ?? "no-store", result.headers));
  }

  if (isReadRequest(request) && url.pathname === "/v1/weather/current") {
    const result = await currentWeatherEndpoint(request, env);
    return responseForMethod(request, json(result.body, result.status, result.cacheControl ?? "no-store"));
  }

  if (isReadRequest(request) && url.pathname === "/v1/weather/forecast") {
    const result = await forecastWeatherEndpoint(request, env);
    return responseForMethod(request, json(result.body, result.status, result.cacheControl ?? "no-store"));
  }

  if (isReadRequest(request) && url.pathname === "/v1/weather/hotel-stay-summary") {
    const result = await hotelStayWeatherEndpoint(request, env);
    return responseForMethod(request, json(result.body, result.status, result.cacheControl ?? "no-store"));
  }

  if (["POST", "PUT", "PATCH", "DELETE"].includes(request.method)) {
    return json(error("method_not_allowed", "This endpoint currently accepts read-only GET or HEAD requests."), 405);
  }

  return responseForMethod(request, json(error("not_found", "The requested endpoint does not exist."), 404));
}

async function manifestResponse(request: Request, env: Env): Promise<Response> {
  const catalogBody = JSON.stringify(placesCatalog);
  const sha256 = await sha256Hex(catalogBody);
  const etag = weakETag(sha256);
  const currencyCatalogBody = JSON.stringify(currenciesCatalog);
  const currencySha256 = await sha256Hex(currencyCatalogBody);
  const currencyETag = weakETag(currencySha256);
  const baseURL = publicAPIOrigin(request, env);
  const releaseNotes = await releaseNotesManifest(env.COMMON_API_DB);

  return json(
    {
      schemaVersion: 1,
      resourceVersion: serviceResourceVersion,
      generatedAt: serviceGeneratedAt,
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
        currencyCatalog: {
          status: "available",
          schemaVersion: currenciesCatalog.schemaVersion,
          resourceVersion: currenciesCatalog.resourceVersion,
          url: `${baseURL}/v1/currencies/catalog`,
          sha256: currencySha256,
          etag: currencyETag,
          currencyCount: currencies.length,
          defaultCurrencyCode,
          fallback: "Use the bundled App currency catalog when manifest or catalog download fails."
        },
        exchangeRates: {
          status: "available",
          endpoint: `${baseURL}/v1/exchange-rates/rate`,
          provider: env.EXCHANGE_RATE_PROVIDER || "frankfurter",
          supportedCurrencyCodes: currencyCodes,
          query: {
            required: ["base", "quote"],
            optional: ["date"]
          },
          privacy: "The App should send base currency, quote currency, and optional rate date only; transaction amounts stay on device."
        },
        releaseNotes: {
          status: releaseNotes.status,
          schemaVersion: releaseNotes.schemaVersion,
          resourceVersion: releaseNotes.resourceVersion,
          endpoint: `${baseURL}/v1/release-notes`,
          supportedApps: releaseNotes.supportedApps,
          supportedVersions: releaseNotes.supportedVersions,
          supportedLocales: releaseNotes.supportedLocales,
          query: {
            required: ["app", "version"],
            optional: ["locale"]
          },
          privacy: "The App should send app id, app version, and locale only; no ledger, receipt, hotel, subscription, or user account data is needed."
        },
        hotelWeather: {
          status: weatherProviderConfigured(env) ? "available" : "configuration_required",
          endpoint: `${baseURL}/v1/weather/hotel-stay-summary`,
          provider: env.WEATHER_PROVIDER || "disabled",
          query: {
            required: ["lat", "lon", "checkIn", "checkOut"],
            optional: ["locale", "timezone", "units"]
          },
          privacy: "The App should send coordinates, stay dates, locale, timezone, and units only; hotel names and folio contents stay on device."
        },
        weatherForecast: {
          status: "configuration_required",
          currentEndpoint: `${baseURL}/v1/weather/current`,
          forecastEndpoint: `${baseURL}/v1/weather/forecast`,
          providers: ["weatherkit", "openweathermap", "mock"],
          privacy: "The App should send coordinates, locale, and timezone only. WeatherKit credentials are configured as Worker secrets."
        }
      }
    },
    200,
    "public, max-age=300"
  );
}

async function releaseNotesResponse(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const appID = normalizeReleaseNotesAppID(url.searchParams.get("app"));
  const version = normalizeAppVersion(url.searchParams.get("version"));
  const locale = normalizeLocale(url.searchParams.get("locale"));

  if (!appID) {
    return json(error("missing_release_notes_app", "Pass an app id, for example app=autoledger."), 400);
  }
  if (!version) {
    return json(error("missing_release_notes_version", "Pass the client app version, for example version=1.6.0."), 400);
  }
  if (!env.COMMON_API_DB) {
    return json(error("release_notes_unconfigured", "Release notes database is not configured."), 503, "no-store");
  }

  const notes = await releaseNotesFor(env.COMMON_API_DB, appID, version, locale);
  if (!notes) {
    return json(
      error(
        "release_notes_not_found",
        `No release notes are configured for app=${appID} version=${version}.`
      ),
      404,
      "public, max-age=300"
    );
  }

  return json(
    {
      schemaVersion: releaseNotesSchemaVersion,
      resourceVersion: notes.resourceVersion,
      app: notes.app,
      version: notes.version,
      locale: notes.locale,
      current: notes.current,
      upcoming: notes.upcoming,
      availableVersions: await supportedReleaseNoteVersions(env.COMMON_API_DB, appID),
      privacy: "This endpoint uses only app id, app version, and locale. User ledger data, receipt text, hotel folios, subscriptions, and account identifiers stay on device."
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
    return responseForMethod(request, withCommonHeaders(new Response(null, { status: 304, headers: { etag } })));
  }

  return responseForMethod(
    request,
    withCommonHeaders(
      new Response(body, {
        status: 200,
        headers: {
          "content-type": jsonContentType,
          "cache-control": "public, max-age=300",
          etag,
          "x-content-sha256": sha256
        }
      })
    )
  );
}

async function currencyCatalogResponse(request: Request): Promise<Response> {
  const body = JSON.stringify(currenciesCatalog);
  const sha256 = await sha256Hex(body);
  const etag = weakETag(sha256);
  if (request.headers.get("if-none-match") === etag) {
    return responseForMethod(request, withCommonHeaders(new Response(null, { status: 304, headers: { etag } })));
  }

  return responseForMethod(
    request,
    withCommonHeaders(
      new Response(body, {
        status: 200,
        headers: {
          "content-type": jsonContentType,
          "cache-control": "public, max-age=300",
          etag,
          "x-content-sha256": sha256
        }
      })
    )
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

function localizedCurrencies(locale: SupportedLocale): LocalizedCurrency[] {
  return currencies.map((record) => ({
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

function normalizeReleaseNotesAppID(rawAppID: string | null): string | null {
  const normalized = rawAppID?.trim().toLowerCase();
  return normalized && /^[a-z][a-z0-9-]{1,48}$/.test(normalized) ? normalized : null;
}

function normalizeAppVersion(rawVersion: string | null): string | null {
  const normalized = rawVersion?.trim();
  return normalized && /^\d+(?:\.\d+){1,3}$/.test(normalized) ? normalized : null;
}

function isReadRequest(request: Request): boolean {
  return readMethods.has(request.method);
}

function responseForMethod(request: Request, response: Response): Response {
  if (request.method !== "HEAD") {
    return response;
  }
  return withCommonHeaders(
    new Response(null, {
      status: response.status,
      statusText: response.statusText,
      headers: response.headers
    })
  );
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

function weatherProviderConfigured(env: Env): boolean {
  return (env.WEATHER_PROVIDER ?? "disabled").trim().toLowerCase() !== "disabled";
}

function plannedEndpoint(code: string, message: string): Response {
  return json(error(code, message), 501, "no-store");
}

function error(code: string, message: string): APIError {
  return { error: { code, message } };
}

function json(body: unknown, status = 200, cacheControl = "no-store", extraHeaders: Record<string, string> = {}): Response {
  return withCommonHeaders(
    new Response(JSON.stringify(body), {
      status,
      headers: {
        "content-type": jsonContentType,
        "cache-control": cacheControl,
        ...extraHeaders
      }
    })
  );
}

function withCommonHeaders(response: Response): Response {
  const headers = new Headers(response.headers);
  headers.set("access-control-allow-origin", "*");
  headers.set("access-control-allow-methods", "GET, HEAD, OPTIONS");
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
  const allRecords = [...countries, ...cities, ...currencies];
  for (const record of allRecords) {
    for (const locale of supportedLocales) {
      const value = (record.names as LocalizedText)[locale]?.trim();
      if (!value) {
        const recordID = "id" in record ? record.id : record.code;
        failures.push(`${recordID}:${locale}`);
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
  localizedCurrencies,
  exchangeRateTestInternals,
  displayName,
  validateCatalogLocales,
  sha256Hex,
  weakETag,
  normalizeReleaseNotesAppID,
  normalizeAppVersion
};
