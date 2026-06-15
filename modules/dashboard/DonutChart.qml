import QtQuick

Canvas {
    id: root

    /// Array of { label, value, color } — redraws on change
    property var segments: []
    /// Fraction of outer radius for the hole (0–1)
    property real holeRatio: 0.67

    onSegmentsChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);

        if (!segments || segments.length === 0) return;

        var total = 0;
        for (var i = 0; i < segments.length; i++) {
            total += segments[i].value;
        }
        if (total <= 0) return;

        var cx = width / 2;
        var cy = height / 2;
        var outerR = Math.min(cx, cy) - 2;
        var innerR = outerR * holeRatio;

        var startAngle = -Math.PI / 2;
        for (i = 0; i < segments.length; i++) {
            var sweep = (segments[i].value / total) * 2 * Math.PI;
            var endAngle = startAngle + sweep;

            ctx.beginPath();
            ctx.arc(cx, cy, outerR, startAngle, endAngle);
            ctx.arc(cx, cy, innerR, endAngle, startAngle, true);
            ctx.closePath();
            ctx.fillStyle = segments[i].color;
            ctx.fill();

            startAngle = endAngle;
        }
    }

}
