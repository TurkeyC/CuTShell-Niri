pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.config

/*
 * ClickEffects — BASpark 风格点击特效
 *
 * 使用 Canvas 渲染，包含：
 * - 扩散填充圆（ease-out cubic）
 * - 旋转圆弧段（从白色渐变到主题色）
 * - 迸射三角形粒子（白色，随机方向）
 * - 拖尾轨迹（按下时跟随鼠标）
 *
 * 不设 MouseArea，不消费事件。由 Interactions 转发坐标进来。
 */

Item {
    id: root
    anchors.fill: parent

    // ---- 可调参数 ----
    property real scale: 1.5
    property real effectOpacity: 1.0
    property real clickSpeed: 1.0
    property real trailSpeed: 1.0
    property real sparkSize: 1.0
    property real clickScale: 1.0
    property real trailWidth: 1.0

    // ---- 颜色 (BASpark 默认蓝) ----
    // 可通过 colorRgb 属性自定义，格式 "R,G,B"
    property string colorRgb: "45,175,255"

    readonly property var _themeRgb: {
        var parts = colorRgb.split(",");
        return [parseInt(parts[0]), parseInt(parts[1]), parseInt(parts[2])];
    }
    readonly property var _ringStartColor: [250, 252, 252]
    readonly property var _ringEndColor: [
        Math.round((_themeRgb[0] + 255 * 2) / 3),
        Math.round((_themeRgb[1] + 255 * 2) / 3),
        Math.round((_themeRgb[2] + 255 * 2) / 3),
    ]
    readonly property string _colorStr: colorRgb

    // ---- Canvas 渲染器 ----
    Canvas {
        id: canvas
        anchors.fill: parent

        property var waves: []
        property var sparks: []
        property var trail: []

        // 画笔缓存
        onPaint: {
            var ctx = canvas.getContext("2d");
            ctx.clearRect(0, 0, canvas.width, canvas.height);

            ctx.globalCompositeOperation = "lighter";

            _drawTrail(ctx);
            _drawWaves(ctx);
            _drawSparks(ctx);

            ctx.globalCompositeOperation = "source-over";
        }

        // ---- 涟漪绘制 ----
        function _drawWaves(ctx) {
            var waves = canvas.waves;
            for (var i = 0; i < waves.length; i++) {
                var w = waves[i];

                // 填充圆
                var waveLife = w.filledLife;
                var waveMax = w.filledMaxLife;
                if (waveLife < waveMax) {
                    var prog = waveLife / waveMax;
                    var ease = 1 - Math.pow(1 - prog, 3);
                    var r = 26 * root.scale * root.clickScale * ease;
                    w.r = r;
                    var alpha = Math.max(0, 1 - prog) * root.effectOpacity;

                    ctx.beginPath();
                    ctx.arc(w.x, w.y, r, 0, Math.PI * 2);
                    ctx.fillStyle = "rgba(" + root._colorStr + "," + alpha + ")";
                    ctx.fill();
                }

                // 旋转环
                var ringLife = w.ringLife;
                var ringMax = w.ringMaxLife;
                if (ringLife < ringMax) {
                    var rp = ringLife / ringMax; // ring progress
                    var o = w.ring;

                    // 环角度旋转（实际在 _update 中用 clickFs 更新）
                    // 此处不再更新角度

                    // 环长度：先增长后收缩
                    var segLen;
                    if (rp <= 0.1) {
                        segLen = o.len * (rp / 0.1);
                    } else if (rp > 0.4) {
                        segLen = o.len * Math.max(0, 1 - (rp - 0.4) / 0.6);
                    } else {
                        segLen = o.len;
                    }

                    // 颜色渐变：白 → 主题色
                    var colorT = Math.min(1, 1.2 * rp);
                    var rr = Math.round(root._ringStartColor[0] * (1 - colorT) + root._ringEndColor[0] * colorT);
                    var gg = Math.round(root._ringStartColor[1] * (1 - colorT) + root._ringEndColor[1] * colorT);
                    var bb = Math.round(root._ringStartColor[2] * (1 - colorT) + root._ringEndColor[2] * colorT);
                    var ringAlpha = Math.min(1, 1.1 - 0.3 * rp) * root.effectOpacity;

                    for (var si = 0; si < 2; si++) {
                        var seg = o.segs[si];
                        var baseAng = o.ang + seg.off;
                        var currLen = segLen * (seg.len / o.len); // but actually seg.len == o.len
                        var start = baseAng;
                        var end = start + currLen;

                        // 将弧分成 10 段绘制（粗细渐变效果）
                        for (var ki = 0; ki < 10; ki++) {
                            var t0 = ki / 10;
                            var t1 = (ki + 1) / 10;
                            var a0 = start + (end - start) * t0;
                            var a1 = start + (end - start) * t1;
                            if (Math.abs(a1 - a0) < 0.01) continue;

                            var wT = Math.min(1, 2 - Math.abs(4 * (t0 - 0.5)));
                            var lineWidthMul = Math.min(1, -0.8 * (rp - 0.8) + 1);
                            var lw = (0.4 * (1 - wT) + 3.3 * wT) * lineWidthMul;
                            var radius = w.r + seg.rRoundRate * root.scale * root.clickScale;

                            ctx.beginPath();
                            ctx.arc(w.x, w.y, radius, a0, a1);
                            ctx.strokeStyle = "rgba(" + rr + "," + gg + "," + bb + "," + ringAlpha + ")";
                            ctx.lineWidth = Math.max(1, lw);
                            ctx.stroke();
                        }
                    }
                }
            }
        }

        // ---- 粒子绘制 ----
        function _drawSparks(ctx) {
            var sparks = canvas.sparks;
            for (var i = 0; i < sparks.length; i++) {
                var s = sparks[i];
                var sz = s.s * root.sparkSize;
                if (sz <= 0 || s.a <= 0) continue;

                ctx.save();
                ctx.translate(s.x, s.y);
                ctx.rotate(s.rot);
                ctx.beginPath();
                ctx.moveTo(0, -sz);
                ctx.lineTo(sz * 0.6, sz * 0.6);
                ctx.lineTo(-sz * 0.6, sz * 0.6);
                ctx.closePath();
                ctx.fillStyle = "rgba(255,255,255," + (s.a * root.effectOpacity) + ")";
                ctx.fill();
                ctx.restore();
            }
        }

        // ---- 拖尾绘制 ----
        function _drawTrail(ctx) {
            var trail = canvas.trail;
            if (trail.length < 2) {
                // 单点拖尾：画圆点
                if (trail.length === 1) {
                    var t = trail[0];
                    var dotSize = (2.5 + 2 * t.life) * (root.scale / 1.5) * root.trailWidth;
                    ctx.beginPath();
                    ctx.arc(t.x, t.y, dotSize, 0, Math.PI * 2);
                    ctx.fillStyle = "rgba(" + root._colorStr + "," + (t.life * 0.85 * root.effectOpacity) + ")";
                    ctx.fill();
                }
                return;
            }

            var pts = trail;
            var numPts = pts.length;
            var lastIdx = numPts - 1;
            var baseWidth = 8 * (root.scale / 1.5) * root.trailWidth;

            // 计算左右边缘
            var leftEdge = [];
            var rightEdge = [];

            for (var i = 0; i < numPts; i++) {
                var progress = i / lastIdx;
                var lancetW;
                if (progress < 0.65) {
                    lancetW = Math.pow(progress / 0.65, 0.6);
                } else {
                    lancetW = Math.pow((1 - progress) / 0.35, 1.8);
                }
                var hw = Math.max(0.25, baseWidth * lancetW) / 2;

                var dx, dy;
                if (i === 0) {
                    dx = pts[1].x - pts[0].x;
                    dy = pts[1].y - pts[0].y;
                } else if (i === lastIdx) {
                    dx = pts[i].x - pts[i - 1].x;
                    dy = pts[i].y - pts[i - 1].y;
                } else {
                    dx = pts[i + 1].x - pts[i - 1].x;
                    dy = pts[i + 1].y - pts[i - 1].y;
                }
                var len = Math.hypot(dx, dy);
                if (len < 0.001) {
                    dx = 0;
                    dy = 1;
                    len = 1;
                }
                var nx = -dy / len;
                var ny = dx / len;

                leftEdge.push({ x: pts[i].x + nx * hw, y: pts[i].y + ny * hw });
                rightEdge.push({ x: pts[i].x - nx * hw, y: pts[i].y - ny * hw });
            }

            ctx.shadowColor = "rgba(" + root._colorStr + ", 0.6)";
            ctx.shadowBlur = 3;

            ctx.beginPath();
            ctx.moveTo(leftEdge[0].x, leftEdge[0].y);
            for (i = 1; i < numPts; i++) {
                ctx.lineTo(leftEdge[i].x, leftEdge[i].y);
            }
            for (i = numPts - 1; i >= 0; i--) {
                ctx.lineTo(rightEdge[i].x, rightEdge[i].y);
            }
            ctx.closePath();

            var grad = ctx.createLinearGradient(pts[0].x, pts[0].y, pts[lastIdx].x, pts[lastIdx].y);
            grad.addColorStop(0, "rgba(" + root._colorStr + ", 0)");
            grad.addColorStop(1, "rgba(" + root._colorStr + ", 1)");
            ctx.fillStyle = grad;
            ctx.fill();

            ctx.shadowColor = "transparent";
            ctx.shadowBlur = 0;
        }
    }

    // ---- 动画循环 ----
    Timer {
        id: animTimer
        interval: 16
        repeat: true
        running: false

        property real lastTime: 0

        onTriggered: {
            var now = (new Date()).getTime();
            var dt = lastTime > 0 ? (now - lastTime) / 16.667 : 1;
            lastTime = now;
            if (dt > 6) dt = 6; // cap at ~100ms

            _update(dt);
            canvas.requestPaint();
        }

        function _update(fs) {
            var waves = canvas.waves;
            var sparks = canvas.sparks;
            var trail = canvas.trail;

            // -- 更新涟漪 --
            var clickFs = fs * root.clickSpeed;
            for (var wi = waves.length - 1; wi >= 0; wi--) {
                var w = waves[wi];
                w.filledLife += 1 * clickFs;
                w.ringLife += 1 * clickFs;
                w.ring.ang -= w.ring.rs * clickFs;
                if (w.ringLife >= w.ringMaxLife && w.filledLife >= w.filledMaxLife) {
                    waves.splice(wi, 1);
                }
            }

            // -- 更新粒子 --
            var clickSparkFs = fs * root.clickSpeed;
            var trailSparkFs = fs * root.trailSpeed;
            for (var si = sparks.length - 1; si >= 0; si--) {
                var s = sparks[si];
                var spd = s.fromClick ? clickSparkFs : trailSparkFs;
                s.x += s.vx * spd;
                s.y += s.vy * spd;
                s.vx *= Math.pow(s.f, spd);
                s.vy *= Math.pow(s.f, spd);
                s.rot += s.rs * spd;
                s.a -= 0.032 * spd;
                if (s.a <= 0) {
                    sparks.splice(si, 1);
                }
            }

            // -- 更新拖尾 --
            var trailFs = fs * root.trailSpeed;
            var baseDecay = 0.085 * trailFs;
            var maxStep = 0.42;
            for (var ti = trail.length - 1; ti >= 0; ti--) {
                var t = trail[ti];
                var span = Math.max(1, trail.length - 1);
                var along = trail.length > 1 ? ti / span : 1;
                var towardBias = 1.25 - 0.55 * along;
                var step = Math.min(baseDecay * towardBias, maxStep);
                t.life -= step;
                if (t.life <= 0) {
                    trail.splice(ti, 1);
                }
            }

            // 停止空循环
            if (waves.length === 0 && sparks.length === 0 && trail.length === 0) {
                animTimer.stop();
                // 清空 canvas
                var ctx = canvas.getContext("2d");
                ctx.clearRect(0, 0, canvas.width, canvas.height);
            }
        }
    }

    // ---- 公共接口 ----

    function spawn(x, y) {
        // 涟漪
        var rcList = [0, 0.03, 0.06];
        var rrList = [0, 1, 1.5, 2];

        var wave = {
            x: x,
            y: y,
            r: 0,
            filledLife: 0,
            filledMaxLife: 16,
            ringLife: 0,
            ringMaxLife: 23,
            ring: {
                ang: Math.random() * Math.PI * 2,
                rs: rcList[Math.floor(Math.random() * rcList.length)],
                len: 1.1 * Math.PI,
                segs: [
                    {
                        off: 0,
                        len: 1.1 * Math.PI,
                        rRoundRate: rrList[Math.floor(Math.random() * rrList.length)],
                    },
                    {
                        off: (Math.random() * 3 - 1.5) * Math.PI,
                        len: 1.1 * Math.PI,
                        rRoundRate: rrList[Math.floor(Math.random() * rrList.length)],
                    },
                ],
            },
        };
        canvas.waves.push(wave);

        // 迸射粒子
        var speedAdjust = root.scale / 1.5;
        for (var i = 0; i < 4; i++) {
            var a = Math.random() * Math.PI * 2;
            var sp = (4.8 + Math.random() * 2) * speedAdjust;
            canvas.sparks.push({
                x: x,
                y: y,
                vx: Math.cos(a) * sp,
                vy: Math.sin(a) * sp,
                rot: Math.random() * Math.PI * 2,
                rs: (Math.random() - 0.5) * 0.28,
                s: (4 + Math.random() * 3) * root.scale * root.sparkSize,
                a: 1,
                f: 0.9,
                fromClick: true,
            });
        }

        if (!animTimer.running) {
            animTimer.lastTime = 0;
            animTimer.start();
        }
    }

    function feedTrail(x, y) {
        // 按下时由 Interactions 调用，添加拖尾点
        canvas.trail.push({ x: x, y: y, life: 1 });
        if (canvas.trail.length > 16) {
            canvas.trail.shift();
        }

        // 沿途迸发小粒子
        if (Math.random() < 0.3) {
            var a = Math.random() * Math.PI * 2;
            var speedAdjust = root.scale / 1.5;
            canvas.sparks.push({
                x: x + Math.cos(a) * 10 * root.scale,
                y: y + Math.sin(a) * 10 * root.scale,
                vx: Math.cos(a) * 1.3 * speedAdjust,
                vy: Math.sin(a) * 1.3 * speedAdjust,
                rot: Math.random() * Math.PI * 2,
                rs: 0.16,
                s: 9 * root.scale * root.sparkSize,
                a: 0.7,
                f: 0.95,
                fromClick: false,
            });
        }

        if (!animTimer.running) {
            animTimer.lastTime = 0;
            animTimer.start();
        }
    }
}
