pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick

StyledRect {
    id: root

    readonly property color colour: Colours.palette.m3tertiary
    readonly property int padding: Config.bar.clock.background ? Appearance.padding.normal : Appearance.padding.small

    implicitHeight: Config.bar.sizes.innerHeight
    implicitWidth: layout.implicitWidth + root.padding * 2

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, Config.bar.clock.background ? Colours.tPalette.m3surfaceContainer.a : 0)
    radius: Appearance.rounding.full

    /// 根据配置的语言代码 + 日期格式返回本地化的日期文字
    function localizedDate() {
        const fmt = Config.bar.clock.dateFormat || "d";
        const localeKey = Config.bar.clock.dateLocale;

        if (localeKey === "system") {
            return Time.format("ddd " + fmt);
        }

        const wd = new Date(Time.date).getDay(); // 0=Sun … 6=Sat

        const dayNames = {
            "en": ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
            "zh": ["周日", "周一", "周二", "周三", "周四", "周五", "周六"],
            "ja": ["日曜", "月曜", "火曜", "水曜", "木曜", "金曜", "土曜"],
        };

        const names = dayNames[localeKey];
        if (names) {
            return names[wd] + " " + Time.format(fmt);
        }

        return Time.format("ddd " + fmt);
    }

    Row {
        id: layout
        anchors.centerIn: parent
        spacing: Appearance.spacing.small

        Loader {
            anchors.verticalCenter: parent.verticalCenter

            active: Config.bar.clock.showIcon
            visible: active

            sourceComponent: MaterialIcon {
                text: "calendar_month"
                color: root.colour
            }
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: Config.bar.clock.showDate

            horizontalAlignment: StyledText.AlignHCenter
            text: root.localizedDate()
            font.pointSize: Appearance.font.size.smaller
            font.family: Appearance.font.family.mono
            color: root.colour
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter

            horizontalAlignment: StyledText.AlignHCenter
            text: {
                let fmt = Config.services.useTwelveHourClock ? "hh:mm" : "HH:mm";
                if (Config.bar.clock.showSeconds) fmt += ":ss";
                if (Config.services.useTwelveHourClock) fmt += " A";
                return Time.format(fmt);
            }
            font.pointSize: Appearance.font.size.smaller
            font.family: Appearance.font.family.mono
            color: root.colour
        }
    }
}
