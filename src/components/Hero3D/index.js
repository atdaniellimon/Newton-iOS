/*
    Newton AI - Three.js Monolithic Kinetic Background Engine
    Renders 3D undulating wave grid, floating particle fields, and golden ochre lighting
*/

(function() {
    function initHero3D() {
        const container = document.getElementById('hero-canvas');
        if (!container || typeof THREE === 'undefined') return;

        container.innerHTML = '';

        const scene = new THREE.Scene();
        scene.fog = new THREE.FogExp2(0xFFFFFF, 0.0018);

        const camera = new THREE.PerspectiveCamera(60, window.innerWidth / window.innerHeight, 0.1, 1000);
        camera.position.set(0, 15, 35);
        camera.lookAt(0, 0, 0);

        const renderer = new THREE.WebGLRenderer({ alpha: true, antialias: true });
        renderer.setSize(window.innerWidth, window.innerHeight);
        renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
        container.appendChild(renderer.domElement);

        // 1. Undulating Kinetic Wireframe Mesh Grid
        const planeGeo = new THREE.PlaneGeometry(120, 120, 48, 48);
        planeGeo.rotateX(-Math.PI / 2.5);

        const posAttr = planeGeo.attributes.position;
        const initialY = new Float32Array(posAttr.count);
        for (let i = 0; i < posAttr.count; i++) {
            initialY[i] = posAttr.getY(i);
        }

        const wireMat = new THREE.MeshBasicMaterial({
            color: 0x64748B,
            wireframe: true,
            transparent: true,
            opacity: 0.12
        });
        const planeMesh = new THREE.Mesh(planeGeo, wireMat);
        planeMesh.position.y = -10;
        scene.add(planeMesh);

        // 2. Floating Kinetic Particle Swarm
        const particleCount = 0;
        const particlesGeo = new THREE.BufferGeometry();
        const positions = new Float32Array(particleCount * 3);
        const scales = new Float32Array(particleCount);

        for (let i = 0; i < particleCount * 3; i += 3) {
            positions[i] = (Math.random() - 0.5) * 80;
            positions[i + 1] = (Math.random() - 0.5) * 60;
            positions[i + 2] = (Math.random() - 0.5) * 80;
            scales[i / 3] = Math.random() * 0.8 + 0.2;
        }

        particlesGeo.setAttribute('position', new THREE.BufferAttribute(positions, 3));

        const pMat = new THREE.PointsMaterial({
            color: 0x475569,
            size: 1.4,
            transparent: true,
            opacity: 0.25,
            blending: THREE.NormalBlending
        });

        const particleSystem = new THREE.Points(particlesGeo, pMat);
        scene.add(particleSystem);

        // Mouse Parallax Effect
        let mouseX = 0, mouseY = 0;
        window.addEventListener('mousemove', (e) => {
            mouseX = (e.clientX / window.innerWidth - 0.5) * 2;
            mouseY = (e.clientY / window.innerHeight - 0.5) * 2;
        });

        // Resize Handler
        window.addEventListener('resize', () => {
            camera.aspect = window.innerWidth / window.innerHeight;
            camera.updateProjectionMatrix();
            renderer.setSize(window.innerWidth, window.innerHeight);
        });

        // Animation Loop
        let clock = new THREE.Clock();

        function animate() {
            requestAnimationFrame(animate);
            const time = clock.getElapsedTime();

            // Wave Distortion on Plane Mesh
            const positions = planeGeo.attributes.position;
            for (let i = 0; i < positions.count; i++) {
                const u = positions.getX(i);
                const v = positions.getZ(i);
                const z = Math.sin(u * 0.08 + time * 0.8) * Math.cos(v * 0.08 + time * 0.8) * 2.5;
                positions.setY(i, initialY[i] + z);
            }
            positions.needsUpdate = true;

            // Rotate Particles
            particleSystem.rotation.y = time * 0.02;
            particleSystem.rotation.x = time * 0.01;

            // Smooth Camera Parallax
            camera.position.x += (mouseX * 4 - camera.position.x) * 0.03;
            camera.position.y += (-mouseY * 3 + 15 - camera.position.y) * 0.03;
            camera.lookAt(0, 0, 0);

            renderer.render(scene, camera);
        }

        animate();
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initHero3D);
    } else {
        initHero3D();
    }
})();
