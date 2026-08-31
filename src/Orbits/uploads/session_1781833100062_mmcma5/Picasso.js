(function() {
    'use strict';
    
    if (typeof window.Picasso !== 'undefined' && window.Picasso._initialized) {
        return;
    }
    
    const Picasso = {
        _initialized: true,
        version: '2.0.0'
    };

    // ============================================
    // CSS COMPLETO
    // ============================================
    
    const cascadestylesheet = `
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');

:root {
    --elevation-0: none;
    --elevation-1: 0 1px 3px rgba(0,0,0,0.06), 0 1px 2px rgba(0,0,0,0.04);
    --elevation-2: 0 4px 12px rgba(0,0,0,0.05), 0 2px 4px rgba(0,0,0,0.03);
    --elevation-3: 0 8px 24px rgba(0,0,0,0.06), 0 4px 8px rgba(0,0,0,0.04);
    --elevation-4: 0 16px 48px rgba(0,0,0,0.08), 0 8px 16px rgba(0,0,0,0.05);
    
    --neumo-light: rgba(255, 255, 255, 0.8);
    --neumo-dark: rgba(0, 0, 0, 0.06);
    --neumo-inset-light: rgba(255, 255, 255, 0.6);
    --neumo-inset-dark: rgba(0, 0, 0, 0.08);
    
    --shadow-neumo: -2px -2px 6px var(--neumo-light), 2px 2px 6px var(--neumo-dark);
    --shadow-neumo-pressed: inset -1px -1px 3px var(--neumo-inset-light), inset 1px 1px 3px var(--neumo-inset-dark);
    --shadow-neumo-hover: -3px -3px 8px var(--neumo-light), 3px 3px 8px var(--neumo-dark);
    
    --glass-bg: rgba(255, 255, 255, 0.12);
    --glass-border: rgba(255, 255, 255, 0.15);
    --glass-blur: blur(20px) saturate(180%);
    --glass-shadow: 0 8px 32px rgba(0,0,0,0.04);
    
    --color-bg: #F5F5F7;
    --color-surface: #FFFFFF;
    --color-surface-muted: #F2F2F7;
    --color-elevated: #FFFFFF;
    --color-text-primary: #1C1C1E;
    --color-text-secondary: #6C6C70;
    --color-text-muted: #8E8E93;
    --color-border: rgba(0, 0, 0, 0.04);
    --color-divider: rgba(0, 0, 0, 0.06);
    
    --touch-min: 44px;
    
    --ease-standard: cubic-bezier(0.4, 0, 0.2, 1);
    --ease-spring: cubic-bezier(0.34, 1.56, 0.64, 1);
    --ease-bounce: cubic-bezier(0.18, 0.89, 0.32, 1.28);
    --duration-instant: 0.08s;
    --duration-fast: 0.15s;
    --duration-standard: 0.25s;
    --duration-slow: 0.35s;
}

* {
    box-sizing: border-box;
    -webkit-user-select: none !important;
    -webkit-user-drag: none !important;
    user-select: none !important;
    -webkit-tap-highlight-color: transparent;
}

body {
    margin: 0;
    padding: 0;
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
    background: var(--color-bg);
    color: var(--color-text-primary);
    min-height: 100vh;
    touch-action: pan-x pan-y;
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
}

/* ============================================
   BOTONES - NEUMORPHISM
   ============================================ */

button {
    transition: transform var(--duration-fast) var(--ease-standard),
                box-shadow var(--duration-standard) var(--ease-standard),
                background var(--duration-standard) var(--ease-standard);
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
    font-weight: 500;
    font-size: 15px;
    letter-spacing: 0.01em;
    border: none;
    border-radius: 40px;
    min-width: var(--touch-min);
    min-height: var(--touch-min);
    padding: 0 24px;
    background: var(--color-surface-muted);
    color: var(--color-text-primary);
    box-shadow: var(--shadow-neumo);
    cursor: pointer;
    outline: none;
    position: relative;
    overflow: hidden;
    display: inline-flex;
    align-items: center;
    justify-content: center;
}
button:active:not(:disabled) {
    transform: scale(0.96);
    box-shadow: var(--shadow-neumo-pressed);
    transition-duration: var(--duration-instant);
}
button:hover:not(:disabled) {
    box-shadow: var(--shadow-neumo-hover);
    transform: translateY(-1px);
}
button:disabled {
    opacity: 0.4;
    cursor: not-allowed;
    transform: none !important;
    box-shadow: var(--shadow-neumo);
}

/* Variantes */
.picasso-primary {
    background: var(--color-surface);
    box-shadow: -2px -2px 8px var(--neumo-light), 2px 2px 12px rgba(0,0,0,0.08);
    color: var(--color-text-primary);
    font-weight: 600;
}
.picasso-primary:active:not(:disabled) { box-shadow: var(--shadow-neumo-pressed); }
.picasso-primary:hover:not(:disabled) { box-shadow: -3px -3px 10px var(--neumo-light), 3px 3px 16px rgba(0,0,0,0.10); }

.picasso-secondary {
    background: transparent;
    box-shadow: none;
    color: var(--color-text-secondary);
}
.picasso-secondary:active:not(:disabled) { transform: scale(0.96); box-shadow: var(--shadow-neumo-pressed); }
.picasso-secondary:hover:not(:disabled) { background: rgba(0,0,0,0.02); box-shadow: var(--shadow-neumo); }

.picasso-danger {
    background: var(--color-surface-muted);
    box-shadow: var(--shadow-neumo);
    color: var(--color-text-primary);
}
.picasso-danger:active:not(:disabled) { box-shadow: var(--shadow-neumo-pressed); }

.picasso-success {
    background: var(--color-surface-muted);
    box-shadow: var(--shadow-neumo);
    color: var(--color-text-primary);
}
.picasso-success:active:not(:disabled) { box-shadow: var(--shadow-neumo-pressed); }

.picasso-warning {
    background: var(--color-surface-muted);
    box-shadow: var(--shadow-neumo);
    color: var(--color-text-primary);
}
.picasso-warning:active:not(:disabled) { box-shadow: var(--shadow-neumo-pressed); }

.picasso-disabled {
    opacity: 0.4;
    cursor: not-allowed;
    transform: none !important;
    box-shadow: var(--shadow-neumo);
}

.picasso-bordered {
    background: transparent;
    box-shadow: none;
    border: 1.5px solid rgba(0,0,0,0.06);
    color: var(--color-text-primary);
}
.picasso-bordered:active:not(:disabled) { transform: scale(0.96); box-shadow: var(--shadow-neumo-pressed); border-color: rgba(0,0,0,0.12); }
.picasso-bordered:hover:not(:disabled) { background: rgba(0,0,0,0.02); border-color: rgba(0,0,0,0.10); }

.picasso-plain {
    background: transparent;
    box-shadow: none;
    color: var(--color-text-primary);
}
.picasso-plain:active:not(:disabled) { transform: scale(0.96); background: rgba(0,0,0,0.02); }
.picasso-plain:hover:not(:disabled) { background: rgba(0,0,0,0.01); }

.picasso-link {
    background: transparent;
    box-shadow: none;
    color: var(--color-text-primary);
    text-decoration: underline;
    text-underline-offset: 4px;
    text-decoration-color: rgba(0,0,0,0.2);
}
.picasso-link:active:not(:disabled) { opacity: 0.6; transform: scale(0.98); }
.picasso-link:hover:not(:disabled) { opacity: 0.7; }

/* ============================================
   INPUTS - SKEUOMORPHISM
   ============================================ */
input.picasso-input, textarea.picasso-input {
    transition: box-shadow var(--duration-standard) var(--ease-standard),
                background var(--duration-standard) var(--ease-standard),
                border-color var(--duration-standard) var(--ease-standard);
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
    font-size: 15px;
    font-weight: 400;
    color: var(--color-text-primary);
    padding: 12px 20px;
    border: 1.5px solid rgba(0,0,0,0.04);
    border-radius: 40px;
    outline: none;
    width: 100%;
    max-width: 300px;
    background: rgba(255,255,255,0.5);
    backdrop-filter: var(--glass-blur);
    -webkit-backdrop-filter: var(--glass-blur);
    box-shadow: inset -1px -1px 4px rgba(255,255,255,0.6), inset 1px 1px 4px rgba(0,0,0,0.04);
    caret-color: var(--color-text-primary);
    -webkit-user-select: text;
    user-select: text;
}
input.picasso-input::placeholder, textarea.picasso-input::placeholder { color: var(--color-text-muted); font-weight: 300; }
input.picasso-input:focus, textarea.picasso-input:focus {
    border-color: rgba(0,0,0,0.08);
    background: rgba(255,255,255,0.7);
    box-shadow: inset -1px -1px 4px rgba(255,255,255,0.6), inset 1px 1px 4px rgba(0,0,0,0.04), 0 4px 16px rgba(0,0,0,0.02);
}
input.picasso-input:disabled, textarea.picasso-input:disabled { opacity: 0.4; cursor: not-allowed; }

/* ============================================
   CARD - GLASSMORPHISM + NEUMORPHISM
   ============================================ */
.picasso-card {
    padding: 20px;
    border-radius: 16px;
    background: rgba(255,255,255,0.6);
    backdrop-filter: var(--glass-blur);
    -webkit-backdrop-filter: var(--glass-blur);
    border: 1px solid rgba(255,255,255,0.25);
    box-shadow: -2px -2px 8px rgba(255,255,255,0.6), 2px 2px 12px rgba(0,0,0,0.04), 0 8px 32px rgba(0,0,0,0.02);
    transition: box-shadow var(--duration-standard) var(--ease-standard);
}
.picasso-card:hover {
    box-shadow: -3px -3px 12px rgba(255,255,255,0.6), 3px 3px 16px rgba(0,0,0,0.06), 0 8px 32px rgba(0,0,0,0.02);
}

/* ============================================
   LIST - NEUMORPHISM SUTIL
   ============================================ */
.picasso-list-row {
    display: flex;
    align-items: center;
    padding: 14px 18px;
    background: rgba(255,255,255,0.3);
    backdrop-filter: blur(10px);
    -webkit-backdrop-filter: blur(10px);
    border-radius: 12px;
    margin-bottom: 4px;
    box-shadow: -1px -1px 4px rgba(255,255,255,0.4), 1px 1px 6px rgba(0,0,0,0.03);
    transition: box-shadow var(--duration-fast) var(--ease-standard),
                transform var(--duration-fast) var(--ease-standard),
                background var(--duration-fast) var(--ease-standard);
    cursor: pointer;
}
.picasso-list-row:hover {
    background: rgba(255,255,255,0.5);
    box-shadow: -2px -2px 6px rgba(255,255,255,0.5), 2px 2px 10px rgba(0,0,0,0.04);
}
.picasso-list-row:active {
    transform: scale(0.98);
    box-shadow: inset -1px -1px 3px rgba(255,255,255,0.4), inset 1px 1px 3px rgba(0,0,0,0.04);
}

/* ============================================
   NAVIGATION BAR
   ============================================ */
.picasso-navigation-bar {
    background: rgba(255,255,255,0.5);
    backdrop-filter: var(--glass-blur);
    -webkit-backdrop-filter: var(--glass-blur);
    border-bottom: 1px solid rgba(0,0,0,0.03);
    position: sticky;
    top: 0;
    z-index: 100;
    min-height: 56px;
    display: flex;
    align-items: center;
    padding: 0 16px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.02);
}
.picasso-navigation-bar-large {
    padding-top: 8px;
    padding-bottom: 8px;
    align-items: flex-end;
    min-height: 80px;
}
.picasso-navigation-bar-large .picasso-navigation-bar-title {
    font-size: 34px;
    font-weight: 700;
    color: var(--color-text-primary);
    letter-spacing: -0.02em;
    margin-left: 0;
    margin-bottom: 0;
}
.picasso-navigation-bar-inline {
    min-height: 56px;
    padding: 0 16px;
}
.picasso-navigation-bar-inline .picasso-navigation-bar-title {
    font-size: 17px;
    font-weight: 600;
    color: var(--color-text-primary);
}
.picasso-navigation-bar-back {
    background: transparent;
    border: none;
    font-size: 24px;
    cursor: pointer;
    color: var(--color-text-primary);
    padding: 4px 8px 4px 0;
    border-radius: 40px;
    min-width: 36px;
    min-height: 36px;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all 0.2s var(--ease-standard);
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
}
.picasso-navigation-bar-back:hover { background: rgba(0,0,0,0.03); }
.picasso-navigation-bar-back:active { transform: scale(0.92); background: rgba(0,0,0,0.05); }

/* ============================================
   ALERT - GLASSMORPHISM
   ============================================ */
.picasso-alert-overlay {
    position: fixed;
    top: 0;
    left: 0;
    width: 100vw;
    height: 100vh;
    background: rgba(0,0,0,0.08);
    backdrop-filter: blur(6px);
    -webkit-backdrop-filter: blur(6px);
    z-index: 999999999;
    display: flex;
    align-items: center;
    justify-content: center;
    animation: picasso-alert-in 0.3s var(--ease-spring) forwards;
}
.picasso-alert-box {
    position: relative;
    width: 340px;
    max-width: 90vw;
    padding: 32px 28px 80px;
    background: rgba(255,255,255,0.5);
    backdrop-filter: var(--glass-blur);
    -webkit-backdrop-filter: var(--glass-blur);
    border-radius: 28px;
    border: 1px solid rgba(255,255,255,0.25);
    box-shadow: -4px -4px 16px rgba(255,255,255,0.4), 4px 4px 24px rgba(0,0,0,0.06), 0 20px 60px rgba(0,0,0,0.04);
    animation: picasso-alert-scale 0.3s var(--ease-spring) forwards;
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
}
.picasso-alert-text {
    display: block;
    font-size: 16px;
    color: var(--color-text-primary);
    margin-bottom: 8px;
    font-weight: 500;
    line-height: 1.5;
}
.picasso-alert-btn {
    width: 95%;
    height: 44px;
    bottom: 5%;
    left: 2.5%;
    position: absolute;
    background: rgba(255,255,255,0.3);
    backdrop-filter: blur(10px);
    -webkit-backdrop-filter: blur(10px);
    border-radius: 40px;
    border: 1px solid rgba(255,255,255,0.2);
    box-shadow: -2px -2px 6px rgba(255,255,255,0.4), 2px 2px 10px rgba(0,0,0,0.04);
    color: var(--color-text-primary);
    font-size: 15px;
    font-weight: 500;
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
    cursor: pointer;
    transition: all 0.2s var(--ease-standard);
    display: flex;
    align-items: center;
    justify-content: center;
    outline: none;
}
.picasso-alert-btn:hover {
    background: rgba(255,255,255,0.5);
    box-shadow: -3px -3px 8px rgba(255,255,255,0.5), 3px 3px 14px rgba(0,0,0,0.06);
}
.picasso-alert-btn:active {
    transform: scale(0.96);
    box-shadow: inset -1px -1px 3px rgba(255,255,255,0.4), inset 1px 1px 3px rgba(0,0,0,0.04);
}
.picasso-alert-group {
    display: flex;
    gap: 10px;
    position: absolute;
    bottom: 5%;
    left: 2.5%;
    width: 95%;
}
.picasso-alert-group .picasso-alert-btn {
    position: relative;
    left: 0;
    flex: 1;
}
.picasso-alert-input {
    display: block;
    width: 100%;
    padding: 10px 14px;
    margin-top: 15px;
    background: rgba(255,255,255,0.2);
    backdrop-filter: blur(10px);
    -webkit-backdrop-filter: blur(10px);
    border: 1px solid rgba(255,255,255,0.1);
    border-radius: 16px;
    font-size: 15px;
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
    outline: none;
    box-sizing: border-box;
    color: #1c1c1e;
    transition: all 0.2s ease;
}
.picasso-alert-input:focus { border-color: rgba(0,0,0,0.2); background: rgba(255,255,255,0.3); }

/* ============================================
   TABVIEW - ADAPTATIVO (iOS / macOS)
   ============================================ */

.picasso-tabview {
    display: flex;
    flex-direction: column;
    height: 100%;
    min-height: 100vh;
    background: var(--color-bg);
    position: relative;
    overflow: hidden;
}

.picasso-tabview-content {
    flex: 1;
    overflow: hidden;
    position: relative;
}

.picasso-tabview-content > * {
    height: 100%;
    overflow-y: auto;
}

/* ===== BOTTOM BAR (iOS style) ===== */
.picasso-tabview-bar-bottom {
    display: flex;
    align-items: center;
    justify-content: space-around;
    background: rgba(255, 255, 255, 0.7);
    backdrop-filter: blur(30px) saturate(180%);
    -webkit-backdrop-filter: blur(30px) saturate(180%);
    border-top: 1px solid rgba(0, 0, 0, 0.04);
    height: 60px;
    flex-shrink: 0;
    padding: 0 12px;
    position: relative;
    z-index: 10;
    box-shadow: 0 -2px 12px rgba(0, 0, 0, 0.03);
    margin: 0 12px 12px 12px;
    border-radius: 32px;
    max-width: 97vw;
}

.picasso-tab-item-bottom {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 2px;
    cursor: pointer;
    padding: 6px 8px;
    border-radius: 16px;
    min-width: 44px;
    transition: all 0.25s cubic-bezier(0.34, 1.56, 0.64, 1);
    flex: 1;
    max-width: 80px;
    position: relative;
    -webkit-tap-highlight-color: transparent;
    height: 100%;
    background: transparent;
    border: none;
}
.picasso-tab-item-bottom:active {
    transform: scale(0.90);
}
.picasso-tab-item-bottom .picasso-tab-icon {
    font-size: 22px;
    transition: all 0.25s cubic-bezier(0.34, 1.56, 0.64, 1);
    color: #8E8E93;
    line-height: 1;
}
.picasso-tab-item-bottom .picasso-tab-label {
    font-size: 10px;
    font-weight: 400;
    color: #8E8E93;
    transition: all 0.25s cubic-bezier(0.34, 1.56, 0.64, 1);
    text-align: center;
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
}
.picasso-tab-item-bottom.active .picasso-tab-icon {
    color: #0066CC;
}
.picasso-tab-item-bottom.active .picasso-tab-label {
    color: #0066CC;
    font-weight: 600;
}
.picasso-tab-item-bottom.active .picasso-tab-indicator-bottom {
    display: block;
}

.picasso-tab-indicator-bottom {
    position: absolute;
    top: 0;
    left: 50%;
    transform: translateX(-50%);
    width: 18px;
    height: 3px;
    background: #0066CC;
    border-radius: 4px;
    transition: all 0.35s cubic-bezier(0.34, 1.56, 0.64, 1);
    display: none;
}

/* ===== SIDEBAR (macOS style) ===== */
.picasso-tabview-bar-sidebar {
    display: flex;
    flex-direction: column;
    align-items: stretch;
    background: rgba(255, 255, 255, 0.5);
    backdrop-filter: blur(30px) saturate(180%);
    -webkit-backdrop-filter: blur(30px) saturate(180%);
    border-right: 1px solid rgba(0, 0, 0, 0.04);
    width: 200px;
    min-width: 200px;
    flex-shrink: 0;
    padding: 12px 8px;
    gap: 4px;
    position: relative;
    z-index: 10;
    box-shadow: 2px 0 12px rgba(0, 0, 0, 0.02);
    height: 100vh;
    overflow-y: auto;
}

.picasso-sidebar-item {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 8px 12px;
    border-radius: 8px;
    cursor: pointer;
    transition: all 0.15s ease;
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
    font-size: 14px;
    font-weight: 400;
    color: #6C6C70;
    background: transparent;
    border: none;
    width: 100%;
    text-align: left;
    user-select: none;
}
.picasso-sidebar-item:hover {
    background: rgba(0, 0, 0, 0.04);
}
.picasso-sidebar-item.active {
    background: rgba(0, 0, 0, 0.06);
    color: #1C1C1E;
    font-weight: 500;
}
.picasso-sidebar-item.active .picasso-sidebar-icon {
    color: #1C1C1E;
}
.picasso-sidebar-item.active .picasso-sidebar-label {
    color: #1C1C1E;
    font-weight: 500;
}
.picasso-sidebar-icon {
    font-size: 18px;
    line-height: 1;
    color: #8E8E93;
    transition: color 0.15s ease;
    width: 24px;
    text-align: center;
}
.picasso-sidebar-label {
    font-size: 14px;
    font-weight: 400;
    color: #6C6C70;
    transition: color 0.15s ease;
    flex: 1;
}

/* ===== RESPONSIVE ===== */
@media (max-width: 767px) {
    .picasso-tabview {
        flex-direction: column !important;
    }
    .picasso-tabview-bar-sidebar {
        flex-direction: row !important;
        width: 100% !important;
        min-width: unset !important;
        height: 60px !important;
        border-right: none !important;
        border-top: 1px solid rgba(0,0,0,0.04) !important;
        padding: 0 12px !important;
        margin: 0 12px 12px 12px !important;
        border-radius: 32px !important;
        box-shadow: 0 -2px 12px rgba(0,0,0,0.03) !important;
        overflow-y: visible !important;
        background: rgba(255,255,255,0.7) !important;
    }
    .picasso-sidebar-item {
        flex-direction: column !important;
        justify-content: center !important;
        padding: 6px 8px !important;
        gap: 2px !important;
        font-size: 10px !important;
        min-width: 44px !important;
        max-width: 80px !important;
        flex: 1 !important;
        border-radius: 16px !important;
    }
    .picasso-sidebar-icon {
        font-size: 20px !important;
        width: auto !important;
    }
    .picasso-sidebar-label {
        font-size: 9px !important;
    }
    .picasso-sidebar-item.active .picasso-sidebar-indicator {
        display: block !important;
    }
    .picasso-sidebar-indicator {
        position: absolute !important;
        top: 0 !important;
        left: 50% !important;
        transform: translateX(-50%) !important;
        width: 18px !important;
        height: 3px !important;
        background: #0066CC !important;
        border-radius: 4px !important;
        display: none !important;
    }
}

@media (min-width: 768px) {
    .picasso-tabview {
        flex-direction: row !important;
    }
    .picasso-tabview-bar-bottom {
        display: none !important;
    }
}

/* ============================================
   ANIMACIONES, UTILITIES, STACKS, SCROLLVIEW, SCREEN
   ============================================ */
@keyframes picasso-alert-in {
    from { opacity: 0; }
    to { opacity: 1; }
}
@keyframes picasso-alert-scale {
    from { opacity: 0; transform: scale(0.94) translateY(10px); }
    to { opacity: 1; transform: scale(1) translateY(0); }
}
.picasso-divider { border: none; margin: 8px 0; height: 1px; background: var(--color-divider); }
.picasso-spacer { flex: 1; }
.picasso-icon { display: inline-flex; align-items: center; justify-content: center; color: var(--color-text-secondary); }
.picasso-avatar {
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 600;
    overflow: hidden;
    flex-shrink: 0;
    background: var(--color-surface-muted);
    color: var(--color-text-secondary);
    box-shadow: var(--shadow-neumo);
}
.picasso-badge {
    border-radius: 40px;
    font-weight: 500;
    display: inline-block;
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
    background: var(--color-surface-muted);
    color: var(--color-text-secondary);
    box-shadow: var(--shadow-neumo);
    padding: 2px 12px;
    font-size: 12px;
}
.picasso-stack { display: flex; gap: 8px; }
.picasso-stack-vertical { flex-direction: column; }
.picasso-stack-horizontal { flex-direction: row; flex-wrap: wrap; }
.picasso-scrollview { overflow: auto; -webkit-overflow-scrolling: touch; }
.picasso-scrollview::-webkit-scrollbar { width: 4px; }
.picasso-scrollview::-webkit-scrollbar-track { background: transparent; }
.picasso-scrollview::-webkit-scrollbar-thumb { background: rgba(0,0,0,0.08); border-radius: 10px; }
.picasso-screen {
    display: flex;
    flex-direction: column;
    height: 100%;
    min-height: 100vh;
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
    background: var(--color-bg);
}
.picasso-screen-content {
    flex: 1;
    padding: 20px 20px 30px;
    overflow-y: auto;
    overflow-x: hidden;
}

@media (max-width: 640px) {
    button { font-size: 14px; padding: 0 18px; min-height: 40px; }
    .picasso-screen-content { padding: 16px 16px 80px; }
    .picasso-navigation-bar-large .picasso-navigation-bar-title { font-size: 28px; }
    .picasso-navigation-bar { padding: 0 12px; }
    .picasso-alert-box { padding: 24px 20px 72px; width: 90vw; }
}
    `;

    const PicassoCSS = document.createElement('style');
    PicassoCSS.innerHTML = cascadestylesheet;
    document.head.appendChild(PicassoCSS);
    
    // ============================================
    // ENUMS
    // ============================================
    
    const Enums = {
        controlSize: {
            mini: 'mini', small: 'small', regular: 'regular',
            large: 'large', extraLarge: 'extraLarge'
        },
        style: {
            primary: 'primary', secondary: 'secondary', danger: 'danger',
            success: 'success', warning: 'warning', disabled: 'disabled',
            bordered: 'bordered', plain: 'plain', link: 'link'
        },
        textStyle: {
            headline: 'headline', subheadline: 'subheadline', body: 'body',
            callout: 'callout', caption: 'caption', footnote: 'footnote'
        },
        fontWeight: {
            bold: 'bold', regular: 'regular', medium: 'medium',
            light: 'light', semibold: 'semibold'
        },
        color: {
            blue: '#007AFF', red: '#FF3B30', green: '#34C759',
            orange: '#FF9500', yellow: '#FFCC00', purple: '#AF52DE',
            pink: '#FF2D55', gray: '#8E8E93', white: '#FFFFFF', black: '#000000'
        }
    };
    
    // ============================================
    // ALERT SYSTEM (COMPLETO)
    // ============================================
    
    const PicassoAlerts = {
        _queue: [], _open: false,
        
        override: function() {
            window.alert = (content) => this.alert(content);
            window.confirm = (content, options) => this.confirm(content, options);
            window.prompt = (content, defaultValue, options) => this.prompt(content, defaultValue, options);
        },
        
        alert: function(content) { return this._enqueue('alert', content); },
        confirm: function(content, options = {}) { return this._enqueue('confirm', content, options); },
        prompt: function(content, defaultValue = '', options = {}) { return this._enqueue('prompt', content, defaultValue, options); },
        
        _enqueue: function(type, ...args) {
            return new Promise((resolve) => {
                this._queue.push({ type, args, resolve });
                this._processQueue();
            });
        },
        
        _processQueue: function() {
            if (this._open || this._queue.length === 0) return;
            this._open = true;
            const { type, args, resolve } = this._queue.shift();
            this._showDialog(type, args, resolve);
        },
        
        _closeDialog: function(overlay) {
            overlay.style.transition = 'all 0.15s ease';
            overlay.style.opacity = '0';
            overlay.style.transform = 'scale(0.95)';
            setTimeout(() => {
                if (overlay.parentNode) overlay.remove();
                PicassoAlerts._open = false;
                PicassoAlerts._processQueue();
            }, 150);
        },
        
        _showDialog: function(type, args, resolve) {
            const overlay = document.createElement('div');
            overlay.className = 'picasso-alert-overlay';
            const box = document.createElement('div');
            box.className = 'picasso-alert-box';
            
            const escHandler = (e) => {
                if (e.key === 'Escape') {
                    if (type === 'confirm') resolve(false);
                    else if (type === 'prompt') resolve(null);
                    else resolve();
                    this._closeDialog(overlay);
                    document.removeEventListener('keydown', escHandler);
                }
            };
            document.addEventListener('keydown', escHandler);
            
            if (type !== 'alert') {
                overlay.addEventListener('click', (e) => {
                    if (e.target === overlay) {
                        if (type === 'confirm') resolve(false);
                        else if (type === 'prompt') resolve(null);
                        this._closeDialog(overlay);
                        document.removeEventListener('keydown', escHandler);
                    }
                });
            }
            
            if (type === 'alert') {
                const content = args[0];
                box.innerHTML = `
                    <span class="picasso-alert-text">${content}</span>
                    <button class="picasso-alert-btn" id="picasso-alert-ok">OK</button>
                `;
                box.querySelector('#picasso-alert-ok').addEventListener('click', () => {
                    resolve();
                    this._closeDialog(overlay);
                    document.removeEventListener('keydown', escHandler);
                });
                overlay.appendChild(box);
                document.body.appendChild(overlay);
                setTimeout(() => box.querySelector('#picasso-alert-ok').focus(), 50);
                return;
            }
            
            if (type === 'confirm') {
                const [content, options = {}] = args;
                const okText = options.okText || 'OK';
                const cancelText = options.cancelText || 'Cancel';
                box.innerHTML = `
                    <span class="picasso-alert-text">${content}</span>
                    <div class="picasso-alert-group">
                        <button class="picasso-alert-btn" id="picasso-confirm-cancel">${cancelText}</button>
                        <button class="picasso-alert-btn" id="picasso-confirm-ok">${okText}</button>
                    </div>
                `;
                const ok = box.querySelector('#picasso-confirm-ok');
                const cancel = box.querySelector('#picasso-confirm-cancel');
                ok.addEventListener('click', () => { resolve(true); this._closeDialog(overlay); document.removeEventListener('keydown', escHandler); });
                cancel.addEventListener('click', () => { resolve(false); this._closeDialog(overlay); document.removeEventListener('keydown', escHandler); });
                overlay.appendChild(box);
                document.body.appendChild(overlay);
                setTimeout(() => cancel.focus(), 50);
                return;
            }
            
            if (type === 'prompt') {
                const [content, defaultValue = '', options = {}] = args;
                const okText = options.okText || 'OK';
                const cancelText = options.cancelText || 'Cancel';
                const inputId = 'picasso-prompt-' + Date.now();
                box.innerHTML = `
                    <span class="picasso-alert-text">${content}</span>
                    <input class="picasso-alert-input" id="${inputId}" type="text" value="${defaultValue.replace(/"/g, '&quot;')}">
                    <div class="picasso-alert-group">
                        <button class="picasso-alert-btn" id="picasso-prompt-cancel">${cancelText}</button>
                        <button class="picasso-alert-btn" id="picasso-prompt-ok">${okText}</button>
                    </div>
                `;
                const input = box.querySelector('#' + inputId);
                const ok = box.querySelector('#picasso-prompt-ok');
                const cancel = box.querySelector('#picasso-prompt-cancel');
                input.addEventListener('keydown', (e) => {
                    if (e.key === 'Enter') {
                        resolve(input.value);
                        this._closeDialog(overlay);
                        document.removeEventListener('keydown', escHandler);
                    }
                });
                ok.addEventListener('click', () => {
                    resolve(input.value);
                    this._closeDialog(overlay);
                    document.removeEventListener('keydown', escHandler);
                });
                cancel.addEventListener('click', () => {
                    resolve(null);
                    this._closeDialog(overlay);
                    document.removeEventListener('keydown', escHandler);
                });
                overlay.appendChild(box);
                document.body.appendChild(overlay);
                setTimeout(() => input.focus(), 50);
                return;
            }
        }
    };
    
    // Sobrescribir alertas nativas
    PicassoAlerts.override();
    
    // ============================================
    // COMPONENTES BASE
    // ============================================
    
    let currentContainer = null;
    
    class Component {
        constructor() {
            this._children = [];
            this._style = null;
            this._controlSize = 'regular';
            this._disabled = false;
            this._hidden = false;
            this._callbacks = {};
            this._element = null;
            this._width = null;
            this._height = null;
            this._minWidth = null;
            this._minHeight = null;
            this._maxWidth = null;
            this._maxHeight = null;
        }
        
        width(value) { this._width = value; return this; }
        height(value) { this._height = value; return this; }
        size(value) { this._width = value; this._height = value; return this; }
        minWidth(value) { this._minWidth = value; return this; }
        minHeight(value) { this._minHeight = value; return this; }
        maxWidth(value) { this._maxWidth = value; return this; }
        maxHeight(value) { this._maxHeight = value; return this; }
        frame(width = null, height = null, minWidth = null, maxWidth = null, minHeight = null, maxHeight = null) {
            if (width !== null) this._width = width;
            if (height !== null) this._height = height;
            if (minWidth !== null) this._minWidth = minWidth;
            if (maxWidth !== null) this._maxWidth = maxWidth;
            if (minHeight !== null) this._minHeight = minHeight;
            if (maxHeight !== null) this._maxHeight = maxHeight;
            return this;
        }
        fixed(value) { return this.size(value); }
        lock(size) { return this.size(size); }
        
        _applySizeStyles(element) {
            if (!element) return;
            let styles = '';
            if (this._width !== null) styles += `width: ${this._width}px;`;
            if (this._height !== null) styles += `height: ${this._height}px;`;
            if (this._minWidth !== null) styles += `min-width: ${this._minWidth}px;`;
            if (this._minHeight !== null) styles += `min-height: ${this._minHeight}px;`;
            if (this._maxWidth !== null) styles += `max-width: ${this._maxWidth}px;`;
            if (this._maxHeight !== null) styles += `max-height: ${this._maxHeight}px;`;
            if (styles) element.style.cssText += styles;
            return element;
        }
        
        style(style) { this._style = style; return this; }
        controlSize(size) { this._controlSize = size; return this; }
        disabled(disabled = true) { this._disabled = disabled; return this; }
        hidden(hidden = true) { this._hidden = hidden; return this; }
        onTap(callback) { this._callbacks.tap = callback; return this; }
        render() { return this; }
    }
    
    // ============================================
    // BUTTON
    // ============================================
    
    class Button extends Component {
        constructor(label) {
            super();
            this._label = label;
            this._action = null;
        }
        
        press() {
            if (this._disabled) return this;
            if (this._action) this._action();
            if (this._callbacks.tap) this._callbacks.tap();
            return this;
        }
        
        render() {
            const sizeMap = {
                mini: 'font-size: 11px; padding: 4px 12px; min-height: 32px;',
                small: 'font-size: 13px; padding: 6px 16px; min-height: 36px;',
                regular: 'font-size: 15px; padding: 8px 20px; min-height: 44px;',
                large: 'font-size: 17px; padding: 10px 24px; min-height: 48px;',
                extraLarge: 'font-size: 20px; padding: 12px 30px; min-height: 56px;'
            };
            
            const styleMap = {
                primary: 'picasso-primary',
                secondary: 'picasso-secondary',
                danger: 'picasso-danger',
                success: 'picasso-success',
                warning: 'picasso-warning',
                disabled: 'picasso-disabled',
                bordered: 'picasso-bordered',
                plain: 'picasso-plain',
                link: 'picasso-link'
            };
            
            const variant = this._style || 'primary';
            
            this._element = document.createElement('button');
            this._element.textContent = this._label;
            this._element.className = styleMap[variant] || 'picasso-primary';
            
            const sizeStyle = sizeMap[this._controlSize] || sizeMap.regular;
            this._element.style.cssText += sizeStyle;
            this._applySizeStyles(this._element);
            
            if (this._disabled) this._element.disabled = true;
            if (!this._disabled) this._element.onclick = () => this.press();
            if (this._hidden) this._element.style.display = 'none';
            
            return this._element;
        }
    }
    
    function UI_button(label) {
        return function(action) {
            const button = new Button(label);
            if (typeof action === 'function') button._action = action;
            
            // Añadir métodos de tamaño
            button.lock = function(size) { this._width = size; this._height = size; return this; };
            button.size = function(value) { this._width = value; this._height = value; return this; };
            
            return button;
        };
    }
    
    // ============================================
    // TEXT
    // ============================================
    
    class Text extends Component {
        constructor(content) { super(); this._content = content; this._font = 'body'; this._weight = 'regular'; this._color = '#1C1C1E'; this._alignment = 'left'; }
        font(style) { this._font = style; return this; }
        fontWeight(weight) { this._weight = weight; return this; }
        foregroundColor(color) { this._color = color; return this; }
        multilineTextAlignment(alignment) { this._alignment = alignment; return this; }
        render() {
            const fontMap = { headline: '28px', subheadline: '20px', body: '16px', callout: '15px', caption: '13px', footnote: '12px' };
            const weightMap = { bold: '700', regular: '400', medium: '500', light: '300', semibold: '600' };
            const size = fontMap[this._font] || fontMap.body;
            const weight = weightMap[this._weight] || weightMap.regular;
            this._element = document.createElement('p');
            this._element.textContent = this._content;
            this._element.style.cssText = `
                font-size: ${size}; font-weight: ${weight}; color: ${this._color};
                text-align: ${this._alignment}; margin: 4px 0;
                font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
            `;
            return this._element;
        }
    }
    
    function UI_text(content) {
        const text = new Text(content);
        const element = text.render();
        if (currentContainer) {
            currentContainer.appendChild(element);
        } else {
            document.body.appendChild(element);
        }
        return text;
    }
    
    // ============================================
    // TEXTFIELD
    // ============================================
    
    class TextField extends Component {
        constructor(placeholder = '') { super(); this._placeholder = placeholder; this._text = ''; this._secureTextEntry = false; }
        text(text) { this._text = text; return this; }
        secureTextEntry(secure = true) { this._secureTextEntry = secure; return this; }
        onCommit(callback) { this._callbacks.commit = callback; return this; }
        render() {
            this._element = document.createElement('input');
            this._element.type = this._secureTextEntry ? 'password' : 'text';
            this._element.placeholder = this._placeholder;
            this._element.value = this._text;
            this._element.className = 'picasso-input';
            if (this._disabled) this._element.disabled = true;
            this._element.oninput = () => {
                this._text = this._element.value;
                if (this._callbacks.commit) this._callbacks.commit(this._text);
            };
            return this._element;
        }
    }
    
    function UI_textField(placeholder) {
        const field = new TextField(placeholder);
        const element = field.render();
        if (currentContainer) {
            currentContainer.appendChild(element);
        } else {
            document.body.appendChild(element);
        }
        return field;
    }
    
    // ============================================
    // CONTAINER
    // ============================================
    
    class Container extends Component {
        constructor(children = []) { super(); this._children = children; this._padding = 0; this._margin = 0; this._background = 'transparent'; this._cornerRadius = 0; }
        padding(value) { this._padding = value; return this; }
        margin(value) { this._margin = value; return this; }
        background(color) { this._background = color; return this; }
        cornerRadius(radius) { this._cornerRadius = radius; return this; }
        render() {
            this._element = document.createElement('div');
            this._element.style.cssText = `
                padding: ${this._padding}px; margin: ${this._margin}px;
                background: ${this._background}; border-radius: ${this._cornerRadius}px;
            `;
            this._children.forEach(child => {
                if (typeof child === 'function') child = child();
                if (child && child.render) {
                    const childElement = child.render();
                    if (childElement instanceof HTMLElement) this._element.appendChild(childElement);
                }
            });
            return this._element;
        }
    }
    
    function UI_container(children = []) {
        const container = new Container(children);
        const oldContainer = currentContainer;
        currentContainer = container.render();
        children.forEach(child => {
            if (typeof child === 'function') child();
        });
        if (oldContainer) {
            oldContainer.appendChild(currentContainer);
        } else {
            document.body.appendChild(currentContainer);
        }
        currentContainer = oldContainer;
        return container;
    }
    
    // ============================================
    // CARD
    // ============================================
    
    class Card extends Container {
        constructor(children = []) { super(children); this._elevation = 2; }
        elevation(value) { this._elevation = value; return this; }
        render() {
            this._element = document.createElement('div');
            this._element.className = 'picasso-card';
            let styles = `
                padding: ${this._padding || 20}px;
                border-radius: ${this._cornerRadius || 16}px;
            `;
            if (this._elevation > 0) {
                styles += `box-shadow: 
                    -${this._elevation}px -${this._elevation}px ${this._elevation * 4}px rgba(255,255,255,0.6),
                    ${this._elevation}px ${this._elevation}px ${this._elevation * 6}px rgba(0,0,0,0.04),
                    0 ${this._elevation * 4}px ${this._elevation * 8}px rgba(0,0,0,0.02);
                `;
            }
            this._element.style.cssText = styles;
            this._children.forEach(child => {
                if (typeof child === 'function') child = child();
                if (child && child.render) {
                    const el = child.render();
                    if (el instanceof HTMLElement) this._element.appendChild(el);
                }
            });
            return this._element;
        }
    }
    
    function UI_card(children = []) { return new Card(children); }
    
    // ============================================
    // AVATAR
    // ============================================
    
    class Avatar extends Component {
        constructor(nameOrSrc) { super(); this._name = ''; this._src = null; this._size = 40; this._color = '#F2F2F7'; this._textColor = '#1C1C1E';
            if (nameOrSrc && (nameOrSrc.startsWith('http') || nameOrSrc.startsWith('/'))) { this._src = nameOrSrc; }
            else { this._name = nameOrSrc || ''; }
        }
        size(value) { this._size = value; return this; }
        color(value) { this._color = value; return this; }
        render() {
            this._element = document.createElement('div');
            this._element.className = 'picasso-avatar';
            this._element.style.cssText = `
                width: ${this._size}px; height: ${this._size}px;
                font-size: ${this._size * 0.4}px;
                background: ${this._color}; color: ${this._textColor};
            `;
            if (this._src) {
                const img = document.createElement('img');
                img.src = this._src;
                img.style.cssText = 'width:100%; height:100%; object-fit:cover;';
                this._element.appendChild(img);
            } else if (this._name) {
                const initials = this._name.split(' ').map(w => w[0]).join('').toUpperCase().slice(0, 2);
                this._element.textContent = initials;
            }
            return this._element;
        }
    }
    
    function UI_avatar(nameOrSrc) { return new Avatar(nameOrSrc); }
    
    // ============================================
    // BADGE
    // ============================================
    
    class Badge extends Component {
        constructor(text) { super(); this._text = text; this._size = 'small'; }
        size(size) { this._size = size; return this; }
        render() {
            const sizeMap = { small: 'font-size: 11px; padding: 2px 8px;', medium: 'font-size: 13px; padding: 4px 12px;', large: 'font-size: 15px; padding: 6px 16px;' };
            this._element = document.createElement('span');
            this._element.className = 'picasso-badge';
            this._element.textContent = this._text;
            this._element.style.cssText = sizeMap[this._size] || sizeMap.small;
            return this._element;
        }
    }
    
    function UI_badge(text) { return new Badge(text); }
    
    // ============================================
    // DIVIDER, SPACER, ICON, IMAGE
    // ============================================
    
    class Divider extends Component {
        constructor() { super(); this._orientation = 'horizontal'; this._thickness = 1; this._color = 'rgba(0,0,0,0.06)'; }
        orientation(orientation) { this._orientation = orientation; return this; }
        thickness(value) { this._thickness = value; return this; }
        color(value) { this._color = value; return this; }
        render() {
            this._element = document.createElement('hr');
            this._element.className = 'picasso-divider';
            this._element.style.cssText = `
                border: none;
                ${this._orientation === 'horizontal' ? 
                    `height: ${this._thickness}px; width: 100%;` : 
                    `width: ${this._thickness}px; height: 100%; min-height: 40px;`
                }
                background: ${this._color};
            `;
            return this._element;
        }
    }
    
    function UI_divider() { return new Divider(); }
    
    class Spacer extends Component {
        constructor() { super(); this._minSize = 0; this._flex = 1; }
        minSize(value) { this._minSize = value; return this; }
        flex(value) { this._flex = value; return this; }
        render() {
            this._element = document.createElement('div');
            this._element.className = 'picasso-spacer';
            this._element.style.cssText = `flex: ${this._flex}; min-width: ${this._minSize}px; min-height: ${this._minSize}px;`;
            return this._element;
        }
    }
    
    function UI_spacer() { return new Spacer(); }
    
    class Icon extends Component {
        constructor(name) { super(); this._name = name; this._size = 24; this._color = '#6C6C70'; }
        size(value) { this._size = value; return this; }
        color(value) { this._color = value; return this; }
        render() {
            this._element = document.createElement('span');
            this._element.className = 'picasso-icon';
            this._element.textContent = this._name;
            this._element.style.cssText = `font-size: ${this._size}px; color: ${this._color};`;
            return this._element;
        }
    }
    
    function UI_icon(name) { return new Icon(name); }
    
    class Image extends Component {
        constructor(src) { super(); this._src = src; this._alt = ''; this._width = null; this._height = null; this._fit = 'cover'; this._radius = 0; this._loading = 'lazy'; }
        alt(text) { this._alt = text; return this; }
        width(value) { this._width = value; return this; }
        height(value) { this._height = value; return this; }
        fit(mode) { this._fit = mode; return this; }
        radius(value) { this._radius = value; return this; }
        loading(mode) { this._loading = mode; return this; }
        render() {
            this._element = document.createElement('img');
            this._element.src = this._src;
            this._element.alt = this._alt;
            this._element.loading = this._loading;
            let styles = `object-fit: ${this._fit}; border-radius: ${this._radius}px; display: block;`;
            if (this._width) styles += `width: ${this._width}px;`;
            if (this._height) styles += `height: ${this._height}px;`;
            this._element.style.cssText = styles;
            return this._element;
        }
    }
    
    function UI_image(src) { return new Image(src); }
    
    // ============================================
    // LIST
    // ============================================
    
    class List extends Component {
        constructor(items = [], renderItem = null) {
            super();
            this._items = items;
            this._renderItem = renderItem;
            this._inset = false;
        }
        inset(show = true) { this._inset = show; return this; }
        render() {
            this._element = document.createElement('div');
            this._element.className = 'picasso-list';
            this._element.style.cssText = this._inset ? 'padding: 0 16px;' : '';
            
            this._items.forEach((item, index) => {
                const row = document.createElement('div');
                row.className = 'picasso-list-row';
                
                if (this._renderItem) {
                    const child = this._renderItem(item, index);
                    if (child && child.render) {
                        const childElement = child.render();
                        if (childElement instanceof HTMLElement) row.appendChild(childElement);
                    } else if (child instanceof HTMLElement) {
                        row.appendChild(child);
                    } else if (typeof child === 'string' || typeof child === 'number') {
                        row.textContent = String(child);
                    }
                } else {
                    row.textContent = String(item);
                }
                
                this._element.appendChild(row);
            });
            
            return this._element;
        }
    }
    
    function UI_List(items = [], renderItem = null) { return new List(items, renderItem); }
    
    // ============================================
    // SCROLLVIEW
    // ============================================
    
    class ScrollView extends Component {
        constructor(children = []) { super(); this._children = children; this._horizontal = false; this._showsIndicators = true; this._contentInset = { top: 0, bottom: 0, left: 0, right: 0 }; }
        horizontal(value = true) { this._horizontal = value; return this; }
        showsIndicators(value = true) { this._showsIndicators = value; return this; }
        contentInset(insets) { this._contentInset = { ...this._contentInset, ...insets }; return this; }
        render() {
            this._element = document.createElement('div');
            this._element.className = 'picasso-scrollview';
            this._element.style.cssText = `
                overflow: auto;
                overflow-y: ${this._horizontal ? 'hidden' : 'auto'};
                overflow-x: ${this._horizontal ? 'auto' : 'hidden'};
                scrollbar-width: ${this._showsIndicators ? 'auto' : 'none'};
                -webkit-overflow-scrolling: touch;
                padding: ${this._contentInset.top}px ${this._contentInset.right}px ${this._contentInset.bottom}px ${this._contentInset.left}px;
            `;
            const content = document.createElement('div');
            content.className = 'picasso-scrollview-content';
            content.style.cssText = `
                display: ${this._horizontal ? 'flex' : 'block'};
                flex-direction: ${this._horizontal ? 'row' : 'column'};
                gap: ${this._horizontal ? '12px' : '0'};
                ${this._horizontal ? 'padding: 8px;' : ''}
            `;
            this._children.forEach(child => {
                if (typeof child === 'function') child = child();
                if (child && child.render) {
                    const el = child.render();
                    if (el instanceof HTMLElement) content.appendChild(el);
                }
            });
            this._element.appendChild(content);
            return this._element;
        }
    }
    
    function UI_ScrollView(children = []) { return new ScrollView(children); }
    
    // ============================================
    // STACK (VStack / HStack)
    // ============================================
    
    class Stack extends Component {
        constructor(children = [], orientation = 'vertical') { super(); this._children = children; this._orientation = orientation; this._spacing = 8; this._padding = 0; this._alignment = 'center'; }
        spacing(value) { this._spacing = value; return this; }
        padding(value) { this._padding = value; return this; }
        alignment(value) { this._alignment = value; return this; }
        render() {
            this._element = document.createElement('div');
            this._element.className = `picasso-stack picasso-stack-${this._orientation}`;
            this._element.style.cssText = `
                display: flex;
                flex-direction: ${this._orientation === 'vertical' ? 'column' : 'row'};
                gap: ${this._spacing}px;
                padding: ${this._padding}px;
                align-items: ${this._alignment};
                flex-wrap: ${this._orientation === 'horizontal' ? 'wrap' : 'nowrap'};
            `;
            this._children.forEach(child => {
                if (typeof child === 'function') child = child();
                if (child && child.render) {
                    const el = child.render();
                    if (el instanceof HTMLElement) this._element.appendChild(el);
                }
            });
            return this._element;
        }
    }
    
    function UI_VStack(children = []) { return new Stack(children, 'vertical'); }
    function UI_HStack(children = []) { return new Stack(children, 'horizontal'); }
    
    // ============================================
    // SCREEN & NAVIGATION
    // ============================================
    
    class Screen extends Component {
        constructor(title = '', navigationInstance = null) {
            super();
            this._title = title;
            this._navigationTitle = title;
            this._navigationBarHidden = false;
            this._navigationBarTitleDisplayMode = 'large';
            this._toolbarItems = [];
            this._backgroundColor = '#F5F5F7';
            this._content = null;
            this._navigationInstance = navigationInstance;
            this._navigationStack = navigationInstance ? navigationInstance.stack() : (window.PicassoNavigation ? window.PicassoNavigation._stack : []);
        }
        
        navigationTitle(title) { this._navigationTitle = title; return this; }
        navigationBarHidden(hidden = true) { this._navigationBarHidden = hidden; return this; }
        navigationBarTitleDisplayMode(mode) { this._navigationBarTitleDisplayMode = mode; return this; }
        toolbar(items) { this._toolbarItems = items; return this; }
        background(color) { this._backgroundColor = color; return this; }
        content(view) { this._content = view; return this; }
        navigation(nav) {
            this._navigationInstance = nav;
            this._navigationStack = nav ? nav.stack() : [];
            return this;
        }
        
        render() {
            this._element = document.createElement('div');
            this._element.className = 'picasso-screen';
            this._element.style.cssText = `background: ${this._backgroundColor};`;
            
            if (!this._navigationBarHidden) {
                const isLarge = this._navigationBarTitleDisplayMode === 'large';
                const stack = this._navigationInstance ? this._navigationInstance.stack() : (window.PicassoNavigation ? window.PicassoNavigation._stack : []);
                const hasBack = stack.length > 1;
                
                const navBar = document.createElement('div');
                navBar.className = `picasso-navigation-bar ${isLarge ? 'picasso-navigation-bar-large' : 'picasso-navigation-bar-inline'}`;
                
                // Contenedor principal con layout de 3 columnas: [Back] [Title] [Toolbar]
                const container = document.createElement('div');
                container.style.cssText = 'display:flex; align-items:center; width:100%; position:relative; min-height:44px;';
                
                // Columna izquierda: Back button (si existe)
                const leftCol = document.createElement('div');
                leftCol.style.cssText = 'display:flex; align-items:center; flex:0 0 auto; min-width:40px;';
                
                if (hasBack) {
                    const backBtn = document.createElement('button');
                    backBtn.className = 'picasso-navigation-bar-back';
                    backBtn.textContent = '←';
                    backBtn.style.cssText = `
                        background: none; border: none; font-size: 22px; cursor: pointer;
                        color: var(--color-text-primary); padding: 4px 8px 4px 0;
                        border-radius: 40px; min-width: 36px; min-height: 36px;
                        display: flex; align-items: center; justify-content: center;
                        transition: all 0.2s ease; font-family: 'Inter', sans-serif;
                        margin-left: -4px;
                    `;
                    backBtn.onmouseenter = () => { backBtn.style.background = 'rgba(0,0,0,0.03)'; };
                    backBtn.onmouseleave = () => { backBtn.style.background = 'transparent'; };
                    backBtn.onclick = () => {
                        if (this._navigationInstance && this._navigationInstance.pop) {
                            this._navigationInstance.pop();
                        } else if (window.PicassoNavigation) {
                            window.PicassoNavigation.pop();
                        }
                    };
                    leftCol.appendChild(backBtn);
                }
                
                // Columna central: Título (centrado)
                const centerCol = document.createElement('div');
                centerCol.style.cssText = 'flex:1; text-align:center; min-width:0; padding:0 8px;';
                
                const titleEl = document.createElement('span');
                titleEl.className = 'picasso-navigation-bar-title';
                titleEl.textContent = this._navigationTitle;
                if (isLarge) {
                    titleEl.style.cssText = 'font-size:28px; font-weight:700; color:var(--color-text-primary); letter-spacing:-0.02em; display:block; text-align:center;';
                } else {
                    titleEl.style.cssText = 'font-size:17px; font-weight:600; color:var(--color-text-primary); display:block; text-align:center;';
                }
                centerCol.appendChild(titleEl);
                
                // Columna derecha: Toolbar items
                const rightCol = document.createElement('div');
                rightCol.style.cssText = 'display:flex; align-items:center; gap:4px; flex:0 0 auto;';
                
                if (this._toolbarItems.length > 0) {
                    this._toolbarItems.forEach(item => {
                        if (item && item.render) {
                            const el = item.render();
                            if (el instanceof HTMLElement) {
                                if (el.tagName === 'BUTTON') {
                                    el.style.cssText += `
                                        min-width: 36px !important;
                                        min-height: 36px !important;
                                        padding: 0 12px !important;
                                        font-size: 16px !important;
                                        display: flex !important;
                                        align-items: center !important;
                                        justify-content: center !important;
                                    `;
                                }
                                rightCol.appendChild(el);
                            }
                        }
                    });
                }
                
                // Ensamblar
                container.appendChild(leftCol);
                container.appendChild(centerCol);
                container.appendChild(rightCol);
                
                navBar.appendChild(container);
                this._element.appendChild(navBar);
            }
            
            const contentArea = document.createElement('div');
            contentArea.className = 'picasso-screen-content';
            if (this._content && this._content.render) {
                const el = this._content.render();
                if (el instanceof HTMLElement) contentArea.appendChild(el);
            }
            this._element.appendChild(contentArea);
            return this._element;
        }
    }

    function UI_Screen(title = '', navigation = null) {
        return new Screen(title, navigation);
    }
    
    // ============================================
    // TABVIEW - ADAPTATIVO (iOS / macOS)
    // ============================================
    
    class TabView extends Component {
        constructor(tabs = []) {
            super();
            this._tabs = tabs;
            this._selectedIndex = 0;
            this._tintColor = '#0066CC';
            this._backgroundColor = '#F5F5F7';
            this._tabBarBackground = 'rgba(255,255,255,0.7)';
            this._tabBarHeight = 60;
            this._showLabels = true;
            this._onTabChange = null;
            this._contentContainer = null;
            this._tabContainer = null;
            this._layout = 'auto'; // 'auto', 'bottom', 'sidebar'
            this._sidebarWidth = 200;
            this._isDesktop = window.innerWidth >= 768;
        }
        
        tint(color) { this._tintColor = color; return this; }
        background(color) { this._backgroundColor = color; return this; }
        tabBarBackground(color) { this._tabBarBackground = color; return this; }
        tabBarHeight(height) { this._tabBarHeight = height; return this; }
        showLabels(show = true) { this._showLabels = show; return this; }
        onTabChange(callback) { this._onTabChange = callback; return this; }
        layout(mode) { this._layout = mode; return this; }
        sidebarWidth(width) { this._sidebarWidth = width; return this; }
        
        select(index) {
            if (index >= 0 && index < this._tabs.length) {
                this._selectedIndex = index;
                this._renderContent();
                if (this._onTabChange) this._onTabChange(index, this._tabs[index]);
            }
            return this;
        }
        
        render() {
            const isDesktop = this._layout === 'sidebar' || (this._layout === 'auto' && window.innerWidth >= 768);
            this._isDesktop = isDesktop;
            
            this._element = document.createElement('div');
            this._element.className = 'picasso-tabview';
            this._element.style.cssText = `
                display: flex;
                flex-direction: ${isDesktop ? 'row' : 'column'};
                height: 100%;
                min-height: 100vh;
                background: ${this._backgroundColor};
                position: relative;
                overflow: hidden;
            `;
            
            // Contenedor de contenido
            this._contentContainer = document.createElement('div');
            this._contentContainer.className = 'picasso-tabview-content';
            this._contentContainer.style.cssText = `
                flex: 1;
                overflow: hidden;
                position: relative;
                ${isDesktop ? 'order: 2;' : ''}
            `;
            this._element.appendChild(this._contentContainer);
            
            this._renderContent();
            
            // Barra de tabs
            this._tabContainer = document.createElement('div');
            
            if (isDesktop) {
                // SIDEBAR (macOS)
                this._tabContainer.className = 'picasso-tabview-bar-sidebar';
                this._tabContainer.style.cssText = `
                    display: flex;
                    flex-direction: column;
                    align-items: stretch;
                    background: ${this._tabBarBackground};
                    backdrop-filter: blur(30px) saturate(180%);
                    -webkit-backdrop-filter: blur(30px) saturate(180%);
                    border-right: 1px solid rgba(0,0,0,0.04);
                    width: ${this._sidebarWidth}px;
                    min-width: ${this._sidebarWidth}px;
                    flex-shrink: 0;
                    padding: 12px 8px;
                    gap: 4px;
                    position: relative;
                    z-index: 10;
                    box-shadow: 2px 0 12px rgba(0,0,0,0.02);
                    height: 100vh;
                    overflow-y: auto;
                    order: 1;
                `;
                
                this._tabs.forEach((tab, index) => {
                    const item = this._createSidebarItem(tab, index);
                    this._tabContainer.appendChild(item);
                });
                
                // Espaciador flexible
                const spacer = document.createElement('div');
                spacer.style.cssText = 'flex:1;';
                this._tabContainer.appendChild(spacer);
                
            } else {
                // BOTTOM BAR (iOS)
                this._tabContainer.className = 'picasso-tabview-bar-bottom';
                this._tabContainer.style.cssText = `
                    display: flex;
                    align-items: center;
                    justify-content: space-around;
                    background: ${this._tabBarBackground};
                    backdrop-filter: blur(30px) saturate(180%);
                    -webkit-backdrop-filter: blur(30px) saturate(180%);
                    border-top: 1px solid rgba(0,0,0,0.04);
                    height: ${this._tabBarHeight}px;
                    flex-shrink: 0;
                    padding: 0 12px;
                    position: relative;
                    z-index: 10;
                    box-shadow: 0 -2px 12px rgba(0,0,0,0.03);
                    margin: 0 12px 12px 12px;
                    border-radius: 32px;
                    max-width: 97vw;
                    order: 3;
                `;
                
                this._tabs.forEach((tab, index) => {
                    const item = this._createBottomItem(tab, index);
                    this._tabContainer.appendChild(item);
                });
            }
            
            this._element.appendChild(this._tabContainer);
            
            // Resize listener
            this._resizeHandler = () => {
                const nowDesktop = window.innerWidth >= 768;
                if (nowDesktop !== this._isDesktop && this._layout === 'auto') {
                    // Re-renderizar para cambiar layout
                    this._isDesktop = nowDesktop;
                    // Forzamos re-render
                    const parent = this._element.parentNode;
                    if (parent) {
                        const newEl = this.render();
                        parent.replaceChild(newEl, this._element);
                        this._element = newEl;
                    }
                }
            };
            window.addEventListener('resize', this._resizeHandler);
            
            return this._element;
        }
        
        // ===== SIDEBAR ITEM (macOS) =====
        _createSidebarItem(tab, index) {
            const isActive = index === this._selectedIndex;
            const item = document.createElement('div');
            item.className = 'picasso-sidebar-item' + (isActive ? ' active' : '');
            item.style.cssText = `
                display: flex;
                align-items: center;
                gap: 12px;
                padding: 8px 12px;
                border-radius: 8px;
                cursor: pointer;
                transition: all 0.15s ease;
                font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
                font-size: 14px;
                font-weight: ${isActive ? '500' : '400'};
                color: ${isActive ? this._tintColor : '#6C6C70'};
                background: ${isActive ? 'rgba(0,0,0,0.04)' : 'transparent'};
                border: none;
                width: 100%;
                text-align: left;
                user-select: none;
                position: relative;
            `;
            
            // Icono
            const icon = document.createElement('span');
            icon.className = 'picasso-sidebar-icon';
            icon.textContent = tab.icon || '●';
            icon.style.cssText = `
                font-size: 18px;
                line-height: 1;
                color: ${isActive ? this._tintColor : '#8E8E93'};
                transition: color 0.15s ease;
                width: 24px;
                text-align: center;
            `;
            
            // Label
            const label = document.createElement('span');
            label.className = 'picasso-sidebar-label';
            label.textContent = tab.title || '';
            label.style.cssText = `
                font-size: 14px;
                font-weight: ${isActive ? '500' : '400'};
                color: ${isActive ? this._tintColor : '#6C6C70'};
                transition: color 0.15s ease;
                flex: 1;
            `;
            
            item.appendChild(icon);
            item.appendChild(label);
            
            // Efectos hover
            item.onmouseenter = () => {
                if (!isActive) {
                    item.style.background = 'rgba(0,0,0,0.02)';
                }
            };
            item.onmouseleave = () => {
                if (!isActive) {
                    item.style.background = 'transparent';
                }
            };
            
            item.onclick = () => {
                if (index !== this._selectedIndex) {
                    this.select(index);
                }
            };
            
            return item;
        }
        
        // ===== BOTTOM ITEM (iOS) =====
        _createBottomItem(tab, index) {
            const isActive = index === this._selectedIndex;
            const item = document.createElement('div');
            item.className = 'picasso-tab-item-bottom' + (isActive ? ' active' : '');
            item.style.cssText = `
                display: flex;
                flex-direction: column;
                align-items: center;
                justify-content: center;
                gap: 2px;
                cursor: pointer;
                padding: 6px 8px;
                border-radius: 16px;
                min-width: 44px;
                transition: all 0.25s cubic-bezier(0.34, 1.56, 0.64, 1);
                flex: 1;
                max-width: 80px;
                position: relative;
                -webkit-tap-highlight-color: transparent;
                height: 100%;
                background: transparent;
                border: none;
            `;
            
            // Icono
            const icon = document.createElement('span');
            icon.className = 'picasso-tab-icon';
            icon.textContent = tab.icon || '●';
            icon.style.cssText = `
                font-size: 22px;
                transition: all 0.25s cubic-bezier(0.34, 1.56, 0.64, 1);
                color: ${isActive ? this._tintColor : '#8E8E93'};
                line-height: 1;
            `;
            
            // Label
            const label = document.createElement('span');
            label.className = 'picasso-tab-label';
            label.textContent = tab.title || '';
            label.style.cssText = `
                font-size: ${this._showLabels ? '10px' : '0px'};
                font-weight: ${isActive ? '500' : '400'};
                color: ${isActive ? this._tintColor : '#8E8E93'};
                transition: all 0.25s cubic-bezier(0.34, 1.56, 0.64, 1);
                ${!this._showLabels ? 'opacity: 0; height: 0;' : ''}
                text-align: center;
                font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
            `;
            
            // Indicador (línea arriba)
            const indicator = document.createElement('div');
            indicator.className = 'picasso-tab-indicator-bottom';
            indicator.style.cssText = `
                position: absolute;
                top: 0;
                left: 50%;
                transform: translateX(-50%);
                width: ${isActive ? '18px' : '0'};
                height: 3px;
                background: ${this._tintColor};
                border-radius: 4px;
                transition: all 0.35s cubic-bezier(0.34, 1.56, 0.64, 1);
                display: ${isActive ? 'block' : 'none'};
            `;
            
            item.appendChild(indicator);
            item.appendChild(icon);
            item.appendChild(label);
            
            // Hover effect
            item.onmouseenter = () => {
                if (!isActive) {
                    icon.style.color = '#1C1C1E';
                    label.style.color = '#1C1C1E';
                    item.style.background = 'rgba(0,0,0,0.02)';
                    item.style.borderRadius = '16px';
                }
            };
            item.onmouseleave = () => {
                if (!isActive) {
                    icon.style.color = '#8E8E93';
                    label.style.color = '#8E8E93';
                    item.style.background = 'transparent';
                    item.style.borderRadius = '16px';
                }
            };
            
            item.onclick = () => {
                if (index !== this._selectedIndex) {
                    this.select(index);
                }
            };
            
            return item;
        }
        
        _renderContent() {
            if (!this._contentContainer) return;
            const tab = this._tabs[this._selectedIndex];
            if (!tab) return;
            this._contentContainer.innerHTML = '';
            if (tab.view) {
                const view = typeof tab.view === 'function' ? tab.view() : tab.view;
                if (view && view.render) {
                    const el = view.render();
                    if (el instanceof HTMLElement) {
                        el.style.cssText += 'height:100%; overflow-y:auto;';
                        this._contentContainer.appendChild(el);
                    }
                } else if (view instanceof HTMLElement) {
                    this._contentContainer.appendChild(view);
                } else if (typeof view === 'string') {
                    const textEl = document.createElement('div');
                    textEl.textContent = view;
                    textEl.style.cssText = 'padding:20px; color:#1C1C1E; font-size:16px; font-family:Inter;';
                    this._contentContainer.appendChild(textEl);
                }
            }
            this._updateTabBar();
        }
        
        _updateTabBar() {
            if (!this._tabContainer) return;
            const isDesktop = this._layout === 'sidebar' || (this._layout === 'auto' && window.innerWidth >= 768);
            
            if (isDesktop) {
                // Sidebar items
                const items = this._tabContainer.querySelectorAll('.picasso-sidebar-item');
                items.forEach((item, index) => {
                    const isActive = index === this._selectedIndex;
                    const icon = item.querySelector('.picasso-sidebar-icon');
                    const label = item.querySelector('.picasso-sidebar-label');
                    
                    if (icon) icon.style.color = isActive ? this._tintColor : '#8E8E93';
                    if (label) {
                        label.style.color = isActive ? this._tintColor : '#6C6C70';
                        label.style.fontWeight = isActive ? '500' : '400';
                    }
                    item.style.color = isActive ? this._tintColor : '#6C6C70';
                    item.style.background = isActive ? 'rgba(0,0,0,0.04)' : 'transparent';
                    if (isActive) item.classList.add('active');
                    else item.classList.remove('active');
                });
            } else {
                // Bottom items
                const items = this._tabContainer.querySelectorAll('.picasso-tab-item-bottom');
                items.forEach((item, index) => {
                    const isActive = index === this._selectedIndex;
                    const icon = item.querySelector('.picasso-tab-icon');
                    const label = item.querySelector('.picasso-tab-label');
                    const indicator = item.querySelector('.picasso-tab-indicator-bottom');
                    
                    if (icon) icon.style.color = isActive ? this._tintColor : '#8E8E93';
                    if (label) {
                        label.style.color = isActive ? this._tintColor : '#8E8E93';
                        label.style.fontWeight = isActive ? '500' : '400';
                    }
                    if (indicator) {
                        indicator.style.width = isActive ? '18px' : '0';
                        indicator.style.display = isActive ? 'block' : 'none';
                        indicator.style.background = this._tintColor;
                    }
                    if (isActive) item.classList.add('active');
                    else item.classList.remove('active');
                });
            }
        }
    }
    
    function UI_TabView(tabs = []) { return new TabView(tabs); }
    function UI_Tab(title, icon, view) { return { title, icon, view }; }
    
    // ============================================
    // NAVIGATION
    // ============================================
    
    const PicassoNavigation = {
        _stack: [],
        _container: null,
        _isTransitioning: false,
        _transitionDuration: 250,
        _useTransitions: true,
        
        init(container) {
            this._container = container || document.body;
            return this;
        },
        withTransitions(enabled = true) { this._useTransitions = enabled; return this; },
        transitionDuration(ms) { this._transitionDuration = ms; return this; },
        
        async push(view) {
            if (this._isTransitioning) return this;
            if (!this._container) this._container = document.body;
            if (typeof view === 'function') view = view();
            this._stack.push(view);
            if (this._useTransitions) await this._renderWithTransition('push');
            else this._renderImmediate();
            return this;
        },
        
        async pop() {
            if (this._isTransitioning) return this;
            if (this._stack.length <= 1) return this;
            this._stack.pop();
            if (this._useTransitions) await this._renderWithTransition('pop');
            else this._renderImmediate();
            return this;
        },
        
        async popToRoot() {
            if (this._isTransitioning) return this;
            if (this._stack.length <= 1) return this;
            const root = this._stack[0];
            this._stack = [root];
            if (this._useTransitions) await this._renderWithTransition('popToRoot');
            else this._renderImmediate();
            return this;
        },
        
        async replace(view) {
            if (this._isTransitioning) return this;
            if (typeof view === 'function') view = view();
            if (this._stack.length > 0) this._stack.pop();
            this._stack.push(view);
            if (this._useTransitions) await this._renderWithTransition('replace');
            else this._renderImmediate();
            return this;
        },
        
        current() { return this._stack[this._stack.length - 1] || null; },
        stack() { return this._stack; },
        
        _renderImmediate() {
            const current = this.current();
            if (!current) return;
            current._navigationStack = this._stack;
            this._container.innerHTML = '';
            const el = current.render();
            if (el instanceof HTMLElement) this._container.appendChild(el);
        },
        
        async _renderWithTransition(type) {
            this._isTransitioning = true;
            const current = this.current();
            if (!current) { this._isTransitioning = false; return; }
            current._navigationStack = this._stack;
            const newEl = current.render();
            if (!(newEl instanceof HTMLElement)) { this._isTransitioning = false; return; }
            const oldEl = this._container.firstChild;
            if (!oldEl) {
                this._container.appendChild(newEl);
                this._isTransitioning = false;
                return;
            }
            const duration = this._transitionDuration / 1000;
            newEl.style.position = 'absolute';
            newEl.style.top = '0';
            newEl.style.left = '0';
            newEl.style.width = '100%';
            newEl.style.height = '100%';
            newEl.style.opacity = '0';
            newEl.style.transform = 'scale(0.96)';
            newEl.style.transition = `all ${duration}s var(--ease-standard)`;
            newEl.style.pointerEvents = 'none';
            this._container.appendChild(newEl);
            newEl.offsetHeight;
            newEl.style.opacity = '1';
            newEl.style.transform = 'scale(1)';
            newEl.style.pointerEvents = 'auto';
            if (type === 'push' || type === 'replace') {
                oldEl.style.transition = `all ${duration}s var(--ease-standard)`;
                oldEl.style.opacity = '0';
                oldEl.style.transform = 'scale(0.94)';
                oldEl.style.pointerEvents = 'none';
            } else {
                oldEl.style.transition = `all ${duration}s var(--ease-standard)`;
                oldEl.style.opacity = '0';
                oldEl.style.transform = 'translateX(30px) scale(0.96)';
                oldEl.style.pointerEvents = 'none';
            }
            await this._sleep(this._transitionDuration);
            if (oldEl.parentNode) oldEl.remove();
            newEl.style.position = '';
            newEl.style.top = '';
            newEl.style.left = '';
            newEl.style.width = '';
            newEl.style.height = '';
            newEl.style.transition = '';
            newEl.style.pointerEvents = '';
            this._isTransitioning = false;
        },
        _sleep(ms) { return new Promise(resolve => setTimeout(resolve, ms)); }
    };
    
    window.PicassoNavigation = PicassoNavigation;
    
    // ============================================
    // PROXY
    // ============================================
    
    function createEnumProxy() {
        return new Proxy({}, {
            get: function(target, prop) {
                for (let enumType in Enums) {
                    if (Enums[enumType][prop] !== undefined) {
                        return Enums[enumType][prop];
                    }
                }
                return prop;
            }
        });
    }
    
    const _ = createEnumProxy();
    
    // ============================================
    // EXPORTAR
    // ============================================
    
    window.Picasso = Picasso;
    window.UI_button = UI_button;
    window.UI_text = UI_text;
    window.UI_textField = UI_textField;
    window.UI_container = UI_container;
    window.UI_VStack = UI_VStack;
    window.UI_HStack = UI_HStack;
    window.UI_image = UI_image;
    window.UI_icon = UI_icon;
    window.UI_avatar = UI_avatar;
    window.UI_badge = UI_badge;
    window.UI_card = UI_card;
    window.UI_divider = UI_divider;
    window.UI_spacer = UI_spacer;
    window.UI_List = UI_List;
    window.UI_ScrollView = UI_ScrollView;
    window.UI_Screen = UI_Screen;
    window.UI_Navigation = PicassoNavigation;
    window.UI_TabView = UI_TabView;
    window.UI_Tab = UI_Tab;
    window.print = function(...args) { console.log(...args); };
    window._ = _;
    window.UI = {
        style: Enums.style,
        controlSize: Enums.controlSize,
        textStyle: Enums.textStyle,
        fontWeight: Enums.fontWeight,
        color: Enums.color
    };
    
    console.log('🎨 Picasso v2.0 - TabView Adaptativo (iOS/macOS)');
})();