import { supportedLocales, type LocalizedText } from "./places-catalog";

export type CurrencyRecord = {
  code: string;
  symbol: string;
  names: LocalizedText;
  decimalDigits: number;
};

export const currencyCatalogSchemaVersion = 1;
export const currencyCatalogResourceVersion = "2026.07.02.1";
export const currencyCatalogGeneratedAt = "2026-07-02T00:00:00.000Z";
export const defaultCurrencyCode = "CNY";

export const currencies = [
  currency("CNY", "¥", ["人民币", "人民幣", "Chinese Yuan", "中国人民元", "중국 위안"], 2),
  currency("USD", "$", ["美元", "美元", "US Dollar", "米ドル", "미국 달러"], 2),
  currency("EUR", "€", ["欧元", "歐元", "Euro", "ユーロ", "유로"], 2),
  currency("JPY", "¥", ["日元", "日圓", "Japanese Yen", "日本円", "일본 엔"], 0),
  currency("GBP", "£", ["英镑", "英鎊", "British Pound", "英ポンド", "영국 파운드"], 2),
  currency("HKD", "HK$", ["港币", "港幣", "Hong Kong Dollar", "香港ドル", "홍콩 달러"], 2),
  currency("MOP", "MOP$", ["澳门元", "澳門元", "Macanese Pataca", "マカオ・パタカ", "마카오 파타카"], 2),
  currency("TWD", "NT$", ["新台币", "新台幣", "New Taiwan Dollar", "ニュー台湾ドル", "신대만 달러"], 2),
  currency("SGD", "S$", ["新加坡元", "新加坡元", "Singapore Dollar", "シンガポールドル", "싱가포르 달러"], 2),
  currency("KRW", "₩", ["韩元", "韓元", "South Korean Won", "韓国ウォン", "대한민국 원"], 0),
  currency("THB", "฿", ["泰铢", "泰銖", "Thai Baht", "タイバーツ", "태국 바트"], 2),
  currency("MYR", "RM", ["马来西亚林吉特", "馬來西亞令吉", "Malaysian Ringgit", "マレーシアリンギット", "말레이시아 링깃"], 2),
  currency("IDR", "Rp", ["印尼盾", "印尼盾", "Indonesian Rupiah", "インドネシアルピア", "인도네시아 루피아"], 0),
  currency("PHP", "₱", ["菲律宾比索", "菲律賓披索", "Philippine Peso", "フィリピンペソ", "필리핀 페소"], 2),
  currency("VND", "₫", ["越南盾", "越南盾", "Vietnamese Dong", "ベトナムドン", "베트남 동"], 0),
  currency("AUD", "A$", ["澳元", "澳元", "Australian Dollar", "豪ドル", "호주 달러"], 2),
  currency("CAD", "C$", ["加元", "加元", "Canadian Dollar", "カナダドル", "캐나다 달러"], 2),
  currency("CHF", "CHF", ["瑞士法郎", "瑞士法郎", "Swiss Franc", "スイスフラン", "스위스 프랑"], 2),
  currency("NZD", "NZ$", ["新西兰元", "紐西蘭元", "New Zealand Dollar", "ニュージーランドドル", "뉴질랜드 달러"], 2),
  currency("AED", "د.إ", ["阿联酋迪拉姆", "阿聯酋迪拉姆", "UAE Dirham", "UAEディルハム", "아랍에미리트 디르함"], 2)
] satisfies CurrencyRecord[];

export const currencyCodes = currencies.map((record) => record.code);

export const currenciesCatalog = {
  schemaVersion: currencyCatalogSchemaVersion,
  resourceVersion: currencyCatalogResourceVersion,
  generatedAt: currencyCatalogGeneratedAt,
  supportedLocales,
  defaultLocale: "en",
  fallbackLocales: ["en", "zh-Hans"],
  defaultCurrencyCode,
  currencies
};

function currency(
  code: string,
  symbol: string,
  nameValues: readonly [string, string, string, string, string],
  decimalDigits: number
): CurrencyRecord {
  return {
    code,
    symbol,
    names: localized(nameValues),
    decimalDigits
  };
}

function localized(values: readonly [string, string, string, string, string]): LocalizedText {
  return {
    "zh-Hans": values[0],
    "zh-Hant": values[1],
    en: values[2],
    ja: values[3],
    ko: values[4]
  };
}
