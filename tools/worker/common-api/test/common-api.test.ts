import { describe, expect, it } from "vitest";
import { cities, countries, placesCatalog, supportedLocales } from "../src/places-catalog";
import { routeFetch, testInternals } from "../src/index";

const env = { PUBLIC_API_ORIGIN: "https://api.darkrio326.top", WEATHER_PROVIDER: "disabled" } as Env;
const mockWeatherEnv = { PUBLIC_API_ORIGIN: "https://api.darkrio326.top", WEATHER_PROVIDER: "mock" } as unknown as Env;

async function jsonBody(response: Response): Promise<Record<string, unknown>> {
  return (await response.json()) as Record<string, unknown>;
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
    const weatherForecastCapability = capabilities.weatherForecast;

    expect(response.status).toBe(200);
    expect(body.supportedLocales).toEqual(supportedLocales);
    expect(placesCatalogCapability).toBeDefined();
    expect(weatherForecastCapability).toBeDefined();
    if (!placesCatalogCapability) {
      throw new Error("placesCatalog capability is missing");
    }
    if (!weatherForecastCapability) {
      throw new Error("weatherForecast capability is missing");
    }
    expect(placesCatalogCapability.status).toBe("available");
    expect(placesCatalogCapability.url).toBe("https://api.darkrio326.top/v1/locations/catalog");
    expect(placesCatalogCapability.sha256).toMatch(/^[a-f0-9]{64}$/);
    expect(placesCatalogCapability.countryCount).toBe(countries.length);
    expect(placesCatalogCapability.cityCount).toBe(cities.length);
    expect(weatherForecastCapability.status).toBe("configuration_required");
    expect(weatherForecastCapability.currentEndpoint).toBe("https://api.darkrio326.top/v1/weather/current");
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

  it("supports HEAD probes for cacheable read endpoints", async () => {
    const response = await routeFetch(new Request("https://example.test/v1/locations/catalog", { method: "HEAD" }), env);

    expect(response.status).toBe(200);
    expect(response.headers.get("etag")).toMatch(/^W\/"sha256-[a-f0-9]{64}"$/);
    expect(response.headers.get("access-control-allow-methods")).toContain("HEAD");
    expect(await response.text()).toBe("");
  });

  it("keeps every country and city name filled for all supported locales", () => {
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

    expect(localizedCities.map((record) => record.countryCode)).toEqual(localizedCities.map(() => "JP"));
    expect(localizedCities.find((record) => record.id === "city.jp.tokyo")?.displayName).toBe("东京");
  });

  it("keeps planned exchange rate and weather endpoints explicit", async () => {
    const rate = await routeFetch(new Request("https://example.test/v1/exchange-rates/rate?base=USD&quote=CNY&date=2026-07-02"), env);
    const weather = await routeFetch(
      new Request("https://example.test/v1/weather/hotel-stay-summary?lat=35.6&lon=139.7&checkIn=2026-07-01"),
      env
    );

    expect(rate.status).toBe(501);
    expect(await jsonBody(rate)).toMatchObject({ error: { code: "exchange_rates_not_implemented" } });
    expect(weather.status).toBe(501);
    expect(await jsonBody(weather)).toMatchObject({ error: { code: "hotel_weather_not_implemented" } });
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
