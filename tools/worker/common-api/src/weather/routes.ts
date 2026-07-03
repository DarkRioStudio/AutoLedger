import {
  getCurrentWeatherCache,
  getForecastWeatherCache,
  getHotelStayWeatherCache,
  setCurrentWeatherCache,
  setForecastWeatherCache,
  setHotelStayWeatherCache
} from "./cache";
import { createWeatherProvider } from "./providers";
import type { HotelStayWeatherQuery, WeatherQuery } from "./types";

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

export async function hotelStayWeatherEndpoint(request: Request, env: Env): Promise<APIResult> {
  const parsed = parseHotelStayWeatherQuery(request);
  if (!parsed.ok) {
    return parsed.error;
  }

  const provider = createWeatherProvider(env);
  if (!provider.ok) {
    return { status: 503, body: { error: { code: provider.code, message: provider.message } }, cacheControl: "no-store" };
  }
  if (!provider.provider.getHotelStaySummary) {
    return {
      status: 501,
      body: {
        error: {
          code: "hotel_weather_not_supported_by_provider",
          message: "The configured weather provider does not support hotel stay daily summaries."
        }
      },
      cacheControl: "no-store"
    };
  }

  const cached = getHotelStayWeatherCache(
    parsed.query.lat,
    parsed.query.lon,
    parsed.query.checkIn,
    parsed.query.checkOut
  );
  if (cached) {
    return {
      status: 200,
      body: {
        provider: cached.provider,
        cached: true,
        data: cached.data,
        privacy: "Only coordinates, stay dates, locale, timezone, and units are sent to the weather provider."
      },
      cacheControl: "public, max-age=300"
    };
  }

  try {
    const data = await provider.provider.getHotelStaySummary(parsed.query);
    setHotelStayWeatherCache(
      parsed.query.lat,
      parsed.query.lon,
      parsed.query.checkIn,
      parsed.query.checkOut,
      provider.provider.name,
      data
    );
    return {
      status: 200,
      body: {
        provider: provider.provider.name,
        cached: false,
        data,
        privacy: "Only coordinates, stay dates, locale, timezone, and units are sent to the weather provider."
      },
      cacheControl: "public, max-age=300"
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
  const parsed = parseWeatherBaseQuery(request);
  if (!parsed.ok) {
    return parsed;
  }
  return { ok: true, query: parsed.query };
}

function parseHotelStayWeatherQuery(
  request: Request
): { ok: true; query: HotelStayWeatherQuery } | { ok: false; error: APIResult } {
  const parsed = parseWeatherBaseQuery(request);
  if (!parsed.ok) {
    return parsed;
  }

  const url = new URL(request.url);
  const checkIn = dateOnlyQuery(url, "checkIn");
  const checkOut = dateOnlyQuery(url, "checkOut");
  if (!checkIn || !checkOut) {
    return {
      ok: false,
      error: {
        status: 400,
        body: { error: { code: "missing_stay_dates", message: "Missing required query params: checkIn and checkOut." } },
        cacheControl: "no-store"
      }
    };
  }

  if (checkOut <= checkIn) {
    return {
      ok: false,
      error: {
        status: 400,
        body: { error: { code: "invalid_stay_dates", message: "checkOut must be later than checkIn." } },
        cacheControl: "no-store"
      }
    };
  }

  const summaryEndDate = addDays(checkOut, -1);
  if (checkIn < "2021-08-01") {
    return {
      ok: false,
      error: {
        status: 422,
        body: {
          error: {
            code: "weather_history_out_of_range",
            message: "WeatherKit daily summary history starts on 2021-08-01."
          }
        },
        cacheControl: "no-store"
      }
    };
  }

  const today = currentDateISO();
  if (checkIn > today || summaryEndDate > today) {
    return {
      ok: false,
      error: {
        status: 400,
        body: {
          error: {
            code: "future_stay_weather_not_supported",
            message: "Hotel stay weather summary currently supports historical stay dates only."
          }
        },
        cacheControl: "no-store"
      }
    };
  }

  if (daysBetween(checkIn, checkOut) > 31) {
    return {
      ok: false,
      error: {
        status: 400,
        body: {
          error: {
            code: "stay_date_range_too_large",
            message: "Hotel stay weather summary supports up to 31 nights per request."
          }
        },
        cacheControl: "no-store"
      }
    };
  }

  const units = url.searchParams.get("units")?.trim().toLowerCase() || "metric";
  if (units !== "metric") {
    return {
      ok: false,
      error: {
        status: 400,
        body: {
          error: {
            code: "unsupported_weather_units",
            message: "Hotel stay weather summary currently supports metric units only."
          }
        },
        cacheControl: "no-store"
      }
    };
  }

  return {
    ok: true,
    query: {
      ...parsed.query,
      checkIn,
      checkOut,
      units
    }
  };
}

function parseWeatherBaseQuery(request: Request): { ok: true; query: WeatherQuery } | { ok: false; error: APIResult } {
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

function dateOnlyQuery(url: URL, name: string): string | null {
  const value = url.searchParams.get(name)?.trim() ?? "";
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return null;
  }
  const parsed = new Date(`${value}T00:00:00.000Z`);
  return Number.isFinite(parsed.getTime()) && parsed.toISOString().slice(0, 10) === value ? value : null;
}

function addDays(date: string, days: number): string {
  const parsed = new Date(`${date}T00:00:00.000Z`);
  parsed.setUTCDate(parsed.getUTCDate() + days);
  return parsed.toISOString().slice(0, 10);
}

function daysBetween(start: string, end: string): number {
  const startTime = new Date(`${start}T00:00:00.000Z`).getTime();
  const endTime = new Date(`${end}T00:00:00.000Z`).getTime();
  return Math.round((endTime - startTime) / 86_400_000);
}

function currentDateISO(): string {
  return new Date().toISOString().slice(0, 10);
}
