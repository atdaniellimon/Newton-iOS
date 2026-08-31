/*
    thinking-orbs - Vanilla JS Implementation of Jakub Antalik's Dotted Thought-Orb Renderers
    Renders official 3D Canvas thought-orbs (globe, orbits, rubik, wave, ribbon, morph)
*/

(function() {
    function pseudoRandom(seed, offset) {
        const s = Math.sin(seed * 12.9898 + offset * 78.233) * 43758.5453;
        return s - Math.floor(s);
    }

    function project3D(rotX, rotY, cx, cy, radius) {
        const sinY = Math.sin(rotY), cosY = Math.cos(rotY);
        const sinX = Math.sin(rotX), cosX = Math.cos(rotX);
        return (x, y, z) => {
            const rx = x * cosX + z * sinX;
            const rz = -x * sinX + z * cosX;
            const ry = y * cosY - rz * sinY;
            const rz2 = y * sinY + rz * cosY;
            return [cx + rx * radius, cy - ry * radius, rz2];
        };
    }

    function drawDepthDots(ctx, dots, isDark) {
        dots.sort((a, b) => a.z - b.z);
        for (const t of dots) {
            const alpha = t.a ?? 1;
            if (alpha < 0.02) continue;
            const whiteRatio = Math.min(1, Math.max(0, t.white));
            const val = Math.round((isDark ? 1 - whiteRatio : whiteRatio) * 255);
            ctx.fillStyle = `rgba(${val},${val},${val},${alpha})`;
            ctx.beginPath();
            ctx.arc(t.x, t.y, Math.max(0.3, t.r), 0, Math.PI * 2);
            ctx.fill();
        }
    }

    // Renderers
    const renderers = {
        // Globe / Searching
        globe: (ctx, size, time, isDark) => {
            const cx = size / 2, cy = size / 2, radius = (size / 2) * 0.82;
            const tilt = 0.4 + 0.06 * Math.sin(time * 0.35);
            const proj = project3D(time * 0.5, tilt, cx, cy, radius);
            const scanPos = time * 0.9;
            const scalePow = (size / 300) ** 0.6;
            const dots = [];
            const latRings = 17, lonDensity = 44;

            for (let p = 0; p <= latRings; p++) {
                const lat = -Math.PI / 2 + (p / latRings) * Math.PI;
                const cosLat = Math.cos(lat), sinLat = Math.sin(lat);
                const count = Math.max(1, Math.round(Math.abs(cosLat) * lonDensity));
                for (let v = 0; v < count; v++) {
                    const lon = (v / count) * 2 * Math.PI;
                    const [x, y, z] = proj(cosLat * Math.cos(lon), sinLat, cosLat * Math.sin(lon));
                    const depthFactor = (z + 1) / 2;
                    const diff = Math.atan2(Math.sin(lon + time * 0.5 - scanPos), Math.cos(lon + time * 0.5 - scanPos));
                    const scanHighlight = Math.exp(-(diff * diff) / 0.18) * Math.max(0, z);

                    dots.push({
                        x, y, z,
                        r: (0.6 + 1.7 * depthFactor + scanHighlight) * scalePow,
                        white: 0.62 - 0.54 * depthFactor,
                        a: 0.3 + 0.7 * Math.min(1, scanHighlight)
                    });
                }
            }
            drawDepthDots(ctx, dots, isDark);
        },

        // Orbits / Working
        orbits: (ctx, size, time, isDark) => {
            const cx = size / 2, cy = size / 2, radius = (size / 2) * 0.82;
            const proj = project3D(time * 0.12, 0.3, cx, cy, 1);
            const scalePow = (size / 300) ** 0.6;
            const dots = [];
            const orbitN = 12, ghostN = 40, particles = 3;

            for (let b = 0; b < orbitN; b++) {
                const r1 = pseudoRandom(b, 1.7), r2 = pseudoRandom(b, 5.2), r3 = pseudoRandom(b, 8.9);
                const orbitRadius = radius * (0.45 + 0.52 * r1);
                const angle = r1 * 2 * Math.PI;
                const phi = Math.acos(2 * r2 - 1);
                const k = Math.sin(phi) * Math.cos(angle);
                const v = Math.cos(phi);
                const r = Math.sin(phi) * Math.sin(angle);
                let p = -v, d = k;
                const len = Math.max(1e-6, Math.sqrt(p * p + d * d));
                p /= len; d /= len;
                const S = v * 0 - r * d, L = r * p - k * 0, A = k * d - v * p;
                const speed = (0.25 + 0.55 * r3) * (r3 > 0.5 ? 1 : -1);

                for (let c = 0; c < ghostN; c++) {
                    const rotAngle = (c / ghostN) * 2 * Math.PI;
                    const [tx, ty, tz] = proj(
                        (p * Math.cos(rotAngle) + S * Math.sin(rotAngle)) * orbitRadius,
                        (d * Math.cos(rotAngle) + L * Math.sin(rotAngle)) * orbitRadius,
                        (0 * Math.cos(rotAngle) + A * Math.sin(rotAngle)) * orbitRadius
                    );
                    const depthFactor = (tz / orbitRadius + 1) / 2;
                    dots.push({
                        x: tx, y: ty, z: tz,
                        r: 0.9 * scalePow,
                        white: 0.72,
                        a: 0.5 * (0.4 + 0.6 * depthFactor)
                    });
                }

                for (let c = 0; c < particles; c++) {
                    const rotAngle = time * speed + (c / particles) * 2 * Math.PI + r1 * 6;
                    const [tx, ty, tz] = proj(
                        (p * Math.cos(rotAngle) + S * Math.sin(rotAngle)) * orbitRadius,
                        (d * Math.cos(rotAngle) + L * Math.sin(rotAngle)) * orbitRadius,
                        (0 * Math.cos(rotAngle) + A * Math.sin(rotAngle)) * orbitRadius
                    );
                    const depthFactor = (tz / orbitRadius + 1) / 2;
                    dots.push({
                        x: tx, y: ty, z: tz,
                        r: (1.2 + 1.6 * depthFactor) * scalePow,
                        white: 0.3 - 0.22 * depthFactor
                    });
                }
            }
            drawDepthDots(ctx, dots, isDark);
        },

        // Wave / Listening
        wave: (ctx, size, time, isDark) => {
            const cx = size / 2, cy = size / 2, radius = (size / 2) * 0.874;
            const proj = project3D(time * 0.18, 0.38, cx, cy, 1);
            const scalePow = (size / 300) ** 0.6;
            const dots = [];
            const rings = 15, lonDensity = 40;

            for (let h = 0; h <= rings; h++) {
                const lat = -Math.PI / 2 + (h / rings) * Math.PI;
                const cosLat = Math.cos(lat), sinLat = Math.sin(lat);
                const waveVal = 0.62 * Math.sin(time * 2.1 - h * 0.52) + 0.38 * Math.sin(time * 1.27 + h * 0.83);
                const rCur = radius * (0.88 + 0.105 * waveVal);
                const count = Math.max(1, Math.round(Math.abs(cosLat) * lonDensity));

                for (let w = 0; w < count; w++) {
                    const lon = (w / count) * 2 * Math.PI;
                    const [x, y, z] = proj(cosLat * Math.cos(lon) * rCur, sinLat * rCur, cosLat * Math.sin(lon) * rCur);
                    const depthFactor = (z / radius + 1) / 2;
                    const peak = Math.max(0, waveVal);
                    dots.push({
                        x, y, z,
                        r: (0.6 + 1.7 * depthFactor) * (1 + 0.4 * peak) * scalePow,
                        white: 0.66 - 0.56 * depthFactor - 0.1 * peak
                    });
                }
            }
            drawDepthDots(ctx, dots, isDark);
        }
    };

    class ThinkingOrbElement {
        constructor(canvas, options = {}) {
            this.canvas = canvas;
            this.ctx = canvas.getContext('2d');
            this.state = options.state || 'searching';
            this.size = options.size || 48;
            this.isDark = options.isDark ?? true;
            this.animId = null;
            this.startTime = performance.now();

            this.canvas.width = this.size * window.devicePixelRatio;
            this.canvas.height = this.size * window.devicePixelRatio;
            this.canvas.style.width = `${this.size}px`;
            this.canvas.style.height = `${this.size}px`;

            this.render = this.render.bind(this);
            this.start();
        }

        start() {
            if (this.animId) cancelAnimationFrame(this.animId);
            this.render();
        }

        stop() {
            if (this.animId) cancelAnimationFrame(this.animId);
        }

        render() {
            const time = (performance.now() - this.startTime) / 1000;
            const dpr = window.devicePixelRatio || 1;
            this.ctx.save();
            this.ctx.scale(dpr, dpr);
            this.ctx.clearRect(0, 0, this.size, this.size);

            const stateName = this.state === 'searching' ? 'globe' : (this.state === 'working' ? 'orbits' : (renderers[this.state] ? this.state : 'globe'));
            const renderFn = renderers[stateName] || renderers.globe;
            renderFn(this.ctx, this.size, time, this.isDark);

            this.ctx.restore();
            this.animId = requestAnimationFrame(this.render);
        }
    }

    window.createThinkingOrb = function(container, options = {}) {
        if (!container) return null;
        container.innerHTML = '';
        const canvas = document.createElement('canvas');
        canvas.className = 'thinking-orb-canvas';
        container.appendChild(canvas);
        return new ThinkingOrbElement(canvas, options);
    };
})();
