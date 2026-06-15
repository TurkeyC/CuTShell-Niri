#include "usagetracker.hpp"

#include <QDir>
#include <QFileInfo>
#include <QDebug>
#include <QSqlQuery>
#include <QSqlError>
#include <QStandardPaths>
#include <QUuid>
#include <QDate>

namespace caelestia {

// ── Constructor / Destructor ──────────────────────────────────────────

UsageTracker::UsageTracker(QObject* parent)
    : QObject(parent)
    , m_uuid(QUuid::createUuid().toString())
{
    m_flushTimer.setSingleShot(false);
    m_flushTimer.setInterval(30000); // flush every 30 seconds
    connect(&m_flushTimer, &QTimer::timeout, this, &UsageTracker::onFlushTimer);

    // Default path: XDG_DATA_HOME/caelestia/app_usage.db
    const QString dataHome = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);
    m_path = dataHome + QStringLiteral("/caelestia/app_usage.db");
}

UsageTracker::~UsageTracker() {
    // Flush any in-progress session before destruction
    if (m_started) {
        flushCurrentSession();
    }
}

// ── Properties ────────────────────────────────────────────────────────

QString UsageTracker::path() const { return m_path; }

void UsageTracker::setPath(const QString& path) {
    if (m_path == path) return;
    m_path = path;
    emit pathChanged();

    if (m_started) {
        // Reopen database with new path
        stop();
        start();
    }
}

bool UsageTracker::ready() const { return m_ready; }

QString UsageTracker::currentAppId() const { return m_currentAppId; }
QString UsageTracker::currentAppName() const { return m_currentAppName; }

// ── Lifecycle ─────────────────────────────────────────────────────────

void UsageTracker::start() {
    if (m_started) return;

    if (openDatabase()) {
        m_started = true;
        m_ready = true;
        emit readyChanged();
        qDebug() << "UsageTracker: Started, database at" << m_path;
    } else {
        qWarning() << "UsageTracker: Failed to open database at" << m_path;
    }
}

void UsageTracker::stop() {
    if (!m_started) return;

    flushCurrentSession();
    m_flushTimer.stop();
    m_started = false;
    m_ready = false;

    // Close the database connection
    if (QSqlDatabase::contains(m_uuid)) {
        QSqlDatabase::database(m_uuid).close();
        QSqlDatabase::removeDatabase(m_uuid);
    }

    emit readyChanged();
    qDebug() << "UsageTracker: Stopped";
}

void UsageTracker::flush() {
    flushCurrentSession();
}

// ── Focus Tracking ────────────────────────────────────────────────────

void UsageTracker::reportFocusIn(const QString& appId, const QString& appName) {
    if (!m_started) return;

    // Flush previous session first
    flushCurrentSession();

    // Start new session
    m_currentAppId = appId;
    m_currentAppName = appName;
    m_sessionStart = QDateTime::currentDateTime();
    m_lastFlushedDuration = 0;

    // Start periodic flush timer if not already running
    if (!m_flushTimer.isActive()) {
        m_flushTimer.start();
    }

    emit currentAppChanged();
}

void UsageTracker::reportFocusOut() {
    if (!m_started || m_currentAppId.isEmpty()) return;

    flushCurrentSession();

    m_currentAppId.clear();
    m_currentAppName.clear();
    m_flushTimer.stop();

    emit currentAppChanged();
}

// ── Data Queries ──────────────────────────────────────────────────────

QVariantList UsageTracker::getTodayUsage() {
    return getTopApps(QStringLiteral("today"), 100);
}

QVariantList UsageTracker::getWeekUsage() {
    return getTopApps(QStringLiteral("week"), 100);
}

QVariantList UsageTracker::getMonthUsage() {
    return getTopApps(QStringLiteral("month"), 100);
}

QVariantList UsageTracker::getTotalUsage() {
    return getTopApps(QStringLiteral("total"), 100);
}

QVariantList UsageTracker::getTopApps(const QString& period, int limit) {
    if (!m_ready) return {};

    QSqlDatabase db = QSqlDatabase::database(m_uuid);
    QString sql;
    QVariantMap bindings;

    const QString today = todayString();

    if (period == QStringLiteral("today")) {
        sql = QStringLiteral(
            "SELECT app_id, app_name, SUM(total_ms) AS total_ms, SUM(session_count) AS session_count "
            "FROM daily_usage WHERE date = :today "
            "GROUP BY app_id ORDER BY total_ms DESC LIMIT :limit"
        );
        bindings[QStringLiteral(":today")] = today;
    } else if (period == QStringLiteral("week")) {
        const QString weekStart = weekStartString();
        sql = QStringLiteral(
            "SELECT app_id, app_name, SUM(total_ms) AS total_ms, SUM(session_count) AS session_count "
            "FROM daily_usage WHERE date >= :week_start AND date <= :today "
            "GROUP BY app_id ORDER BY total_ms DESC LIMIT :limit"
        );
        bindings[QStringLiteral(":week_start")] = weekStart;
        bindings[QStringLiteral(":today")] = today;
    } else if (period == QStringLiteral("month")) {
        const QString monthStart = monthStartString();
        sql = QStringLiteral(
            "SELECT app_id, app_name, SUM(total_ms) AS total_ms, SUM(session_count) AS session_count "
            "FROM daily_usage WHERE date >= :month_start AND date <= :today "
            "GROUP BY app_id ORDER BY total_ms DESC LIMIT :limit"
        );
        bindings[QStringLiteral(":month_start")] = monthStart;
        bindings[QStringLiteral(":today")] = today;
    } else {
        // total / all-time
        sql = QStringLiteral(
            "SELECT app_id, app_name, SUM(total_ms) AS total_ms, SUM(session_count) AS session_count "
            "FROM daily_usage "
            "GROUP BY app_id ORDER BY total_ms DESC LIMIT :limit"
        );
    }

    bindings[QStringLiteral(":limit")] = limit;

    QSqlQuery query(db);
    query.prepare(sql);
    for (auto it = bindings.begin(); it != bindings.end(); ++it) {
        query.bindValue(it.key(), it.value());
    }

    QVariantList results;
    if (!query.exec()) {
        qWarning() << "UsageTracker::getTopApps query failed:" << query.lastError().text();
        return results;
    }

    while (query.next()) {
        QVariantMap row;
        const qint64 totalMs = query.value(QStringLiteral("total_ms")).toLongLong();
        row[QStringLiteral("app_id")] = query.value(QStringLiteral("app_id")).toString();
        row[QStringLiteral("app_name")] = query.value(QStringLiteral("app_name")).toString();
        row[QStringLiteral("total_ms")] = totalMs;
        row[QStringLiteral("total_display")] = formatDuration(totalMs);
        row[QStringLiteral("session_count")] = query.value(QStringLiteral("session_count")).toInt();
        results.append(row);
    }

    return results;
}

QVariantList UsageTracker::getSessionHistory(const QString& appId, int limit) {
    if (!m_ready) return {};

    QSqlDatabase db = QSqlDatabase::database(m_uuid);
    QSqlQuery query(db);

    QString sql;
    if (appId.isEmpty()) {
        sql = QStringLiteral(
            "SELECT app_id, app_name, start_time, end_time, duration_ms "
            "FROM usage_sessions WHERE duration_ms > 0 "
            "ORDER BY start_time DESC LIMIT :limit"
        );
    } else {
        sql = QStringLiteral(
            "SELECT app_id, app_name, start_time, end_time, duration_ms "
            "FROM usage_sessions WHERE app_id = :app_id AND duration_ms > 0 "
            "ORDER BY start_time DESC LIMIT :limit"
        );
    }

    query.prepare(sql);
    if (!appId.isEmpty()) {
        query.bindValue(QStringLiteral(":app_id"), appId);
    }
    query.bindValue(QStringLiteral(":limit"), limit);

    QVariantList results;
    if (!query.exec()) {
        qWarning() << "UsageTracker::getSessionHistory query failed:" << query.lastError().text();
        return results;
    }

    while (query.next()) {
        QVariantMap row;
        const qint64 durationMs = query.value(QStringLiteral("duration_ms")).toLongLong();
        row[QStringLiteral("app_id")] = query.value(QStringLiteral("app_id")).toString();
        row[QStringLiteral("app_name")] = query.value(QStringLiteral("app_name")).toString();
        row[QStringLiteral("start_time")] = query.value(QStringLiteral("start_time")).toString();
        row[QStringLiteral("end_time")] = query.value(QStringLiteral("end_time")).toString();
        row[QStringLiteral("duration_ms")] = durationMs;
        row[QStringLiteral("duration_display")] = formatDuration(durationMs);
        results.append(row);
    }

    return results;
}

QVariantList UsageTracker::getPeriodSessions(const QString& period, int limit) {
    if (!m_ready) return {};

    QSqlDatabase db = QSqlDatabase::database(m_uuid);
    QString sql;
    QVariantMap bindings;

    const QString today = todayString();

    if (period == QStringLiteral("today")) {
        sql = QStringLiteral(
            "SELECT app_id, app_name, start_time, end_time, duration_ms "
            "FROM usage_sessions WHERE date = :today AND duration_ms > 0 "
            "ORDER BY start_time ASC LIMIT :limit"
        );
        bindings[QStringLiteral(":today")] = today;
    } else if (period == QStringLiteral("week")) {
        const QString weekStart = weekStartString();
        sql = QStringLiteral(
            "SELECT app_id, app_name, start_time, end_time, duration_ms "
            "FROM usage_sessions WHERE date >= :week_start AND date <= :today AND duration_ms > 0 "
            "ORDER BY start_time ASC LIMIT :limit"
        );
        bindings[QStringLiteral(":week_start")] = weekStart;
        bindings[QStringLiteral(":today")] = today;
    } else if (period == QStringLiteral("month")) {
        const QString monthStart = monthStartString();
        sql = QStringLiteral(
            "SELECT app_id, app_name, start_time, end_time, duration_ms "
            "FROM usage_sessions WHERE date >= :month_start AND date <= :today AND duration_ms > 0 "
            "ORDER BY start_time ASC LIMIT :limit"
        );
        bindings[QStringLiteral(":month_start")] = monthStart;
        bindings[QStringLiteral(":today")] = today;
    } else {
        // total / all-time
        sql = QStringLiteral(
            "SELECT app_id, app_name, start_time, end_time, duration_ms "
            "FROM usage_sessions WHERE duration_ms > 0 "
            "ORDER BY start_time ASC LIMIT :limit"
        );
    }

    bindings[QStringLiteral(":limit")] = limit;

    QSqlQuery query(db);
    query.prepare(sql);
    for (auto it = bindings.begin(); it != bindings.end(); ++it) {
        query.bindValue(it.key(), it.value());
    }

    QVariantList results;
    if (!query.exec()) {
        qWarning() << "UsageTracker::getPeriodSessions query failed:" << query.lastError().text();
        return results;
    }

    while (query.next()) {
        QVariantMap row;
        const qint64 durationMs = query.value(QStringLiteral("duration_ms")).toLongLong();
        row[QStringLiteral("app_id")] = query.value(QStringLiteral("app_id")).toString();
        row[QStringLiteral("app_name")] = query.value(QStringLiteral("app_name")).toString();
        row[QStringLiteral("start_time")] = query.value(QStringLiteral("start_time")).toString();
        row[QStringLiteral("end_time")] = query.value(QStringLiteral("end_time")).toString();
        row[QStringLiteral("duration_ms")] = durationMs;
        row[QStringLiteral("duration_display")] = formatDuration(durationMs);
        results.append(row);
    }

    return results;
}

// ── Private Slots ─────────────────────────────────────────────────────

void UsageTracker::onFlushTimer() {
    if (m_currentAppId.isEmpty()) return;

    const qint64 nowMs = QDateTime::currentDateTime().toMSecsSinceEpoch();
    const qint64 startMs = m_sessionStart.toMSecsSinceEpoch();
    const qint64 duration = nowMs - startMs;
    const qint64 delta = duration - m_lastFlushedDuration;

    if (delta < 1000) return; // skip sub-second updates

    QSqlDatabase db = QSqlDatabase::database(m_uuid);
    QSqlQuery query(db);

    // Update daily_usage with the delta (no session_count change on periodic flush)
    query.prepare(QStringLiteral(
        "INSERT INTO daily_usage (app_id, app_name, date, total_ms, session_count) "
        "VALUES (:app_id, :app_name, :date, :delta, 0) "
        "ON CONFLICT(app_id, date) DO UPDATE SET total_ms = total_ms + :delta2"
    ));
    query.bindValue(QStringLiteral(":app_id"), m_currentAppId);
    query.bindValue(QStringLiteral(":app_name"), m_currentAppName);
    query.bindValue(QStringLiteral(":date"), todayString());
    query.bindValue(QStringLiteral(":delta"), delta);
    query.bindValue(QStringLiteral(":delta2"), delta);

    if (!query.exec()) {
        qWarning() << "UsageTracker::onFlushTimer query failed:" << query.lastError().text();
    }

    m_lastFlushedDuration = duration;
    emit usageUpdated(m_currentAppId, duration);
}

// ── Private Helpers ───────────────────────────────────────────────────

bool UsageTracker::openDatabase() {
    // Ensure directory exists
    QDir dir = QFileInfo(m_path).absoluteDir();
    if (!dir.exists()) {
        dir.mkpath(QStringLiteral("."));
    }

    QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), m_uuid);
    db.setDatabaseName(m_path);

    if (!db.open()) {
        qWarning() << "UsageTracker: Cannot open database:" << db.lastError().text();
        return false;
    }

    // Enable WAL mode for better concurrent read performance
    QSqlQuery pragma(db);
    pragma.exec(QStringLiteral("PRAGMA journal_mode=WAL"));
    pragma.exec(QStringLiteral("PRAGMA busy_timeout=5000"));

    createTables();
    return true;
}

void UsageTracker::createTables() {
    QSqlDatabase db = QSqlDatabase::database(m_uuid);
    QSqlQuery query(db);

    // Daily aggregated usage
    query.exec(QStringLiteral(
        "CREATE TABLE IF NOT EXISTS daily_usage ("
        "  app_id        TEXT NOT NULL,"
        "  app_name      TEXT NOT NULL DEFAULT '',"
        "  date          TEXT NOT NULL,"       // ISO date: "2026-06-14"
        "  total_ms      INTEGER NOT NULL DEFAULT 0,"
        "  session_count INTEGER NOT NULL DEFAULT 0,"
        "  PRIMARY KEY (app_id, date)"
        ")"
    ));

    // Individual sessions for detailed history
    query.exec(QStringLiteral(
        "CREATE TABLE IF NOT EXISTS usage_sessions ("
        "  id          INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  app_id      TEXT NOT NULL,"
        "  app_name    TEXT NOT NULL DEFAULT '',"
        "  start_time  TEXT NOT NULL,"          // ISO 8601: "2026-06-14T09:30:00"
        "  end_time    TEXT,"                    // ISO 8601
        "  duration_ms INTEGER NOT NULL DEFAULT 0,"
        "  date        TEXT NOT NULL"            // ISO date for fast joins
        ")"
    ));

    // Indices for performance
    query.exec(QStringLiteral(
        "CREATE INDEX IF NOT EXISTS idx_sessions_date ON usage_sessions(date)"
    ));
    query.exec(QStringLiteral(
        "CREATE INDEX IF NOT EXISTS idx_sessions_app_date ON usage_sessions(app_id, date)"
    ));
    query.exec(QStringLiteral(
        "CREATE INDEX IF NOT EXISTS idx_daily_date ON daily_usage(date)"
    ));
}

void UsageTracker::flushCurrentSession() {
    if (m_currentAppId.isEmpty()) return;

    const QDateTime now = QDateTime::currentDateTime();
    const qint64 duration = m_sessionStart.msecsTo(now);
    const qint64 delta = duration - m_lastFlushedDuration;

    if (duration < 1000) {
        // Session too short, don't record
        return;
    }

    QSqlDatabase db = QSqlDatabase::database(m_uuid);
    QSqlQuery query(db);

    // 1. Write the session record
    query.prepare(QStringLiteral(
        "INSERT INTO usage_sessions (app_id, app_name, start_time, end_time, duration_ms, date) "
        "VALUES (:app_id, :app_name, :start_time, :end_time, :duration, :date)"
    ));
    query.bindValue(QStringLiteral(":app_id"), m_currentAppId);
    query.bindValue(QStringLiteral(":app_name"), m_currentAppName);
    query.bindValue(QStringLiteral(":start_time"), m_sessionStart.toString(Qt::ISODate));
    query.bindValue(QStringLiteral(":end_time"), now.toString(Qt::ISODate));
    query.bindValue(QStringLiteral(":duration"), duration);
    query.bindValue(QStringLiteral(":date"), m_sessionStart.date().toString(Qt::ISODate));

    if (!query.exec()) {
        qWarning() << "UsageTracker: Failed to insert session:" << query.lastError().text();
    }

    // 2. UPSERT into daily_usage with remaining delta AND increment session_count
    if (delta > 0) {
        query.prepare(QStringLiteral(
            "INSERT INTO daily_usage (app_id, app_name, date, total_ms, session_count) "
            "VALUES (:app_id, :app_name, :date, :delta, 1) "
            "ON CONFLICT(app_id, date) DO UPDATE SET "
            "  total_ms = total_ms + :delta2,"
            "  session_count = session_count + 1"
        ));
        query.bindValue(QStringLiteral(":app_id"), m_currentAppId);
        query.bindValue(QStringLiteral(":app_name"), m_currentAppName);
        query.bindValue(QStringLiteral(":date"), todayString());
        query.bindValue(QStringLiteral(":delta"), delta);
        query.bindValue(QStringLiteral(":delta2"), delta);

        if (!query.exec()) {
            qWarning() << "UsageTracker: Failed to update daily_usage:" << query.lastError().text();
        }
    }

    emit usageUpdated(m_currentAppId, duration);
}

QString UsageTracker::formatDuration(qint64 ms) const {
    if (ms < 1000) return QStringLiteral("0s");

    const qint64 totalSecs = ms / 1000;
    const qint64 hours = totalSecs / 3600;
    const qint64 mins = (totalSecs % 3600) / 60;
    const qint64 secs = totalSecs % 60;

    if (hours > 0) {
        if (mins > 0)
            return QStringLiteral("%1h %2m").arg(hours).arg(mins);
        return QStringLiteral("%1h").arg(hours);
    }
    if (mins > 0) {
        if (secs > 0)
            return QStringLiteral("%1m %2s").arg(mins).arg(secs);
        return QStringLiteral("%1m").arg(mins);
    }
    return QStringLiteral("%1s").arg(secs);
}

QString UsageTracker::todayString() const {
    return QDate::currentDate().toString(Qt::ISODate);
}

QString UsageTracker::weekStartString() const {
    QDate today = QDate::currentDate();
    QDate monday = today.addDays(-(today.dayOfWeek() - 1));
    return monday.toString(Qt::ISODate);
}

QString UsageTracker::monthStartString() const {
    QDate today = QDate::currentDate();
    QDate firstOfMonth(today.year(), today.month(), 1);
    return firstOfMonth.toString(Qt::ISODate);
}

} // namespace caelestia
