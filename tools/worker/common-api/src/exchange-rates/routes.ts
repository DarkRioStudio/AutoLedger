import { currencyCodes } from "../currencies-catalog";
import { ExchangeRateProviderError, exchangeRateProviderCacheScope, fetchExchangeRateQuote } from "./providers";
import type { ExchangeRateEndpointResult, ExchangeRateErrorBody, ExchangeRateSuccessBody } from "./types";

const supportedCurrencyCodes = new Set(currencyCodes);
const isoDatePattern = /^\d{4}-\d{2}-\d{2}$/;
const exchangeRatePrivacy = "Only base currency, quote currency, and optional rate date are sent. Transaction amounts stay on device.";
const exchangeRateCacheHeader = "x-common-api-cache";
const exchangeRateCacheOrigin = "https://darkrio-common-api.local";
const exchangeRateCacheName = "darkrio-common-api-exchange-rates-v1";

type ExchangeRateCacheStore = {
  match(request: Request): Promise<Response | undefined>;
  put(request: Request, response: Response): Promise<void>;
};

type ExchangeRateEndpointOptions = {
  cache?: ExchangeRateCacheStore | null;
  ctx?: Pick<ExecutionContext, "waitUntil">;
};

export async function exchangeRateEndpoint(
  request: Request,
  env: Env,
  options: ExchangeRateEndpointOptions = {}
): Promise<ExchangeRateEndpointResult> {
  const url = new URL(request.url);
  const baseResult = normalizeCurrencyParam(url.searchParams.get("base"), "base");
  const quoteResult = normalizeCurrencyParam(url.searchParams.get("quote"), "quote");
  const requestedDateResult = normalizeRateDate(url.searchParams.get("date"));

  if (baseResult.error) {
    return baseResult.error;
  }
  if (quoteResult.error) {
    return quoteResult.error;
  }
  if (requestedDateResult.error) {
    return requestedDateResult.error;
  }

  const baseCurrencyCode = baseResult.code;
  const quoteCurrencyCode = quoteResult.code;
  if (baseCurrencyCode === quoteCurrencyCode) {
    return successResult({
      provider: "identity",
      source: "identity://same-currency",
      date: requestedDateResult.date ?? todayISODate(),
      baseCurrencyCode,
      quoteCurrencyCode,
      rate: 1
    }, requestedDateResult.date);
  }

  try {
    const cache = options.cache === undefined ? await defaultExchangeRateCache() : options.cache;
    const cacheKey = exchangeRateCacheKey(env, baseCurrencyCode, quoteCurrencyCode, requestedDateResult.date);
    if (cache) {
      const cached = await readCachedQuote(cache, cacheKey, requestedDateResult.date);
      if (cached) {
        return {
          ...cached,
          headers: {
            ...(cached.headers ?? {}),
            [exchangeRateCacheHeader]: "hit"
          }
        };
      }
    }

    const quote = await fetchExchangeRateQuote(env, baseCurrencyCode, quoteCurrencyCode, requestedDateResult.date);
    const result = successResult(quote, requestedDateResult.date);
    if (!cache) {
      return {
        ...result,
        headers: {
          ...(result.headers ?? {}),
          [exchangeRateCacheHeader]: "bypass"
        }
      };
    }

    const cacheWrite = writeCachedQuote(cache, cacheKey, result).catch((caught: unknown) => {
      console.warn("exchange-rate-cache-write-failed", caught);
    });
    if (options.ctx) {
      options.ctx.waitUntil(cacheWrite);
    } else {
      await cacheWrite;
    }

    return {
      ...result,
      headers: {
        ...(result.headers ?? {}),
        [exchangeRateCacheHeader]: "miss"
      }
    };
  } catch (caught) {
    if (caught instanceof ExchangeRateProviderError) {
      return endpointError(caught.code, caught.message, caught.status);
    }
    return endpointError("exchange_rate_provider_failed", "Exchange rate provider request failed.", 502);
  }
}

function successResult(
  quote: {
    provider: ExchangeRateSuccessBody["provider"];
    source: string;
    date: string;
    baseCurrencyCode: string;
    quoteCurrencyCode: string;
    rate: number;
  },
  requestedDate: string | null
): ExchangeRateEndpointResult {
  return {
    status: 200,
    cacheControl: cacheControlForRateDate(requestedDate),
    body: {
      schemaVersion: 1,
      provider: quote.provider,
      source: quote.source,
      requestedDate,
      date: quote.date,
      baseCurrencyCode: quote.baseCurrencyCode,
      quoteCurrencyCode: quote.quoteCurrencyCode,
      rate: quote.rate,
      inverseRate: Number((1 / quote.rate).toFixed(8)),
      fetchedAt: new Date().toISOString(),
      privacy: exchangeRatePrivacy
    }
  };
}

async function readCachedQuote(
  cache: ExchangeRateCacheStore,
  cacheKey: Request,
  requestedDate: string | null
): Promise<ExchangeRateEndpointResult | null> {
  const response = await cache.match(cacheKey);
  if (!response || !response.ok) {
    return null;
  }

  const payload = await response.json();
  if (!isExchangeRateSuccessBody(payload)) {
    return null;
  }

  return {
    status: 200,
    cacheControl: cacheControlForRateDate(requestedDate),
    body: payload
  };
}

async function writeCachedQuote(
  cache: ExchangeRateCacheStore,
  cacheKey: Request,
  result: ExchangeRateEndpointResult
): Promise<void> {
  if (!isExchangeRateSuccessBody(result.body)) {
    return;
  }

  await cache.put(
    cacheKey,
    new Response(JSON.stringify(result.body), {
      status: 200,
      headers: {
        "content-type": "application/json; charset=utf-8",
        "cache-control": result.cacheControl ?? "public, max-age=3600"
      }
    })
  );
}

function exchangeRateCacheKey(
  env: Env,
  baseCurrencyCode: string,
  quoteCurrencyCode: string,
  requestedDate: string | null
): Request {
  const url = new URL("/v1/exchange-rates/rate", exchangeRateCacheOrigin);
  url.searchParams.set("provider", exchangeRateProviderCacheScope(env));
  url.searchParams.set("base", baseCurrencyCode);
  url.searchParams.set("quote", quoteCurrencyCode);
  url.searchParams.set("date", requestedDate ?? "latest");
  return new Request(url.toString(), { method: "GET" });
}

async function defaultExchangeRateCache(): Promise<ExchangeRateCacheStore | null> {
  if (!globalThis.caches) {
    return null;
  }
  return globalThis.caches.open(exchangeRateCacheName);
}

function isExchangeRateSuccessBody(value: unknown): value is ExchangeRateSuccessBody {
  if (!value || typeof value !== "object") {
    return false;
  }
  const body = value as Partial<ExchangeRateSuccessBody>;
  return body.schemaVersion === 1 &&
    typeof body.provider === "string" &&
    typeof body.source === "string" &&
    (typeof body.requestedDate === "string" || body.requestedDate === null) &&
    typeof body.date === "string" &&
    typeof body.baseCurrencyCode === "string" &&
    typeof body.quoteCurrencyCode === "string" &&
    typeof body.rate === "number" &&
    Number.isFinite(body.rate) &&
    body.rate > 0 &&
    typeof body.inverseRate === "number" &&
    Number.isFinite(body.inverseRate) &&
    typeof body.fetchedAt === "string" &&
    typeof body.privacy === "string";
}

function normalizeCurrencyParam(rawCode: string | null, name: "base" | "quote"): { code: string; error?: never } | { code?: never; error: ExchangeRateEndpointResult } {
  const trimmed = rawCode?.trim();
  if (!trimmed) {
    return {
      error: endpointError(`missing_${name}_currency`, `Query parameter ${name} is required.`, 400)
    };
  }

  const code = trimmed.toUpperCase();
  if (!/^[A-Z]{3}$/.test(code)) {
    return {
      error: endpointError(`invalid_${name}_currency`, `Query parameter ${name} must be an ISO 4217 currency code.`, 400)
    };
  }
  if (!supportedCurrencyCodes.has(code)) {
    return {
      error: endpointError(`unsupported_${name}_currency`, `Currency ${code} is not in the common-api currency catalog.`, 400)
    };
  }

  return { code };
}

function normalizeRateDate(rawDate: string | null): { date: string | null; error?: ExchangeRateEndpointResult } {
  if (!rawDate) {
    return { date: null };
  }
  const date = rawDate.trim();
  if (!isoDatePattern.test(date)) {
    return {
      date: null,
      error: endpointError("invalid_rate_date", "Query parameter date must use YYYY-MM-DD.", 400)
    };
  }

  const parsed = new Date(`${date}T00:00:00.000Z`);
  if (Number.isNaN(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== date) {
    return {
      date: null,
      error: endpointError("invalid_rate_date", "Query parameter date must be a real calendar date.", 400)
    };
  }

  if (date > todayISODate()) {
    return {
      date: null,
      error: endpointError("future_rate_date_not_supported", "Exchange rates cannot be requested for a future date.", 400)
    };
  }

  return { date };
}

function cacheControlForRateDate(requestedDate: string | null): string {
  if (!requestedDate || requestedDate === todayISODate()) {
    return "public, max-age=3600";
  }
  return "public, max-age=86400";
}

function todayISODate(): string {
  return new Date().toISOString().slice(0, 10);
}

function endpointError(code: string, message: string, status: number): ExchangeRateEndpointResult {
  return {
    status,
    cacheControl: "no-store",
    body: errorBody(code, message)
  };
}

function errorBody(code: string, message: string): ExchangeRateErrorBody {
  return { error: { code, message } };
}

export const exchangeRateTestInternals = {
  normalizeCurrencyParam,
  normalizeRateDate,
  cacheControlForRateDate,
  exchangeRateCacheKey,
  isExchangeRateSuccessBody
};
