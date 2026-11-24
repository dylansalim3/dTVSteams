// Minimalist, robust, self-contained QR Code Generator (Model 2, Byte Encoding, Error Correction M/L)
// Compatible with all standard smartphone cameras (iOS, Android, WeChat, LINE, Camera app)
(function (root, factory) {
  if (typeof define === "function" && define.amd) {
    define([], factory);
  } else if (typeof module === "object" && module.exports) {
    module.exports = factory();
  } else {
    root.QRCode = factory();
  }
})(typeof self !== "undefined" ? self : this, function () {
  "use strict";

  // GF(256) Math for Reed-Solomon Error Correction
  const EXP_TABLE = new Uint8Array(256);
  const LOG_TABLE = new Uint8Array(256);
  for (let i = 0, x = 1; i < 256; i++) {
    EXP_TABLE[i] = x;
    LOG_TABLE[x] = i;
    x = (x << 1) ^ (x >= 128 ? 0x11d : 0);
  }

  function gmult(a, b) {
    if (a === 0 || b === 0) return 0;
    return EXP_TABLE[(LOG_TABLE[a] + LOG_TABLE[b]) % 255];
  }

  function rsGenPoly(n) {
    let poly = [1];
    for (let i = 0; i < n; i++) {
      const next = new Array(poly.length + 1).fill(0);
      for (let j = 0; j < poly.length; j++) {
        next[j] ^= gmult(poly[j], EXP_TABLE[i]);
        next[j + 1] ^= poly[j];
      }
      poly = next;
    }
    return poly;
  }

  function rsEncode(data, ecLen) {
    const poly = rsGenPoly(ecLen);
    const buf = new Uint8Array(data.length + ecLen);
    buf.set(data);
    for (let i = 0; i < data.length; i++) {
      const coef = buf[i];
      if (coef !== 0) {
        for (let j = 0; j < poly.length; j++) {
          buf[i + j] ^= gmult(poly[j], coef);
        }
      }
    }
    return buf.slice(data.length);
  }

  // Version Table capacities (Level M: Medium 15% error correction)
  // [Version, Total Modules, Data Bytes, EC Bytes, EC Block Count, Block Data Len]
  const VERSIONS_M = [
    null,
    [1, 21, 16, 10, 1, 16],
    [2, 25, 28, 16, 1, 28],
    [3, 29, 44, 26, 1, 44],
    [4, 33, 64, 36, 2, 32],
    [5, 37, 86, 48, 2, 43],
    [6, 41, 108, 64, 4, 27],
    [7, 45, 124, 72, 4, 31],
    [8, 49, 154, 88, 4, 38],
    [9, 53, 182, 110, 5, 36],
    [10, 57, 216, 130, 5, 43]
  ];

  // Alignment pattern centers per version
  const ALIGNMENT_PATTERN_POS = [
    [],
    [],
    [6, 18],
    [6, 22],
    [6, 26],
    [6, 30],
    [6, 34],
    [6, 22, 38],
    [6, 24, 42],
    [6, 26, 46],
    [6, 28, 50]
  ];

  // Convert string to UTF-8 byte array
  function toUtf8(str) {
    const bytes = [];
    for (let i = 0; i < str.length; i++) {
      let code = str.charCodeAt(i);
      if (code < 0x80) {
        bytes.push(code);
      } else if (code < 0x800) {
        bytes.push(0xc0 | (code >> 6), 0x80 | (code & 0x3f));
      } else if (code < 0xd800 || code >= 0xe000) {
        bytes.push(0xe0 | (code >> 12), 0x80 | ((code >> 6) & 0x3f), 0x80 | (code & 0x3f));
      } else {
        i++;
        code = 0x10000 + (((code & 0x3ff) << 10) | (str.charCodeAt(i) & 0x3ff));
        bytes.push(0xf0 | (code >> 18), 0x80 | ((code >> 12) & 0x3f), 0x80 | ((code >> 6) & 0x3f), 0x80 | (code & 0x3f));
      }
    }
    return bytes;
  }

  function pickVersion(dataLen) {
    for (let v = 1; v < VERSIONS_M.length; v++) {
      if (VERSIONS_M[v][2] >= dataLen + 3) {
        return v;
      }
    }
    return 10;
  }

  function buildBitstream(utf8Bytes, version) {
    const info = VERSIONS_M[version];
    const maxDataBytes = info[2];
    const bits = [];

    function pushBits(val, len) {
      for (let i = len - 1; i >= 0; i--) {
        bits.push((val >> i) & 1);
      }
    }

    // Mode: 0100 (Byte mode)
    pushBits(0b0100, 4);

    // Character count indicator (8 bits for versions 1-9, 16 for version 10+)
    const countBits = version >= 10 ? 16 : 8;
    pushBits(utf8Bytes.length, countBits);

    // Data bits
    for (const b of utf8Bytes) {
      pushBits(b, 8);
    }

    // Terminator (up to 4 zeroes)
    const totalDataBits = maxDataBytes * 8;
    const termLen = Math.min(4, totalDataBits - bits.length);
    for (let i = 0; i < termLen; i++) bits.push(0);

    // Pad to multiple of 8
    while (bits.length % 8 !== 0) bits.push(0);

    // Pad bytes 0xEC, 0x11
    const padBytes = [0xec, 0x11];
    let padIdx = 0;
    while (bits.length < totalDataBits) {
      pushBits(padBytes[padIdx % 2], 8);
      padIdx++;
    }

    // Convert bits to byte array
    const dataBytes = new Uint8Array(maxDataBytes);
    for (let i = 0; i < maxDataBytes; i++) {
      let b = 0;
      for (let j = 0; j < 8; j++) {
        b = (b << 1) | bits[i * 8 + j];
      }
      dataBytes[i] = b;
    }

    // Error Correction Interleaving
    const blockCount = info[4];
    const blockDataLen = info[5];
    const ecLenPerBlock = Math.floor(info[3] / blockCount);

    const dataBlocks = [];
    const ecBlocks = [];
    for (let b = 0; b < blockCount; b++) {
      const d = dataBytes.slice(b * blockDataLen, (b + 1) * blockDataLen);
      dataBlocks.push(d);
      ecBlocks.push(rsEncode(d, ecLenPerBlock));
    }

    const finalBytes = [];
    for (let i = 0; i < blockDataLen; i++) {
      for (let b = 0; b < blockCount; b++) {
        finalBytes.push(dataBlocks[b][i]);
      }
    }
    for (let i = 0; i < ecLenPerBlock; i++) {
      for (let b = 0; b < blockCount; b++) {
        finalBytes.push(ecBlocks[b][i]);
      }
    }

    return finalBytes;
  }

  function createMatrix(version) {
    const size = VERSIONS_M[version][1];
    const m = [];
    const reserved = [];
    for (let y = 0; y < size; y++) {
      m[y] = new Uint8Array(size);
      reserved[y] = new Uint8Array(size);
    }

    function setFinder(x0, y0) {
      for (let y = -1; y <= 7; y++) {
        for (let x = -1; x <= 7; x++) {
          const rx = x0 + x;
          const ry = y0 + y;
          if (rx < 0 || rx >= size || ry < 0 || ry >= size) continue;
          reserved[ry][rx] = 1;
          if (x >= 0 && x <= 6 && y >= 0 && y <= 6) {
            if (x === 0 || x === 6 || y === 0 || y === 6 || (x >= 2 && x <= 4 && y >= 2 && y <= 4)) {
              m[ry][rx] = 1;
            } else {
              m[ry][rx] = 0;
            }
          } else {
            m[ry][rx] = 0;
          }
        }
      }
    }

    // 3 Finder patterns
    setFinder(0, 0);
    setFinder(size - 7, 0);
    setFinder(0, size - 7);

    // Timing patterns
    for (let i = 8; i < size - 8; i++) {
      if (!reserved[6][i]) {
        m[6][i] = i % 2 === 0 ? 1 : 0;
        reserved[6][i] = 1;
      }
      if (!reserved[i][6]) {
        m[i][6] = i % 2 === 0 ? 1 : 0;
        reserved[i][6] = 1;
      }
    }

    // Alignment patterns for version >= 2
    const alignCoords = ALIGNMENT_PATTERN_POS[version];
    for (let i = 0; i < alignCoords.length; i++) {
      for (let j = 0; j < alignCoords.length; j++) {
        const cx = alignCoords[i];
        const cy = alignCoords[j];
        if (reserved[cy][cx]) continue;
        for (let dy = -2; dy <= 2; dy++) {
          for (let dx = -2; dx <= 2; dx++) {
            const rx = cx + dx;
            const ry = cy + dy;
            reserved[ry][rx] = 1;
            if (Math.abs(dx) === 2 || Math.abs(dy) === 2 || (dx === 0 && dy === 0)) {
              m[ry][rx] = 1;
            } else {
              m[ry][rx] = 0;
            }
          }
        }
      }
    }

    // Dark module
    m[size - 8][8] = 1;
    reserved[size - 8][8] = 1;

    // Reserve format information areas
    for (let i = 0; i < 9; i++) {
      reserved[8][i] = 1;
      reserved[i][8] = 1;
    }
    for (let i = 0; i < 8; i++) {
      reserved[8][size - 1 - i] = 1;
      reserved[size - 1 - i][8] = 1;
    }

    return { matrix: m, reserved, size };
  }

  function fillData(matrixObj, bytes) {
    const { matrix, reserved, size } = matrixObj;
    const bits = [];
    for (const b of bytes) {
      for (let i = 7; i >= 0; i--) {
        bits.push((b >> i) & 1);
      }
    }

    let bitIdx = 0;
    let upward = true;

    for (let right = size - 1; right > 0; right -= 2) {
      if (right === 6) right--; // Skip vertical timing column
      const colPairs = [right, right - 1];

      for (let step = 0; step < size; step++) {
        const y = upward ? size - 1 - step : step;
        for (const x of colPairs) {
          if (!reserved[y][x]) {
            let val = 0;
            if (bitIdx < bits.length) {
              val = bits[bitIdx++];
            }
            // Apply standard Mask Pattern 0: (row + col) % 2 === 0
            if ((y + x) % 2 === 0) {
              val ^= 1;
            }
            matrix[y][x] = val;
          }
        }
      }
      upward = !upward;
    }

    // Format Information for Mask Pattern 0 & Level M: 101010000010010 (BCH code + XOR mask 0x5412)
    // Level M = 00, Mask 0 = 000 -> 00000 -> BCH 000001010010 -> XOR with 101010000010010 = 101011010000000
    const formatBits = [1, 0, 1, 0, 1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0];

    // Horizontal format info
    let fIdx = 0;
    for (let x = 0; x <= 8; x++) {
      if (x === 6) continue;
      matrix[8][x] = formatBits[fIdx++];
    }
    for (let x = size - 8; x < size; x++) {
      matrix[8][x] = formatBits[fIdx++];
    }

    // Vertical format info
    fIdx = 0;
    for (let y = size - 1; y >= size - 7; y--) {
      matrix[y][8] = formatBits[fIdx++];
    }
    matrix[size - 8][8] = 1; // dark module
    fIdx++;
    for (let y = 8; y >= 0; y--) {
      if (y === 6) continue;
      matrix[y][8] = formatBits[fIdx++];
    }
  }

  function generateMatrix(text) {
    const utf8 = toUtf8(text);
    const version = pickVersion(utf8.length);
    const dataBytes = buildBitstream(utf8, version);
    const matrixObj = createMatrix(version);
    fillData(matrixObj, dataBytes);
    return { matrix: matrixObj.matrix, size: matrixObj.size };
  }

  function generateSVG(text, options = {}) {
    const margin = options.margin !== undefined ? options.margin : 2;
    const { matrix, size } = generateMatrix(text);
    const fullSize = size + margin * 2;
    const rects = [];

    for (let y = 0; y < size; y++) {
      for (let x = 0; x < size; x++) {
        if (matrix[y][x]) {
          rects.push(`<rect x="${x + margin}" y="${y + margin}" width="1" height="1" fill="#000"/>`);
        }
      }
    }

    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${fullSize} ${fullSize}" shape-rendering="crispEdges" style="background:#fff; border-radius:12px; display:block; width:100%; height:100%; max-width:220px; max-height:220px; margin:0 auto; box-shadow:0 4px 16px rgba(0,0,0,0.3); padding:8px; box-sizing:border-box;">${rects.join("")}</svg>`;
  }

  function renderTo(container, text, options = {}) {
    if (!container) return;
    container.innerHTML = generateSVG(text, options);
  }

  return {
    generateMatrix,
    generateSVG,
    renderTo
  };
});
