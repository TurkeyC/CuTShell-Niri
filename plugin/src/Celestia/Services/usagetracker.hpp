#pragma once

#include <QObject>
#include <QTimer>
#include <QDateTime>
#include <QVariantList>
#include <QVariantMap>
#include <QString>
#include <QSqlDatabase>
#include <qqmlintegration.h>

namespace celestia {

/// UsageTracker — tracks per-application usage time with SQLite persistence.
///
/// Records window focus sessions and provides aggregated queries for
/// today / this week / this month / all-time usage statistics.
///
/// Usage from QML:
///   UsageTracker { id: tracker; path: "~/.local/share/Celestia/Shell/app_usage.db" }
///   tracker.reportFocusIn(appId, appName);
///   tracker.reportFocusOut();
///   var today = tracker.getTodayUsage();
class UsageTracker : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString path READ path WRITE setPath NOTIFY pathChanged)
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)
    Q_PROPERTY(QString currentAppId READ currentAppId NOTIFY currentAppChanged)
    Q_PROPERTY(QString currentAppName READ currentAppName NOTIFY currentAppChanged)

public:
    explicit UsageTracker(QObject* parent = nullptr);
    ~UsageTracker() override;

    // ── Properties ──

    QString path() const;
    void setPath(const QString& path);

    bool ready() const;

    QString currentAppId() const;
    QString currentAppName() const;

    // ── Lifecycle ──

    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void flush();

    // ── Focus tracking ──

    Q_INVOKABLE void reportFocusIn(const QString& appId, const QString& appName);
    Q_INVOKABLE void reportFocusOut();

    // ── Data queries ──
    // Each returns QVariantList of { app_id, app_name, total_ms, total_display, session_count }
    // where total_display is a human-readable string like "2h 15m"

    Q_INVOKABLE QVariantList getTodayUsage();
    Q_INVOKABLE QVariantList getWeekUsage();
    Q_INVOKABLE QVariantList getMonthUsage();
    Q_INVOKABLE QVariantList getTotalUsage();
    Q_INVOKABLE QVariantList getTopApps(const QString& period, int limit = 20);

    // Returns QVariantList of { app_id, app_name, start_time, end_time, duration_ms, duration_display }
    Q_INVOKABLE QVariantList getSessionHistory(const QString& appId = QString(), int limit = 50);

    // Returns all sessions for a period (today/week/month/total) ordered by start_time ASC
    // Each item: { app_id, app_name, start_time, end_time, duration_ms, duration_display }
    Q_INVOKABLE QVariantList getPeriodSessions(const QString& period, int limit = 500);

signals:
    void pathChanged();
    void readyChanged();
    void currentAppChanged();
    void usageUpdated(const QString& appId, qint64 totalMs);

private slots:
    void onFlushTimer();

private:
    bool openDatabase();
    void createTables();
    void flushCurrentSession();

    QString formatDuration(qint64 ms) const;
    QString todayString() const;
    QString weekStartString() const;
    QString monthStartString() const;

    // Internal state
    QString m_path;
    QString m_uuid;
    bool m_ready = false;
    bool m_started = false;

    // Current session tracking
    QString m_currentAppId;
    QString m_currentAppName;
    QDateTime m_sessionStart;
    qint64 m_lastFlushedDuration = 0;

    // Timers
    QTimer m_flushTimer;
};

} // namespace celestia
