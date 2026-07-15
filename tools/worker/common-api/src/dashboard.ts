import { analyticsRetentionDays } from "./analytics";

type APIError = {
  error: {
    code: string;
    message: string;
  };
};

type AnalyticsDashboardRow = {
  event_name: string;
  event_id: string | null;
  app_version: string | null;
  build_number: string | null;
  os_major: string | null;
  device_class: string | null;
  payload_json: string;
  received_at: string;
};

type PrimitivePayload = Record<string, string | number | boolean | null>;

type DashboardMetric = {
  metricID: string;
  label: string;
  value: number | null;
  unit: "count" | "percent";
  numerator: number;
  denominator: number;
  status: "available" | "insufficient_data";
  breakdown?: Record<string, number>;
};

const dashboardWindowDays = 30;
const dashboardMaxRows = 5000;
const jsonContentType = "application/json; charset=utf-8";
const htmlContentType = "text/html; charset=utf-8";

export async function autoLedgerDashboardDataResponse(env: Env): Promise<Response> {
  if (!env.COMMON_API_DB) {
    return json(error("analytics_database_unconfigured", "Analytics database is not configured."), 503);
  }

  const rowsResult = await env.COMMON_API_DB.prepare(`
    SELECT
      event_name,
      event_id,
      app_version,
      build_number,
      os_major,
      device_class,
      payload_json,
      received_at
    FROM autoledger_analytics_events
    WHERE received_at >= strftime('%Y-%m-%dT%H:%M:%fZ', 'now', ?)
    ORDER BY received_at DESC
    LIMIT ?
  `).bind(`-${dashboardWindowDays} days`, dashboardMaxRows).all<AnalyticsDashboardRow>();
  const rows = rowsResult.results ?? [];
  const events = rows.map((row) => ({
    eventName: row.event_name,
    payload: parsePayload(row.payload_json),
    appVersion: row.app_version ?? "unknown",
    buildNumber: row.build_number ?? "unknown",
    receivedAt: row.received_at
  }));

  return json({
    schemaVersion: 1,
    app: "autoledger",
    generatedAt: new Date().toISOString(),
    windowDays: dashboardWindowDays,
    rowLimit: dashboardMaxRows,
    retentionDays: analyticsRetentionDays(env),
    source: "autoledger_analytics_events",
    access: {
      protection: "cloudflare_access",
      emailHeaderTrustedOnlyOnProtectedHosts: true
    },
    privacy: {
      summary: "此面板只展示聚合计数和比率，不返回原始事件行或 payload JSON。",
      dataCategories: ["Diagnostics", "Usage Data"],
      linked: false,
      tracking: false
    },
    metrics: buildMetrics(events),
    eventBreakdown: eventBreakdown(events),
    appVersionBreakdown: breakdown(events.map((event) => event.appVersion)),
    latestReceivedAt: events[0]?.receivedAt ?? null
  });
}

export function autoLedgerDashboardHTMLResponse(): Response {
  return new Response(dashboardHTML, {
    status: 200,
    headers: {
      "content-type": htmlContentType,
      "cache-control": "no-store",
      "referrer-policy": "no-referrer",
      "x-robots-tag": "noindex",
      "content-security-policy": "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; connect-src 'self'"
    }
  });
}

function buildMetrics(events: Array<{ eventName: string; payload: PrimitivePayload }>): DashboardMetric[] {
  const launchCompletionEvents = events.filter((event) => (
    event.eventName === "al_perf_app_launch" &&
    stringPayload(event.payload, "launch_type") === "foreground" &&
    stringPayload(event.payload, "result") === "success"
  ));
  const featureSurfaceEvents = events.filter((event) => event.eventName === "al_feature_surface_opened");
  const importStarts = events.filter((event) => event.eventName === "al_import_flow_started");
  const importCompletions = events.filter((event) => event.eventName === "al_import_flow_completed");
  const confirmationEvents = events.filter((event) => event.eventName === "al_confirmation_state");
  const currencyEvents = events.filter((event) => event.eventName === "al_currency_lookup_status");
  const hotelPDFEvents = events.filter((event) => event.eventName === "al_hotel_pdf_flow_status");
  const commonAPIEvents = events.filter((event) => event.eventName === "al_common_api_request_status");
  const proGateEvents = events.filter((event) => event.eventName === "al_pro_gate_viewed");
  const purchaseEvents = events.filter((event) => event.eventName === "al_purchase_flow_status");
  const crashEvents = events.filter((event) => event.eventName === "al_crash_diagnostic");
  const uncleanSessionRecoveryEvents = crashEvents.filter((event) => (
    stringPayload(event.payload, "diagnostic_type") === "unclean_active_session" &&
    stringPayload(event.payload, "signal_source") === "session_marker"
  ));
  const systemCrashEvents = crashEvents.filter((event) => !uncleanSessionRecoveryEvents.includes(event));
  const performanceEvents = events.filter((event) => event.eventName === "al_performance_diagnostic");
  const slowPerformanceEvents = performanceEvents.filter((event) => isSlowPerformanceEvent(event.payload));
  const privacyEvents = events.filter((event) => event.eventName === "al_privacy_payload_guard_violation");

  return [
    countMetric("total_events_count", "已接收匿名事件总数", events.length),
    countMetric(
      "feature_surface_open_count",
      "功能入口打开分布",
      featureSurfaceEvents.length,
      breakdown(featureSurfaceEvents.map((event) => stringPayload(event.payload, "surface") ?? "unknown"))
    ),
    countMetric("launch_completion_count", "启动完成信号", launchCompletionEvents.length),
    countMetric(
      "unclean_session_recovery_count",
      "异常会话恢复信号",
      uncleanSessionRecoveryEvents.length
    ),
    percentMetric(
      "import_completion_rate",
      "导入完成率",
      importCompletions.filter((event) => stringPayload(event.payload, "status") === "success").length,
      importStarts.length
    ),
    countMetric(
      "import_error_code_top_n",
      "导入错误码分布",
      importCompletions.length,
      breakdown(importCompletions.map((event) => stringPayload(event.payload, "error_code") ?? "unknown"))
    ),
    percentMetric(
      "confirmation_discard_rate",
      "确认页放弃率",
      confirmationEvents.filter((event) => stringPayload(event.payload, "confirm_status") === "discarded").length,
      confirmationEvents.length
    ),
    percentMetric(
      "currency_lookup_success_rate",
      "汇率查询成功率",
      currencyEvents.filter((event) => stringPayload(event.payload, "rate_lookup_status") === "success").length,
      currencyEvents.length
    ),
    percentMetric(
      "hotel_pdf_completion_rate",
      "酒店 PDF 完成率",
      hotelPDFEvents.filter((event) => stringPayload(event.payload, "status") === "success").length,
      hotelPDFEvents.length
    ),
    countMetric(
      "common_api_status_top_n",
      "Common API 状态分布",
      commonAPIEvents.length,
      breakdown(commonAPIEvents.map((event) => stringPayload(event.payload, "http_status_bucket") ?? "unknown"))
    ),
    countMetric(
      "pro_gate_action_count",
      "Pro 入口行为分布",
      proGateEvents.length,
      breakdown(proGateEvents.map((event) => stringPayload(event.payload, "user_action") ?? "unknown"))
    ),
    percentMetric(
      "purchase_flow_failure_rate",
      "购买流程失败率",
      purchaseEvents.filter((event) => isPurchaseFailure(stringPayload(event.payload, "storekit_status"))).length,
      purchaseEvents.length
    ),
    countMetric(
      "crash_diagnostic_count",
      "系统崩溃与挂起信号",
      systemCrashEvents.length,
      breakdown(systemCrashEvents.map((event) => stringPayload(event.payload, "diagnostic_type") ?? "unknown"))
    ),
    countMetric(
      "slow_operation_count",
      "慢操作与卡顿信号",
      slowPerformanceEvents.length,
      breakdown(slowPerformanceEvents.map((event) => stringPayload(event.payload, "operation") ?? "unknown"))
    ),
    countMetric(
      "performance_operation_top_n",
      "性能操作分布",
      performanceEvents.length,
      breakdown(performanceEvents.map((event) => stringPayload(event.payload, "operation") ?? "unknown"))
    ),
    countMetric(
      "privacy_payload_violation_count",
      "隐私 payload 拦截次数",
      privacyEvents.length,
      breakdown(privacyEvents.map((event) => stringPayload(event.payload, "blocked_field_category") ?? "unknown"))
    )
  ];
}

function percentMetric(metricID: string, label: string, numerator: number, denominator: number): DashboardMetric {
  return {
    metricID,
    label,
    value: denominator > 0 ? roundPercent(numerator, denominator) : null,
    unit: "percent",
    numerator,
    denominator,
    status: denominator > 0 ? "available" : "insufficient_data"
  };
}

function countMetric(
  metricID: string,
  label: string,
  value: number,
  metricBreakdown?: Record<string, number>
): DashboardMetric {
  return {
    metricID,
    label,
    value,
    unit: "count",
    numerator: value,
    denominator: 1,
    status: "available",
    ...(metricBreakdown ? { breakdown: metricBreakdown } : {})
  };
}

function eventBreakdown(events: Array<{ eventName: string; receivedAt?: string }>): Array<{ eventName: string; count: number; latestReceivedAt: string | null }> {
  const byEventName = new Map<string, { count: number; latestReceivedAt: string | null }>();
  for (const event of events) {
    const current = byEventName.get(event.eventName) ?? { count: 0, latestReceivedAt: null };
    current.count += 1;
    if (!current.latestReceivedAt || (event.receivedAt && event.receivedAt > current.latestReceivedAt)) {
      current.latestReceivedAt = event.receivedAt ?? current.latestReceivedAt;
    }
    byEventName.set(event.eventName, current);
  }
  return [...byEventName.entries()]
    .map(([eventName, value]) => ({ eventName, ...value }))
    .sort((a, b) => b.count - a.count || a.eventName.localeCompare(b.eventName));
}

function breakdown(values: string[]): Record<string, number> {
  return values.reduce<Record<string, number>>((result, value) => {
    result[value] = (result[value] ?? 0) + 1;
    return result;
  }, {});
}

function parsePayload(payloadJSON: string): PrimitivePayload {
  try {
    const parsed = JSON.parse(payloadJSON) as unknown;
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      return {};
    }
    return Object.entries(parsed).reduce<PrimitivePayload>((result, [key, value]) => {
      if (typeof value === "string" || typeof value === "number" || typeof value === "boolean" || value === null) {
        result[key] = value;
      }
      return result;
    }, {});
  } catch {
    return {};
  }
}

function stringPayload(payload: PrimitivePayload, key: string): string | null {
  const value = payload[key];
  return typeof value === "string" ? value : null;
}

function isPurchaseFailure(status: string | null): boolean {
  return status === "failed" || status === "cancelled" || status === "canceled" || status === "unknown";
}

function isSlowPerformanceEvent(payload: PrimitivePayload): boolean {
  const durationBucket = stringPayload(payload, "duration_ms_bucket");
  if (durationBucket === "3s_10s" || durationBucket === "10s_30s" || durationBucket === "over_30s") {
    return true;
  }
  const severity = stringPayload(payload, "severity");
  return severity === "warning" || severity === "critical";
}

function roundPercent(numerator: number, denominator: number): number {
  return Math.round((numerator / denominator) * 1000) / 10;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": jsonContentType,
      "cache-control": "no-store"
    }
  });
}

function error(code: string, message: string): APIError {
  return { error: { code, message } };
}

const dashboardHTML = `<!doctype html>
<html lang="zh-Hans">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta name="robots" content="noindex,nofollow" />
  <title>AutoLedger 运营观测面板</title>
  <style>
    :root {
      color-scheme: light dark;
      --bg: #f3f7fb;
      --surface: rgba(255,255,255,.86);
      --surface-strong: #ffffff;
      --text: #152234;
      --muted: #65748a;
      --border: rgba(88,112,138,.18);
      --accent: #118b75;
      --accent-strong: #0f766e;
      --good: #0f8f60;
      --warn: #b77905;
      --bad: #bd3d36;
      --shadow: 0 20px 60px rgba(21,34,52,.10);
    }
    @media (prefers-color-scheme: dark) {
      :root {
        --bg: #0f1726;
        --surface: rgba(22,31,47,.88);
        --surface-strong: #172133;
        --text: #edf4ff;
        --muted: #9fb0c5;
        --border: rgba(180,200,230,.16);
        --accent: #5ed6c4;
        --accent-strong: #45c7b3;
        --good: #5ed6a0;
        --warn: #f0ba55;
        --bad: #ff7b72;
        --shadow: 0 20px 60px rgba(0,0,0,.26);
      }
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      min-height: 100vh;
      font-family: ui-sans-serif, -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", sans-serif;
      background:
        radial-gradient(circle at 18% 0%, rgba(17,139,117,.18), transparent 34rem),
        radial-gradient(circle at 88% 10%, rgba(53,132,214,.14), transparent 30rem),
        var(--bg);
      color: var(--text);
      letter-spacing: 0;
    }
    button, input, select { font: inherit; }
    .shell { width: min(1180px, calc(100% - 36px)); margin: 0 auto; padding: 34px 0 48px; }
    header { display: flex; align-items: flex-start; justify-content: space-between; gap: 24px; margin-bottom: 24px; }
    .brand { display: flex; align-items: center; gap: 14px; }
    .mark {
      width: 52px; height: 52px; border-radius: 14px;
      background: linear-gradient(145deg, #14a085, #0b6f65);
      box-shadow: inset 0 1px 0 rgba(255,255,255,.35), 0 16px 36px rgba(17,139,117,.24);
      display: grid; place-items: center; color: white;
    }
    .mark svg { width: 30px; height: 30px; }
    h1 { margin: 0; font-size: clamp(30px, 4vw, 48px); line-height: 1.02; }
    .lead { margin: 8px 0 0; max-width: 780px; color: var(--muted); font-size: 15px; line-height: 1.7; }
    .toolbar {
      display: flex; flex-wrap: wrap; align-items: center; justify-content: flex-end; gap: 10px;
      min-width: min(100%, 420px);
    }
    .control {
      height: 40px; border: 1px solid var(--border); background: var(--surface);
      border-radius: 10px; color: var(--text); padding: 0 12px;
    }
    .control:disabled { color: var(--muted); opacity: .82; }
    .button {
      height: 40px; border: 0; border-radius: 10px; background: var(--accent); color: #fff;
      padding: 0 15px; font-weight: 700; cursor: pointer;
    }
    .button.secondary { color: var(--accent); background: var(--surface); border: 1px solid var(--border); }
    .status { width: 100%; text-align: right; color: var(--muted); font-size: 13px; min-height: 18px; }
    .status.error { color: var(--bad); }
    .grid { display: grid; gap: 14px; }
    .summary { grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); }
    .split { grid-template-columns: repeat(2, minmax(0, 1fr)); }
    .content { grid-template-columns: minmax(0, 1.25fr) minmax(340px, .75fr); align-items: start; }
    .card {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 18px;
      box-shadow: var(--shadow);
      backdrop-filter: blur(18px);
    }
    .widget { overflow: hidden; margin-bottom: 14px; }
    .widget > summary.section-head {
      list-style: none;
      cursor: pointer;
      padding: 18px;
      margin: 0;
      align-items: center;
    }
    .widget > summary.section-head::-webkit-details-marker { display: none; }
    .widget > summary.section-head::after {
      content: "收起";
      color: var(--muted);
      font-size: 12px;
      font-weight: 800;
      margin-left: auto;
    }
    .widget:not([open]) > summary.section-head::after { content: "展开"; }
    .widget-body { padding: 0 18px 18px; }
    .metric {
      padding: 18px; min-height: 126px; display: flex; flex-direction: column; justify-content: space-between;
      background: var(--surface-strong); border: 1px solid var(--border); border-radius: 16px;
    }
    .metric span { color: var(--muted); font-size: 13px; font-weight: 700; }
    .metric strong { font-size: 34px; line-height: 1; }
    .metric small { color: var(--muted); line-height: 1.45; }
    section { padding: 18px; }
    .section-head { display: flex; align-items: baseline; justify-content: space-between; gap: 12px; margin-bottom: 14px; }
    h2 { margin: 0; font-size: 18px; }
    .section-head span { color: var(--muted); font-size: 12px; }
    table { width: 100%; border-collapse: collapse; font-size: 14px; }
    th, td { padding: 11px 8px; border-top: 1px solid var(--border); vertical-align: top; text-align: left; }
    th { color: var(--muted); font-size: 12px; font-weight: 800; }
    td { font-size: 13px; line-height: 1.45; }
    .title { font-weight: 800; font-size: 14px; }
    .muted { color: var(--muted); }
    .nowrap { white-space: nowrap; }
    .table-scroll { overflow-x: auto; }
    .pill {
      display: inline-flex; align-items: center; height: 24px; padding: 0 8px; border-radius: 999px;
      background: rgba(17,139,117,.11); color: var(--accent); font-size: 12px; font-weight: 800;
      margin-right: 6px; white-space: nowrap;
    }
    .pill.sent { background: rgba(15,143,96,.12); color: var(--good); }
    .pill.warning { background: rgba(183,121,5,.13); color: var(--warn); }
    .pill.failed { background: rgba(189,61,54,.12); color: var(--bad); }
    .bars { display: grid; gap: 10px; }
    .bar-row { display: grid; grid-template-columns: minmax(120px, 1fr) minmax(140px, 2fr) 52px; gap: 10px; align-items: center; }
    .bar-label { color: var(--muted); font-size: 13px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    .bar-track { height: 10px; background: rgba(101,116,138,.14); border-radius: 999px; overflow: hidden; }
    .bar-fill { height: 100%; width: 0; background: linear-gradient(90deg, var(--accent), #2f80ed); border-radius: inherit; }
    .bar-value { text-align: right; font-variant-numeric: tabular-nums; color: var(--muted); font-size: 13px; }
    .empty { color: var(--muted); padding: 16px 0; }
    .footer-note { margin-top: 18px; color: var(--muted); font-size: 12px; line-height: 1.6; }
    @media (max-width: 900px) {
      header { display: block; }
      .toolbar { justify-content: stretch; margin-top: 18px; }
      .summary, .content, .split { grid-template-columns: 1fr; }
      .status { text-align: left; }
    }
  </style>
</head>
<body>
  <main class="shell">
    <header>
      <div>
        <div class="brand">
          <div class="mark" aria-hidden="true">
            <svg viewBox="0 0 24 24" fill="none">
              <path d="M6.8 4.5h10.4a2.3 2.3 0 0 1 2.3 2.3v10.4a2.3 2.3 0 0 1-2.3 2.3H6.8a2.3 2.3 0 0 1-2.3-2.3V6.8a2.3 2.3 0 0 1 2.3-2.3Z" stroke="currentColor" stroke-width="1.8"/>
              <path d="M8 9h8M8 12h5M8 15h7" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
              <path d="M17.2 3.4v3.2M6.8 3.4v3.2" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
            </svg>
          </div>
          <div>
            <h1>AutoLedger 运营观测面板</h1>
            <p class="lead">匿名聚合指标，用于上线前检查。启动完成、异常会话恢复和系统崩溃分开统计；异常会话恢复可包含调试器停止或系统回收，不等同于崩溃率。这里不展示账本金额、商户名、截图、PDF、邮箱、酒店标识、房号、精确位置、OCR 文本、StoreKit 交易标识、票据或支付数据。</p>
          </div>
        </div>
      </div>
      <div class="toolbar">
        <select id="window" class="control" aria-label="时间范围" disabled>
          <option value="30">最近 30 天</option>
        </select>
        <button id="load" class="button" type="button">刷新</button>
        <div id="status" class="status">通过 Cloudflare Access 登录后自动加载。</div>
      </div>
    </header>

    <details class="card widget" data-widget="overview" open>
      <summary class="section-head">
        <h2>总览</h2>
        <span>导入、启动、购买与隐私边界</span>
      </summary>
      <div class="widget-body">
        <div class="grid summary" id="summary"></div>
      </div>
    </details>

    <details class="card widget" data-widget="metrics" open>
      <summary class="section-head">
        <h2>最小指标</h2>
        <span>推广前观测口径</span>
      </summary>
      <div class="widget-body" id="metrics"></div>
    </details>

    <div class="grid content">
      <details class="card widget" data-widget="events" open>
        <summary class="section-head">
          <h2>事件分布</h2>
          <span id="eventsRange">最近 30 天</span>
        </summary>
        <div class="widget-body table-scroll">
          <table>
            <thead><tr><th>事件</th><th>次数</th><th>最近接收</th></tr></thead>
            <tbody id="eventBreakdown"><tr><td colspan="3" class="muted">正在加载</td></tr></tbody>
          </table>
        </div>
      </details>

      <div class="grid">
        <details class="card widget" data-widget="versions" open>
          <summary class="section-head">
            <h2>版本分布</h2>
            <span>按 App 版本聚合</span>
          </summary>
          <div class="widget-body bars" id="versionBreakdown"></div>
        </details>
        <details class="card widget" data-widget="crash-diagnostics" open>
          <summary class="section-head">
            <h2>崩溃诊断</h2>
            <span>仅系统诊断，恢复信号单列</span>
          </summary>
          <div class="widget-body bars" id="crashDiagnostics"></div>
        </details>
        <details class="card widget" data-widget="privacy" open>
          <summary class="section-head">
            <h2>隐私边界</h2>
            <span>只读聚合面板</span>
          </summary>
          <div class="widget-body" id="privacy"></div>
        </details>
      </div>
    </div>

    <div class="grid split">
      <details class="card widget" data-widget="performance-ops" open>
        <summary class="section-head">
          <h2>性能操作</h2>
          <span>Tab / 月报 / 数据清洗</span>
        </summary>
        <div class="widget-body bars" id="performanceOps"></div>
      </details>
      <details class="card widget" data-widget="import-errors" open>
        <summary class="section-head">
          <h2>导入错误</h2>
          <span>错误码聚合</span>
        </summary>
        <div class="widget-body bars" id="importErrors"></div>
      </details>
      <details class="card widget" data-widget="privacy-blocks" open>
        <summary class="section-head">
          <h2>隐私拦截</h2>
          <span>禁止字段类别</span>
        </summary>
        <div class="widget-body bars" id="privacyBlocks"></div>
      </details>
    </div>

    <div class="footer-note">
      后续可在 dashboard.darkrio326.top 做跨 App 总面板，把 AutoLedger、AutoNotice 和其他 App 的匿名聚合指标汇总到同一个受 Cloudflare Access 保护的入口；当前页面仍只读，只展示 AutoLedger Common API D1 聚合结果。
    </div>
  </main>
  <script>
    const metricOrder = [
      "total_events_count",
      "feature_surface_open_count",
      "launch_completion_count",
      "unclean_session_recovery_count",
      "crash_diagnostic_count",
      "slow_operation_count",
      "import_completion_rate",
      "hotel_pdf_completion_rate",
      "common_api_status_top_n",
      "pro_gate_action_count",
      "purchase_flow_failure_rate",
      "performance_operation_top_n",
      "privacy_payload_violation_count",
      "currency_lookup_success_rate",
      "confirmation_discard_rate",
      "import_error_code_top_n"
    ];
    const els = {
      load: document.getElementById("load"),
      status: document.getElementById("status"),
      summary: document.getElementById("summary"),
      metrics: document.getElementById("metrics"),
      eventBreakdown: document.getElementById("eventBreakdown"),
      versionBreakdown: document.getElementById("versionBreakdown"),
      crashDiagnostics: document.getElementById("crashDiagnostics"),
      performanceOps: document.getElementById("performanceOps"),
      importErrors: document.getElementById("importErrors"),
      privacyBlocks: document.getElementById("privacyBlocks"),
      privacy: document.getElementById("privacy"),
      eventsRange: document.getElementById("eventsRange")
    };

    els.load.addEventListener("click", loadDashboard);
    loadDashboard();

    async function loadDashboard() {
      setStatus("正在读取 D1 聚合数据...");
      try {
        const response = await fetch("/dashboard/data", { cache: "no-store" });
        if (!response.ok) {
          throw new Error("请求失败。请确认 Cloudflare Access 已放行当前邮箱。");
        }
        const data = await response.json();
        render(data);
        setStatus("已更新：" + formatTime(data.generatedAt));
      } catch (error) {
        setStatus(error instanceof Error ? error.message : String(error), true);
        renderUnavailable();
      }
    }

    function render(data) {
      const byID = new Map((data.metrics || []).map((metric) => [metric.metricID, metric]));
      renderSummary([
        ["匿名事件", metricValue(byID.get("total_events_count")), "最近接收 " + formatTime(data.latestReceivedAt)],
        ["启动完成", metricValue(byID.get("launch_completion_count")), "存活至启动事件上报"],
        ["会话恢复", metricValue(byID.get("unclean_session_recovery_count")), "非崩溃率，含系统回收"],
        ["系统崩溃", metricValue(byID.get("crash_diagnostic_count")), "MetricKit / 系统诊断"],
        ["慢操作", metricValue(byID.get("slow_operation_count")), "超过 3 秒或 warning"],
        ["导入完成率", metricValue(byID.get("import_completion_rate")), metricRatio(byID.get("import_completion_rate"))]
      ]);
      els.eventsRange.textContent = "最近 " + (data.windowDays || 30) + " 天";
      renderMetricTable((data.metrics || []).slice().sort((left, right) => metricOrder.indexOf(left.metricID) - metricOrder.indexOf(right.metricID)));
      renderEventBreakdown(data.eventBreakdown || []);
      renderBars(els.versionBreakdown, objectEntries(data.appVersionBreakdown || {}));
      renderBars(els.crashDiagnostics, objectEntries((byID.get("crash_diagnostic_count") || {}).breakdown || {}));
      renderBars(els.performanceOps, objectEntries((byID.get("performance_operation_top_n") || {}).breakdown || {}));
      renderBars(els.importErrors, objectEntries((byID.get("import_error_code_top_n") || {}).breakdown || {}));
      renderBars(els.privacyBlocks, objectEntries((byID.get("privacy_payload_violation_count") || {}).breakdown || {}));
      renderPrivacy(data);
    }

    function renderSummary(items) {
      els.summary.innerHTML = items.map(([label, value, note]) => (
        '<section class="metric"><span>' + escapeHTML(label) + '</span><strong>' + escapeHTML(value) + '</strong><small>' + escapeHTML(note) + '</small></section>'
      )).join("");
    }

    function renderMetricTable(metrics) {
      if (!metrics.length) {
        els.metrics.innerHTML = '<div class="empty">当前没有最小指标数据。</div>';
        return;
      }
      els.metrics.innerHTML = '<div class="table-scroll"><table><thead><tr><th>指标</th><th>数值</th><th>样本</th><th>状态</th></tr></thead><tbody>' + metrics.map((metric) => (
        '<tr>'
          + '<td><div class="title">' + escapeHTML(metric.label || metric.metricID) + '</div><div class="muted">' + escapeHTML(metric.metricID) + '</div></td>'
          + '<td class="nowrap"><span class="pill ' + metricClass(metric) + '">' + escapeHTML(formatMetric(metric)) + '</span></td>'
          + '<td class="muted nowrap">' + escapeHTML(metricRatio(metric)) + '</td>'
          + '<td class="muted">' + escapeHTML(statusText(metric.status)) + '</td>'
        + '</tr>'
      )).join("") + '</tbody></table></div>';
    }

    function renderEventBreakdown(rows) {
      els.eventBreakdown.innerHTML = rows.length
        ? rows.map((row) => '<tr><td><div class="title">' + escapeHTML(row.eventName) + '</div></td><td class="nowrap">' + escapeHTML(row.count) + '</td><td class="muted nowrap">' + escapeHTML(formatTime(row.latestReceivedAt)) + '</td></tr>').join("")
        : '<tr><td colspan="3" class="muted">当前窗口内没有事件。</td></tr>';
    }

    function renderBars(container, rows) {
      if (!rows.length) {
        container.innerHTML = '<div class="empty">当前范围内没有数据。</div>';
        return;
      }
      const max = Math.max(...rows.map((row) => Number(row.value) || 0), 1);
      container.innerHTML = rows.map((row) => {
        const value = Number(row.value) || 0;
        const width = Math.max(4, Math.round((value / max) * 100));
        return '<div class="bar-row">'
          + '<div class="bar-label" title="' + escapeHTML(row.label) + '">' + escapeHTML(row.label) + '</div>'
          + '<div class="bar-track"><div class="bar-fill" style="width:' + width + '%"></div></div>'
          + '<div class="bar-value">' + escapeHTML(value) + '</div>'
          + '</div>';
      }).join("");
    }

    function renderPrivacy(data) {
      const privacy = data.privacy || {};
      const access = data.access || {};
      const rows = [
        ["数据边界", privacy.summary || "此面板只展示聚合计数和比率。"],
        ["数据类别", Array.isArray(privacy.dataCategories) ? privacy.dataCategories.join(" / ") : "-"],
        ["关联用户", privacy.linked ? "是" : "否"],
        ["用于追踪", privacy.tracking ? "是" : "否"],
        ["访问保护", access.protection || "cloudflare_access"],
        ["保留期", String(data.retentionDays || "-") + " 天"]
      ];
      els.privacy.innerHTML = '<div class="table-scroll"><table><tbody>' + rows.map(([label, value]) => (
        '<tr><th>' + escapeHTML(label) + '</th><td class="muted">' + escapeHTML(value) + '</td></tr>'
      )).join("") + '</tbody></table></div>';
    }

    function renderUnavailable() {
      renderSummary([
        ["面板暂不可用", "-", "请确认 Access、Worker 和 D1 绑定"],
        ["启动完成", "-", "暂无数据"],
        ["会话恢复", "-", "暂无数据"],
        ["系统崩溃", "-", "暂无数据"],
        ["慢操作", "-", "暂无数据"],
        ["导入完成率", "-", "暂无数据"]
      ]);
      els.metrics.innerHTML = '<div class="empty">暂时无法读取指标。</div>';
      els.eventBreakdown.innerHTML = '<tr><td colspan="3" class="muted">暂时无法读取事件分布。</td></tr>';
      els.versionBreakdown.innerHTML = '<div class="empty">暂时无法读取版本分布。</div>';
      els.crashDiagnostics.innerHTML = '<div class="empty">暂时无法读取崩溃诊断。</div>';
      els.performanceOps.innerHTML = '<div class="empty">暂时无法读取性能操作。</div>';
      els.importErrors.innerHTML = '<div class="empty">暂时无法读取导入错误。</div>';
      els.privacyBlocks.innerHTML = '<div class="empty">暂时无法读取隐私拦截。</div>';
      els.privacy.innerHTML = '<div class="empty">请在 Worker 和 D1 绑定恢复后刷新。</div>';
    }

    function objectEntries(record) {
      return Object.entries(record)
        .map(([label, value]) => ({ label, value }))
        .sort((left, right) => Number(right.value) - Number(left.value) || left.label.localeCompare(right.label));
    }

    function metricValue(metric) {
      return metric ? formatMetric(metric) : "-";
    }

    function formatMetric(metric) {
      if (!metric || metric.value === null || metric.value === undefined) {
        return "暂无数据";
      }
      return metric.unit === "percent" ? metric.value + "%" : String(metric.value);
    }

    function metricRatio(metric) {
      if (!metric) {
        return "-";
      }
      return String(metric.numerator) + " / " + String(metric.denominator);
    }

    function metricClass(metric) {
      if (!metric || metric.status !== "available") {
        return "warning";
      }
      if (metric.metricID === "privacy_payload_violation_count" && Number(metric.value) > 0) {
        return "failed";
      }
      if (metric.unit === "percent" && Number(metric.value) < 80) {
        return "warning";
      }
      return "sent";
    }

    function statusText(status) {
      switch (status) {
        case "available": return "可用";
        case "insufficient_data": return "数据不足";
        default: return status || "-";
      }
    }

    function formatTime(value) {
      if (!value) {
        return "暂无数据";
      }
      const date = new Date(value);
      if (Number.isNaN(date.getTime())) {
        return value;
      }
      return date.toLocaleString("zh-CN", { hour12: false });
    }

    function setStatus(message, isError) {
      els.status.textContent = message;
      els.status.className = isError ? "status error" : "status";
    }

    function escapeHTML(value) {
      return String(value).replace(/[&<>"']/g, (char) => ({
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        '"': "&quot;",
        "'": "&#39;"
      }[char]));
    }
  </script>
</body>
</html>`;
