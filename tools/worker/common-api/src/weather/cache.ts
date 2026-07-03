import type { CurrentWeather, ForecastWeather, HotelStayWeatherSummary } from "./types";

type CurrentWeatherCacheEntry = {
  data: CurrentWeather;
  provider: string;
  cachedAt: number;
};

type ForecastWeatherCacheEntry = {
  data: ForecastWeather;
  provider: string;
  cachedAt: number;
};

type HotelStayWeatherCacheEntry = {
  data: HotelStayWeatherSummary;
  provider: string;
  cachedAt: number;
};

const cacheTTLMS = 5 * 60 * 1000;
const hotelStayCacheTTLMS = 6 * 60 * 60 * 1000;
const maxEntries = 500;
const currentWeatherCache = new Map<string, CurrentWeatherCacheEntry>();
const forecastWeatherCache = new Map<string, ForecastWeatherCacheEntry>();
const hotelStayWeatherCache = new Map<string, HotelStayWeatherCacheEntry>();

export function getCurrentWeatherCache(lat: number, lon: number): { provider: string; data: CurrentWeather } | null {
  const key = cacheKey(lat, lon);
  const entry = currentWeatherCache.get(key);
  if (!entry) {
    return null;
  }
  if (Date.now() - entry.cachedAt > cacheTTLMS) {
    currentWeatherCache.delete(key);
    return null;
  }
  return { provider: entry.provider, data: entry.data };
}

export function setCurrentWeatherCache(lat: number, lon: number, provider: string, data: CurrentWeather): void {
  evictOldestIfNeeded(currentWeatherCache);
  currentWeatherCache.set(cacheKey(lat, lon), { provider, data, cachedAt: Date.now() });
}

export function getForecastWeatherCache(lat: number, lon: number): { provider: string; data: ForecastWeather } | null {
  const key = cacheKey(lat, lon);
  const entry = forecastWeatherCache.get(key);
  if (!entry) {
    return null;
  }
  if (Date.now() - entry.cachedAt > cacheTTLMS) {
    forecastWeatherCache.delete(key);
    return null;
  }
  return { provider: entry.provider, data: entry.data };
}

export function setForecastWeatherCache(lat: number, lon: number, provider: string, data: ForecastWeather): void {
  evictOldestIfNeeded(forecastWeatherCache);
  forecastWeatherCache.set(cacheKey(lat, lon), { provider, data, cachedAt: Date.now() });
}

export function getHotelStayWeatherCache(
  lat: number,
  lon: number,
  checkIn: string,
  checkOut: string
): { provider: string; data: HotelStayWeatherSummary } | null {
  const key = hotelStayCacheKey(lat, lon, checkIn, checkOut);
  const entry = hotelStayWeatherCache.get(key);
  if (!entry) {
    return null;
  }
  if (Date.now() - entry.cachedAt > hotelStayCacheTTLMS) {
    hotelStayWeatherCache.delete(key);
    return null;
  }
  return { provider: entry.provider, data: entry.data };
}

export function setHotelStayWeatherCache(
  lat: number,
  lon: number,
  checkIn: string,
  checkOut: string,
  provider: string,
  data: HotelStayWeatherSummary
): void {
  evictOldestIfNeeded(hotelStayWeatherCache);
  hotelStayWeatherCache.set(hotelStayCacheKey(lat, lon, checkIn, checkOut), { provider, data, cachedAt: Date.now() });
}

function cacheKey(lat: number, lon: number): string {
  return `${lat.toFixed(2)},${lon.toFixed(2)}`;
}

function hotelStayCacheKey(lat: number, lon: number, checkIn: string, checkOut: string): string {
  return `${cacheKey(lat, lon)},${checkIn},${checkOut}`;
}

function evictOldestIfNeeded(cache: Map<string, unknown>): void {
  if (cache.size < maxEntries) {
    return;
  }
  const oldestKey = cache.keys().next().value as string | undefined;
  if (oldestKey) {
    cache.delete(oldestKey);
  }
}
