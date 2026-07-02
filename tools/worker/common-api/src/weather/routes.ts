import {
  getCurrentWeatherCache,
  getForecastWeatherCache,
  setCurrentWeatherCache,
  setForecastWeatherCache
} from "./cache";
import { createWeatherProvider } from "./providers";
import type { WeatherQuery } from "./types";

export type APIResult = {
  status: number;
  body: unknown;
  cacheControl?: string;
};

export async function currentWeatherEndpoint(request: Request, env: Env): Promise<APIResult> {
  const parsed = parseWeatherQuery(request);
  if (!parsed.ok) {
    return parsed.error;
  }

  const provider = createWeatherProvider(env);
  if (!provider.ok) {
    return { status: 503, body: { error: { code: provider.code, message: provider.message } }, cacheControl: "no-store" };
  }

  const cached = getCurrentWeatherCache(parsed.query.lat, parsed.query.lon);
  if (cached) {
    return {
      status: 200,
      body: {
        provider: cached.provider,
        cached: true,
        data: cached.data
      },
      cacheControl: "public, max-age=60"
    };
  }

  try {
    const data = await provider.provider.getCurrentWeather(parsed.query);
    setCurrentWeatherCache(parsed.query.lat, parsed.query.lon, provider.provider.name, data);
    return {
      status: 200,
      body: {
        provider: provider.provider.name,
        cached: false,
        data
      },
      cacheControl: "public, max-age=60"
    };
  } catch (caught) {
    return {
      status: 502,
      body: {
        error: {
          code: "weather_provider_failed",
          message: caught instanceof Error ? caught.message : String(caught)
        }
      },
      cacheControl: "no-store"
    };
  }
}

export async function forecastWeatherEndpoint(request: Request, env: Env): Promise<APIResult> {
  const parsed = parseWeatherQuery(request);
  if (!parsed.ok) {
    return parsed.error;
  }

  const provider = createWeatherProvider(env);
  if (!provider.ok) {
    return { status: 503, body: { error: { code: provider.code, message: provider.message } }, cacheControl: "no-store" };
  }

  const cached = getForecastWeatherCache(parsed.query.lat, parsed.query.lon);
  if (cached) {
    return {
      status: 200,
      body: {
        provider: cached.provider,
        cached: true,
        data: cached.data
      },
      cacheControl: "public, max-age=60"
    };
  }

  try {
    const data = await provider.provider.getForecast(parsed.query);
    setForecastWeatherCache(parsed.query.lat, parsed.query.lon, provider.provider.name, data);
    return {
      status: 200,
      body: {
        provider: provider.provider.name,
        cached: false,
        data
      },
      cacheControl: "public, max-age=60"
    };
  } catch (caught) {
    return {
      status: 502,
      body: {
        error: {
          code: "weather_provider_failed",
          message: caught instanceof Error ? caught.message : String(caught)
        }
      },
      cacheControl: "no-store"
    };
  }
}

function parseWeatherQuery(request: Request): { ok: true; query: WeatherQuery } | { ok: false; error: APIResult } {
  const url = new URL(request.url);
  const lat = numericQuery(url, "lat");
  const lon = numericQuery(url, "lon");

  if (lat === null || lon === null) {
    return {
      ok: false,
      error: {
        status: 400,
        body: { error: { code: "missing_coordinates", message: "Missing required query params: lat and lon." } },
        cacheControl: "no-store"
      }
    };
  }

  if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
    return {
      ok: false,
      error: {
        status: 400,
        body: { error: { code: "invalid_coordinates", message: "lat must be -90...90 and lon must be -180...180." } },
        cacheControl: "no-store"
      }
    };
  }

  return {
    ok: true,
    query: {
      lat,
      lon,
      locale: url.searchParams.get("locale")?.trim() || "en",
      timezone: url.searchParams.get("timezone")?.trim() || "UTC"
    }
  };
}

function numericQuery(url: URL, name: string): number | null {
  const value = url.searchParams.get(name);
  if (!value) {
    return null;
  }
  const numberValue = Number.parseFloat(value);
  return Number.isFinite(numberValue) ? numberValue : null;
}
