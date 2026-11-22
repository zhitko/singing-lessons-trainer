import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 6.8
import "../utils"

Column {
    id: root
    width: 300
    height: 150

    property var waveData: []
    property var cuePoints: []
    property bool independentScale: false
    property var datasetColors: []
    // Per-dataset multipliers of lineWidth and stroke opacities (default 1.0),
    // so curves can differ by shape as well as by color.
    property var datasetWidthScales: []
    property var datasetOpacities: []
    property var cueNLabels: []
    property double lineWidth: 2.5
    property bool showCueLabels: true

    property bool showLegend: false
    property var datasetLabels: []
    property var thresholdValue: null
    property color thresholdColor: Theme.error(Material.theme)

    // Chart ink is the Light theme's, in both themes. The plot itself is a
    // light panel so the Dark theme chart stays readable and the curves
    // (and the green nucleus bands) match the Light theme exactly. In Dark
    // the panel is a slightly softer light tone to reduce glare.
    readonly property bool darkTheme: Theme.isDark(Material.theme)
    readonly property color chartPlotBackground: darkTheme ? "#E9ECF4" : "#F9F9FF"
    // Neutral gray so nucleus bands read the same for every color vision
    // type and do not compete with the curve hues.
    readonly property color chartNucleus: "#7A8294"
    readonly property color chartInk: "#74777F"
    readonly property real plotRadius: 12
    property bool showYAxis: true
    // Shade the area between the first two datasets (e.g. reference vs. user)
    // so deviations between the curves stand out.
    property bool fillBetween: false
    property color fillBetweenColor: Theme.error(Material.theme)
    property real fillBetweenOpacity: 0.22

    onDarkThemeChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        width: parent.width
        height: root.showLegend ? parent.height - 30 : parent.height

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.clearRect(0, 0, canvas.width, canvas.height);

            if (!root.waveData || root.waveData.length === 0) {
                return;
            }

            // Normalize data to array of arrays.
            // QVariantList from C++ arrives as an object with numeric keys and a
            // 'length' property, but Array.isArray() returns false for it, so we
            // convert explicitly. Each individual dataset may also be a QVariantList.
            function toJSArray(val) {
                if (!val)
                    return [];
                if (Array.isArray(val))
                    return val;
                if (typeof val === "object" && val.length !== undefined) {
                    if (val[0].x !== undefined)
                       return [val];
                    return Array.from(val);
                }
                return [val];
            }

            var datasets = toJSArray(root.waveData);

            if (datasets.length === 0 || datasets[0].length < 2) {
                return;
            }

            // Find global min/max for scaling (and per-dataset Y ranges for independent scaling)
            var minX = datasets[0][0].x;
            var maxX = datasets[0][datasets[0].length - 1].x;
            var minY = datasets[0][0].y;
            var maxY = datasets[0][0].y;

            // Arrays to hold per-dataset Y ranges when independent scaling is enabled
            var perMinY = [];
            var perMaxY = [];

            for (var d = 0; d < datasets.length; d++) {
                var data = datasets[d];
                if (data.length > 0) {
                    if (data[0].x < minX)
                        minX = data[0].x;
                    if (data[data.length - 1].x > maxX)
                        maxX = data[data.length - 1].x;

                    var dMin = data[0].y;
                    var dMax = data[0].y;

                    for (var i = 0; i < data.length; i++) {
                        var y = data[i].y;
                        if (y < minY)
                            minY = y;
                        if (y > maxY)
                            maxY = y;
                        if (y < dMin)
                            dMin = y;
                        if (y > dMax)
                            dMax = y;
                    }

                    dMin = dMin - (dMax - dMin) * 0.01;
                    dMax = dMax + (dMax - dMin) * 0.01;

                    perMinY.push(dMin);
                    perMaxY.push(dMax);
                } else {
                    // Keep placeholder values for empty datasets
                    perMinY.push(0);
                    perMaxY.push(0);
                }
            }

            var realMinY = minY;
            var realMaxY = maxY;
            
            minY = minY - (maxY - minY) * 0.01;
            maxY = maxY + (maxY - minY) * 0.01;

            // Logger.debug("MinX: " + minX);
            // Logger.debug("MaxX: " + maxX);
            // Logger.debug("MinY: " + minY);
            // Logger.debug("MaxY: " + maxY);

            // Add some padding
            var rangeY = maxY - minY;
            if (rangeY === 0) {
                rangeY = 1.0;
            }

            var rangeX = maxX - minX;
            if (rangeX === 0) {
                rangeX = 1.0;
            }

            // Reserve space for Y axis and paddings
            var leftMargin = root.showYAxis ? 40 : 0;
            var topPadding = 10;
            var bottomPadding = (root.cueNLabels && root.cueNLabels.length > 0) ? 40 : 20;
            var graphWidth = canvas.width - leftMargin;
            var graphHeight = canvas.height - topPadding - bottomPadding;

            function scaleX(x) {
                let scaledX = (x - minX) / rangeX * graphWidth;
                if (scaledX < 0)
                    return leftMargin;
                if (scaledX > graphWidth)
                    return leftMargin + graphWidth;
                return scaledX + leftMargin;
            }

            // Light plot panel in both themes. Cue bands and curves are drawn
            // on top of this, so their colors no longer depend on the page.
            var plotRadius = Math.min(root.plotRadius, graphHeight / 4, graphWidth / 4);
            function plotPath() {
                ctx.beginPath();
                ctx.roundedRect(leftMargin, topPadding, graphWidth, graphHeight, plotRadius, plotRadius);
            }
            plotPath();
            ctx.fillStyle = root.chartPlotBackground;
            ctx.fill();

            // Faint horizontal guides at quarter heights.
            ctx.save();
            plotPath();
            ctx.clip();
            ctx.strokeStyle = Qt.alpha(root.chartInk, 0.14);
            ctx.lineWidth = 1;
            ctx.beginPath();
            for (var gi = 1; gi < 4; gi++) {
                var gy = Math.round(topPadding + graphHeight * gi / 4) + 0.5;
                ctx.moveTo(leftMargin, gy);
                ctx.lineTo(leftMargin + graphWidth, gy);
            }
            ctx.stroke();
            ctx.restore();

            function scaleY(y, datasetIndex) {
                // If independentScale is enabled and a datasetIndex is provided,
                // scale using that dataset's min/max Y range; otherwise use global range.
                var min = minY;
                var range = rangeY;
                if (root.independentScale && typeof datasetIndex === "number" && perMinY.length > datasetIndex) {
                    min = perMinY[datasetIndex];
                    var max = perMaxY[datasetIndex];
                    range = max - min;
                    if (range === 0)
                        range = 1.0;
                }
                // Y is inverted in canvas, so we subtract from height. Curves
                // keep half of the widest line from the panel edge so thick
                // lines are not cut off at the extremes.
                var maxScale = 1.0;
                for (var si = 0; si < (root.datasetWidthScales ? root.datasetWidthScales.length : 0); si++)
                    maxScale = Math.max(maxScale, root.datasetWidthScales[si]);
                var inset = Math.min(root.lineWidth * maxScale / 2 + 1, graphHeight / 4);
                var h = graphHeight - 2 * inset;
                let scaledY = (y - min) / range * h;
                if (scaledY < 0)
                    scaledY = 0;
                if (scaledY > h)
                    scaledY = h;
                return topPadding + inset + h - scaledY;
            }

            if (root.showYAxis) {
                // Draw Y axis
                ctx.strokeStyle = root.chartInk;
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.moveTo(leftMargin, topPadding);
                ctx.lineTo(leftMargin, canvas.height - bottomPadding);
                ctx.stroke();

                // Draw Y axis marks
                ctx.beginPath();
                ctx.moveTo(leftMargin, topPadding);
                ctx.lineTo(leftMargin - 5, topPadding);
                ctx.moveTo(leftMargin, canvas.height - bottomPadding);
                ctx.lineTo(leftMargin - 5, canvas.height - bottomPadding);
                ctx.stroke();

                // Draw Y axis labels
                ctx.fillStyle = Theme.onSurfaceVariant(Material.theme);
                ctx.font = "10px sans-serif";
                ctx.textAlign = "right";
                ctx.textBaseline = "middle";
                ctx.fillText(realMaxY.toFixed(2), leftMargin - 8, topPadding);
                ctx.fillText(realMinY.toFixed(2), leftMargin - 8, canvas.height - bottomPadding);
            }

            // Draw cue points
            ctx.lineWidth = 1;
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";

            // Draw 0 mark and line
            if (root.showYAxis && minY <= 0 && maxY >= 0) {
                var y0 = scaleY(0);

                // Draw horizontal line
                ctx.save();
                ctx.beginPath();
                ctx.rect(leftMargin, topPadding, graphWidth, graphHeight);
                ctx.clip();

                ctx.beginPath();
                ctx.moveTo(leftMargin, y0);
                ctx.lineTo(leftMargin + graphWidth, y0);
                ctx.strokeStyle = Theme.outlineVariant(Material.theme);
                ctx.lineWidth = 1;
                ctx.stroke();
                ctx.restore();

                // Draw axis mark
                ctx.beginPath();
                ctx.moveTo(leftMargin, y0);
                ctx.lineTo(leftMargin - 5, y0);
                ctx.strokeStyle = Theme.outline(Material.theme);
                ctx.lineWidth = 1;
                ctx.stroke();

                // Draw label
                ctx.fillStyle = Theme.onSurfaceVariant(Material.theme);
                ctx.textAlign = "right";
                // Draw "0" label only if it's not overlapping with min/max labels
                if (Math.abs(y0 - topPadding) > 12 && Math.abs(y0 - (canvas.height - bottomPadding)) > 12)
                    ctx.fillText("0", leftMargin - 8, y0);
            }

            var nIdx = 0;
            for (var i = 0; i < root.cuePoints.length; i++) {
                var cue = root.cuePoints[i];
                var x = scaleX(cue.position);
                var width = scaleX(cue.position + cue.length) - x;

                // Only nucleus bands are tinted. Pauses and transitions show
                // the plot panel, so they need no fill or border of their own.
                if (cue.label.toUpperCase().startsWith("N")) {
                    ctx.save();
                    plotPath();
                    ctx.clip();
                    ctx.fillStyle = Qt.alpha(root.chartNucleus, 0.16);
                    ctx.fillRect(x, topPadding, width, graphHeight);
                    ctx.strokeStyle = Qt.alpha(root.chartNucleus, 0.45);
                    ctx.lineWidth = 1;
                    ctx.beginPath();
                    ctx.moveTo(Math.round(x) + 0.5, topPadding);
                    ctx.lineTo(Math.round(x) + 0.5, topPadding + graphHeight);
                    ctx.moveTo(Math.round(x + width) - 0.5, topPadding);
                    ctx.lineTo(Math.round(x + width) - 0.5, topPadding + graphHeight);
                    ctx.stroke();
                    ctx.restore();
                }

                // Draw label
                if (root.showCueLabels || root.cueNLabels.length > 0) {
                    ctx.fillStyle = Theme.onSurface(Material.theme);
                    let fontSize = AppScale.fs(10);
                    ctx.font = fontSize + "px sans-serif";
                    var labelY = canvas.height - bottomPadding + 15;
                    if (root.showCueLabels)
                        ctx.fillText(cue.label, x + width / 2, labelY);

                    if (cue.label.toUpperCase().startsWith("N")) {
                        if (root.cueNLabels && nIdx < root.cueNLabels.length) {
                            var nLabel = root.cueNLabels[nIdx];
                            if (nLabel) {
                                ctx.save();
                                let nFontSize = AppScale.fs(21);
                                ctx.font = "bold " + nFontSize + "px sans-serif";
                                var textW = ctx.measureText(nLabel).width;
                                var maxW = Math.max(width - 4, 1);
                                if (textW > maxW) {
                                    nFontSize = Math.max(AppScale.fs(9), Math.floor(nFontSize * maxW / textW));
                                    ctx.font = "bold " + nFontSize + "px sans-serif";
                                    textW = ctx.measureText(nLabel).width;
                                }
                                var cx = Math.min(Math.max(x + width / 2, textW / 2 + 2), canvas.width - textW / 2 - 2);
                                ctx.fillStyle = Theme.primary(Material.theme);
                                ctx.fillText(nLabel, cx, labelY + 16);
                                ctx.restore();
                            }
                        }
                        nIdx++;
                    }
                }
            }

            // Draw datasets
            // Build a color palette for datasets. Priority:
            // 1) dataset.color property, 2) root.datasetColors, 3) theme graph palette, 4) generated HSL colors
            var graphicsPalette = Theme.chartPalette(Material.theme);
            var colors = [];
            for (var i = 0; i < datasets.length; i++) {
                var color = null;
                if (datasets[i] && datasets[i].color) {
                    color = datasets[i].color;
                } else if (root.datasetColors && root.datasetColors.length > 0) {
                    color = root.datasetColors[i % root.datasetColors.length];
                } else {
                    color = graphicsPalette[i % graphicsPalette.length];
                }
                colors.push(color);
            }

            console.log("Drawing " + datasets.length + " datasets. First dataset points: " + (datasets.length > 0 ? datasets[0].length : 0));
            console.log("Drawing datasets with colors:", colors);

            ctx.save();
            plotPath();
            ctx.clip();

            // Area between the first two curves: trace dataset 0 forward and
            // dataset 1 backward. Crossings form separate loops, all filled.
            if (root.fillBetween && datasets.length >= 2
                    && datasets[0].length >= 2 && datasets[1].length >= 2) {
                var fa = datasets[0];
                var fb = datasets[1];
                ctx.beginPath();
                ctx.moveTo(scaleX(fa[0].x), scaleY(fa[0].y, 0));
                for (var fi = 1; fi < fa.length; fi++)
                    ctx.lineTo(scaleX(fa[fi].x), scaleY(fa[fi].y, 0));
                for (var fj = fb.length - 1; fj >= 0; fj--)
                    ctx.lineTo(scaleX(fb[fj].x), scaleY(fb[fj].y, 1));
                ctx.closePath();
                ctx.fillStyle = Qt.alpha(root.fillBetweenColor, root.fillBetweenOpacity);
                ctx.fill();
            }

            for (var d = 0; d < datasets.length; d++) {
                var data = datasets[d];
                if (data.length < 2)
                    continue;

                ctx.beginPath();
                ctx.moveTo(scaleX(data[0].x), scaleY(data[0].y, d));

                for (var i = 1; i < data.length; i++) {
                    // Simple optimization: skip points if they map to same pixel?
                    // For now, just draw all.
                    ctx.lineTo(scaleX(data[i].x), scaleY(data[i].y, d));
                }

                var widthScale = (root.datasetWidthScales && d < root.datasetWidthScales.length) ? root.datasetWidthScales[d] : 1.0;
                var opacity = (root.datasetOpacities && d < root.datasetOpacities.length) ? root.datasetOpacities[d] : 1.0;
                ctx.strokeStyle = Qt.alpha(colors[d % colors.length], opacity);
                ctx.lineWidth = root.lineWidth * widthScale;
                ctx.lineJoin = "round";
                ctx.lineCap = "round";
                ctx.stroke();
            }

            // Draw threshold line OUTSIDE clipping region
            if (root.thresholdValue !== null && typeof root.thresholdValue === "number") {
                var thresholdY = scaleY(root.thresholdValue);

                console.log("Drawing threshold line at Y:", thresholdY, "Canvas bounds: top=", topPadding, "bottom=", graphHeight + topPadding, "leftMargin=", leftMargin, "graphWidth=", graphWidth);
                
                // Draw threshold line
                ctx.strokeStyle = root.thresholdColor;
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.moveTo(leftMargin, thresholdY);
                ctx.lineTo(leftMargin + graphWidth, thresholdY);
                ctx.stroke();
                console.log("Threshold line drawn");
            }
            ctx.restore();

            // Thin panel outline, drawn last so bands do not cover it.
            ctx.beginPath();
            ctx.roundedRect(leftMargin + 0.5, topPadding + 0.5, graphWidth - 1, graphHeight - 1, plotRadius, plotRadius);
            ctx.strokeStyle = Qt.alpha(root.chartInk, root.darkTheme ? 0.5 : 0.25);
            ctx.lineWidth = 1;
            ctx.stroke();
        }
    }

    onWaveDataChanged: {
        canvas.requestPaint();
    }

    onCuePointsChanged: {
        canvas.requestPaint();
    }

    onIndependentScaleChanged: {
        canvas.requestPaint();
    }

    onDatasetColorsChanged: {
        canvas.requestPaint();
    }

    onDatasetWidthScalesChanged: canvas.requestPaint()
    onDatasetOpacitiesChanged: canvas.requestPaint()
    onLineWidthChanged: canvas.requestPaint()
    onFillBetweenChanged: canvas.requestPaint()
    onFillBetweenColorChanged: canvas.requestPaint()
    onFillBetweenOpacityChanged: canvas.requestPaint()

    onThresholdValueChanged: {
        canvas.requestPaint();
    }

    onThresholdColorChanged: {
        canvas.requestPaint();
    }

    onShowCueLabelsChanged: {
        canvas.requestPaint();
    }

    onCueNLabelsChanged: {
        canvas.requestPaint();
    }

    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()

    RowLayout {
        id: legendRow
        anchors.horizontalCenter: parent.horizontalCenter
        height: 30
        visible: root.showLegend && root.datasetLabels.length > 0
        spacing: 20

        Repeater {
            model: root.datasetLabels.length
            Row {
                spacing: 5
                Rectangle {
                    width: 12
                    height: 12
                    radius: 2
                    color: {
                        if (root.datasetColors && root.datasetColors.length > index)
                            return root.datasetColors[index];
                        return Theme.chartPalette(Material.theme)[index % Theme.chartPalette(Material.theme).length];
                    }
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: root.datasetLabels[index]
                    color: Theme.onSurface(Material.theme)
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: AppScale.fs(12)
                }
            }
        }
    }
}
