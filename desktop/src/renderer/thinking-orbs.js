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
            // Use warm sand / cream tones for Newton aesthetics
            const r = Math.round((isDark ? 224 : 31) * whiteRatio + (isDark ? 167 : 200) * (1 - whiteRatio));
            const g = Math.round((isDark ? 189 : 37) * whiteRatio + (isDark ? 192 : 180) * (1 - whiteRatio));
            const b = Math.round((isDark ? 128 : 40) * whiteRatio + (isDark ? 128 : 150) * (1 - whiteRatio));
            ctx.fillStyle = `rgba(${r},${g},${b},${alpha})`;
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

    // Shared RAF + visibility-aware throttling for all orbs (one RAF total, 24 fps, DPR clamped to 1.5)
    const OrbScheduler = (() => {
        const orbs = new Set();
        let raf = 0, last = 0;
        const interval = 1000 / 24;
        const prefersReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
        let visible = !document.hidden;
        document.addEventListener('visibilitychange', () => {
            visible = !document.hidden;
            if (visible) { last = performance.now(); if (orbs.size && !raf) raf = requestAnimationFrame(tick); }
        });
        function tick(now) {
            raf = requestAnimationFrame(tick);
            if (!visible || prefersReduced) return;
            if (now - last < interval) return;
            last = now;
            const t = (now - (orbs.values().next().value?.startTime || now)) / 1000;
            // Use per-orb time base for correctness, but batch DOM work
            for (const o of orbs) {
                if (!o._isVisibleInViewport) continue;
                o._renderFrame((performance.now() - o.startTime) / 1000);
            }
        }
        return {
            add(o) { orbs.add(o); if (!raf && visible && !prefersReduced) { last = performance.now(); raf = requestAnimationFrame(tick); } if (prefersReduced) o._renderFrame(0); },
            remove(o) { orbs.delete(o); if (!orbs.size && raf) { cancelAnimationFrame(raf); raf = 0; } },
        };
    })();

    class ThinkingOrbElement {
        constructor(canvas, options = {}) {
            this.canvas = canvas;
            this.ctx = canvas.getContext('2d');
            this.state = options.state || 'orbits';
            this.size = options.size || 42;
            this.isDark = options.isDark ?? true;
            this.startTime = performance.now();
            this._isVisibleInViewport = true;

            const dpr = Math.min(window.devicePixelRatio || 1, 1.5);
            this.canvas.width = this.size * dpr;
            this.canvas.height = this.size * dpr;
            this.canvas.style.width = `${this.size}px`;
            this.canvas.style.height = `${this.size}px`;
            this._dpr = dpr;

            // Pause when off-screen
            if ('IntersectionObserver' in window) {
                this._io = new IntersectionObserver((entries) => {
                    this._isVisibleInViewport = entries[0]?.isIntersecting ?? true;
                }, { threshold: 0 });
                this._io.observe(this.canvas);
            }

            OrbScheduler.add(this);
        }

        stop() { OrbScheduler.remove(this); if (this._io) { try { this._io.disconnect(); } catch(_) {} this._io = null; } }

        destroy() {
            this.stop();
            if (this.canvas && this.canvas.parentNode) this.canvas.remove();
        }

        setState(newState) { this.state = newState; }

        _renderFrame(time) {
            const dpr = this._dpr;
            this.ctx.save();
            this.ctx.scale(dpr, dpr);
            this.ctx.clearRect(0, 0, this.size, this.size);
            const stateName = this.state === 'searching' ? 'globe' : (this.state === 'working' ? 'orbits' : (renderers[this.state] ? this.state : 'orbits'));
            const renderFn = renderers[stateName] || renderers.orbits;
            renderFn(this.ctx, this.size, time, this.isDark);
            this.ctx.restore();
        }
        // Back-compat: some callers may call render/start
        render() { this._renderFrame((performance.now() - this.startTime)/1000); }
        start() { OrbScheduler.add(this); }
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
