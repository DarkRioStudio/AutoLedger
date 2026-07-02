import type { ExchangeRateProviderName, ExchangeRateProviderQuote } from "./types";

type ConfiguredExchangeRateProviderName = Exclude<ExchangeRateProviderName, "identity">;

type FrankfurterRateRecord = {
  date?: unknown;
  base?: unknown;
  quote?: unknown;
  rate?: unknown;
};

type ParsedFrankfurterRateRecord = {
  date: string;
  base: string;
  quote: string;
  rate: number;
};

export class ExchangeRateProviderError extends Error {
  constructor(
    readonly code: string,
    message: string,
    readonly status = 502
  ) {
    super(message);
  }
}

export async function fetchExchangeRateQuote(
  env: Env,
  baseCurrencyCode: string,
  quoteCurrencyCode: string,
  requestedDate: string | null
): Promise<ExchangeRateProviderQuote> {
  const provider = normalizeProvider(env.EXCHANGE_RATE_PROVIDER);
  switch (provider) {
    case "disabled":
      throw new ExchangeRateProviderError(
        "exchange_rate_provider_not_configured",
        "Exchange rate provider is not configured.",
        503
      );
    case "mock":
      return mockQuote(baseCurrencyCode, quoteCurrencyCode, requestedDate);
    case "frankfurter":
      return frankfurterQuote(env, baseCurrencyCode, quoteCurrencyCode, requestedDate);
  }
}

function normalizeProvider(rawProvider: string | undefined): ConfiguredExchangeRateProviderName {
  const provider = rawProvider?.trim().toLowerCase();
  if (provider === "disabled" || provider === "mock" || provider === "frankfurter") {
    return provider;
  }
  return "frankfurter";
}

function mockQuote(baseCurrencyCode: string, quoteCurrencyCode: string, requestedDate: string | null): ExchangeRateProviderQuote {
  const directKey = `${baseCurrencyCode}:${quoteCurrencyCode}`;
  const inverseKey = `${quoteCurrencyCode}:${baseCurrencyCode}`;
  const directRate = mockRates[directKey];
  const inverseRate = mockRates[inverseKey];
  const rate = directRate ?? (inverseRate ? roundRate(1 / inverseRate) : 1.2345);

  return {
    provider: "mock",
    source: "mock://exchange-rates",
    date: requestedDate ?? "2026-07-02",
    baseCurrencyCode,
    quoteCurrencyCode,
    rate
  };
}

async function frankfurterQuote(
  env: Env,
  baseCurrencyCode: string,
  quoteCurrencyCode: string,
  requestedDate: string | null
): Promise<ExchangeRateProviderQuote> {
  const baseURL = normalizeFrankfurterBaseURL(env.EXCHANGE_RATE_BASE_URL);
  const url = new URL(`${baseURL}/rates`);
  url.searchParams.set("base", baseCurrencyCode);
  url.searchParams.set("quotes", quoteCurrencyCode);
  if (requestedDate) {
    url.searchParams.set("date", requestedDate);
  }

  const response = await fetch(url, {
    headers: { accept: "application/json" }
  });
  if (!response.ok) {
    throw new ExchangeRateProviderError(
      "exchange_rate_provider_http_error",
      `Exchange rate provider returned HTTP ${response.status}.`,
      502
    );
  }

  const payload = await response.json();
  const record = parseFrankfurterRecord(payload, baseCurrencyCode, quoteCurrencyCode);
  return {
    provider: "frankfurter",
    source: "https://api.frankfurter.dev/v2/rates",
    date: record.date,
    baseCurrencyCode,
    quoteCurrencyCode,
    rate: record.rate
  };
}

function parseFrankfurterRecord(payload: unknown, baseCurrencyCode: string, quoteCurrencyCode: string): ParsedFrankfurterRateRecord {
  const records = Array.isArray(payload) ? payload : [payload];
  const record = records.find((candidate): candidate is FrankfurterRateRecord => {
    if (!candidate || typeof candidate !== "object") {
      return false;
    }
    const value = candidate as FrankfurterRateRecord;
    return value.base === baseCurrencyCode && value.quote === quoteCurrencyCode;
  });

  if (
    !record ||
    typeof record.date !== "string" ||
    typeof record.base !== "string" ||
    typeof record.quote !== "string" ||
    typeof record.rate !== "number" ||
    !Number.isFinite(record.rate) ||
    record.rate <= 0
  ) {
    throw new ExchangeRateProviderError(
      "exchange_rate_provider_invalid_response",
      "Exchange rate provider returned an unexpected response.",
      502
    );
  }

  return {
    date: record.date,
    base: record.base,
    quote: record.quote,
    rate: record.rate
  };
}

function normalizeFrankfurterBaseURL(rawBaseURL: string | undefined): string {
  const baseURL = rawBaseURL?.trim() || "https://api.frankfurter.dev/v2";
  return baseURL.replace(/\/+$/, "");
}

function roundRate(value: number): number {
  return Number(value.toFixed(8));
}

const mockRates: Record<string, number> = {
  "USD:CNY": 7.1111,
  "CNY:USD": 0.140625,
  "JPY:CNY": 0.0462,
  "EUR:CNY": 7.75
};
