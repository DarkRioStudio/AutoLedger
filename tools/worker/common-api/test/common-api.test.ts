import { describe, expect, it } from "vitest";
import { currencies, currenciesCatalog, defaultCurrencyCode } from "../src/currencies-catalog";
import { exchangeRateEndpoint } from "../src/exchange-rates/routes";
import { cities, countries, placesCatalog, supportedLocales } from "../src/places-catalog";
import { routeFetch, testInternals } from "../src/index";
import { weatherProviderTestInternals } from "../src/weather/providers";

type ReleaseNoteFixture = {
  app_id: string;
  app_version: string;
  locale: string;
  schema_version: number;
  resource_version: string;
  current_title: string;
  current_body: string;
  upcoming_title: string;
  upcoming_body: string;
  status: "published" | "draft" | "archived";
};

const releaseNotesFixtures: ReleaseNoteFixture[] = [
  {
    app_id: "autoledger",
    app_version: "1.5.0",
    locale: "zh-Hans",
    schema_version: 1,
    resource_version: "2026.07.06.2",
    current_title: "当前版本",
    current_body: "这个版本加入了 AutoLedger Pro 的第一批自动化能力。",
    upcoming_title: "后续计划",
    upcoming_body: "后续版本会加入更强的搜索、订阅异常提醒、月结导出和自动规则整理。",
    status: "published"
  },
  {
    app_id: "autoledger",
    app_version: "1.5.0",
    locale: "en",
    schema_version: 1,
    resource_version: "2026.07.06.2",
    current_title: "Current Version",
    current_body: "This version adds the first AutoLedger Pro automations.",
    upcoming_title: "Coming Next",
    upcoming_body: "Later releases will add stronger search and smarter rules automation.",
    status: "published"
  },
  {
    app_id: "autoledger",
    app_version: "1.6.0",
    locale: "zh-Hans",
    schema_version: 1,
    resource_version: "2026.07.06.2",
    current_title: "当前版本",
    current_body: "这个版本让记账更适合真实票据场景：票据扫描升级为实时 OCR，并新增韩语界面和韩语账单识别。",
    upcoming_title: "后续计划",
    upcoming_body: "接下来会继续补齐更多地区票据样本，并推进 Pro 自动化里的搜索、月结导出和规则整理。",
    status: "published"
  },
  {
    app_id: "autoledger",
    app_version: "1.6.0",
    locale: "en",
    schema_version: 1,
    resource_version: "2026.07.06.2",
    current_title: "Current Version",
    current_body: "This version makes AutoLedger better for real receipt workflows with live OCR and Korean receipt recognition.",
    upcoming_title: "Coming Next",
    upcoming_body: "Next we will add more regional receipt samples and continue Pro automations for search, month-end exports, and rules.",
    status: "published"
  }
];

class MemoryD1Database {
  constructor(private readonly rows: ReleaseNoteFixture[]) {}

  prepare(sql: string): MemoryD1PreparedStatement {
    return new MemoryD1PreparedStatement(sql, this.rows);
  }
}

class MemoryD1PreparedStatement {
  private readonly params: unknown[];

  constructor(
    private readonly sql: string,
    private readonly rows: ReleaseNoteFixture[],
    params: unknown[] = []
  ) {
    this.params = params;
  }

  bind(...params: unknown[]): MemoryD1PreparedStatement {
    return new MemoryD1PreparedStatement(this.sql, this.rows, params);
  }

  async first<T>(): Promise<T | null> {
    const [appID, version, locale] = this.params.map(String);
    const row = this.rows.find((candidate) =>
      candidate.app_id === appID &&
      candidate.app_version === version &&
      candidate.locale === locale &&
      candidate.status === "published"
    );
    return (row ?? null) as T | null;
  }

  async all<T>(): Promise<{ results: T[] }> {
    if (this.sql.includes("SELECT DISTINCT app_version")) {
      const [appID] = this.params.map(String);
      const versions = Array.from(new Set(
        this.rows
          .filter((row) => row.app_id === appID && row.status === "published")
          .map((row) => row.app_version)
      ))
        .sort()
        .map((app_version) => ({ app_version }));
      return { results: versions as T[] };
    }

    const manifestRows = this.rows
      .filter((row) => row.status === "published")
      .map((row) => ({
        app_id: row.app_id,
        app_version: row.app_version,
        locale: row.locale,
        resource_version: row.resource_version,
        schema_version: row.schema_version
      }));
    return { results: manifestRows as T[] };
  }
}

const releaseNotesDB = new MemoryD1Database(releaseNotesFixtures) as unknown as D1Database;

const env = {
  PUBLIC_API_ORIGIN: "https://api.darkrio326.top",
  EXCHANGE_RATE_PROVIDER: "mock",
  EXCHANGE_RATE_BASE_URL: "https://api.frankfurter.dev/v2",
  WEATHER_PROVIDER: "disabled",
  COMMON_API_DB: releaseNotesDB
} as unknown as Env;
const disabledExchangeEnv = {
  PUBLIC_API_ORIGIN: "https://api.darkrio326.top",
  EXCHANGE_RATE_PROVIDER: "disabled",
  EXCHANGE_RATE_BASE_URL: "https://api.frankfurter.dev/v2",
  WEATHER_PROVIDER: "disabled",
  COMMON_API_DB: releaseNotesDB
} as unknown as Env;
const mockWeatherEnv = {
  PUBLIC_API_ORIGIN: "https://api.darkrio326.top",
  EXCHANGE_RATE_PROVIDER: "mock",
  EXCHANGE_RATE_BASE_URL: "https://api.frankfurter.dev/v2",
  WEATHER_PROVIDER: "mock",
  COMMON_API_DB: releaseNotesDB
} as unknown as Env;

async function jsonBody(response: Response): Promise<Record<string, unknown>> {
  return (await response.json()) as Record<string, unknown>;
}

class MemoryCache {
  private readonly records = new Map<string, Response>();

  async match(request: Request): Promise<Response | undefined> {
    return this.records.get(request.url)?.clone();
  }

  async put(request: Request, response: Response): Promise<void> {
    this.records.set(request.url, response.clone());
  }
}

describe("common api worker contract", () => {
  it("serves a health response", async () => {
    const response = await routeFetch(new Request("https://example.test/health"), env);
    const body = await jsonBody(response);

    expect(response.status).toBe(200);
    expect(body.ok).toBe(true);
    expect(body.service).toBe("darkrio-common-api");
  });

  it("publishes a manifest for the five-locale places catalog", async () => {
    const response = await routeFetch(new Request("https://example.test/v1/manifest"), env);
    const body = await jsonBody(response);
    const capabilities = body.capabilities as Record<string, Record<string, unknown>>;
    const placesCatalogCapability = capabilities.placesCatalog;
    const currencyCatalogCapability = capabilities.currencyCatalog;
    const exchangeRatesCapability = capabilities.exchangeRates;
    const releaseNotesCapability = capabilities.releaseNotes;
    const weatherForecastCapability = capabilities.weatherForecast;
    const hotelWeatherCapability = capabilities.hotelWeather;

    expect(response.status).toBe(200);
    expect(body.supportedLocales).toEqual(supportedLocales);
    expect(placesCatalogCapability).toBeDefined();
    expect(currencyCatalogCapability).toBeDefined();
    expect(exchangeRatesCapability).toBeDefined();
    expect(releaseNotesCapability).toBeDefined();
    expect(weatherForecastCapability).toBeDefined();
    expect(hotelWeatherCapability).toBeDefined();
    if (!placesCatalogCapability) {
      throw new Error("placesCatalog capability is missing");
    }
    if (!currencyCatalogCapability) {
      throw new Error("currencyCatalog capability is missing");
    }
    if (!weatherForecastCapability) {
      throw new Error("weatherForecast capability is missing");
    }
    if (!hotelWeatherCapability) {
      throw new Error("hotelWeather capability is missing");
    }
    if (!exchangeRatesCapability) {
      throw new Error("exchangeRates capability is missing");
    }
    if (!releaseNotesCapability) {
      throw new Error("releaseNotes capability is missing");
    }
    expect(placesCatalogCapability.status).toBe("available");
    expect(placesCatalogCapability.url).toBe("https://api.darkrio326.top/v1/locations/catalog");
    expect(placesCatalogCapability.sha256).toMatch(/^[a-f0-9]{64}$/);
    expect(placesCatalogCapability.countryCount).toBe(countries.length);
    expect(placesCatalogCapability.cityCount).toBe(cities.length);
    expect(currencyCatalogCapability.status).toBe("available");
    expect(currencyCatalogCapability.url).toBe("https://api.darkrio326.top/v1/currencies/catalog");
    expect(currencyCatalogCapability.sha256).toMatch(/^[a-f0-9]{64}$/);
    expect(currencyCatalogCapability.currencyCount).toBe(currencies.length);
    expect(currencyCatalogCapability.defaultCurrencyCode).toBe(defaultCurrencyCode);
    expect(exchangeRatesCapability.status).toBe("available");
    expect(exchangeRatesCapability.endpoint).toBe("https://api.darkrio326.top/v1/exchange-rates/rate");
    expect(exchangeRatesCapability.supportedCurrencyCodes).toEqual(currencies.map((record) => record.code));
    expect(releaseNotesCapability.status).toBe("available");
    expect(releaseNotesCapability.endpoint).toBe("https://api.darkrio326.top/v1/release-notes");
    expect(releaseNotesCapability.supportedApps).toContain("autoledger");
    expect(releaseNotesCapability.supportedVersions).toMatchObject({ autoledger: ["1.5.0", "1.6.0"] });
    expect(releaseNotesCapability.resourceVersion).toBe("2026.07.06.2");
    expect(weatherForecastCapability.status).toBe("configuration_required");
    expect(weatherForecastCapability.currentEndpoint).toBe("https://api.darkrio326.top/v1/weather/current");
    expect(hotelWeatherCapability.status).toBe("configuration_required");
    expect(hotelWeatherCapability.endpoint).toBe("https://api.darkrio326.top/v1/weather/hotel-stay-summary");
  });

  it("serves the full places catalog with an etag", async () => {
    const response = await routeFetch(new Request("https://example.test/v1/locations/catalog"), env);
    const body = await response.json();
    const etag = response.headers.get("etag");

    expect(response.status).toBe(200);
    expect(etag).toMatch(/^W\/"sha256-[a-f0-9]{64}"$/);
    expect(body).toMatchObject({
      schemaVersion: placesCatalog.schemaVersion,
      resourceVersion: placesCatalog.resourceVersion,
      supportedLocales
    });

    const cached = await routeFetch(
      new Request("https://example.test/v1/locations/catalog", {
        headers: { "if-none-match": etag ?? "" }
      }),
      env
    );
    expect(cached.status).toBe(304);
  });

  it("serves the full currency catalog with an etag", async () => {
    const response = await routeFetch(new Request("https://example.test/v1/currencies/catalog"), env);
    const body = await response.json();
    const etag = response.headers.get("etag");

    expect(response.status).toBe(200);
    expect(etag).toMatch(/^W\/"sha256-[a-f0-9]{64}"$/);
    expect(body).toMatchObject({
      schemaVersion: currenciesCatalog.schemaVersion,
      resourceVersion: currenciesCatalog.resourceVersion,
      defaultCurrencyCode,
      supportedLocales
    });

    const cached = await routeFetch(
      new Request("https://example.test/v1/currencies/catalog", {
        headers: { "if-none-match": etag ?? "" }
      }),
      env
    );
    expect(cached.status).toBe(304);
  });

  it("supports HEAD probes for cacheable read endpoints", async () => {
    const response = await routeFetch(new Request("https://example.test/v1/locations/catalog", { method: "HEAD" }), env);

    expect(response.status).toBe(200);
    expect(response.headers.get("etag")).toMatch(/^W\/"sha256-[a-f0-9]{64}"$/);
    expect(response.headers.get("access-control-allow-methods")).toContain("HEAD");
    expect(await response.text()).toBe("");

    const currenciesResponse = await routeFetch(new Request("https://example.test/v1/currencies/catalog", { method: "HEAD" }), env);

    expect(currenciesResponse.status).toBe(200);
    expect(currenciesResponse.headers.get("etag")).toMatch(/^W\/"sha256-[a-f0-9]{64}"$/);
    expect(await currenciesResponse.text()).toBe("");
  });

  it("keeps every country, city, and currency name filled for all supported locales", () => {
    expect(testInternals.validateCatalogLocales()).toEqual([]);
  });

  it("normalizes locale aliases and unknown locales safely", () => {
    expect(testInternals.normalizeLocale("zh-CN")).toBe("zh-Hans");
    expect(testInternals.normalizeLocale("zh-HK")).toBe("zh-Hant");
    expect(testInternals.normalizeLocale("ja-JP")).toBe("ja");
    expect(testInternals.normalizeLocale("ko-KR")).toBe("ko");
    expect(testInternals.normalizeLocale("en-GB")).toBe("en");
    expect(testInternals.normalizeLocale("fr-FR")).toBe("en");
  });

  it("localizes countries and filters cities after a country is selected", async () => {
    const countryResponse = await routeFetch(new Request("https://example.test/v1/locations/countries?locale=ko"), env);
    const countryBody = await jsonBody(countryResponse);
    const localizedCountries = countryBody.countries as Array<Record<string, unknown>>;
    const japan = localizedCountries.find((record) => record.countryCode === "JP");

    expect(japan?.displayName).toBe("일본");

    const cityResponse = await routeFetch(new Request("https://example.test/v1/locations/cities?country=JP&locale=zh-Hans"), env);
    const cityBody = await jsonBody(cityResponse);
    const localizedCities = cityBody.cities as Array<Record<string, unknown>>;
    const tokyo = localizedCities.find((record) => record.id === "city.jp.tokyo");

    expect(localizedCities.map((record) => record.countryCode)).toEqual(localizedCities.map(() => "JP"));
    expect(tokyo?.displayName).toBe("东京");
    expect(tokyo?.latitude).toBe(35.6762);
    expect(tokyo?.longitude).toBe(139.6503);
    expect(tokyo?.timezone).toBe("Asia/Tokyo");
  });

  it("uses country/region compliance names without changing city names", async () => {
    const zhCountryResponse = await routeFetch(new Request("https://example.test/v1/locations/countries?locale=zh-Hans"), env);
    const zhCountryBody = await jsonBody(zhCountryResponse);
    const zhCountries = zhCountryBody.countries as Array<Record<string, unknown>>;

    expect(zhCountries.find((record) => record.countryCode === "HK")?.displayName).toBe("香港（中国）");
    expect(zhCountries.find((record) => record.countryCode === "MO")?.displayName).toBe("澳门（中国）");
    expect(zhCountries.find((record) => record.countryCode === "TW")?.displayName).toBe("台湾（中国）");

    const enCountryResponse = await routeFetch(new Request("https://example.test/v1/locations/countries?locale=en"), env);
    const enCountryBody = await jsonBody(enCountryResponse);
    const enCountries = enCountryBody.countries as Array<Record<string, unknown>>;

    expect(enCountries.find((record) => record.countryCode === "HK")?.displayName).toBe("Hong Kong (China)");
    expect(enCountries.find((record) => record.countryCode === "MO")?.displayName).toBe("Macau (China)");
    expect(enCountries.find((record) => record.countryCode === "TW")?.displayName).toBe("Taiwan (China)");

    const hkCityResponse = await routeFetch(new Request("https://example.test/v1/locations/cities?country=HK&locale=en"), env);
    const hkCityBody = await jsonBody(hkCityResponse);
    const hkCities = hkCityBody.cities as Array<Record<string, unknown>>;

    expect(hkCities.find((record) => record.id === "city.hk.hong-kong")?.displayName).toBe("Hong Kong");

    const moCityResponse = await routeFetch(new Request("https://example.test/v1/locations/cities?country=MO&locale=zh-Hans"), env);
    const moCityBody = await jsonBody(moCityResponse);
    const moCities = moCityBody.cities as Array<Record<string, unknown>>;

    expect(moCities.find((record) => record.id === "city.mo.macau")?.displayName).toBe("澳门");
  });

  it("localizes currencies and publishes default conversion targets", async () => {
    const currencyResponse = await routeFetch(new Request("https://example.test/v1/currencies?locale=ko"), env);
    const currencyBody = await jsonBody(currencyResponse);
    const localizedCurrencies = currencyBody.currencies as Array<Record<string, unknown>>;
    const cny = localizedCurrencies.find((record) => record.code === "CNY");
    const jpy = localizedCurrencies.find((record) => record.code === "JPY");

    expect(currencyBody.defaultCurrencyCode).toBe("CNY");
    expect(cny?.displayName).toBe("중국 위안");
    expect(jpy?.decimalDigits).toBe(0);
  });

  it("serves versioned release notes by app version and locale", async () => {
    const response = await routeFetch(new Request("https://example.test/v1/release-notes?app=autoledger&version=1.6.0&locale=zh-Hans"), env);
    const body = await jsonBody(response);
    const current = body.current as Record<string, unknown>;
    const upcoming = body.upcoming as Record<string, unknown>;

    expect(response.status).toBe(200);
    expect(body).toMatchObject({
      schemaVersion: 1,
      app: "autoledger",
      version: "1.6.0",
      locale: "zh-Hans"
    });
    expect(current.title).toBe("当前版本");
    expect(current.body).toContain("实时 OCR");
    expect(upcoming.title).toBe("后续计划");
    expect(upcoming.body).toContain("Pro 自动化");
    expect(body.privacy).toContain("stay on device");
    expect(body).not.toHaveProperty("ledger");
    expect(response.headers.get("cache-control")).toBe("public, max-age=300");
  });

  it("keeps ASC 1.5.0 release notes available separately from the 1.6.0 draft", async () => {
    const response = await routeFetch(new Request("https://example.test/v1/release-notes?app=autoledger&version=1.5.0&locale=zh-Hans"), env);
    const body = await jsonBody(response);
    const current = body.current as Record<string, unknown>;
    const upcoming = body.upcoming as Record<string, unknown>;

    expect(response.status).toBe(200);
    expect(body).toMatchObject({
      schemaVersion: 1,
      app: "autoledger",
      version: "1.5.0",
      locale: "zh-Hans"
    });
    expect(current.body).toContain("AutoLedger Pro");
    expect(upcoming.body).toContain("订阅异常提醒");
  });

  it("falls back locale aliases for release notes without changing the requested app version", async () => {
    const response = await routeFetch(new Request("https://example.test/v1/release-notes?app=autoledger&version=1.6.0&locale=en-GB"), env);
    const body = await jsonBody(response);
    const current = body.current as Record<string, unknown>;

    expect(response.status).toBe(200);
    expect(body.locale).toBe("en");
    expect(body.version).toBe("1.6.0");
    expect(current.title).toBe("Current Version");
  });

  it("requires explicit release-note app and known version values", async () => {
    const missingApp = await routeFetch(new Request("https://example.test/v1/release-notes?version=1.6.0"), env);
    const missingVersion = await routeFetch(new Request("https://example.test/v1/release-notes?app=autoledger"), env);
    const unknownVersion = await routeFetch(new Request("https://example.test/v1/release-notes?app=autoledger&version=9.9.9"), env);

    expect(missingApp.status).toBe(400);
    expect(await jsonBody(missingApp)).toMatchObject({ error: { code: "missing_release_notes_app" } });
    expect(missingVersion.status).toBe(400);
    expect(await jsonBody(missingVersion)).toMatchObject({ error: { code: "missing_release_notes_version" } });
    expect(unknownVersion.status).toBe(404);
    expect(await jsonBody(unknownVersion)).toMatchObject({ error: { code: "release_notes_not_found" } });
  });

  it("serves exchange rate quotes without receiving transaction amounts", async () => {
    const response = await routeFetch(new Request("https://example.test/v1/exchange-rates/rate?base=USD&quote=CNY&date=2026-07-01"), env);
    const body = await jsonBody(response);

    expect(response.status).toBe(200);
    expect(body).toMatchObject({
      schemaVersion: 1,
      provider: "mock",
      requestedDate: "2026-07-01",
      date: "2026-07-01",
      baseCurrencyCode: "USD",
      quoteCurrencyCode: "CNY",
      rate: 7.1111
    });
    expect(body).not.toHaveProperty("amount");
    expect(body.privacy).toContain("Transaction amounts stay on device");
    expect(response.headers.get("cache-control")).toBe("public, max-age=86400");
    expect(response.headers.get("x-common-api-cache")).toBe("bypass");
  });

  it("caches exchange rate quotes behind a normalized cache key", async () => {
    const cache = new MemoryCache();
    const request = new Request("https://example.test/v1/exchange-rates/rate?quote=CNY&base=USD&date=2026-07-01");

    const first = await exchangeRateEndpoint(request, env, { cache });
    const second = await exchangeRateEndpoint(request, env, { cache });
    const cacheKey = testInternals.exchangeRateTestInternals.exchangeRateCacheKey(env, "USD", "CNY", "2026-07-01");

    expect(first.status).toBe(200);
    expect(first.headers?.["x-common-api-cache"]).toBe("miss");
    expect(second.status).toBe(200);
    expect(second.headers?.["x-common-api-cache"]).toBe("hit");
    expect(second.body).toEqual(first.body);
    expect(cacheKey.url).toBe("https://darkrio-common-api.local/v1/exchange-rates/rate?provider=mock&base=USD&quote=CNY&date=2026-07-01");
  });

  it("handles same-currency exchange rates locally", async () => {
    const response = await routeFetch(new Request("https://example.test/v1/exchange-rates/rate?base=CNY&quote=CNY"), env);
    const body = await jsonBody(response);

    expect(response.status).toBe(200);
    expect(body).toMatchObject({
      provider: "identity",
      baseCurrencyCode: "CNY",
      quoteCurrencyCode: "CNY",
      rate: 1,
      inverseRate: 1
    });
  });

  it("validates exchange rate parameters before provider calls", async () => {
    const missingBase = await routeFetch(new Request("https://example.test/v1/exchange-rates/rate?quote=CNY"), env);
    const unsupportedQuote = await routeFetch(new Request("https://example.test/v1/exchange-rates/rate?base=USD&quote=XXX"), env);
    const invalidDate = await routeFetch(new Request("https://example.test/v1/exchange-rates/rate?base=USD&quote=CNY&date=2026-02-31"), env);
    const futureDate = await routeFetch(new Request("https://example.test/v1/exchange-rates/rate?base=USD&quote=CNY&date=9999-01-01"), env);

    expect(missingBase.status).toBe(400);
    expect(await jsonBody(missingBase)).toMatchObject({ error: { code: "missing_base_currency" } });
    expect(unsupportedQuote.status).toBe(400);
    expect(await jsonBody(unsupportedQuote)).toMatchObject({ error: { code: "unsupported_quote_currency" } });
    expect(invalidDate.status).toBe(400);
    expect(await jsonBody(invalidDate)).toMatchObject({ error: { code: "invalid_rate_date" } });
    expect(futureDate.status).toBe(400);
    expect(await jsonBody(futureDate)).toMatchObject({ error: { code: "future_rate_date_not_supported" } });
  });

  it("keeps exchange rate provider configuration explicit", async () => {
    const response = await routeFetch(new Request("https://example.test/v1/exchange-rates/rate?base=USD&quote=CNY"), disabledExchangeEnv);

    expect(response.status).toBe(503);
    expect(await jsonBody(response)).toMatchObject({ error: { code: "exchange_rate_provider_not_configured" } });
  });

  it("keeps hotel stay weather disabled until provider secrets are configured", async () => {
    const weather = await routeFetch(
      new Request("https://example.test/v1/weather/hotel-stay-summary?lat=35.6&lon=139.7&checkIn=2026-07-01&checkOut=2026-07-03"),
      env
    );

    expect(weather.status).toBe(503);
    expect(await jsonBody(weather)).toMatchObject({ error: { code: "weather_provider_not_configured" } });
  });

  it("serves hotel stay weather summaries when a provider is configured", async () => {
    const response = await routeFetch(
      new Request("https://example.test/v1/weather/hotel-stay-summary?lat=35.6&lon=139.7&checkIn=2026-07-01&checkOut=2026-07-03&locale=zh-Hans&timezone=Asia/Tokyo"),
      mockWeatherEnv
    );
    const body = await jsonBody(response);
    const data = body.data as Record<string, unknown>;

    expect(response.status).toBe(200);
    expect(body).toMatchObject({
      provider: "mock",
      cached: false,
      privacy: expect.stringContaining("Only coordinates")
    });
    expect(data).toMatchObject({
      checkIn: "2026-07-01",
      checkOut: "2026-07-03",
      timezone: "Asia/Tokyo",
      units: "metric"
    });
    expect(data).not.toHaveProperty("hotelName");
    expect(data).not.toHaveProperty("amount");
    expect(data).not.toHaveProperty("folioText");
    expect(data.days as unknown[]).toHaveLength(2);
  });

  it("parses WeatherKit daily summary numeric day records", () => {
    const days = weatherProviderTestInternals.extractWeatherKitDailySummaryDays(
      {
        days: [
          {
            date: 20635,
            temperatureMin: 22.739359,
            temperatureMax: 27.76866,
            precipitationAmount: 0.899,
            snowfallAmount: 0
          }
        ]
      },
      {
        lat: 35.68,
        lon: 139.76,
        locale: "en",
        timezone: "Asia/Tokyo",
        checkIn: "2026-07-01",
        checkOut: "2026-07-02",
        units: "metric"
      }
    );

    expect(days).toEqual([
      {
        date: "2026-07-01",
        tempMin: 22.739359,
        tempMax: 27.76866,
        precipitationAmount: 0.899,
        snowfallAmount: 0,
        description: "Summary",
        icon: "Summary"
      }
    ]);
  });

  it("rejects hotel stay weather dates outside the supported historical window", async () => {
    const tooOld = await routeFetch(
      new Request("https://example.test/v1/weather/hotel-stay-summary?lat=35.6&lon=139.7&checkIn=2021-07-31&checkOut=2021-08-02"),
      mockWeatherEnv
    );
    const future = await routeFetch(
      new Request("https://example.test/v1/weather/hotel-stay-summary?lat=35.6&lon=139.7&checkIn=9999-01-01&checkOut=9999-01-03"),
      mockWeatherEnv
    );

    expect(tooOld.status).toBe(422);
    expect(await jsonBody(tooOld)).toMatchObject({ error: { code: "weather_history_out_of_range" } });
    expect(future.status).toBe(400);
    expect(await jsonBody(future)).toMatchObject({ error: { code: "future_stay_weather_not_supported" } });
  });

  it("keeps live weather disabled until provider secrets are configured", async () => {
    const response = await routeFetch(new Request("https://example.test/v1/weather/current?lat=35.68&lon=139.76"), env);

    expect(response.status).toBe(503);
    expect(await jsonBody(response)).toMatchObject({ error: { code: "weather_provider_not_configured" } });
  });

  it("validates weather coordinates before calling providers", async () => {
    const missing = await routeFetch(new Request("https://example.test/v1/weather/current?lat=35.68"), mockWeatherEnv);
    const invalid = await routeFetch(new Request("https://example.test/v1/weather/forecast?lat=91&lon=139.76"), mockWeatherEnv);

    expect(missing.status).toBe(400);
    expect(await jsonBody(missing)).toMatchObject({ error: { code: "missing_coordinates" } });
    expect(invalid.status).toBe(400);
    expect(await jsonBody(invalid)).toMatchObject({ error: { code: "invalid_coordinates" } });
  });

  it("serves migrated current and forecast weather contracts when a provider is configured", async () => {
    const current = await routeFetch(
      new Request("https://example.test/v1/weather/current?lat=35.68&lon=139.76&locale=ja&timezone=Asia/Tokyo"),
      mockWeatherEnv
    );
    const forecast = await routeFetch(
      new Request("https://example.test/v1/weather/forecast?lat=35.68&lon=139.76&locale=ko&timezone=Asia/Seoul"),
      mockWeatherEnv
    );

    expect(current.status).toBe(200);
    expect(await jsonBody(current)).toMatchObject({
      provider: "mock",
      data: {
        location: { lat: 35.68, lon: 139.76, timezone: "Asia/Tokyo" },
        current: { icon: "MostlyCloudy" }
      }
    });
    expect(forecast.status).toBe(200);
    const forecastBody = await jsonBody(forecast);
    expect(forecastBody.provider).toBe("mock");
    expect(((forecastBody.data as Record<string, unknown>).hourly as unknown[])).toHaveLength(24);
    expect(((forecastBody.data as Record<string, unknown>).daily as unknown[])).toHaveLength(7);
  });

  it("handles CORS preflight and read-only method boundaries", async () => {
    const options = await routeFetch(new Request("https://example.test/v1/manifest", { method: "OPTIONS" }), env);
    const post = await routeFetch(new Request("https://example.test/v1/manifest", { method: "POST" }), env);

    expect(options.status).toBe(204);
    expect(options.headers.get("access-control-allow-origin")).toBe("*");
    expect(post.status).toBe(405);
  });
});
