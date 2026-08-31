// ============================================================
// Kai T-9 Workstation — runtime
// Balanced ternary core, 9-trit bus. ISA: load/add/sub/vadd/...
// ============================================================

let transistors = [];
const MAX_TRANSISTORS = 4500;

// Register file. 16 registers on a 15-trit machine (RISC-style).
//   a0 (acc / r0)    -> return value / accumulator
//   a1..a8 (t0..t7 / r1..r8)   -> temporaries
//   a9..a13 (s0..s4 / r9..r13)  -> saved registers
//   a14 (lr / r14)   -> link register (written by `call`, read for debug)
//   a15 (zero / r15) -> hardwired to 0, writes discarded (read-only).
let registers = {};
function freshRegisters() {
    const r = {};
    for (let i = 0; i < 16; i++) r[`a${i}`] = new Array(15).fill(0);
    return r;
}
registers = freshRegisters();

// Alias -> canonical register name. Both forms are accepted by the parser.
const REG_ALIASES = {
    "acc":  "a0",  "r0":  "a0",
    "t0":   "a1",  "r1":  "a1",
    "t1":   "a2",  "r2":  "a2",
    "t2":   "a3",  "r3":  "a3",
    "t3":   "a4",  "r4":  "a4",
    "t4":   "a5",  "r5":  "a5",
    "t5":   "a6",  "r6":  "a6",
    "t6":   "a7",  "r7":  "a7",
    "t7":   "a8",  "r8":  "a8",
    "s0":   "a9",  "r9":  "a9",
    "s1":   "a10", "r10": "a10",
    "s2":   "a11", "r11": "a11",
    "s3":   "a12", "r12": "a12",
    "s4":   "a13", "r13": "a13",
    "lr":   "a14", "r14": "a14",
    "zero": "a15", "r15": "a15"
};
// Map r0..r15 explicitly
for (let i = 0; i < 16; i++) {
    REG_ALIASES[`r${i}`] = `a${i}`;
}
const ZERO_REG = "a15";

// Resolve any alias to its canonical a0..a8 name. Unknown names
// pass through unchanged so that compile-time validation can flag them.
function canonicalReg(name) {
    if (!name) return name;
    if (REG_ALIASES[name]) return REG_ALIASES[name];
    return name;
}
// `zero` is read-only: writes are silently discarded by stepCpu.
function isZeroReg(name) {
    return name === ZERO_REG || name === "zero";
}

let programCounter = 0;
let compiledProgram = [];

// Status flags, written only by ALU ops (add/sub/...). Persistent
// between instructions so that brg/bre/brl can read them later.
//   Z = result is all-zero
//   N = result is negative (sign trit === -1)
//   C = last carry-out (overflow)
let statusFlags = { Z: 0, N: 0, C: 0 };

// Call stack of return addresses (PCs) — supports nested subroutines.
let returnStack = [];

let clockInterval = null;
let clockSpeedHz = 1000;
let isRunning = false;
let clockCyclesCount = 0;

// ============================================================
// Transistor model (analog gate primitives).
// A toy NPN/PNP simulation; only `invert` is currently exercised
// by the ALU, the rest is reserved for future gate composition.
// ============================================================

function makeTransistor(id, type) {
    return { id: id, type: type, base: 0, collector: 0 };
}

function init() {
    transistors = [];
    for (let i = 0; i < MAX_TRANSISTORS; i++) {
        const type = (i % 2 === 0) ? "NPN" : "PNP";
        transistors.push(makeTransistor(i, type));
    }
    renderLedBank();
    setupKeyboardListener();
    setupMouseListener();
    redrawCanvas();
    updateUi("Awaiting program...");
}

function processTransistor(t) {
    if (t.type === "NPN" && t.base === 1) return 1;
    if (t.type === "PNP" && t.base === -1) return -1;
    return 0;
}

function invert(entry) {
    const npn = transistors[0];
    const pnp = transistors[1];
    npn.base = entry;
    pnp.base = entry;

    if (processTransistor(npn) === 1) return -1;
    if (processTransistor(pnp) === -1) return 1;
    return 0;
}

// ============================================================
// Balanced-ternary arithmetic
// ============================================================

// One trit adder with carry-in/out in {-1, 0, +1}.
function adderTrit(a, b, carryIn = 0) {
    const total = a + b + carryIn;
    let sum = 0, carryOut = 0;

    if (total > 1) { sum = total - 3; carryOut = 1; }
    else if (total < -1) { sum = total + 3; carryOut = -1; }
    else { sum = total; carryOut = 0; }

    return { sum: sum, carryOut: carryOut };
}

// 15-trit ALU. Modes: ADD, SUB, VSUB, SCALE_ADD, VADD.
function aluCore(regA, regB, mode = "ADD") {
    let inputA = [...regA];
    let inputB = [...regB];
    let result = new Array(15).fill(0);
    let carry = 0;

    if (mode === "SUB" || mode === "VSUB") {
        inputB = inputB.map(trit => invert(trit));
    }

    if (mode === "SCALE_ADD") {
        inputA.pop();
        inputA.unshift(0);
    }

    for (let i = 0; i < 15; i++) {
        // VADD/VSUB splits the 15 trits into five independent 3-trit lanes
        // by dropping the carry at lane boundaries.
        if ((mode === "VADD" || mode === "VSUB") && (i === 3 || i === 6 || i === 9 || i === 12)) {
            carry = 0;
        }

        const op = adderTrit(inputA[i], inputB[i], carry);
        result[i] = op.sum;
        carry = op.carryOut;
    }

    return { result: result, overflow: carry };
}

// Compute Z/N/C flags from a 15-trit result and a carry/overflow value.
//   Z = 1 if every trit is 0
//   N = 1 if the most significant non-zero trit is -1 (balanced ternary sign)
//   C = the carry-out / overflow (kept as-is from the ALU)
function makeFlags(result, carry) {
    const Z = result.every(t => t === 0) ? 1 : 0;
    let N = 0;
    for (let i = 14; i >= 0; i--) {
        if (result[i] !== 0) {
            N = result[i] === -1 ? 1 : 0;
            break;
        }
    }
    const C = carry !== 0 ? 1 : 0;
    return { Z: Z, N: N, C: C };
}

// Signed integer -> balanced ternary, 15 trits (LSB-first).
function decimalToTernary(val) {
    const trits = new Array(15).fill(0);
    let n = val;

    for (let i = 0; i < 15; i++) {
        let rem = ((n % 3) + 3) % 3;
        n = Math.floor((n - rem) / 3);

        if (rem === 2) {
            rem = -1;
            n += 1;
        }
        trits[i] = rem;
    }
    return trits;
}

// Balanced ternary (LSB-first) -> signed integer.
function ternaryToDecimal(trits) {
    let decimal = 0;
    for (let i = 0; i < trits.length; i++) {
        decimal += trits[i] * Math.pow(3, i);
    }
    return decimal;
}

// ============================================================
// Multiply / divide / remainder
//
// These run logically in a single cycle (like the rest of the ISA), but
// internally they operate on the decimal values of their operands and
// convert back to 9 trits. decimalToTernary() already truncates to 9 trits,
// which is the agreed-upon overflow behaviour for mul (no flag is set —
// the result "wraps" modulo the signed 9-trit range). div/rem check for
// division by zero on the way in; if so, the caller halts the machine.
//
// Division truncates toward zero (C / Java style); rem takes the sign
// of the dividend.
// ============================================================

function mulCore(regA, regB) {
    const a = ternaryToDecimal(regA);
    const b = ternaryToDecimal(regB);
    return decimalToTernary(a * b);
}

// Returns { result, divideByZero } so the caller can decide to halt.
function divCore(regA, regB) {
    const a = ternaryToDecimal(regA);
    const b = ternaryToDecimal(regB);
    if (b === 0) return { divideByZero: true };
    // JS division already truncates toward zero for ints when used with trunc.
    const q = Math.trunc(a / b);
    return { result: decimalToTernary(q), divideByZero: false };
}

function remCore(regA, regB) {
    const a = ternaryToDecimal(regA);
    const b = ternaryToDecimal(regB);
    if (b === 0) return { divideByZero: true };
    // JS % keeps the sign of the dividend — matches C-style truncating division.
    const m = a % b;
    return { result: decimalToTernary(m), divideByZero: false };
}

// ============================================================
// Floating Point (15-trit: 10-trit mantissa, 5-trit exponent)
// Value = Mantissa * 3^Exponent
// ============================================================

function encodeFloat(value) {
    if (value === 0 || !isFinite(value)) return new Array(15).fill(0);
    
    let mantissa = value;
    let exponent = 0;

    // Shift right if mantissa is too large (max 10-trit mantissa = 29524)
    while (Math.abs(mantissa) > 29524 && exponent < 121) {
        mantissa /= 3;
        exponent++;
    }
    
    // Shift left if we have room, to gain precision
    while (Math.abs(mantissa * 3) <= 29524 && Math.abs(mantissa) > 0 && exponent > -121) {
        mantissa *= 3;
        exponent--;
    }

    mantissa = Math.round(mantissa);

    // If rounding pushed it over 29524, adjust once more
    if (Math.abs(mantissa) > 29524) {
        if (exponent < 121) {
            mantissa = Math.round(mantissa / 3);
            exponent++;
        } else {
            mantissa = Math.sign(mantissa) * 29524; // cap at max
        }
    }

    const mTrits = decimalToTernary(mantissa).slice(0, 10);
    const eTrits = decimalToTernary(exponent).slice(0, 5);
    
    return [...mTrits, ...eTrits];
}

function decodeFloat(trits) {
    const mTrits = trits.slice(0, 10);
    const eTrits = trits.slice(10, 15);
    // Pad to 15 trits to use ternaryToDecimal
    const mantissa = ternaryToDecimal([...mTrits, 0, 0, 0, 0, 0]);
    const exponent = ternaryToDecimal([...eTrits, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
    return mantissa * Math.pow(3, exponent);
}

// ============================================================
// Memory Map & Hardware Emulation Layer (Triad-15)
// ============================================================
//   0        .. 1,000,000 : System RAM (Code & Data)
//   1000001  .. 1,008,000 : Framebuffer VRAM (100 x 80 = 8,000 pixels)
//   1008001  .. 1,008,100 : Video MMIO Control Registers
//   1008101  .. 1,008,200 : I/O Peripherals (Keyboard, Timers, RNG)

const RAM_MAX_ADDR   = 1000000;
const VRAM_START     = 1000001;
const VRAM_END       = 1008000;
const MMIO_V_PALETTE = 1008001;
const MMIO_V_FLUSH   = 1008002;
const MMIO_K_ASCII   = 1008101;
const MMIO_K_READY   = 1008102;
const MMIO_TIMER     = 1008103;
const MMIO_RNG       = 1008104;
const MMIO_M_X       = 1008105;
const MMIO_M_Y       = 1008106;
const MMIO_M_BTN     = 1008107;

const STACK_START_ADDR = 999999;
let stackPointer = STACK_START_ADDR;

let systemMemory = new Map(); // Sparse memory map (address -> decimal value)
let keyBuffer = { ascii: 0, ready: 0 };
let mouseState = { x: 0, y: 0, btn: 0 };
let currentPaletteMode = 0; // 0: Green Phosphor, 1: Amber, 2: Cyber Cyan
let waitingForInterrupt = false; // WFI sleep mode state

function shiftTritArray(trits, amount) {
    const res = new Array(15).fill(0);
    if (amount >= 0) {
        for (let i = 0; i < 15 - amount; i++) {
            res[i + amount] = trits[i];
        }
    } else {
        const shift = Math.abs(amount);
        for (let i = shift; i < 15; i++) {
            res[i - shift] = trits[i];
        }
    }
    return res;
}

function notTritArray(trits) {
    return trits.map(t => -t);
}

function andTritArray(tritsA, tritsB) {
    const res = new Array(15).fill(0);
    for (let i = 0; i < 15; i++) {
        if (tritsA[i] === -1 || tritsB[i] === -1) res[i] = -1;
        else if (tritsA[i] === 1 && tritsB[i] === 1) res[i] = 1;
        else res[i] = 0;
    }
    return res;
}

function orTritArray(tritsA, tritsB) {
    const res = new Array(15).fill(0);
    for (let i = 0; i < 15; i++) {
        if (tritsA[i] === 1 || tritsB[i] === 1) res[i] = 1;
        else if (tritsA[i] === -1 && tritsB[i] === -1) res[i] = -1;
        else res[i] = 0;
    }
    return res;
}

// Pseudo-Random Number Generator (Ternary LFSR)
let lfsrState = [1, -1, 0, 1, 1, -1, 0, -1, 1, 0, 1, -1, 0, -1, 1];
function nextRandomTernary() {
    let sum = lfsrState[0];
    sum = adderTrit(sum, lfsrState[1]).sum;
    sum = adderTrit(sum, lfsrState[13]).sum;
    sum = adderTrit(sum, lfsrState[14]).sum;

    const res = new Array(15).fill(0);
    for (let i = 0; i < 14; i++) {
        res[i] = lfsrState[i+1];
    }
    res[14] = sum;
    lfsrState = res;
    return res.slice();
}

function compareTernary(regA, regB) {
    for (let i = 14; i >= 0; i--) {
        if (regA[i] > regB[i]) return 1;
        if (regA[i] < regB[i]) return -1;
    }
    return 0;
}

function readMemory(addr) {
    if (addr === MMIO_K_ASCII) {
        const charCode = keyBuffer.ascii;
        keyBuffer.ready = 0; // Consume key
        return charCode;
    }
    if (addr === MMIO_K_READY) {
        return keyBuffer.ready;
    }
    if (addr === MMIO_M_X) {
        return mouseState.x;
    }
    if (addr === MMIO_M_Y) {
        return mouseState.y;
    }
    if (addr === MMIO_M_BTN) {
        return mouseState.btn;
    }
    if (addr === MMIO_TIMER) {
        return clockCyclesCount;
    }
    if (addr === MMIO_RNG) {
        return ternaryToDecimal(nextRandomTernary());
    }
    if (addr === MMIO_V_PALETTE) {
        return currentPaletteMode;
    }

    return systemMemory.get(addr) || 0;
}

function writeMemory(addr, val) {
    systemMemory.set(addr, val);

    // VRAM Write -> Draw pixel on Canvas immediately
    if (addr >= VRAM_START && addr <= VRAM_END) {
        const offset = addr - VRAM_START;
        const x = offset % 100;
        const y = Math.floor(offset / 100);
        drawPixel(x, y, val);
    }
    else if (addr === MMIO_V_PALETTE) {
        currentPaletteMode = Math.abs(val) % 3;
        redrawCanvas();
    }
    else if (addr === MMIO_V_FLUSH) {
        redrawCanvas();
    }
}

function getPixelColor(val) {
    if (currentPaletteMode === 0) { // Phosphor Green
        if (val === 1) return "#c8e6a0";
        if (val === -1) return "#3a4a2c";
        if (val === 0) return "#080c06";
        return val < 0 ? "#3a4a2c" : "#c8e6a0";
    }
    if (currentPaletteMode === 1) { // Amber
        if (val === 1) return "#ffb000";
        if (val === -1) return "#5c3e00";
        if (val === 0) return "#0c0800";
        return val < 0 ? "#5c3e00" : "#ffb000";
    }
    if (currentPaletteMode === 2) { // Cyan
        if (val === 1) return "#76a5af";
        if (val === -1) return "#1e3a40";
        if (val === 0) return "#04080a";
        return val < 0 ? "#1e3a40" : "#76a5af";
    }
    return "#c8e6a0";
}

function drawPixel(x, y, val) {
    const canvas = document.getElementById("crtCanvas");
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    ctx.fillStyle = getPixelColor(val);
    ctx.fillRect(x, y, 1, 1);
}

function redrawCanvas() {
    const canvas = document.getElementById("crtCanvas");
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    ctx.fillStyle = getPixelColor(0);
    ctx.fillRect(0, 0, 100, 80);

    for (let addr = VRAM_START; addr <= VRAM_END; addr++) {
        const val = systemMemory.get(addr);
        if (val !== undefined && val !== 0) {
            const offset = addr - VRAM_START;
            const x = offset % 100;
            const y = Math.floor(offset / 100);
            drawPixel(x, y, val);
        }
    }
}

function setupKeyboardListener() {
    window.addEventListener("keydown", (e) => {
        if (document.activeElement && document.activeElement.tagName === "TEXTAREA") return;
        
        if (e.key.length === 1) {
            keyBuffer.ascii = e.key.charCodeAt(0);
            keyBuffer.ready = 1;
            const statusEl = document.getElementById("crtStatus");
            if (statusEl) statusEl.textContent = `KEY: ${e.key.toUpperCase()}`;
        }
    });
}

function setupMouseListener() {
    const canvas = document.getElementById("crtCanvas");
    if (!canvas) return;

    canvas.addEventListener("mousemove", (e) => {
        const rect = canvas.getBoundingClientRect();
        const scaleX = 100 / rect.width;
        const scaleY = 80 / rect.height;
        mouseState.x = Math.floor((e.clientX - rect.left) * scaleX);
        mouseState.y = Math.floor((e.clientY - rect.top) * scaleY);
        mouseState.x = Math.max(0, Math.min(99, mouseState.x));
        mouseState.y = Math.max(0, Math.min(79, mouseState.y));
    });

    canvas.addEventListener("mousedown", (e) => {
        if (e.button === 0) mouseState.btn = 1;
        else if (e.button === 2) mouseState.btn = 2;
    });

    canvas.addEventListener("mouseup", (e) => {
        mouseState.btn = 0;
    });

    canvas.addEventListener("contextmenu", (e) => e.preventDefault());
}

// ============================================================
// Assembler
// ============================================================

const OPCODES = {
    "load":      "LOAD_IMM",
    "sw":        "SW",     // sw srcReg, [addrReg_or_imm] -> store word in memory
    "lw":        "LW",     // lw destReg, [addrReg_or_imm] -> load word from memory
    "add":       "ADD",
    "sub":       "SUB",
    "vsub":      "VSUB",
    "scale_add": "SCALE_ADD",
    "vadd":      "VADD",
    "mul":       "MUL",    // mul a, b, c  -> a = b * c  (truncated to 15 trits)
    "div":       "DIV",    // div a, b, c  -> a = b / c  (toward zero)
    "rem":       "REM",    // rem a, b, c  -> a = b % c  (sign of dividend)
    "fadd":      "FADD",
    "fsub":      "FSUB",
    "fmul":      "FMUL",
    "fdiv":      "FDIV",
    "cmp":       "CMP",    // cmp a, b     -> sub zero, a, b (alias)
    "shl":       "SHL",    // shl dest, src, amount
    "shr":       "SHR",    // shr dest, src, amount
    "not_t":     "NOT_T",  // not_t dest, src
    "and_t":     "AND_T",  // and_t dest, src1, src2
    "or_t":      "OR_T",   // or_t dest, src1, src2
    "push":      "PUSH",   // push src
    "pop":       "POP",    // pop dest
    "mov":       "MOV",    // mov a, b     -> a = b      (zero as dest is a no-op)
    "clr":       "CLR",
    "jmp":       "JMP",
    "brg":       "BRG",   // branch if greater  (N==0 && Z==0)
    "bre":       "BRE",   // branch if equal    (Z==1)
    "brl":       "BRL",   // branch if less     (N==1)
    "call":      "CALL",  // call <label> — push return PC, jump
    "retf":      "RETF",  // return from subroutine — pop PC
    "ret":       "RETI",  // halt the machine (hard stop)
    "wfi":       "WFI",   // wait for interrupt (low-power sleep until keypress/event)
    "nop":       "NOP",   // no operation (delay 1 cycle)
    "min":       "MIN",   // min dest, src1, src2
    "max":       "MAX",   // max dest, src1, src2
    "abs":       "ABS",   // abs dest, src
    "rand":      "RAND"   // rand dest -> generate random number into dest
};

// Expected operand count per opcode.
//   3 operands -> <op> <regD>, <src1>, <src2>     ALU ops + mul/div/rem + float + shl/shr/and_t/or_t + min/max
//   2 operands -> load <reg>, <imm>  |  mov <regD>, <regS>  |  sw/lw <reg>, <addr>  |  cmp/not_t/abs <a, b>
//   1 operand  -> clr <reg>  |  push/pop/rand <reg>  |  jmp/brg/bre/brl/call <label>
//   0 operands -> retf | ret | wfi | nop
const operandCount = {
    "load": 2, "sw": 2, "lw": 2, "cmp": 2, "not_t": 2, "abs": 2,
    "add": 3, "sub": 3, "vsub": 3, "scale_add": 3, "vadd": 3,
    "mul": 3, "div": 3, "rem": 3, "fadd": 3, "fsub": 3, "fmul": 3, "fdiv": 3,
    "shl": 3, "shr": 3, "and_t": 3, "or_t": 3, "min": 3, "max": 3,
    "mov": 2, "clr": 1, "push": 1, "pop": 1, "rand": 1,
    "jmp": 1, "brg": 1, "bre": 1, "brl": 1,
    "call": 1, "retf": 0, "ret": 0, "wfi": 0, "nop": 0
};

// Opcodes whose single operand should be a label (not a register).
const LABEL_JUMP_OPS = new Set(["JMP", "BRG", "BRE", "BRL", "CALL"]);

function resolveSymbol(operand, labels, equs) {
    if (!operand) return operand;
    if (equs[operand] !== undefined) return equs[operand];
    if (labels[operand] !== undefined) return labels[operand];
    return operand;
}

function compileAndLoad() {
    const code = document.getElementById("asmCode").value;
    const lines = code.split("\n");
    const errors = [];
    compiledProgram = [];

    // ===== Pass 1: parse directives (.equ, .data, .text, .string, .word) & labels =====
    const labels = {};
    const equs = {}; // Constant map: NAME -> VALUE (number)
    let currentDataAddr = 500; // Static RAM data starts at 500
    let instrCount = 0;
    const cleaned = [];

    for (let i = 0; i < lines.length; i++) {
        let line = lines[i].split("//")[0].trim();
        if (!line) continue;

        // .equ CONST_NAME, VALUE
        if (line.startsWith(".equ")) {
            const parts = line.replace(/,/g, "").split(/\s+/);
            if (parts.length >= 3) {
                const constName = parts[1];
                let constVal = parts[2];
                if (equs[constVal] !== undefined) constVal = equs[constVal];
                equs[constName] = parseInt(constVal) || constVal;
            }
            continue;
        }

        // Section directives (.text, .data)
        if (line === ".text" || line === ".data") continue;

        // Static data directives: label: .string "text" or label: .word 10, 20
        let labelName = null;
        if (line.includes(":")) {
            const parts = line.split(":");
            labelName = parts[0].trim();
            line = parts.slice(1).join(":").trim();
            if (labelName && !line) { // standalone label
                labels[labelName] = instrCount;
                continue;
            }
        }

        if (line.startsWith(".string")) {
            const match = line.match(/\.string\s+["'](.*)["']/);
            const str = match ? match[1] : "";
            if (labelName) labels[labelName] = currentDataAddr;
            for (let c = 0; c < str.length; c++) {
                systemMemory.set(currentDataAddr++, str.charCodeAt(c));
            }
            systemMemory.set(currentDataAddr++, 0); // Null terminator
            continue;
        }

        if (line.startsWith(".word")) {
            const parts = line.replace(".word", "").replace(/,/g, "").trim().split(/\s+/);
            if (labelName) labels[labelName] = currentDataAddr;
            for (const valStr of parts) {
                let val = valStr;
                if (equs[val] !== undefined) val = equs[val];
                systemMemory.set(currentDataAddr++, parseInt(val) || 0);
            }
            continue;
        }

        if (labelName) {
            labels[labelName] = instrCount;
        }

        cleaned.push({ source: line, lineNo: i });
        instrCount++;
    }

    // ===== Pass 2: parse + resolve labels & constants, validate operand counts =====
    for (const { source: line, lineNo } of cleaned) {
        let parts = line.replace(/,/g, "").split(/\s+/);
        const cmd = parts[0];
        const expected = operandCount[cmd];

        if (OPCODES[cmd] === undefined) {
            errors.push(`Line ${lineNo + 1}: unknown instruction "${cmd}"`);
            continue;
        }

        let operands = parts.slice(1);
        if (operands.length !== expected) {
            errors.push(
                `Line ${lineNo + 1}: "${cmd}" expects ${expected} operand(s), got ${operands.length}`
            );
            continue;
        }

        const opcode = OPCODES[cmd];

        // Jump / call targets are labels (kept as-is). Every other operand
        // is a register name; normalize aliases to their canonical a0..a15.
        let inst;
        if (LABEL_JUMP_OPS.has(opcode)) {
            const targetStr = operands[0];
            const targetIdx = (labels[targetStr] !== undefined)
                ? labels[targetStr]
                : (equs[targetStr] !== undefined)
                    ? equs[targetStr]
                    : undefined;

            if (targetIdx === undefined) {
                errors.push(`Line ${lineNo + 1}: unknown label "${targetStr}"`);
                continue;
            }
            inst = { sourceLine: line, opcode: opcode, target: targetIdx };
        } else {
            // Resolve symbols (equs or data labels) in operands for non-jump instructions
            operands = operands.map(op => resolveSymbol(op, labels, equs));

            if (opcode === "SW" || opcode === "LW") {
            const op1 = canonicalReg(operands[0]);
            const op2 = canonicalReg(operands[1]);
            const isReg2 = registers[op2] !== undefined;
            inst = {
                sourceLine: line,
                opcode: opcode,
                destReg: op1,
                srcReg1: isReg2 ? op2 : operands[1],
                isIndirect: isReg2
            };
        } else if (opcode === "CMP") {
            const op1 = canonicalReg(operands[0]);
            const op2 = canonicalReg(operands[1]);
            const isReg1 = registers[op1] !== undefined;
            const isReg2 = registers[op2] !== undefined;
            inst = {
                sourceLine: line,
                opcode: opcode,
                destReg: isReg1 ? op1 : operands[0],
                srcReg1: isReg2 ? op2 : operands[1],
                isReg1: isReg1,
                isReg2: isReg2
            };
        } else if (opcode === "NOT_T" || opcode === "ABS") {
            const op1 = canonicalReg(operands[0]);
            const op2 = canonicalReg(operands[1]);
            const isReg2 = registers[op2] !== undefined;
            inst = {
                sourceLine: line,
                opcode: opcode,
                destReg: op1,
                srcReg1: isReg2 ? op2 : operands[1],
                isReg1: isReg2
            };
        } else if (opcode === "PUSH") {
            const op1 = canonicalReg(operands[0]);
            const isReg1 = registers[op1] !== undefined;
            inst = {
                sourceLine: line,
                opcode: opcode,
                destReg: isReg1 ? op1 : operands[0],
                isReg1: isReg1
            };
        } else if (opcode === "POP" || opcode === "RAND") {
            const op1 = canonicalReg(operands[0]);
            inst = {
                sourceLine: line,
                opcode: opcode,
                destReg: op1
            };
        } else {
            const op1 = canonicalReg(operands[0]);
            const op2 = canonicalReg(operands[1]);
            const op3 = canonicalReg(operands[2]);
            const isReg2 = registers[op2] !== undefined;
            const isReg3 = registers[op3] !== undefined;
            inst = {
                sourceLine: line,
                opcode: opcode,
                destReg: op1,
                srcReg1: isReg2 ? op2 : operands[1],
                srcReg2: isReg3 ? op3 : operands[2],
                isReg1: isReg2,
                isReg2: isReg3
            };
        }
    }

        // Validate that register operands exist in the register file.
        const regsToValidate = (opcode === "LOAD_IMM" || opcode === "POP" || opcode === "RAND")
            ? [inst.destReg]
            : (opcode === "PUSH")
                ? [inst.isReg1 ? inst.destReg : undefined]
                : (opcode === "CMP")
                    ? [inst.isReg1 ? inst.destReg : undefined, inst.isReg2 ? inst.srcReg1 : undefined]
                    : (opcode === "NOT_T" || opcode === "ABS")
                        ? [inst.destReg, inst.isReg1 ? inst.srcReg1 : undefined]
                        : (opcode === "SW" || opcode === "LW")
                            ? [inst.destReg, inst.isIndirect ? inst.srcReg1 : undefined]
                            : (opcode === "NOP" || opcode === "WFI" || opcode === "RETI" || opcode === "RETF")
                                ? []
                                : [inst.destReg, inst.isReg1 ? inst.srcReg1 : undefined, inst.isReg2 ? inst.srcReg2 : undefined];

        for (const r of regsToValidate) {
            if (r === undefined) continue;
            if (registers[r] === undefined) {
                errors.push(`Line ${lineNo + 1}: unknown register "${r}"`);
                inst = null;
                break;
            }
        }
        if (inst) compiledProgram.push(inst);
    }

    resetCpu();

    if (errors.length > 0) {
        updateStatus(`Compile failed — ${errors[0]}`);
        console.group("Kai T-9 compile errors");
        errors.forEach(e => console.error(e));
        console.groupEnd();
    }
}

// ============================================================
// Execution
// ============================================================

function stepCpu() {
    if (compiledProgram.length === 0) {
        compileAndLoad();
        if (compiledProgram.length === 0) return;
    }

    // WFI sleep state: CPU pauses execution until a hardware event (keyBuffer.ready) occurs
    if (waitingForInterrupt) {
        if (keyBuffer.ready === 1) {
            waitingForInterrupt = false; // Woken up by hardware interrupt!
            const statusEl = document.getElementById("crtStatus");
            if (statusEl) statusEl.textContent = "WOKEN UP BY INTERRUPT";
        } else {
            // CPU stays in low-power sleep mode during this clock tick
            return;
        }
    }

    if (programCounter >= compiledProgram.length && !waitingForInterrupt) {
        halted = true;
        updateStatus("Program ended.");
        if (isRunning) toggleClock();
        return;
    }

    const inst = compiledProgram[programCounter];
    clockCyclesCount++;

    // Default next PC; jumps/calls overwrite this and skip the normal ++ .
    let tookControlFlow = false;
    let nextPc = programCounter + 1;

    if (inst.opcode === "LOAD_IMM") {
        const val = parseInt(inst.srcReg1) || 0;
        // `zero` is read-only: writes are discarded (no flags touched by load).
        if (inst.destReg !== ZERO_REG) {
            registers[inst.destReg] = decimalToTernary(val);
            paintLeds(registers[inst.destReg]);
        }
    } else if (inst.opcode === "SW") {
        // sw srcReg, addr (addr can be register or immediate)
        const valToStore = ternaryToDecimal(registers[inst.destReg] || new Array(15).fill(0));
        let targetAddr = 0;
        if (inst.isIndirect) {
            targetAddr = ternaryToDecimal(registers[inst.srcReg1] || new Array(15).fill(0));
        } else {
            targetAddr = parseInt(inst.srcReg1) || 0;
        }
        writeMemory(targetAddr, valToStore);
    } else if (inst.opcode === "LW") {
        // lw destReg, addr (addr can be register or immediate)
        let targetAddr = 0;
        if (inst.isIndirect) {
            targetAddr = ternaryToDecimal(registers[inst.srcReg1] || new Array(15).fill(0));
        } else {
            targetAddr = parseInt(inst.srcReg1) || 0;
        }
        const memVal = readMemory(targetAddr);
        if (inst.destReg !== ZERO_REG) {
            registers[inst.destReg] = decimalToTernary(memVal);
            paintLeds(registers[inst.destReg]);
        }
        statusFlags = makeFlags(decimalToTernary(memVal), 0);
        paintFlags();
    } else if (inst.opcode === "CMP") {
        const valA = inst.isReg1 ? (registers[inst.destReg] || new Array(15).fill(0)) : decimalToTernary(parseInt(inst.destReg) || 0);
        const valB = inst.isReg2 ? (registers[inst.srcReg1] || new Array(15).fill(0)) : decimalToTernary(parseInt(inst.srcReg1) || 0);
        const res = aluCore(valA, valB, "SUB");
        statusFlags = makeFlags(res.result, res.overflow);
        paintFlags();
    } else if (inst.opcode === "SHL" || inst.opcode === "SHR") {
        const regA = inst.isReg1 ? (registers[inst.srcReg1] || new Array(15).fill(0)) : decimalToTernary(parseInt(inst.srcReg1) || 0);
        const amt = inst.isReg2 ? ternaryToDecimal(registers[inst.srcReg2] || new Array(15).fill(0)) : (parseInt(inst.srcReg2) || 0);
        const shiftVal = inst.opcode === "SHL" ? amt : -amt;
        const result = shiftTritArray(regA, shiftVal);
        if (inst.destReg !== ZERO_REG) {
            registers[inst.destReg] = result;
            paintLeds(result);
        }
        statusFlags = makeFlags(result, 0);
        paintFlags();
    } else if (inst.opcode === "NOT_T") {
        const valA = inst.isReg1
            ? (registers[inst.srcReg1] || new Array(15).fill(0))
            : decimalToTernary(parseInt(inst.srcReg1) || 0);
        const res = valA.map(t => -t);
        if (inst.destReg !== ZERO_REG) {
            registers[inst.destReg] = res;
            paintLeds(res);
        }
        statusFlags = makeFlags(res, 0);
        paintFlags();
    } else if (inst.opcode === "ABS") {
        const val = inst.isReg1
            ? (registers[inst.srcReg1] || new Array(15).fill(0))
            : decimalToTernary(parseInt(inst.srcReg1) || 0);
        let isNegative = false;
        for (let i = 14; i >= 0; i--) {
            if (val[i] !== 0) {
                if (val[i] === -1) isNegative = true;
                break;
            }
        }
        const resTernary = isNegative ? val.map(t => -t) : val.slice();
        if (inst.destReg !== ZERO_REG) {
            registers[inst.destReg] = resTernary;
            paintLeds(resTernary);
        }
        statusFlags = makeFlags(resTernary, 0);
        paintFlags();
    } else if (inst.opcode === "RAND") {
        const resTernary = nextRandomTernary();
        if (inst.destReg !== ZERO_REG) {
            registers[inst.destReg] = resTernary;
            paintLeds(resTernary);
        }
        statusFlags = makeFlags(resTernary, 0);
        paintFlags();
    } else if (inst.opcode === "AND_T" || inst.opcode === "OR_T") {
        const regA = inst.isReg1 ? (registers[inst.srcReg1] || new Array(15).fill(0)) : decimalToTernary(parseInt(inst.srcReg1) || 0);
        const regB = inst.isReg2 ? (registers[inst.srcReg2] || new Array(15).fill(0)) : decimalToTernary(parseInt(inst.srcReg2) || 0);
        const result = inst.opcode === "AND_T" ? andTritArray(regA, regB) : orTritArray(regA, regB);
        if (inst.destReg !== ZERO_REG) {
            registers[inst.destReg] = result;
            paintLeds(result);
        }
        statusFlags = makeFlags(result, 0);
        paintFlags();
    } else if (inst.opcode === "PUSH") {
        const valToPush = inst.isReg1 ? ternaryToDecimal(registers[inst.destReg] || new Array(15).fill(0)) : (parseInt(inst.destReg) || 0);
        writeMemory(stackPointer, valToPush);
        stackPointer--;
    } else if (inst.opcode === "POP") {
        stackPointer++;
        const valPopped = readMemory(stackPointer);
        if (inst.destReg !== ZERO_REG) {
            registers[inst.destReg] = decimalToTernary(valPopped);
            paintLeds(registers[inst.destReg]);
        }
    } else if (inst.opcode === "CLR") {
        // Clear register: zero all 15 trits (no-op on `zero`, which stays 0).
        if (inst.destReg !== ZERO_REG) {
            registers[inst.destReg] = new Array(15).fill(0);
            paintLeds(registers[inst.destReg]);
        }
    } else if (inst.opcode === "MOV") {
        // mov a, b — copy register b into a. Doesn't touch flags.
        // `zero` as dest is a no-op; `zero` as src just delivers 15 trit 0s.
        if (inst.destReg !== ZERO_REG) {
            const src = registers[inst.srcReg1] || new Array(15).fill(0);
            registers[inst.destReg] = src.slice();
            paintLeds(registers[inst.destReg]);
        }
    } else if (inst.opcode === "MUL") {
        // mul a, b, c → a = b * c  (truncated silently to 15 trits).
        const regA = registers[inst.srcReg1] || new Array(15).fill(0);
        const regB = registers[inst.srcReg2] || new Array(15).fill(0);
        const result = mulCore(regA, regB);
        if (inst.destReg !== ZERO_REG) {
            registers[inst.destReg] = result;
            paintLeds(result);
        }
        statusFlags = makeFlags(result, 0);
        paintFlags();
    } else if (inst.opcode === "DIV" || inst.opcode === "REM") {
        // div/rem a, b, c → a = b (op) c, truncated toward zero (C-style).
        // Division by zero halts the machine — flagged by the helper.
        const regA = registers[inst.srcReg1] || new Array(15).fill(0);
        const regB = registers[inst.srcReg2] || new Array(15).fill(0);
        const out = inst.opcode === "DIV" ? divCore(regA, regB) : remCore(regA, regB);
        if (out.divideByZero) {
            halted = true;
            updateStatus(inst.opcode === "DIV"
                ? "div / 0 — halting."
                : "rem / 0 — halting.");
            programCounter = compiledProgram.length;
            if (isRunning) toggleClock();
            return;
        }
        if (inst.destReg !== ZERO_REG) {
            registers[inst.destReg] = out.result;
            paintLeds(out.result);
        }
        statusFlags = makeFlags(out.result, 0);
        paintFlags();
    } else if (["FADD", "FSUB", "FMUL", "FDIV"].includes(inst.opcode)) {
        const regA = registers[inst.srcReg1] || new Array(15).fill(0);
        const regB = registers[inst.srcReg2] || new Array(15).fill(0);
        const a = decodeFloat(regA);
        const b = decodeFloat(regB);
        let resFloat = 0;
        
        if (inst.opcode === "FADD") resFloat = a + b;
        else if (inst.opcode === "FSUB") resFloat = a - b;
        else if (inst.opcode === "FMUL") resFloat = a * b;
        else if (inst.opcode === "FDIV") {
            if (b === 0) {
                halted = true;
                updateStatus("fdiv / 0 — halting.");
                programCounter = compiledProgram.length;
                if (isRunning) toggleClock();
                return;
            }
            resFloat = a / b;
        }
        
        const result = encodeFloat(resFloat);
        if (inst.destReg !== ZERO_REG) {
            registers[inst.destReg] = result;
            paintLeds(result);
        }
        statusFlags = makeFlags(result, 0);
        paintFlags();
    } else if (inst.opcode === "RETI") {
        halted = true;
        updateStatus("Program ended (ret).");
        programCounter = compiledProgram.length;
        if (isRunning) toggleClock();
        return;
    } else if (inst.opcode === "NOP") {
        // No operation
    } else if (inst.opcode === "WFI") {
        waitingForInterrupt = true;
        updateStatus("CPU Sleeping (wfi) — Waiting for interrupt...");
        const statusEl = document.getElementById("crtStatus");
        if (statusEl) statusEl.textContent = "SLEEPING (WFI)";
        nextPc = programCounter + 1; // Advance PC after wake-up
    } else if (inst.opcode === "JMP") {
        nextPc = inst.target;
        tookControlFlow = true;
    } else if (inst.opcode === "BRG") {
        // Branch if greater (signed): not negative and not zero.
        if (statusFlags.N === 0 && statusFlags.Z === 0) {
            nextPc = inst.target;
            tookControlFlow = true;
        }
    } else if (inst.opcode === "BRE") {
        if (statusFlags.Z === 1) {
            nextPc = inst.target;
            tookControlFlow = true;
        }
    } else if (inst.opcode === "BRL") {
        // Branch if less (signed): sign trit was negative.
        if (statusFlags.N === 1) {
            nextPc = inst.target;
            tookControlFlow = true;
        }
    } else if (inst.opcode === "CALL") {
        // Push return address onto the stack (nested calls) AND mirror it into
        // `lr` (a14) so the link register is also inspectable. retf pops the stack.
        returnStack.push(nextPc);
        registers["a14"] = decimalToTernary(nextPc);
        nextPc = inst.target;
        tookControlFlow = true;
    } else if (inst.opcode === "RETF") {
        // Return from subroutine — pop a return address, if any.
        if (returnStack.length === 0) {
            halted = true;
            updateStatus("retf with empty return stack — halting.");
            programCounter = compiledProgram.length;
            if (isRunning) toggleClock();
            return;
        }
        nextPc = returnStack.pop();
        tookControlFlow = true;
    } else {
        // 3-operand RISC form: dest = src1 OP src2.
        // Accepts both registers and immediate numbers for src1 and src2!
        const regA = inst.isReg1
            ? (registers[inst.srcReg1] || new Array(15).fill(0))
            : decimalToTernary(parseInt(inst.srcReg1) || 0);

        const regB = inst.isReg2
            ? (registers[inst.srcReg2] || new Array(15).fill(0))
            : decimalToTernary(parseInt(inst.srcReg2) || 0);

        if (inst.opcode === "MIN" || inst.opcode === "MAX") {
            const cmp = compareTernary(regA, regB);
            let resTernary;
            if (inst.opcode === "MIN") {
                resTernary = (cmp === -1) ? regA.slice() : regB.slice();
            } else {
                resTernary = (cmp === 1) ? regA.slice() : regB.slice();
            }
            if (inst.destReg !== ZERO_REG) {
                registers[inst.destReg] = resTernary;
                paintLeds(resTernary);
            }
            statusFlags = makeFlags(resTernary, 0);
            paintFlags();
        } else {
            const res = aluCore(regA, regB, inst.opcode);
            if (inst.destReg !== ZERO_REG) {
                registers[inst.destReg] = res.result;
                paintLeds(res.result);
            }
            // ALU ops update Z/N/C; load/clr/jumps leave flags untouched.
            statusFlags = makeFlags(res.result, res.overflow);
            paintFlags();
        }
    }

    programCounter = nextPc;
    // Skip the per-step UI write during fast batches — tickFrame paints once.
    if (!suppressPaint) {
        updateUi(tookControlFlow ? `${inst.sourceLine}  ›` : inst.sourceLine);
    }
}

function resetCpu() {
    registers = freshRegisters();
    systemMemory = new Map();
    stackPointer = STACK_START_ADDR;
    programCounter = 0;
    clockCyclesCount = 0;
    statusFlags = { Z: 0, N: 0, C: 0 };
    returnStack = [];
    halted = false;
    waitingForInterrupt = false;
    paintLeds(new Array(15).fill(0));
    paintFlags();
    redrawCanvas();
    updateUi("CPU reset");
}

// ============================================================
// UI
// ============================================================

function updateStatus(text) {
    const el = document.getElementById("statusReadout");
    if (el) el.textContent = text;
}

function updateUi(lastInstruction) {
    // Update every register's decimal readout + its pin rail.
    for (let i = 0; i < 16; i++) {
        const key = `a${i}`;
        const dec = ternaryToDecimal(registers[key] || new Array(15).fill(0));
        const el = document.getElementById(`reg-${key}`);
        if (el) el.textContent = dec;
        paintRegister(key);
    }

    const pcEl = document.getElementById(`reg-pc`);
    if (pcEl) pcEl.textContent = `${programCounter}/${compiledProgram.length}`;

    updateStatus(`Running: "${lastInstruction}" | Cycle: ${clockCyclesCount}`);
}

// Refresh the Z/N/C LEDs in the register panel.
function paintFlags() {
    if (suppressPaint) return;
    const set = (id, on) => {
        const el = document.getElementById(id);
        if (el) el.classList.toggle("on", !!on);
    };
    set("flag-z", statusFlags.Z);
    set("flag-n", statusFlags.N);
    set("flag-c", statusFlags.C);
}

function renderLedBank() {
    const busContainer = document.getElementById("ledBus");
    if (!busContainer) return;
    busContainer.innerHTML = "";

    // 15 LEDs: 5 lanes of 3 trits (V, W, X, Y, Z)
    const laneLabels = ["Z", "Y", "X", "W", "V"];

    for (let i = 0; i < 15; i++) {
        const cell = document.createElement("div");
        cell.className = "led-cell";

        const led = document.createElement("div");
        led.className = "led neu";
        led.id = `led-${i}`;

        const label = document.createElement("div");
        label.className = "trit-label";
        const laneIndex = Math.floor(i / 3);
        const subIndex = i % 3;
        const laneName = laneLabels[laneIndex] || `L${laneIndex}`;
        label.textContent = `${laneName}${subIndex}`;

        cell.appendChild(led);
        cell.appendChild(label);
        busContainer.appendChild(cell);
    }
}

function paintLeds(trits) {
    if (suppressPaint) return;
    for (let i = 0; i < 15; i++) {
        const led = document.getElementById(`led-${i}`);
        if (!led) continue;
        const estado = trits[i];

        led.className = "led";
        if (estado === 1) led.classList.add("pos");
        else if (estado === -1) led.classList.add("neg");
        else led.classList.add("neu");
    }
}

// Redraw a single register's 15-trit pin rail in the backplane.
function paintRegister(name) {
    if (suppressPaint) return;
    const rail = document.getElementById(`pins-${name}`);
    if (!rail) return;
    const trits = registers[name] || new Array(15).fill(0);
    rail.innerHTML = "";

    for (let i = 14; i >= 0; i--) { // MSB on the left
        const pin = document.createElement("span");
        pin.className = "pin " + (trits[i] === 1 ? "pin-pos" : trits[i] === -1 ? "pin-neg" : "pin-neu");
        pin.title = `trit ${i} = {${trits[i]}}`;
        pin.textContent = trits[i] === 1 ? "+" : trits[i] === -1 ? "−" : "0";
        rail.appendChild(pin);
    }
}

// ============================================================
// Clock
// ============================================================
//
// Two timing modes:
//   Hz <= 60: real-time setInterval, one step per tick. Animation is
//             smooth and each cycle is visible on the LED bus.
//   Hz >  60: requestAnimationFrame with a batch of (Hz/60) steps per
//             frame — throughput is real, but only the *last* step of
//             each frame is painted (intermediate states are invisible
//             to the eye; the program just runs fast). A hard cap on
//             the per-frame batch keeps the browser responsive, so the
//             "10 MHz" position is still a narrative badge rather than
//             a measured 10 MHz — but it is now a fast batch, not 60 Hz.
const FAST_FRAME_HZ = 60;             // approximation of the screen refresh
const FAST_BATCH_LIMIT = 50000;       // cap to keep the browser responsive
let suppressPaint = false;            // skip paints + updateUi mid-batch
let halted = false;                   // machine halted (ret / bad retf / end)
let rafId = null;

function tickClock() {
    stepCpu();
}

function tickFrame() {
    // Run a batch of CPU steps; only paint the final one.
    const steps = Math.min(Math.round(clockSpeedHz / FAST_FRAME_HZ), FAST_BATCH_LIMIT);
    // Remember the last instruction executed so we can show it post-batch.
    let lastSource = "";
    suppressPaint = true;
    for (let i = 0; i < steps; i++) {
        if (!waitingForInterrupt && programCounter >= compiledProgram.length) {
            lastSource = "Program ended.";
            halted = true;
            break;
        }
        lastSource = (compiledProgram[programCounter] || {}).sourceLine || "";
        // stepCpu mutates state; if it halted (ret / bad retf) the loop stops.
        stepCpu();
        if (halted) break;
    }
    suppressPaint = false;
    if (lastSource === "") lastSource = "Program ended.";

    // Paint the final state of the frame once. updateUi already walks every
    // register pin rail; the LED bus shows the last register that was touched.
    updateUi(lastSource + (halted ? "  ‹halted›" : ""));
    const someReg = Object.keys(registers)[0];
    if (someReg) paintLeds(registers[someReg]);
    paintFlags();

    if (isRunning && !halted) rafId = requestAnimationFrame(tickFrame);
    else toggleClock();
}

function startClock() {
    if (clockSpeedHz <= 60) {
        clockInterval = setInterval(tickClock, 1000 / clockSpeedHz);
    } else {
        rafId = requestAnimationFrame(tickFrame);
    }
}

function stopClock() {
    clearInterval(clockInterval);
    if (rafId !== null) {
        cancelAnimationFrame(rafId);
        rafId = null;
    }
    suppressPaint = false;
}

function toggleClock() {
    isRunning = !isRunning;
    const btn = document.getElementById("btnClock");

    if (isRunning) {
        if (btn) btn.textContent = "Stop clock";
        startClock();
    } else {
        if (btn) btn.textContent = "Start clock";
        stopClock();
    }
}

function setClockSpeed(newSpeed) {
    clockSpeedHz = parseInt(newSpeed, 10);
    if (isRunning) {
        stopClock();
        startClock();
    }
}

// Initial paint when the script loads.
init();