import { supportedLocales, type SupportedLocale } from "./places-catalog";

export type ReleaseNotesSection = {
  title: string;
  body: string;
};

export type LocalizedReleaseNotes = {
  schemaVersion: number;
  resourceVersion: string;
  app: string;
  version: string;
  locale: SupportedLocale;
  current: ReleaseNotesSection;
  upcoming: ReleaseNotesSection;
};

export type ReleaseNotesManifest = {
  status: "available" | "configuration_required";
  schemaVersion: number;
  resourceVersion: string;
  supportedApps: string[];
  supportedVersions: Record<string, string[]>;
  supportedLocales: SupportedLocale[];
};

type ReleaseNotesRow = {
  schema_version: number;
  resource_version: string;
  app_id: string;
  app_version: string;
  locale: SupportedLocale;
  current_title: string;
  current_body: string;
  upcoming_title: string;
  upcoming_body: string;
};

type ManifestRow = {
  app_id: string;
  app_version: string;
  locale: SupportedLocale;
  resource_version: string;
  schema_version: number;
};

export const releaseNotesSchemaVersion = 1;
const unavailableResourceVersion = "unconfigured";

export async function releaseNotesManifest(db: D1Database | undefined): Promise<ReleaseNotesManifest> {
  if (!db) {
    return unavailableManifest();
  }

  try {
    const { results } = await db
      .prepare(
        `SELECT app_id, app_version, locale, resource_version, schema_version
           FROM release_notes
          WHERE status = 'published'
          ORDER BY app_id ASC, app_version ASC, locale ASC`
      )
      .all<ManifestRow>();

    if (!results.length) {
      return unavailableManifest();
    }

    const supportedApps = Array.from(new Set(results.map((row) => row.app_id))).sort();
    const supportedVersions: Record<string, string[]> = {};
    const localeSet = new Set<SupportedLocale>();
    let resourceVersion = results[0]?.resource_version ?? unavailableResourceVersion;
    let schemaVersion = results[0]?.schema_version ?? releaseNotesSchemaVersion;

    for (const row of results) {
      const versions = supportedVersions[row.app_id] ?? [];
      if (!versions.includes(row.app_version)) {
        versions.push(row.app_version);
      }
      supportedVersions[row.app_id] = versions;
      localeSet.add(row.locale);
      if (row.resource_version.localeCompare(resourceVersion) > 0) {
        resourceVersion = row.resource_version;
      }
      schemaVersion = Math.max(schemaVersion, row.schema_version);
    }

    for (const appID of Object.keys(supportedVersions)) {
      supportedVersions[appID] = (supportedVersions[appID] ?? []).sort(compareVersions);
    }

    return {
      status: "available",
      schemaVersion,
      resourceVersion,
      supportedApps,
      supportedVersions,
      supportedLocales: supportedLocales.filter((locale) => localeSet.has(locale))
    };
  } catch {
    return unavailableManifest();
  }
}

export async function releaseNotesFor(
  db: D1Database,
  appID: string,
  version: string,
  locale: SupportedLocale
): Promise<LocalizedReleaseNotes | null> {
  const row = await db
    .prepare(
      `SELECT schema_version, resource_version, app_id, app_version, locale,
              current_title, current_body, upcoming_title, upcoming_body
         FROM release_notes
        WHERE app_id = ?
          AND app_version = ?
          AND locale = ?
          AND status = 'published'
        LIMIT 1`
    )
    .bind(appID, version, locale)
    .first<ReleaseNotesRow>();

  if (!row) {
    return null;
  }

  return {
    schemaVersion: row.schema_version,
    resourceVersion: row.resource_version,
    app: row.app_id,
    version: row.app_version,
    locale: row.locale,
    current: {
      title: row.current_title,
      body: row.current_body
    },
    upcoming: {
      title: row.upcoming_title,
      body: row.upcoming_body
    }
  };
}

export async function supportedReleaseNoteVersions(db: D1Database, appID: string): Promise<string[]> {
  const { results } = await db
    .prepare(
      `SELECT DISTINCT app_version
         FROM release_notes
        WHERE app_id = ?
          AND status = 'published'
        ORDER BY app_version ASC`
    )
    .bind(appID)
    .all<{ app_version: string }>();

  return results.map((row) => row.app_version).sort(compareVersions);
}

function unavailableManifest(): ReleaseNotesManifest {
  return {
    status: "configuration_required",
    schemaVersion: releaseNotesSchemaVersion,
    resourceVersion: unavailableResourceVersion,
    supportedApps: [],
    supportedVersions: {},
    supportedLocales: []
  };
}

function compareVersions(left: string, right: string): number {
  const leftParts = left.split(".").map((part) => Number.parseInt(part, 10));
  const rightParts = right.split(".").map((part) => Number.parseInt(part, 10));
  const length = Math.max(leftParts.length, rightParts.length);
  for (let index = 0; index < length; index += 1) {
    const delta = (leftParts[index] ?? 0) - (rightParts[index] ?? 0);
    if (delta !== 0) {
      return delta;
    }
  }
  return left.localeCompare(right);
}
