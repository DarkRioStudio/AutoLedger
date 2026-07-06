INSERT INTO release_notes (
  app_id,
  app_version,
  locale,
  schema_version,
  resource_version,
  current_title,
  current_body,
  upcoming_title,
  upcoming_body,
  status,
  updated_at
) VALUES
  (
    'autonotice',
    '0.1.0',
    'zh-Hans',
    1,
    '2026.07.06.3',
    '当前版本',
    '0.1.0 是 AutoNotice 的第一个 App Store 发布版本，打通了天气提醒闭环：选择位置、启用降水提醒、同步提醒规则，并由 Worker 定时检查后通过 APNs 推送通知。',
    '后续计划',
    '0.2.0 会继续完善天气提醒，把单一降水提醒扩展为降雨、降温、升温、大风和天气预警五个开关，同时补齐通知历史、触发证据和 Time Sensitive 天气预警。',
    'published',
    '2026-07-06T08:30:00.000Z'
  ),
  (
    'autonotice',
    '0.1.0',
    'en',
    1,
    '2026.07.06.3',
    'Current Version',
    '0.1.0 is the first App Store release for AutoNotice. It closes the Weather Notice loop: choose a location, enable precipitation notices, sync the rule, and let the Worker check conditions and deliver APNs notifications.',
    'Coming Next',
    '0.2.0 will keep improving Weather Notice by expanding one precipitation notice into five switches: rain, temperature drop, temperature rise, wind, and weather alerts, plus clearer history evidence and Time Sensitive weather alert delivery.',
    'published',
    '2026-07-06T08:30:00.000Z'
  ),
  (
    'autonotice',
    '0.2.0',
    'zh-Hans',
    1,
    '2026.07.06.3',
    '当前版本',
    '0.2.0 是 AutoNotice 的内部开发线，正在把天气提醒从单一降水规则升级为 WeatherSnapshot、多天气规则条件判断和更清晰的通知证据。',
    '后续计划',
    '下一步会落地降雨、降温、升温、大风和天气预警五个开关。天气预警会结合 WeatherKit、和风天气和彩云天气的数据源，并在需要时使用 Time Sensitive 推送。',
    'published',
    '2026-07-06T08:30:00.000Z'
  ),
  (
    'autonotice',
    '0.2.0',
    'en',
    1,
    '2026.07.06.3',
    'Current Version',
    '0.2.0 is the internal AutoNotice development line. It moves Weather Notice from one precipitation rule toward WeatherSnapshot, multiple weather rule evaluators, and clearer notification evidence.',
    'Coming Next',
    'Next we will implement five Weather Notice switches: rain, temperature drop, temperature rise, wind, and weather alerts. Weather alerts will combine WeatherKit, QWeather, and Caiyun sources, and use Time Sensitive delivery when needed.',
    'published',
    '2026-07-06T08:30:00.000Z'
  )
ON CONFLICT(app_id, app_version, locale) DO UPDATE SET
  schema_version = excluded.schema_version,
  resource_version = excluded.resource_version,
  current_title = excluded.current_title,
  current_body = excluded.current_body,
  upcoming_title = excluded.upcoming_title,
  upcoming_body = excluded.upcoming_body,
  status = excluded.status,
  updated_at = excluded.updated_at;
