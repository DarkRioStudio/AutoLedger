import { currencyCodes } from "../currencies-catalog";
import { ExchangeRateProviderError, fetchExchangeRateQuote } from "./providers";
import type { ExchangeRateEndpointResult, ExchangeRateErrorBody, ExchangeRateSuccessBody } from "./types";

const supportedCurrencyCodes = new Set(currencyCodes);
const isoDatePattern = /^\d{4}-\d{2}-\d{2}$/;
const exchangeRatePrivacy = "Only base currency, quote currency, and optional rate date are sent. Transaction amounts stay on device.";

export async function exchangeRateEndpoint(request: Request, env: Env): Promise<ExchangeRateEndpointResult> {
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
    const quote = await fetchExchangeRateQuote(env, baseCurrencyCode, quoteCurrencyCode, requestedDateResult.date);
    return successResult(quote, requestedDateResult.date);
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
  cacheControlForRateDate
};
