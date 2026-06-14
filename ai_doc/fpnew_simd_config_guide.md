# CV32E40P FPNew 精度拆分配置指南

本文详细说明如何修改 CV32E40P 的参数配置，使 FPNew 浮点单元支持 FP32 精度拆分为 FP16（2-lane SIMD）和 FP8（4-lane SIMD）的向量化运算。

## 背景

### 默认配置现状

当前仓库默认 FPU 配置仅启用 RV32F/FP32 标量运算。关键参数在 [rtl/include/cv32e40p_pkg.sv](../rtl/include/cv32e40p_pkg.sv) 中：

| 参数 | 默认值 | 含义 |
|------|--------|------|
| `C_RVF` | `1'b1` | 启用 IEEE binary32 / RV32F |
| `C_RVD` | `1'b0` | IEEE binary64 不支持 |
| `C_XF16` | `1'b0` | IEEE binary16 半精度扩展关闭 |
| `C_XF16ALT` | `1'b0` | 替代 binary16alt 扩展关闭 |
| `C_XF8` | `1'b0` | 8-bit 浮点扩展关闭 |
| `C_XFVEC` | `1'b0` | 向量化 SIMD 扩展关闭 |

因此 wrapper（[rtl/cv32e40p_fp_wrapper.sv](../rtl/cv32e40p_fp_wrapper.sv)）的配置为：

```systemverilog
FPU_FEATURES: Width=32, EnableVectors=0, EnableNanBox=0,
  FpFmtMask={1'b1, 1'b0, 1'b0, 1'b0, 1'b0},  // 仅 FP32
  IntFmtMask={1'b0, 1'b0, 1'b1, 1'b0}          // 仅 INT32
```

### FPNew 的 SIMD 向量化原理

FPNew 通过 `num_lanes()` 函数自动计算 SIMD lane 数量（[fpnew_pkg.sv:390-392](../rtl/vendor/pulp_platform_fpnew/src/fpnew_pkg.sv#L390-L392)）：

```systemverilog
function automatic int unsigned num_lanes(int unsigned width, fp_format_e fmt, logic vec);
    return vec ? width / fp_width(fmt) : 1;
endfunction
```

当 `Width=32` 且 `EnableVectors=1` 时：

| 格式 | 位宽 | Lane 数 | 行为 |
|------|------|---------|------|
| FP32 | 32-bit | 1 | 标量（无拆分） |
| FP16 / FP16ALT | 16-bit | 2 | 2 个 FP16 并行运算 |
| FP8 | 8-bit | 4 | 4 个 FP8 并行运算 |

`fpnew_opgroup_multifmt_slice` 在 elaborate 时根据 `NUM_SIMD_LANES` 自动生成对应数量的 lane 数据路径（[fpnew_opgroup_multifmt_slice.sv:33](../rtl/vendor/pulp_platform_fpnew/src/fpnew_opgroup_multifmt_slice.sv#L33)）：

```systemverilog
localparam int unsigned NUM_SIMD_LANES = fpnew_pkg::max_num_lanes(Width, FpFmtConfig, EnableVectors);
// EnableVectors=1 且 FpFmtConfig 包含 FP8 → NUM_SIMD_LANES = 4
```

---

## 修改步骤

### 步骤一：修改核心参数包 — cv32e40p_pkg.sv

**文件**：[rtl/include/cv32e40p_pkg.sv](../rtl/include/cv32e40p_pkg.sv) 第 771-774 行

**修改前**（默认仅 FP32 标量）：

```systemverilog
// Transprecision floating-point extensions configuration
parameter bit C_XF16     = 1'b0;  // Is half-precision float extension (Xf16) enabled
parameter bit C_XF16ALT  = 1'b0;  // Is alternative half-precision float extension (Xf16alt) enabled
parameter bit C_XF8      = 1'b0;  // Is quarter-precision float extension (Xf8) enabled
parameter bit C_XFVEC    = 1'b0;  // Is vectorial float extension (Xfvec) enabled
```

**修改后**（启用 FP16 + FP8 + 向量化）：

```systemverilog
// Transprecision floating-point extensions configuration
parameter bit C_XF16     = 1'b1;  // Is half-precision float extension (Xf16) enabled
parameter bit C_XF16ALT  = 1'b0;  // Is alternative half-precision float extension (Xf16alt) enabled
parameter bit C_XF8      = 1'b1;  // Is quarter-precision float extension (Xf8) enabled
parameter bit C_XFVEC    = 1'b1;  // Is vectorial float extension (Xfvec) enabled
```

> **说明**：`C_XF16ALT`（binary16alt，8 位指数 + 7 位尾数）和 `C_XF16`（IEEE binary16，5 位指数 + 10 位尾数）是两个互不依赖的独立半精度格式，可按需分别启用。`C_XFVEC` 是向量化 SIMD 的全局开关，必须设为 1 才能启用多 lane 拆分。

### 步骤二：确认 FPU wrapper 配置 — cv32e40p_fp_wrapper.sv

**文件**：[rtl/cv32e40p_fp_wrapper.sv](../rtl/cv32e40p_fp_wrapper.sv) 第 65-73 行

wrapper 的 `FPU_FEATURES` 已经使用步骤一中的参数，**无需手动修改**。但需确认以下映射正确：

```systemverilog
localparam fpnew_pkg::fpu_features_t FPU_FEATURES = '{
    Width:         C_FLEN,        // = 32（C_RVF=1 时）
    EnableVectors: C_XFVEC,       // ← 改为 1 后自动启用
    EnableNanBox:  1'b0,
    FpFmtMask:     {C_RVF, C_RVD, C_XF16, C_XF8, C_XF16ALT},
    //               FP32  FP64  FP16   FP8   FP16ALT
    IntFmtMask:    {C_XFVEC && C_XF8, C_XFVEC && (C_XF16 || C_XF16ALT), 1'b1, 1'b0}
    //               INT8              INT16                             INT32  INT64
};
```

修改 `C_XF16=1`、`C_XF8=1`、`C_XFVEC=1` 后，该结构体将自动变为：

| 字段 | 改前 | 改后 | 效果 |
|------|------|------|------|
| `EnableVectors` | `0` | `1` | `vectorial_op_i=1` 时生成多 lane |
| `FpFmtMask[0]` (FP32) | `1` | `1` | 不变 |
| `FpFmtMask[2]` (FP16) | `0` | `1` | 生成 FP16 运算单元（含 2-lane SIMD） |
| `FpFmtMask[3]` (FP8) | `0` | `1` | 生成 FP8 运算单元（含 4-lane SIMD） |
| `IntFmtMask[0]` (INT8) | `0` | `1` | 生成 INT8↔FP8 转换单元 |
| `IntFmtMask[1]` (INT16) | `0` | `1` | 生成 INT16↔FP16 转换单元 |

### 步骤三：配置流水线延迟参数

**文件**：[rtl/include/cv32e40p_pkg.sv](../rtl/include/cv32e40p_pkg.sv) 第 777-783 行

新启用的格式需要设定流水线寄存器深度：

```systemverilog
// 原有
parameter int unsigned C_LAT_FP64    = 'd0;
parameter int unsigned C_LAT_FP16    = 'd0;
parameter int unsigned C_LAT_FP16ALT = 'd0;
parameter int unsigned C_LAT_FP8     = 'd0;
parameter int unsigned C_LAT_DIVSQRT = 'd1;
```

| 参数 | 推荐值 | 说明 |
|------|--------|------|
| `C_LAT_FP16` | `0`~`2` | FP16 ADDMUL 流水线深度，0 = 纯组合逻辑 |
| `C_LAT_FP8` | `0`~`2` | FP8 ADDMUL 流水线深度 |
| `C_LAT_FP16ALT` | `0`~`2` | 如启用该格式需设置 |
| `C_LAT_DIVSQRT` | `1`~`3` | 多格式 div/sqrt 后处理流水线 |

延迟值在 wrapper 第 78-79 行通过 `FPU_IMPLEMENTATION.PipeRegs` 传入各操作组：

```systemverilog
localparam fpnew_pkg::fpu_implementation_t FPU_IMPLEMENTATION = '{
    PipeRegs: '{
        '{FPU_ADDMUL_LAT, C_LAT_FP64, C_LAT_FP16, C_LAT_FP8, C_LAT_FP16ALT}, // ADDMUL
        '{default: C_LAT_DIVSQRT},                                            // DIVSQRT
        '{default: FPU_OTHERS_LAT},                                           // NONCOMP
        '{default: FPU_OTHERS_LAT}                                            // CONV
    },
    ...
};
```

> **注意**：`FPU_ADDMUL_LAT` 和 `FPU_OTHERS_LAT` 是顶层参数（[cv32e40p_top.sv](../rtl/cv32e40p_top.sv)），通过实例化传入；其他格式延迟是 package 常量。通常设置 `FPU_ADDMUL_LAT=0` 让格式专用延迟参数独立控制各 lane 的流水深度。

### 步骤四：实例化顶层时确保 FPU 启用

**文件**：实例化 `cv32e40p_top` 的上层模块（通常为 testbench 或 SoC wrapper）

```systemverilog
cv32e40p_top #(
    .FPU             (1),     // 必须为 1
    .FPU_ADDMUL_LAT  (0),     // ADDMUL 流水线深度（0 = 使用 package 常量）
    .FPU_OTHERS_LAT  (0),     // CONV/NONCOMP 流水线深度
    .ZFINX           (0)      // 使用独立 FP 寄存器文件
) u_top (
    ...
);
```

`ZFINX` 参数影响 FP 寄存器是否与整数 GPR 共享。当前 SIMD FP 配置建议 `ZFINX=0`（独立 FP 寄存器文件 f0-f31）。

---

## 硬件生成结果

### 操作组变化对比

| 操作组 | 原配置（仅 FP32） | 新配置（FP32 + FP16 + FP8 + VEC） |
|--------|------------------|----------------------------------|
| **ADDMUL** (FMA/ADD/MUL) | 1 个 MERGED FMA 单元，仅 FP32 | 1 个 MERGED 多格式 FMA，内含 FP32(1-lane) + FP16(2-lane) + FP8(4-lane) |
| **DIVSQRT** (DIV/SQRT) | 1 个 MERGED div/sqrt，仅 FP32 | 1 个 MERGED 多格式 div/sqrt |
| **NONCOMP** (SGNJ/MINMAX/CMP/CLASSIFY) | 1 个 FP32 PARALLEL 单元 | 3 个 PARALLEL 单元：FP32、FP16、FP8 各一个 |
| **CONV** (F2F/F2I/I2F/CPKAB/CPKCD) | FP32↔INT32 转换 | FP32/FP16/FP8 ↔ INT32/INT16/INT8 全组合转换 |

### 面积估算

新配置将增加以下硬件资源：

| 单元 | 估算增加量 | 原因 |
|------|-----------|------|
| FMA 数据路径 | ~1.5-2× | FP16/FP8 lane 共享 merged 数据路径的超集宽度 |
| 非计算单元 | ~2× | 新增 2 个 PARALLEL 格式单元（FP16 + FP8） |
| 转换单元 | ~1.5× | 新增 INT8/INT16 支持和多格式转换逻辑 |
| DIV/SQRT | 变化较小 | MERGED 单元共用迭代核心 |
| 总体 | **约 1.5-2× 面积增长** | 取决于综合优化和库 |

### 寄存器文件影响

FP 寄存器文件宽度由 `C_FLEN` 决定（[cv32e40p_pkg.sv:789-794](../rtl/include/cv32e40p_pkg.sv#L789-L794)）：

```systemverilog
parameter C_FLEN = C_RVD ? 64 :      // D 扩展
                   C_RVF ? 32 :      // F 扩展
                   ...
                   0;
```

由于 `C_RVF=1` 且 `C_RVD=0`，`C_FLEN=32`，FP 寄存器文件仍为 32-bit 宽。FP16/FP8 数据通过 pack/unpack 在 32-bit 寄存器内做 SIMD lane 排列，**不需要加宽寄存器文件**。

---

## SIMD 运算的指令编码

### APU 接口信号

FPNew 的向量化控制通过 APU 接口传递（[cv32e40p_fp_wrapper.sv:55-57](../rtl/cv32e40p_fp_wrapper.sv#L55-L57)）：

```systemverilog
assign {fpu_vec_op, fpu_op_mod, fpu_op}                     = apu_op_i;
assign {fpu_int_fmt, fpu_src_fmt, fpu_dst_fmt, fp_rnd_mode} = apu_flags_i;
```

### 向量化操作语义

| `fpu_vec_op` | `src_fmt` | 操作语义 |
|-------------|-----------|---------|
| `0` | 任意 | 标量操作，仅 lane 0 有效 |
| `1` | FP32 | 1×FP32（等同于标量，`32/32=1` lane） |
| `1` | FP16 或 FP16ALT | **2×FP16 SIMD**：32-bit 寄存器拆为 `{FP16_H, FP16_L}` |
| `1` | FP8 | **4×FP8 SIMD**：32-bit 寄存器拆为 `{FP8_3, FP8_2, FP8_1, FP8_0}` |

### SIMD Mask

`simd_mask_i` 信号（[fpnew_top.sv:30](../rtl/vendor/pulp_platform_fpnew/src/fpnew_top.sv#L30)）可以按 lane 掩码控制每个 lane 使能。当前 wrapper 将 `simd_mask_i` 接地（[cv32e40p_fp_wrapper.sv:114](../rtl/cv32e40p_fp_wrapper.sv#L114)），表示所有 lane 均活跃。如需支持 per-lane 掩码，需修改 wrapper 将 APU flags 中的对应位连接到 `simd_mask_i`。

---

## 验证方法

### 仿真验证

在 `example_tb/core/Makefile` 中通过 define 覆盖参数：

```bash
cd example_tb/core
make custom_fp \
    CFG="+define+C_XF16=1+C_XF8=1+C_XFVEC=1+C_LAT_FP16=1+C_LAT_FP8=1"
```

或直接修改 package 文件后运行完整回归：

```bash
make all
```

### Lint 检查

```bash
cd scripts/lint

# 创建新配置目录
mkdir config_1p_1f_0z_0lat_0c_simd

# 复制基础配置
cp config_1p_1f_0z_0lat_0c/cv32e40p_config_pkg.sv \
   config_1p_1f_0z_0lat_0c_simd/

# 修改 cv32e40p_pkg.sv 中的 C_XF16/C_XF8/C_XFVEC 参数后运行 lint
./lint.sh
```

### 功能验证要点

启用 SIMD 后需重点验证：

1. **标量兼容性**：`fpu_vec_op=0` 时 FP32 标量运算结果应与修改前一致
2. **FP16 SIMD**：2 个独立的 FP16 运算结果分别位于 `result_o[15:0]` 和 `result_o[31:16]`
3. **FP8 SIMD**：4 个独立的 FP8 运算结果分别位于 `result_o[7:0]`、`[15:8]`、`[23:16]`、`[31:24]`
4. **混合精度转换**：FP16↔FP32、FP8↔FP32、FP16↔INT16、FP8↔INT8 等
5. **异常标志累积**：各 lane 的 NV/DZ/OF/UF/NX 应正确 OR 汇总到 `fflags`

### 已知限制

1. **指令集需配套**：CV32E40P 的标准 decoder 需要扩展以支持 Xf16/Xf8/Xfvec 自定义指令的译码。当前 decoder 对非 RV32F 的 FP 操作码会判为 illegal instruction。启用 FP16/FP8/向量格式后需同步修改 decoder 和编译器工具链。

2. **PulpDivsqrt 限制**：当前 wrapper 设置 `PulpDivsqrt=1'b0`（使用 T-Head 开源除法器）。T-Head 除法器仅支持 FP32-only 配置。如需在启用多格式后保留 DIV/SQRT，有两种选择：
   - 使用 PULP DivSqrt（设置 `PulpDivsqrt=1'b1`，需额外引入依赖）
   - 限制 DIV/SQRT 仅在 FP32 格式下使用（通过 decoder 约束）

3. **NaN-boxing**：当前 `EnableNanBox=0`，FP16/FP8 值的高位不做 NaN-boxing 检查。如果未来需要与 RV64D NaN-boxing 兼容，需启用并调整位宽逻辑。

---

## 配置速查表

### 典型配置组合

| 目标场景 | `C_XF16` | `C_XF8` | `C_XFVEC` | 说明 |
|---------|----------|---------|-----------|------|
| 仅 FP32 标量（默认） | 0 | 0 | 0 | 当前配置，面积最小 |
| FP32 + FP16 标量 | 1 | 0 | 0 | 支持 FP16 标量运算，无 SIMD |
| FP32 + FP16 SIMD | 1 | 0 | 1 | 2×FP16 SIMD（AI 推理常用） |
| FP32 + FP8 SIMD | 0 | 1 | 1 | 4×FP8 SIMD（量化训练/推理） |
| 全格式（FP32 + FP16 + FP8 + VEC） | 1 | 1 | 1 | 功能最完整，面积最大 |

### FpFmtMask 位映射

```
FpFmtMask[4:0] = {FP32, FP64, FP16, FP8, FP16ALT}
                  [4]   [3]   [2]   [1]  [0]    （fpnew_pkg 枚举序）
```

### IntFmtMask 位映射

```
IntFmtMask[3:0] = {INT8, INT16, INT32, INT64}
                   [3]    [2]    [1]    [0]   （fpnew_pkg 枚举序）
```

---

## 主要依据

- [rtl/include/cv32e40p_pkg.sv](../rtl/include/cv32e40p_pkg.sv)：FPU 格式常量和参数定义
- [rtl/cv32e40p_fp_wrapper.sv](../rtl/cv32e40p_fp_wrapper.sv)：FPNEW wrapper 配置和实例化
- [rtl/include/cv32e40p_fpu_pkg.sv](../rtl/include/cv32e40p_fpu_pkg.sv)：FPU 类型定义（本地副本）
- [rtl/vendor/pulp_platform_fpnew/src/fpnew_pkg.sv](../rtl/vendor/pulp_platform_fpnew/src/fpnew_pkg.sv)：FPNEW 核心包，含 `num_lanes()`、格式枚举、配置结构体
- [rtl/vendor/pulp_platform_fpnew/src/fpnew_top.sv](../rtl/vendor/pulp_platform_fpnew/src/fpnew_top.sv)：FPNEW 顶层，SIMD mask 处理和操作组仲裁
- [rtl/vendor/pulp_platform_fpnew/src/fpnew_opgroup_multifmt_slice.sv](../rtl/vendor/pulp_platform_fpnew/src/fpnew_opgroup_multifmt_slice.sv)：多格式 SIMD slice，lane 生成核心
- [docs/source/fpu.rst](../docs/source/fpu.rst)：FPU 用户文档
- [rtl/cv32e40p_top.sv](../rtl/cv32e40p_top.sv)：顶层实例化参数
