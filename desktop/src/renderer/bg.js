import * as THREE from '../../node_modules/three/build/three.module.js';
window.THREE = THREE;

(function () {
  function initHero3D() {
    const container = document.getElementById('background-canvas');
    if (!container) return;
    container.innerHTML = '';

    const scene = new THREE.Scene();
    scene.fog = new THREE.FogExp2(0x1a1e21, 0.002);

    const camera = new THREE.PerspectiveCamera(56, window.innerWidth / window.innerHeight, 0.1, 1000);
    camera.position.set(0, 15, 34);
    camera.lookAt(0, 0, 0);

    const renderer = new THREE.WebGLRenderer({
      alpha: true,
      antialias: false,
      powerPreference: 'high-performance',
      stencil: false,
      depth: false
    });
    // Clamp DPR to 1.5 on retina to avoid 2x pixel fill; still crisp, far cheaper
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.5));
    renderer.setSize(window.innerWidth, window.innerHeight);
    // Avoid unnecessary clear calls
    renderer.setClearColor(0x000000, 0);
    container.appendChild(renderer.domElement);

    // Adaptive geometry: lower subdivisions on smaller viewports / low-power
    const isSmall = window.innerWidth < 1100;
    const segs = isSmall ? 32 : 42;
    const planeGeo = new THREE.PlaneGeometry(120, 120, segs, segs);
    planeGeo.rotateX(-Math.PI / 2.45);

    const posAttr = planeGeo.attributes.position;
    // Cache positions in typed arrays for direct manipulation (avoid getX/setY per vertex)
    const posArray = posAttr.array; // Float32Array, stride 3: x,y,z,x,y,z...
    const initialY = new Float32Array(posAttr.count);
    for (let i = 0; i < posAttr.count; i++) initialY[i] = posArray[i * 3 + 1];

    const wireMat = new THREE.MeshBasicMaterial({
      color: 0xe2b97f,
      wireframe: true,
      transparent: true,
      opacity: 0.11,
      depthWrite: false
    });
    const planeMesh = new THREE.Mesh(planeGeo, wireMat);
    planeMesh.position.y = -9.5;
    planeMesh.frustumCulled = false;
    scene.add(planeMesh);

    // Particle swarm — disabled by default for perf, can be re-enabled sparingly
    const particleCount = 0;
    let particleSystem = null;
    if (particleCount > 0) {
      const particlesGeo = new THREE.BufferGeometry();
      const positions = new Float32Array(particleCount * 3);
      for (let i = 0; i < particleCount * 3; i += 3) {
        positions[i] = (Math.random() - 0.5) * 90;
        positions[i + 1] = (Math.random() - 0.5) * 50;
        positions[i + 2] = (Math.random() - 0.5) * 90;
      }
      particlesGeo.setAttribute('position', new THREE.BufferAttribute(positions, 3));
      const pMat = new THREE.PointsMaterial({
        color: 0xa7c080,
        size: 1.4,
        transparent: true,
        opacity: 0.18,
        depthWrite: false
      });
      particleSystem = new THREE.Points(particlesGeo, pMat);
      particleSystem.frustumCulled = false;
      scene.add(particleSystem);
    }

    // Visibility & idle handling — pause completely when hidden
    let isVisible = !document.hidden;
    let rafId = 0;
    let lastFrame = performance.now();
    const targetFPS = 30;
    const frameInterval = 1000 / targetFPS;
    let acc = 0;

    document.addEventListener('visibilitychange', () => {
      isVisible = !document.hidden;
      if (isVisible) {
        lastFrame = performance.now();
        acc = 0;
        if (!rafId) rafId = requestAnimationFrame(animate);
      }
    });

    // Mouse parallax — throttled via direct vars, no allocations
    let mouseX = 0, mouseY = 0;
    let targetMouseX = 0, targetMouseY = 0;
    let mouseRaf = 0;
    window.addEventListener('mousemove', (e) => {
      targetMouseX = (e.clientX / window.innerWidth - 0.5) * 2;
      targetMouseY = (e.clientY / window.innerHeight - 0.5) * 2;
      if (!mouseRaf) {
        mouseRaf = requestAnimationFrame(() => {
          mouseX = targetMouseX;
          mouseY = targetMouseY;
          mouseRaf = 0;
        });
      }
    }, { passive: true });

    let resizeTimer = 0;
    window.addEventListener('resize', () => {
      clearTimeout(resizeTimer);
      resizeTimer = setTimeout(() => {
        camera.aspect = window.innerWidth / window.innerHeight;
        camera.updateProjectionMatrix();
        renderer.setSize(window.innerWidth, window.innerHeight);
        renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.5));
      }, 150);
    }, { passive: true });

    // Respect prefers-reduced-motion
    const prefersReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const waveEnabled = !prefersReduced;

    const bgEl = document.getElementById('background-canvas');
    const isModeCode = () => document.getElementById('app-container')?.dataset.mode === 'code';
    const io = ('IntersectionObserver' in window && bgEl)
      ? new IntersectionObserver((entries) => {
          const e = entries[0];
          if (!e) return;
          if (!e.isIntersecting) { isVisible = false; } else { isVisible = !document.hidden && !isModeCode(); if (isVisible && !rafId) { lastFrame = performance.now(); acc = 0; rafId = requestAnimationFrame(animate); } }
        }, { threshold: 0 })
      : null;
    if (io && bgEl) io.observe(bgEl);
    const mo = new MutationObserver(() => {
      const nowCode = isModeCode();
      if (nowCode) { isVisible = false; if (bgEl) bgEl.style.visibility = 'hidden'; }
      else { if (bgEl) bgEl.style.visibility = ''; isVisible = !document.hidden; if (isVisible && !rafId) { lastFrame = performance.now(); acc = 0; rafId = requestAnimationFrame(animate); } }
    });
    try { const ac = document.getElementById('app-container'); if (ac) mo.observe(ac, { attributes: true, attributeFilter: ['data-mode'] }); } catch (_) {}

    function animate(now) {
      rafId = requestAnimationFrame(animate);
      if (!isVisible || isModeCode()) return;

      const delta = now - lastFrame;
      lastFrame = now;
      acc += delta;
      // Throttle to target FPS — skip frames
      if (acc < frameInterval) return;
      // Consume one frame interval, keep remainder for smoothness
      acc %= frameInterval;

      const t = now * 0.001;

      if (waveEnabled) {
        // Direct array walk — ~3x faster than getX/setY per vertex
        // posArray stride 3: [x, y, z]
        const count = posAttr.count;
        for (let i = 0; i < count; i++) {
          const idx = i * 3;
          const u = posArray[idx];
          const v = posArray[idx + 2];
          // Cheap wave: sin(u)*cos(v) with time — precompute factors
          const z = Math.sin(u * 0.065 + t * 0.7) * Math.cos(v * 0.065 + t * 0.7) * 2.6;
          posArray[idx + 1] = initialY[i] + z;
        }
        posAttr.needsUpdate = true;
      }

      if (particleSystem) {
        particleSystem.rotation.y = t * 0.012;
        particleSystem.rotation.x = t * 0.006;
      }

      // Damped parallax — no per-frame allocation
      camera.position.x += (mouseX * 3.2 - camera.position.x) * 0.02;
      camera.position.y += (-mouseY * 2.2 + 15 - camera.position.y) * 0.02;
      camera.lookAt(0, 0, 0);

      renderer.render(scene, camera);
    }

    rafId = requestAnimationFrame(animate);

    // Cleanup on HMR/navigation
    window.addEventListener('beforeunload', () => {
      cancelAnimationFrame(rafId);
      renderer.dispose();
      planeGeo.dispose();
      wireMat.dispose();
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initHero3D);
  } else {
    initHero3D();
  }
})();
