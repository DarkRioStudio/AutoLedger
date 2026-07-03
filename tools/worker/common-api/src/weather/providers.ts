import { generateWeatherKitToken } from "./jwt";
import type {
  CurrentWeather,
  ForecastWeather,
  HotelStayWeatherDay,
  HotelStayWeatherQuery,
  HotelStayWeatherSummary,
  WeatherProvider,
  WeatherProviderName,
  WeatherQuery
} from "./types";

type WeatherRuntimeEnv = Env & {
  WEATHER_PROVIDER?: string;
  WEATHER_API_KEY?: string;
  WEATHERKIT_TEAM_ID?: string;
  WEATHERKIT_SERVICE_ID?: string;
  WEATHERKIT_KEY_ID?: string;
  WEATHERKIT_PRIVATE_KEY?: string;
};

type WeatherProviderResult =
  | { ok: true; provider: WeatherProvider }
  | {
      ok: false;
      code: "weather_provider_not_configured" | "unsupported_weather_provider";
      message: string;
    };

export function createWeatherProvider(env: Env): WeatherProviderResult {
  const runtime = env as WeatherRuntimeEnv;
  const provider = (runtime.WEATHER_PROVIDER?.trim().toLowerCase() || "disabled") as WeatherProviderName | "disabled";

  if (provider === "disabled") {
    return {
      ok: false,
      code: "weather_provider_not_configured",
      message: "Weather provider is disabled. Configure WEATHER_PROVIDER and provider secrets before using weather endpoints."
    };
  }

  if (provider === "mock") {
    return { ok: true, provider: new MockWeatherProvider() };
  }

  if (provider === "openweathermap") {
    const apiKey = runtime.WEATHER_API_KEY?.trim();
    if (!apiKey) {
      return {
        ok: false,
        code: "weather_provider_not_configured",
        message: "OpenWeatherMap provider requires WEATHER_API_KEY."
      };
    }
    return { ok: true, provider: new OpenWeatherMapProvider(apiKey) };
  }

  if (provider === "weatherkit") {
    const teamID = runtime.WEATHERKIT_TEAM_ID?.trim();
    const serviceID = runtime.WEATHERKIT_SERVICE_ID?.trim();
    const keyID = runtime.WEATHERKIT_KEY_ID?.trim();
    const privateKey = runtime.WEATHERKIT_PRIVATE_KEY?.trim();
    if (!teamID || !serviceID || !keyID || !privateKey) {
      return {
        ok: false,
        code: "weather_provider_not_configured",
        message: "WeatherKit provider requires WEATHERKIT_TEAM_ID, WEATHERKIT_SERVICE_ID, WEATHERKIT_KEY_ID, and WEATHERKIT_PRIVATE_KEY."
      };
    }
    return {
      ok: true,
      provider: new WeatherKitProvider({
        teamID,
        serviceID,
        keyID,
        privateKeyPEM: privateKey
      })
    };
  }

  return {
    ok: false,
    code: "unsupported_weather_provider",
    message: `Unsupported weather provider: ${provider}.`
  };
}

class MockWeatherProvider implements WeatherProvider {
  name = "mock" as const;

  async getCurrentWeather(query: WeatherQuery): Promise<CurrentWeather> {
    return {
      location: {
        name: "Mock City",
        lat: query.lat,
        lon: query.lon,
        country: "",
        timezone: query.timezone
      },
      current: {
        temp: 22.5,
        feelsLike: 21,
        humidity: 60,
        pressure: 1013,
        windSpeed: 3.5,
        windDeg: 180,
        description: conditionDescription("MostlyCloudy", query.locale),
        icon: "MostlyCloudy",
        dt: Math.floor(Date.now() / 1000)
      }
    };
  }

  async getForecast(query: WeatherQuery): Promise<ForecastWeather> {
    const now = Math.floor(Date.now() / 1000);
    return {
      location: { lat: query.lat, lon: query.lon },
      hourly: Array.from({ length: 24 }, (_, index) => ({
        dt: now + index * 3600,
        temp: 20 + Math.sin(index / 4) * 5,
        humidity: 60,
        windSpeed: 3,
        description: conditionDescription("MostlyCloudy", query.locale),
        icon: "MostlyCloudy"
      })),
      daily: Array.from({ length: 7 }, (_, index) => ({
        dt: now + index * 86400,
        tempMin: 16 + index,
        tempMax: 25 + index,
        humidity: 55,
        windSpeed: 2.5,
        description: conditionDescription("Clear", query.locale),
        icon: "Clear"
      }))
    };
  }

  async getHotelStaySummary(query: HotelStayWeatherQuery): Promise<HotelStayWeatherSummary> {
    return {
      location: { lat: query.lat, lon: query.lon },
      checkIn: query.checkIn,
      checkOut: query.checkOut,
      timezone: query.timezone,
      units: query.units,
      days: dateRange(query.checkIn, query.checkOut).map((date, index) => ({
        date,
        tempMin: 18 + index,
        tempMax: 26 + index,
        precipitationAmount: index === 0 ? 0.8 : 0,
        snowfallAmount: 0,
        description: conditionDescription(index === 0 ? "Rain" : "Clear", query.locale),
        icon: index === 0 ? "Rain" : "Clear"
      }))
    };
  }
}

class OpenWeatherMapProvider implements WeatherProvider {
  name = "openweathermap" as const;

  constructor(private readonly apiKey: string) {}

  async getCurrentWeather(query: WeatherQuery): Promise<CurrentWeather> {
    const url = new URL("https://api.openweathermap.org/data/2.5/weather");
    url.searchParams.set("lat", String(query.lat));
    url.searchParams.set("lon", String(query.lon));
    url.searchParams.set("appid", this.apiKey);
    url.searchParams.set("units", "metric");
    url.searchParams.set("lang", openWeatherLocale(query.locale));

    const response = await fetch(url.toString());
    if (!response.ok) {
      throw new Error(`OpenWeatherMap API error: ${response.status} ${response.statusText}`);
    }

    const data = (await response.json()) as OpenWeatherMapCurrentResponse;
    return {
      location: {
        name: data.name,
        lat: data.coord.lat,
        lon: data.coord.lon,
        country: data.sys.country,
        timezone: `UTC${data.timezone >= 0 ? "+" : ""}${data.timezone / 3600}`
      },
      current: {
        temp: data.main.temp,
        feelsLike: data.main.feels_like,
        humidity: data.main.humidity,
        pressure: data.main.pressure,
        windSpeed: data.wind.speed,
        windDeg: data.wind.deg,
        description: data.weather[0]?.description ?? "",
        icon: data.weather[0]?.icon ?? "",
        dt: data.dt
      }
    };
  }

  async getForecast(): Promise<ForecastWeather> {
    throw new Error("OpenWeatherMap forecast is not implemented; use WeatherKit or mock provider.");
  }
}

class WeatherKitProvider implements WeatherProvider {
  name = "weatherkit" as const;

  constructor(
    private readonly config: {
      teamID: string;
      serviceID: string;
      keyID: string;
      privateKeyPEM: string;
    }
  ) {}

  async getCurrentWeather(query: WeatherQuery): Promise<CurrentWeather> {
    const data = await this.fetchWeatherKit(query, "currentWeather");
    const current = data.currentWeather;
    if (!current) {
      throw new Error("WeatherKit currentWeather dataset is missing.");
    }

    return {
      location: {
        name: "",
        lat: query.lat,
        lon: query.lon,
        country: "",
        timezone: query.timezone
      },
      current: {
        temp: current.temperature,
        feelsLike: current.temperatureApparent,
        humidity: Math.round(current.humidity * 100),
        pressure: current.pressure,
        windSpeed: current.windSpeed,
        windDeg: current.windDirection,
        description: conditionDescription(current.conditionCode, query.locale),
        icon: current.conditionCode,
        dt: Math.floor(new Date(current.asOf).getTime() / 1000)
      }
    };
  }

  async getForecast(query: WeatherQuery): Promise<ForecastWeather> {
    const data = await this.fetchWeatherKit(query, "forecastHourly,forecastDaily");
    const hourly = (data.forecastHourly?.hours ?? []).slice(0, 24).map((hour) => ({
      dt: Math.floor(new Date(hour.forecastStart).getTime() / 1000),
      temp: hour.temperature,
      humidity: Math.round(hour.humidity * 100),
      windSpeed: hour.windSpeed,
      description: conditionDescription(hour.conditionCode, query.locale),
      icon: hour.conditionCode
    }));
    const daily = (data.forecastDaily?.days ?? []).slice(0, 7).map((day) => ({
      dt: Math.floor(new Date(day.forecastStart).getTime() / 1000),
      tempMin: day.temperatureMin,
      tempMax: day.temperatureMax,
      humidity: Math.round((day.daytimeForecast?.humidity ?? 0) * 100),
      windSpeed: day.daytimeForecast?.windSpeed ?? 0,
      description: conditionDescription(day.conditionCode, query.locale),
      icon: day.conditionCode
    }));

    return { location: { lat: query.lat, lon: query.lon }, hourly, daily };
  }

  async getHotelStaySummary(query: HotelStayWeatherQuery): Promise<HotelStayWeatherSummary> {
    const data = await this.fetchWeatherKitDailySummary(query);
    const days = extractWeatherKitDailySummaryDays(data, query);
    return {
      location: { lat: query.lat, lon: query.lon },
      checkIn: query.checkIn,
      checkOut: query.checkOut,
      timezone: query.timezone,
      units: query.units,
      days,
      unavailableReason: days.length === 0 ? "weatherkit_daily_summary_empty" : undefined
    };
  }

  private async fetchWeatherKit(query: WeatherQuery, dataSets: string): Promise<WeatherKitResponse> {
    const token = await generateWeatherKitToken(this.config);
    const url = new URL(
      `https://weatherkit.apple.com/api/v1/weather/${weatherKitLocale(query.locale)}/${query.lat}/${query.lon}`
    );
    url.searchParams.set("dataSets", dataSets);
    url.searchParams.set("timezone", query.timezone);

    const response = await fetch(url.toString(), {
      method: "GET",
      headers: {
        authorization: `Bearer ${token}`,
        accept: "application/json"
      }
    });
    if (!response.ok) {
      throwWeatherKitAPIError(response);
    }
    return (await response.json()) as WeatherKitResponse;
  }

  private async fetchWeatherKitDailySummary(query: HotelStayWeatherQuery): Promise<WeatherKitDailySummaryResponse> {
    const token = await generateWeatherKitToken(this.config);
    const url = new URL(`https://weatherkit.apple.com/api/v2/summary/daily/${query.lat}/${query.lon}`);
    url.searchParams.set("dataSets", "temperature,precipitation");
    url.searchParams.set("start", query.checkIn);
    url.searchParams.set("end", addDays(query.checkOut, -1));
    url.searchParams.set("timezone", query.timezone);

    const response = await fetch(url.toString(), {
      method: "GET",
      headers: {
        authorization: `Bearer ${token}`,
        accept: "application/json"
      }
    });
    if (!response.ok) {
      throwWeatherKitAPIError(response);
    }
    return (await response.json()) as WeatherKitDailySummaryResponse;
  }
}

function throwWeatherKitAPIError(response: Response): never {
  if (response.status === 401) {
    throw new Error("WeatherKit auth failed: JWT token invalid or expired.");
  }
  if (response.status === 403) {
    throw new Error("WeatherKit request is forbidden; check service ID, key, and environment.");
  }
  throw new Error(`WeatherKit API error: ${response.status} ${response.statusText}`);
}

function weatherKitLocale(locale: string): string {
  const normalized = locale.toLowerCase();
  if (normalized.startsWith("zh-hant")) {
    return "zh_TW";
  }
  if (normalized.startsWith("zh")) {
    return "zh_CN";
  }
  if (normalized.startsWith("ja")) {
    return "ja_JP";
  }
  if (normalized.startsWith("ko")) {
    return "ko_KR";
  }
  return "en_US";
}

function openWeatherLocale(locale: string): string {
  const normalized = locale.toLowerCase();
  if (normalized.startsWith("zh-hant")) {
    return "zh_tw";
  }
  if (normalized.startsWith("zh")) {
    return "zh_cn";
  }
  if (normalized.startsWith("ja")) {
    return "ja";
  }
  if (normalized.startsWith("ko")) {
    return "kr";
  }
  return "en";
}

function conditionDescription(code: string, locale: string): string {
  const normalized = locale.toLowerCase();
  const table = normalized.startsWith("zh")
    ? zhConditionDescriptions
    : normalized.startsWith("ja")
      ? jaConditionDescriptions
      : normalized.startsWith("ko")
        ? koConditionDescriptions
        : enConditionDescriptions;
  return table[code] ?? enConditionDescriptions[code] ?? code;
}

const enConditionDescriptions: Record<string, string> = {
  Clear: "Clear",
  MostlyClear: "Mostly clear",
  PartlyCloudy: "Partly cloudy",
  MostlyCloudy: "Mostly cloudy",
  Cloudy: "Cloudy",
  Overcast: "Overcast",
  Foggy: "Fog",
  Haze: "Haze",
  Smoky: "Smoke",
  Breezy: "Breezy",
  Windy: "Windy",
  Drizzle: "Drizzle",
  Rain: "Rain",
  HeavyRain: "Heavy rain",
  Thunderstorms: "Thunderstorms",
  Snow: "Snow",
  HeavySnow: "Heavy snow",
  Sleet: "Sleet",
  FreezingRain: "Freezing rain",
  Hail: "Hail",
  Hot: "Hot",
  Cold: "Cold"
};

const zhConditionDescriptions: Record<string, string> = {
  Clear: "晴",
  MostlyClear: "大部晴朗",
  PartlyCloudy: "局部多云",
  MostlyCloudy: "大部多云",
  Cloudy: "多云",
  Overcast: "阴",
  Foggy: "雾",
  Haze: "霾",
  Smoky: "烟霾",
  Breezy: "微风",
  Windy: "大风",
  Drizzle: "毛毛雨",
  Rain: "雨",
  HeavyRain: "大雨",
  Thunderstorms: "雷暴",
  Snow: "雪",
  HeavySnow: "大雪",
  Sleet: "雨夹雪",
  FreezingRain: "冻雨",
  Hail: "冰雹",
  Hot: "高温",
  Cold: "寒冷"
};

const jaConditionDescriptions: Record<string, string> = {
  Clear: "晴れ",
  MostlyClear: "ほぼ晴れ",
  PartlyCloudy: "一部曇り",
  MostlyCloudy: "ほぼ曇り",
  Cloudy: "曇り",
  Overcast: "厚い雲",
  Foggy: "霧",
  Haze: "もや",
  Smoky: "煙霧",
  Breezy: "微風",
  Windy: "強風",
  Drizzle: "霧雨",
  Rain: "雨",
  HeavyRain: "大雨",
  Thunderstorms: "雷雨",
  Snow: "雪",
  HeavySnow: "大雪",
  Sleet: "みぞれ",
  FreezingRain: "着氷性の雨",
  Hail: "ひょう",
  Hot: "高温",
  Cold: "低温"
};

const koConditionDescriptions: Record<string, string> = {
  Clear: "맑음",
  MostlyClear: "대체로 맑음",
  PartlyCloudy: "부분적으로 흐림",
  MostlyCloudy: "대체로 흐림",
  Cloudy: "흐림",
  Overcast: "구름 많음",
  Foggy: "안개",
  Haze: "연무",
  Smoky: "연기",
  Breezy: "산들바람",
  Windy: "강풍",
  Drizzle: "이슬비",
  Rain: "비",
  HeavyRain: "폭우",
  Thunderstorms: "뇌우",
  Snow: "눈",
  HeavySnow: "폭설",
  Sleet: "진눈깨비",
  FreezingRain: "어는 비",
  Hail: "우박",
  Hot: "고온",
  Cold: "저온"
};

function dateRange(start: string, exclusiveEnd: string): string[] {
  const dates: string[] = [];
  let current = start;
  while (current < exclusiveEnd) {
    dates.push(current);
    current = addDays(current, 1);
  }
  return dates;
}

function addDays(date: string, days: number): string {
  const parsed = new Date(`${date}T00:00:00.000Z`);
  parsed.setUTCDate(parsed.getUTCDate() + days);
  return parsed.toISOString().slice(0, 10);
}

function extractWeatherKitDailySummaryDays(
  data: WeatherKitDailySummaryResponse,
  query: HotelStayWeatherQuery
): HotelStayWeatherDay[] {
  const merged = new Map<string, Partial<HotelStayWeatherDay> & { icon?: string }>();
  for (const record of weatherKitDailySummaryRecords(data)) {
    const date = dateStringValue(record, "date", "forecastStart", "summaryStart", "startTime");
    if (!date || date < query.checkIn || date >= query.checkOut) {
      continue;
    }
    const existing = merged.get(date) ?? { date };
    const condition = stringValue(record, "conditionCode", "condition", "icon") ?? existing.icon ?? "Summary";
    merged.set(date, {
      ...existing,
      date,
      tempMin: numberValue(record, "temperatureMin", "minimumTemperature", "lowTemperature")
        ?? nestedNumberValue(record, "temperature", "minimum", "min", "low")
        ?? existing.tempMin
        ?? null,
      tempMax: numberValue(record, "temperatureMax", "maximumTemperature", "highTemperature")
        ?? nestedNumberValue(record, "temperature", "maximum", "max", "high")
        ?? existing.tempMax
        ?? null,
      precipitationAmount: numberValue(record, "precipitationAmount", "precipitationTotal")
        ?? nestedNumberValue(record, "precipitation", "amount", "total")
        ?? existing.precipitationAmount
        ?? null,
      snowfallAmount: numberValue(record, "snowfallAmount", "snowfallTotal")
        ?? nestedNumberValue(record, "snowfall", "amount", "total")
        ?? existing.snowfallAmount
        ?? null,
      description: conditionDescription(condition, query.locale),
      icon: condition
    });
  }

  return dateRange(query.checkIn, query.checkOut).map((date) => {
    const record = merged.get(date);
    return {
      date,
      tempMin: record?.tempMin ?? null,
      tempMax: record?.tempMax ?? null,
      precipitationAmount: record?.precipitationAmount ?? null,
      snowfallAmount: record?.snowfallAmount ?? null,
      description: record?.description ?? conditionDescription("Summary", query.locale),
      icon: record?.icon ?? "Summary"
    };
  });
}

function weatherKitDailySummaryRecords(data: WeatherKitDailySummaryResponse): Array<Record<string, unknown>> {
  const records: Array<Record<string, unknown>> = [];
  collectDailySummaryRecords(data, records);
  return records;
}

function collectDailySummaryRecords(value: unknown, records: Array<Record<string, unknown>>): void {
  if (Array.isArray(value)) {
    for (const item of value) {
      if (isRecord(item)) {
        records.push(item);
      }
    }
    return;
  }

  if (!isRecord(value)) {
    return;
  }

  for (const key of ["days", "summaries", "dailySummaries", "temperature", "precipitation"]) {
    const child = value[key];
    if (Array.isArray(child)) {
      collectDailySummaryRecords(child, records);
    } else if (isRecord(child)) {
      collectDailySummaryRecords(child.days ?? child.summaries, records);
    }
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function stringValue(record: Record<string, unknown>, ...keys: string[]): string | null {
  for (const key of keys) {
    const value = record[key];
    if (typeof value === "string" && value.trim()) {
      return value.trim();
    }
  }
  return null;
}

function dateStringValue(record: Record<string, unknown>, ...keys: string[]): string | null {
  for (const key of keys) {
    const value = record[key];
    if (typeof value === "string" && value.trim()) {
      return value.trim().slice(0, 10);
    }
    if (typeof value === "number" && Number.isFinite(value)) {
      return epochDayToISODate(value);
    }
  }
  return null;
}

function epochDayToISODate(day: number): string {
  return new Date(day * 86_400_000).toISOString().slice(0, 10);
}

function numberValue(record: Record<string, unknown>, ...keys: string[]): number | null {
  for (const key of keys) {
    const value = record[key];
    if (typeof value === "number" && Number.isFinite(value)) {
      return value;
    }
  }
  return null;
}

function nestedNumberValue(record: Record<string, unknown>, objectKey: string, ...keys: string[]): number | null {
  const nested = record[objectKey];
  return isRecord(nested) ? numberValue(nested, ...keys) : null;
}

export const weatherProviderTestInternals = {
  extractWeatherKitDailySummaryDays,
  epochDayToISODate
};

type WeatherKitResponse = {
  currentWeather?: {
    metadata?: { reportedTime?: string };
    asOf: string;
    conditionCode: string;
    temperature: number;
    temperatureApparent: number;
    humidity: number;
    pressure: number;
    windSpeed: number;
    windDirection: number;
  };
  forecastHourly?: {
    hours: Array<{
      forecastStart: string;
      temperature: number;
      humidity: number;
      windSpeed: number;
      conditionCode: string;
    }>;
  };
  forecastDaily?: {
    days: Array<{
      forecastStart: string;
      temperatureMin: number;
      temperatureMax: number;
      conditionCode: string;
      daytimeForecast?: {
        humidity: number;
        windSpeed: number;
      };
    }>;
  };
};

type WeatherKitDailySummaryResponse = Record<string, unknown>;

type OpenWeatherMapCurrentResponse = {
  coord: { lat: number; lon: number };
  weather: { id: number; main: string; description: string; icon: string }[];
  main: { temp: number; feels_like: number; pressure: number; humidity: number };
  wind: { speed: number; deg: number };
  sys: { country: string };
  dt: number;
  timezone: number;
  name: string;
};
