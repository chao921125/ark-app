/**
 * 酷我(kw)请求参数加密 — 对齐上游 lx-music-mobile `src/utils/musicSdk/kw/utils/crypto.js`
 * 上游依赖 Node Buffer + CryptoJS.DES；此处用 ArkTS 等价实现：
 *  - 算法：DES（单倍密钥，8 字节 key 'ylzsxkwm'）+ ECB 模式 + PKCS7 填充
 *  - 输出：密文 base64 字符串（等价 CryptoJS encrypt(message, keyHex, {mode: ECB, padding: Pkcs7}).toString()）
 * 密钥/算法与上游保持一致，请求端（mobi.kuwo.cn）据此还原参数。
 */
import { util } from '@kit.ArkTS'

/** 上游 crypto.js 的固定 DES 密钥（8 字节） */
const DES_KEY = 'ylzsxkwm'

/** DES 块大小（字节） */
const BLOCK_SIZE = 8

/* ---------------- 标准 DES 置换表（FIPS 46-3，1-based） ---------------- */

// 初始置换 IP（64 → 64）
const IP_TABLE: number[] = [
  58, 50, 42, 34, 26, 18, 10, 2,
  60, 52, 44, 36, 28, 20, 12, 4,
  62, 54, 46, 38, 30, 22, 14, 6,
  64, 56, 48, 40, 32, 24, 16, 8,
  57, 49, 41, 33, 25, 17, 9, 1,
  59, 51, 43, 35, 27, 19, 11, 3,
  61, 53, 45, 37, 29, 21, 13, 5,
  63, 55, 47, 39, 31, 23, 15, 7
]

// 逆初始置换 FP = IP^-1（64 → 64）
const FP_TABLE: number[] = [
  40, 8, 48, 16, 56, 24, 64, 32,
  39, 7, 47, 15, 55, 23, 63, 31,
  38, 6, 46, 14, 54, 22, 62, 30,
  37, 5, 45, 13, 53, 21, 61, 29,
  36, 4, 44, 12, 52, 20, 60, 28,
  35, 3, 43, 11, 51, 19, 59, 27,
  34, 2, 42, 10, 50, 18, 58, 26,
  33, 1, 41, 9, 49, 17, 57, 25
]

// 扩展置换 E（32 → 48）
const E_TABLE: number[] = [
  32, 1, 2, 3, 4, 5,
  4, 5, 6, 7, 8, 9,
  8, 9, 10, 11, 12, 13,
  12, 13, 14, 15, 16, 17,
  16, 17, 18, 19, 20, 21,
  20, 21, 22, 23, 24, 25,
  24, 25, 26, 27, 28, 29,
  28, 29, 30, 31, 32, 1
]

// P 盒置换（32 → 32）
const P_TABLE: number[] = [
  16, 7, 20, 21,
  29, 12, 28, 17,
  1, 15, 23, 26,
  5, 18, 31, 10,
  2, 8, 24, 14,
  32, 27, 3, 9,
  19, 13, 30, 6,
  22, 11, 4, 25
]

// 密钥置换 PC1（64 → 56）
const PC1_TABLE: number[] = [
  57, 49, 41, 33, 25, 17, 9,
  1, 58, 50, 42, 34, 26, 18,
  10, 2, 59, 51, 43, 35, 27,
  19, 11, 3, 60, 52, 44, 36,
  63, 55, 47, 39, 31, 23, 15,
  7, 62, 54, 46, 38, 30, 22,
  14, 6, 61, 53, 45, 37, 29,
  21, 13, 5, 28, 20, 12, 4
]

// 密钥置换 PC2（56 → 48）
const PC2_TABLE: number[] = [
  14, 17, 11, 24, 1, 5,
  3, 28, 15, 6, 21, 10,
  23, 19, 12, 4, 26, 8,
  16, 7, 27, 20, 13, 2,
  41, 52, 31, 37, 47, 55,
  30, 40, 51, 45, 33, 48,
  44, 49, 39, 56, 34, 53,
  46, 42, 50, 36, 29, 32
]

// 16 轮循环左移位数
const SHIFT_TABLE: number[] = [1, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1]

// 8 个 S 盒（各 4 行 x 16 列，按行展开为 64 项）
const SBOX_TABLE: number[][] = [
  [
    14, 4, 13, 1, 2, 15, 11, 8, 3, 10, 6, 12, 5, 9, 0, 7,
    0, 15, 7, 4, 14, 2, 13, 1, 10, 6, 12, 11, 9, 5, 3, 8,
    4, 1, 14, 8, 13, 6, 2, 11, 15, 12, 9, 7, 3, 10, 5, 0,
    15, 12, 8, 2, 4, 9, 1, 7, 5, 11, 3, 14, 10, 0, 6, 13
  ],
  [
    15, 1, 8, 14, 6, 11, 3, 4, 9, 7, 2, 13, 12, 0, 5, 10,
    3, 13, 4, 7, 15, 2, 8, 14, 12, 0, 1, 10, 6, 9, 11, 5,
    0, 14, 7, 11, 10, 4, 13, 1, 5, 8, 12, 6, 9, 3, 2, 15,
    13, 8, 10, 1, 3, 15, 4, 2, 11, 6, 7, 12, 0, 5, 14, 9
  ],
  [
    10, 0, 9, 14, 6, 3, 15, 5, 1, 13, 12, 7, 11, 4, 2, 8,
    13, 7, 0, 9, 3, 4, 6, 10, 2, 8, 5, 14, 12, 11, 15, 1,
    13, 6, 4, 9, 8, 15, 3, 0, 11, 1, 2, 12, 5, 10, 14, 7,
    1, 10, 13, 0, 6, 9, 8, 7, 4, 15, 14, 3, 11, 5, 2, 12
  ],
  [
    7, 13, 14, 3, 0, 6, 9, 10, 1, 2, 8, 5, 11, 12, 4, 15,
    13, 8, 11, 5, 6, 15, 0, 3, 4, 7, 2, 12, 1, 10, 14, 9,
    10, 6, 9, 0, 12, 11, 7, 13, 15, 1, 3, 14, 5, 2, 8, 4,
    3, 15, 0, 6, 10, 1, 13, 8, 9, 4, 5, 11, 12, 7, 2, 14
  ],
  [
    2, 12, 4, 1, 7, 10, 11, 6, 8, 5, 3, 15, 13, 0, 14, 9,
    14, 11, 2, 12, 4, 7, 13, 1, 5, 0, 15, 10, 3, 9, 8, 6,
    4, 2, 1, 11, 10, 13, 7, 8, 15, 9, 12, 5, 6, 3, 0, 14,
    11, 8, 12, 7, 1, 14, 2, 13, 6, 15, 0, 9, 10, 4, 5, 3
  ],
  [
    12, 1, 10, 15, 9, 2, 6, 8, 0, 13, 3, 4, 14, 7, 5, 11,
    10, 15, 4, 2, 7, 12, 9, 5, 6, 1, 13, 14, 0, 11, 3, 8,
    9, 14, 15, 5, 2, 8, 12, 3, 7, 0, 4, 10, 1, 13, 11, 6,
    4, 3, 2, 12, 9, 5, 15, 10, 11, 14, 1, 7, 6, 0, 8, 13
  ],
  [
    4, 11, 2, 14, 15, 0, 8, 13, 3, 12, 9, 7, 5, 10, 6, 1,
    13, 0, 11, 7, 4, 9, 1, 10, 14, 3, 5, 12, 2, 15, 8, 6,
    1, 4, 11, 13, 12, 3, 7, 14, 10, 15, 6, 8, 0, 5, 9, 2,
    6, 11, 13, 8, 1, 4, 10, 7, 9, 5, 0, 15, 14, 2, 3, 12
  ],
  [
    13, 2, 8, 4, 6, 15, 11, 1, 10, 9, 3, 14, 5, 0, 12, 7,
    1, 15, 13, 8, 10, 3, 7, 4, 12, 5, 6, 11, 0, 14, 9, 2,
    7, 11, 4, 1, 9, 12, 14, 2, 0, 6, 10, 13, 15, 3, 5, 8,
    2, 1, 14, 7, 4, 10, 8, 13, 15, 12, 9, 0, 3, 5, 6, 11
  ]
]

/* ---------------- 位级工具（bit array，1 bit = 1 个 number） ---------------- */

function bytesToBits(bytes: Uint8Array): number[] {
  const bits: number[] = new Array<number>(bytes.length * 8)
  for (let i = 0; i < bytes.length; i++) {
    const b = bytes[i]
    for (let j = 0; j < 8; j++) {
      bits[i * 8 + j] = (b >> (7 - j)) & 1
    }
  }
  return bits
}

function bitsToBytes(bits: number[]): Uint8Array {
  const bytes = new Uint8Array(bits.length / 8)
  for (let i = 0; i < bytes.length; i++) {
    let b = 0
    for (let j = 0; j < 8; j++) {
      b = (b << 1) | bits[i * 8 + j]
    }
    bytes[i] = b
  }
  return bytes
}

/** 按表置换（表项 1-based，输入为 bit array） */
function permute(input: number[], table: number[]): number[] {
  const out: number[] = new Array<number>(table.length)
  for (let i = 0; i < table.length; i++) {
    out[i] = input[table[i] - 1]
  }
  return out
}

/** 28 位半钥循环左移 n 位 */
function rotl28(half: number[], n: number): number[] {
  const out: number[] = new Array<number>(28)
  for (let i = 0; i < 28; i++) {
    out[i] = half[(i + n) % 28]
  }
  return out
}

/** 由 8 字节密钥生成 16 个 48 位子密钥 */
function generateSubKeys(keyBytes: Uint8Array): number[][] {
  const keyBits = bytesToBits(keyBytes)
  const pc1 = permute(keyBits, PC1_TABLE)
  let c = pc1.slice(0, 28)
  let d = pc1.slice(28, 56)
  const subKeys: number[][] = []
  for (let r = 0; r < 16; r++) {
    c = rotl28(c, SHIFT_TABLE[r])
    d = rotl28(d, SHIFT_TABLE[r])
    subKeys.push(permute(c.concat(d), PC2_TABLE))
  }
  return subKeys
}

/** 轮函数 f(R, K)：E 扩展 → 与子密钥异或 → 8 组 S 盒 → P 置换 */
function feistel(rightBits: number[], subKey: number[]): number[] {
  const expanded = permute(rightBits, E_TABLE)
  const xored: number[] = new Array<number>(48)
  for (let i = 0; i < 48; i++) {
    xored[i] = expanded[i] ^ subKey[i]
  }
  const sOut: number[] = new Array<number>(32)
  for (let i = 0; i < 8; i++) {
    const base = i * 6
    const row = (xored[base] << 1) | xored[base + 5]
    const col = (xored[base + 1] << 3) | (xored[base + 2] << 2) | (xored[base + 3] << 1) | xored[base + 4]
    const val = SBOX_TABLE[i][row * 16 + col]
    const outBase = i * 4
    sOut[outBase] = (val >> 3) & 1
    sOut[outBase + 1] = (val >> 2) & 1
    sOut[outBase + 2] = (val >> 1) & 1
    sOut[outBase + 3] = val & 1
  }
  return permute(sOut, P_TABLE)
}

/** 加密单个 64 位块（16 轮 Feistel，末轮后交换左右再过 FP） */
function encryptBlock(blockBits: number[], subKeys: number[][]): number[] {
  const ip = permute(blockBits, IP_TABLE)
  let left = ip.slice(0, 32)
  let right = ip.slice(32, 64)
  for (let r = 0; r < 16; r++) {
    const f = feistel(right, subKeys[r])
    const newRight: number[] = new Array<number>(32)
    for (let i = 0; i < 32; i++) {
      newRight[i] = left[i] ^ f[i]
    }
    left = right
    right = newRight
  }
  return permute(right.concat(left), FP_TABLE)
}

export class KwCrypto {
  /**
   * 对齐上游 crypto.js 的 encryptByDES：
   * DES-ECB-PKCS7，key 'ylzsxkwm'，返回 base64 密文字符串。
   */
  static encryptByDES(message: string): string {
    const textEncoder = new util.TextEncoder()
    const plainBytes = textEncoder.encodeInto(message)
    // PKCS7 填充（填充值 = 缺失字节数，1~8）
    const padLen = BLOCK_SIZE - (plainBytes.length % BLOCK_SIZE)
    const padded = new Uint8Array(plainBytes.length + padLen)
    padded.set(plainBytes, 0)
    for (let i = plainBytes.length; i < padded.length; i++) {
      padded[i] = padLen
    }
    const keyEncoder = new util.TextEncoder()
    const subKeys = generateSubKeys(keyEncoder.encodeInto(DES_KEY))
    // 逐块 ECB 加密
    const cipherBits: number[] = []
    for (let off = 0; off < padded.length; off += BLOCK_SIZE) {
      const blockBits = bytesToBits(padded.subarray(off, off + BLOCK_SIZE))
      const encBits = encryptBlock(blockBits, subKeys)
      for (let i = 0; i < encBits.length; i++) {
        cipherBits.push(encBits[i])
      }
    }
    const cipherBytes = bitsToBytes(cipherBits)
    return new util.Base64Helper().encodeToStringSync(cipherBytes, util.Type.BASIC)
  }
}