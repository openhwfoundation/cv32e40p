# CV32E40P 中 CSR、ALU、乘法器和 FPU 实现总结

本文基于仓库内 README、用户手册和 RTL 阅读整理，重点回答 README 架构图中的 CSR 含义、ALU/乘法器/FPU 支持的运算、精度拆分、除法算法和流水特性。

## 结论速览

- README 架构图中的 **CSR** 指 **Control and Status Registers**，即控制与状态寄存器块，不是算术单元。它支持 CSR 指令语义上的 read/write/set/clear，并实现机器状态、异常/中断、debug、性能计数器、FPU 状态等寄存器。
- 整数 ALU 除法器是 `cv32e40p_alu_div.sv` 中的简单串行整数除法器。数据通路是移位-比较-条件减的二进制串行除法，利用前导位计数预移位以减少迭代次数。它不是吞吐流水除法器，一次只处理一个除法/取余请求，会阻塞 EX。
- ALU 可通过 `vector_mode_i` 拆成 32 位、2x16 位或 4x8 位 lane。可拆分的主要是 CORE-V SIMD 相关 ALU 运算：加/减/平均、移位、min/max、比较、逻辑运算、abs、extract/insert、shuffle/pack，以及部分 16 位复数加减/旋转辅助。标准 RV32I 标量运算、整数除法、bit count/first-one 等不按 SIMD lane 拆分。
- 乘法器支持 RV32M `mul/mulh/mulhsu/mulhu`，CORE-V `mac/msu`，16x16 短乘/带舍入短乘，8 位/16 位点积，以及 16 位复数乘法的实部/虚部计算。乘法精度可拆成 16 位或 8 位用于短乘、点积、复数乘；普通 `mul` 是 32x32 取低 32 位，`mulh*` 通过 16 位部分积多周期完成。
- 本仓库默认 FPU 配置只启用 RV32F/FP32 标量：`C_RVF=1`，`C_RVD/C_XF16/C_XF16ALT/C_XF8/C_XFVEC=0`。因此默认 **FPU 精度不拆分**，不启用 FP16/FP8/vectorial FP。FPNEW 通用代码和 decoder 保留了多格式/向量支持，但当前配置屏蔽。
- 默认 FPU 支持 RV32F 的加、减、乘、除、平方根、融合乘加族、符号注入、min/max、比较、classify、FP32 与 32 位整数转换、move，以及 `fflags/frm/fcsr`。FDIV/FSQRT 为多周期，文档给出 FP32 DIV/SQRT 1..19 cycle。
- 本配置 FPU DIV/SQRT 走 `fpnew_divsqrt_th_32`，内部实例化 OpenE906 FDSU，核心 SRT 单元中使用 SRT quotient/root 生成，商数字包含 -2/-1/0/1/2，属于 radix-4 SRT 风格。它有内部 EX1/EX2/EX3/EX4 和可配置输出寄存器，但从 FPNEW wrapper/FPU 调度角度看不是可连续接收新除法的全流水吞吐单元。
- FPU 外部接口和寄存器文件保存 IEEE 编码的浮点数，不使用对外可见的 recoded 浮点格式。各计算单元内部会解包为 `{sign, exponent, mantissa}`，并在 FMA 等数据通路中使用扩展指数、带隐含位的尾数、guard/round/sticky 等内部宽度。

## CSR：架构图中的含义和操作

CSR 是 `cv32e40p_cs_registers.sv` 中的 **Control and Status Registers**。它负责：

- 浮点 CSR：`fflags`、`frm`、`fcsr`，仅 `FPU=1` 时存在。
- 机器特权 CSR：`mstatus`、`misa`、`mie`、`mtvec`、`mscratch`、`mepc`、`mcause`、`mip` 等。
- debug/trigger CSR：`dcsr`、`dpc`、`dscratch0/1`、`tselect/tdata*` 等。
- 性能计数器 CSR：`mcycle/minstret/mhpmcounter*`、对应 high word、`mcountinhibit/mhpmevent*` 等。
- CORE-V/PULP 自定义只读 CSR：硬件循环寄存器、`uhartid`、`privlv`、`zfinx` 等。
- 可选 PMP 和 user-mode 相关 CSR，受参数控制。

CSR 指令层面的操作枚举在 `cv32e40p_pkg.sv` 中为：

- `CSR_OP_READ`
- `CSR_OP_WRITE`
- `CSR_OP_SET`
- `CSR_OP_CLEAR`

decoder 将 `csrrw/csrrs/csrrc` 以及 immediate 形式映射到上述操作；`rs1=x0` 或 immediate 为 0 的 set/clear 会退化为 read。CSR 写入前的通用变换为：write 直写，set 为 `wdata | old`，clear 为 `~wdata & old`，read 不触发写。之后每个 CSR 再处理自身 WARL/RO、副作用和非法访问条件。

注意：CSR 块不做 ALU 式算术运算。性能计数器的自增、FPU flags 累积、异常入口/返回更新 `mstatus/mepc/mcause` 等属于状态更新逻辑。

## ALU：运算、结构和精度拆分

`cv32e40p_alu.sv` 主要包含以下数据通路：

- 分区加法器：支持标量/向量 lane 的加减，以及 `cv.addN/cv.subN` 一类带右移和可选舍入的运算。
- shifter：支持 SLL/SRL/SRA/ROR，并复用来准备整数除法操作数。
- 比较器：支持 EQ/NE、signed/unsigned GT/GE/LT/LE、SLT/SLE，以及 min/max/abs/clip 的选择。
- bit manipulation：bit extract/insert/clear/set、bit reverse。
- shuffle/pack/extract/insert：服务 CORE-V SIMD。
- bit count/first-one：popcount、ff1、fl1、clb。
- 整数除法子模块：`ALU_DIV/DIVU/REM/REMU` 调用 `cv32e40p_alu_div`。

ALU 精度拆分由 `vector_mode_i` 控制：

- `VEC_MODE32`：1x32 位。
- `VEC_MODE16`：2x16 位。
- `VEC_MODE8`：4x8 位。

可拆分运算按 ISA/实现可归纳为：

- SIMD ALU：`cv.add/sub/avg/avgu/min/minu/max/maxu/srl/sra/sll/or/xor/and/abs` 的 `.h/.b` 形式，含 `.sc/.sci` 标量复制形式。
- SIMD compare：`cmpeq/cmpne/cmpgt/cmpge/cmplt/cmple` 及 unsigned 版本的 `.h/.b`。
- SIMD bit manipulation：`extract/extractu/insert` 的 `.h/.b`。
- SIMD shuffle/pack：`shuffle/shuffle2/pack/pack.h/packhi.b/packlo.b` 等。
- 复数 SIMD 中由 ALU 承担的 16 位复数共轭、加减、subrot 等。

不按 lane 拆分的主要有：

- 整数 DIV/DIVU/REM/REMU。
- popcount/ff1/fl1/clb 这类 bit count 操作。
- 标准 RV32I 标量 ALU 指令本身。

## ALU 整数除法器

整数除法器位于 `rtl/cv32e40p_alu_div.sv`，文件注释称其为 simple serial divider for signed integers。它支持：

- `ALU_DIV`：signed quotient。
- `ALU_DIVU`：unsigned quotient。
- `ALU_REM`：signed remainder。
- `ALU_REMU`：unsigned remainder。

算法结构：

- ALU 前级用 leading-bit/first-one 逻辑计算 `div_shift`，把除数预左移到合适位置。
- divider 内部维护 `AReg`、`BReg`、`ResReg` 和计数器。
- 每轮比较 `AReg` 与 `BReg`，若满足条件则更新余数 `AReg = AReg - BReg`，同时把本轮商 bit 移入 `ResReg`，随后 `BReg` 右移。
- 对有符号情况，通过符号控制和结果取反修正 quotient/remainder 符号。

因此它是串行移位-比较-条件减法的二进制除法器，可理解为 restoring/shift-subtract 风格，不是 SRT，也不是乘法倒数近似。流水特性：

- 不支持吞吐流水；FSM 为 `IDLE/DIVIDE/FINISH`，一次一个请求。
- EX 阶段等待 `OutVld/ready`，除法/取余是多周期阻塞指令。
- 用户手册给出的除法/取余延迟为 3..35 cycle，取决于除数前导 0 数量，除数为 0 时最长。

## 整数乘法器

乘法器位于 `rtl/cv32e40p_mult.sv`，枚举在 `cv32e40p_pkg.sv`：

- `MUL_MAC32`：32 位 multiply-accumulate；标准 `mul` 也映射为 `op_c + op_a * op_b`，`op_c=0`，取低 32 位。
- `MUL_MSU32`：32 位 multiply-subtract，CORE-V `cv.msu`。
- `MUL_I`：16x16 短乘，可选择高/低 half-word，可带右移。
- `MUL_IR`：16x16 短乘，带 rounding。
- `MUL_DOT8`：4 个 8 位 lane 的点积累加。
- `MUL_DOT16`：2 个 16 位 lane 的点积累加；复数乘法也复用这一路径。
- `MUL_H`：标准 `mulh/mulhsu/mulhu` 高 32 位结果。

结构与延迟：

- 普通 `mul` 使用单周期 32x32 乘法器，输出低 32 位。
- `mulh/mulhsu/mulhu` 通过 `STEP0/STEP1/STEP2/FINISH` 分解为多个 16 位部分积，用户手册给出 5 cycle。
- CORE-V MAC/MSU 是 32 位乘加/乘减。
- 短乘从两个 32 位源中选择 16 位 half-word，按 signed mode 扩展为 17 位，得到 34 位中间结果，再按 immediate 右移/舍入。
- 点积把 32 位输入拆成 4x8 或 2x16，分别相乘后求和并加 accumulator。
- 复数乘使用 2x16 表示 `{Im, Re}`，分两条指令分别算实部/虚部，并按 `.div2/.div4/.div8` 或固定缩放右移。

乘法器精度拆分：

- 支持 16 位拆分：短乘、16 位 dot product、16 位复数乘。
- 支持 8 位拆分：8 位 dot product。
- 标准 `mul` 不拆分；`mulh*` 只是内部用 16 位部分积实现 32x32 高半结果，不是 ISA 层面的 SIMD 拆分。

## FPU：支持运算和默认配置

FPU 通过 `cv32e40p_fp_wrapper.sv` 集成 FPNEW，走 APU 接口，参数和常量来自 `cv32e40p_pkg.sv`、`cv32e40p_fpu_pkg.sv` 和 `fpnew_pkg.sv`。

当前仓库默认浮点格式配置：

- `C_RVF = 1`：启用 IEEE binary32 / RV32F。
- `C_RVD = 0`：double 不支持。
- `C_XF16 = 0`、`C_XF16ALT = 0`、`C_XF8 = 0`：半精度、替代半精度、8 位浮点不支持。
- `C_XFVEC = 0`：vectorial FP 不支持。
- wrapper 中 `Width = C_FLEN = 32`，`EnableVectors = 0`，`EnableNanBox = 0`，`FpFmtMask = {FP32=1, 其他=0}`，`IntFmtMask` 只启用 INT32。

因此默认实际支持的 FPU 运算是 RV32F 标量运算：

- `fadd.s`、`fsub.s`：映射到 FPNEW `ADD`，减法通过 `op_mod`。
- `fmul.s`：`MUL`。
- `fdiv.s`：`DIV`。
- `fsqrt.s`：`SQRT`。
- `fmadd.s/fmsub.s/fnmsub.s/fnmadd.s`：`FMADD/FNMSUB` 加 `op_mod`。
- `fsgnj.s/fsgnjn.s/fsgnjx.s`：`SGNJ`。
- `fmin.s/fmax.s`：`MINMAX`。
- `feq.s/flt.s/fle.s`：`CMP`。
- `fclass.s`：`CLASSIFY`。
- `fcvt.w.s/fcvt.wu.s/fcvt.s.w/fcvt.s.wu`：FP32 与 INT32 的有符号/无符号转换。
- `fmv.x.w/fmv.w.x`：通过 `SGNJ` passthrough 实现 move。

FPNEW 通用枚举还包含 `F2F/CPKAB/CPKCD` 以及 FP64/FP16/FP16ALT/FP8/vectorial 指令路径；但在本仓库默认常量下这些路径会被 decoder 判为 illegal 或根本不生成。

## FPU 精度拆分

默认配置下：不支持 FPU 精度拆分。

原因是：

- `C_XFVEC=0`，FPNEW wrapper 的 `EnableVectors=0`。
- `C_XF16/C_XF16ALT/C_XF8=0`，只启用 FP32。
- FPU 输入输出宽度为 32 位，因此不会把一个 32 位字拆成 2xFP16 或 4xFP8。

如果修改包常量启用 FPNEW 的非默认扩展，decoder/FPNEW 里存在精度拆分设计。拆分由 `cv32e40p_fp_wrapper.sv` 中的 `FPU_FEATURES` 和 `FPU_IMPLEMENTATION` 决定：

- `Width = C_FLEN`：本核在有 RVF、无 RVD 时为 32 位数据通路。
- `EnableVectors = C_XFVEC`：只有该参数为 1 时，upper lanes 才真正参与 vectorial FP 运算。
- `FpFmtMask = {C_RVF, C_RVD, C_XF16, C_XF8, C_XF16ALT}`：决定 FP32/FP64/FP16/FP8/FP16ALT 哪些格式生成。
- `UnitTypes`：本 wrapper 配置为 ADDMUL=MERGED、DIVSQRT=MERGED、NONCOMP=PARALLEL、CONV=MERGED。

在 `Width=32` 且启用 `C_XFVEC`、`C_XF16`、`C_XF8` 时，拆分不是把一个 IEEE FP32 数值拆成更低精度，而是把同一个 32 位寄存器/数据通路按较窄格式解释为 packed vector：

- FP16/FP16ALT：32 位通路可容纳 2 个 16 位 lane。
- FP8：32 位通路可容纳 4 个 8 位 lane。
- vectorial FP 指令支持 add/sub/mul/div/min/max/sqrt/mac、move/classify、FP/INT 转换、FP/FP 转换、sgnj、compare、pack 等。

lane 的位布局如下：

- FP32 scalar/vector format：lane0 = bits `[31:0]`，只有 1 个 lane。
- FP16/FP16ALT：lane0 = bits `[15:0]`，lane1 = bits `[31:16]`。
- FP8：lane0 = bits `[7:0]`，lane1 = bits `[15:8]`，lane2 = bits `[23:16]`，lane3 = bits `[31:24]`。

FPNEW 在 multi-format slice 中用 `max_num_lanes(Width, FpFmtMask, EnableVectors)` 决定最大 lane 数；若 FP8 启用且 `Width=32`，最大为 4 lane。`get_lane_formats()` 会按 lane 号筛出该 lane 能承载的格式。若同时启用 FP32、FP16/FP16ALT、FP8，典型 active format mask 是：

- lane0：可承载 FP32、FP16/FP16ALT、FP8。
- lane1：可承载 FP16/FP16ALT、FP8。
- lane2/lane3：只承载 FP8。

资源复用需要按 operation group 分开看：

- ADDMUL 组为 `MERGED`，即 `fadd/fsub/fmul/fmadd` 等走 `fpnew_opgroup_multifmt_slice`。每个 active lane 内实例化一个 `fpnew_fma_multi`，该 lane 内复用同一套多格式 FMA 数据通路：分类器、特殊值处理、指数差/对齐、尾数乘法器、加法器、规格化、舍入和输出流水。lane0 的这套资源既可做 scalar FP32，也可做 FP16 lane0 或 FP8 lane0；lane1/2/3 是为了并行处理 upper lanes 而额外生成的独立 lane-local 资源，不是把 lane0 的 FP32 乘法器在同一周期切分成多个 FP8 乘法器。
- CONV 组为 `MERGED`，FP/INT 转换、FP/FP 转换和 pack 类操作走 `fpnew_cast_multi`。复用方式与 ADDMUL 类似：同一 lane 内多格式转换数据通路复用，多个 vector lane 之间是并行实例。
- DIVSQRT 组配置为 `MERGED`，理论上 multi-format/vector divsqrt 会按 lane 实例化 `fpnew_divsqrt_multi` 并在 lanes 间同步 ready/done；但本 wrapper 固定 `.PulpDivsqrt(1'b0)`，此时 `fpnew_opgroup_multifmt_slice` 明确只支持 FP32-only 的 T-Head/OpenE906 divsqrt。如果要同时启用 FP16/FP8 的 DIV/SQRT，需要改用支持多格式的 PULP divsqrt 路径，即 `PulpDivsqrt=1`，否则多格式配置会在 elaboration 时报错。
- NONCOMP 组为 `PARALLEL`，即 `sgnj/minmax/cmp/classify` 这类非计算操作不是跨格式 merged 复用，而是每个启用格式生成独立 `fpnew_opgroup_fmt_slice`。同一格式内部仍会按 FP16/FP8 lane 并行生成 lane-local `fpnew_noncomp`，但 FP32、FP16、FP8 之间没有共享同一个 noncomp 数据通路。
- 所有组共享顶层调度、operand slicing、result packing、status OR-reduction、valid/ready 汇聚等外围逻辑；真正的数值计算资源是否共享由上述 `UnitTypes` 决定。

因此，所谓 FP32 拆成 2 个 FP16 或 4 个 FP8 lane 时，准确说法是：32 位 FLEN 容器被按较窄格式分 lane 并行计算；lane0 的 multi-format 计算资源可在不同指令/格式间复用，但同一条 vector FP16/FP8 指令的多个 lane 需要各自的 lane-local 计算资源来并行完成。

但这不是当前 CV32E40P 默认配置的行为。

## FPU 除法算法和流水

本仓库 wrapper 对 `fpnew_top` 传入 `.PulpDivsqrt(1'b0)`。在当前 FP32-only 配置下，`fpnew_opgroup_multifmt_slice.sv` 会选择 `fpnew_divsqrt_th_32`，其内部实例化 OpenE906 FDSU。OpenE906 FDSU 的 `pa_fdsu_srt_single.v` 明确包含 SRT remainder/divisor 和 quotient/root generate 逻辑，商数字选择包含 -2、-1、0、1、2，属于 radix-4 SRT 风格。

流水/多周期特性：

- FDIV/FSQRT 是 iterative multi-cycle，decoder 将 DIVSQRT 标记为 APU latency `2'h3`，用户手册给出 FP32 DIV/SQRT 1..19 cycle。
- `fpnew_divsqrt_th_32` 外层 FSM 有 `IDLE/BUSY/HOLD`，同一 lane 中一次主要处理一个 DIV/SQRT 请求；完成后才可接收下一个。因此它不是每周期接收一个新除法的 fully-pipelined divider。
- FDSU 内部有 ex1/ex2/ex3/ex4 等 pipeline/寄存器阶段，FPNEW 外层也可按 `C_LAT_DIVSQRT=1` 加输出后处理寄存器。但这只是内部时序/结果后处理流水，不等同于吞吐流水除法器。

## FPU 内部浮点表示

FPU 外部仍使用 IEEE 编码：

- FP register file、APU operands/result 均是 32 位 IEEE binary32。
- `EnableNanBox=0`，本配置不强制输入 NaN-boxing 检查。

内部计算单元会解包并扩展：

- `fpnew_classifier.sv` 和 `fpnew_fma.sv` 中定义局部 `fp_t`：
  - `sign`：1 bit。
  - `exponent`：`EXP_BITS` bit。
  - `mantissa`：`MAN_BITS` bit。
- 对默认 FP32：`EXP_BITS=8`，`MAN_BITS=23`，外部格式就是 `{sign[31], exponent[30:23], mantissa[22:0]}`。
- classifier 生成 `fp_info_t`：normal/subnormal/zero/inf/nan/signalling/quiet/boxed 等分类位。
- FMA 内部将精度定义为 `PRECISION_BITS = MAN_BITS + 1`，即加入隐含位；默认 FP32 为 24 位有效数。
- FMA 内部指数宽度为 `max(EXP_BITS + 2, clog2(2*PRECISION_BITS+3))`；默认 FP32 为 `max(10, 6)=10` 位 signed exponent container。
- FMA 乘积宽度为 `2*PRECISION_BITS`，默认 48 位；乘加对齐后的内部 addend/sum 宽度为 `3*PRECISION_BITS+4`，默认 76 位，并保留 guard/round/sticky 信息用于规格化和舍入。

所以答案是：FPU 没有对外暴露或寄存器保存的专用 recoded FP 格式；但计算单元内部确实使用了解包后的 `{sign, exponent, mantissa}`、扩展指数、隐含位尾数和 G/R/S 位等内部表示。

## 主要依据

- `README.md`：顶层说明和架构图。
- `docs/source/control_status_registers.rst`：CSR map 和访问规则。
- `docs/source/pipeline.rst`：流水线结构、乘除法/FPU 延迟。
- `docs/source/fpu.rst`：CVFPU/FPNEW 参数配置。
- `docs/source/instruction_set_extensions.rst`：CORE-V ALU/SIMD/MAC 扩展说明。
- `rtl/include/cv32e40p_pkg.sv`：ALU/MUL/CSR 枚举和 FPU 常量。
- `rtl/cv32e40p_alu.sv`、`rtl/cv32e40p_alu_div.sv`：ALU 和整数除法器实现。
- `rtl/cv32e40p_mult.sv`：乘法器、点积、复数乘实现。
- `rtl/cv32e40p_decoder.sv`：指令到 ALU/MUL/FPU/CSR 操作的映射。
- `rtl/cv32e40p_cs_registers.sv`：CSR 状态寄存器实现。
- `rtl/cv32e40p_fp_wrapper.sv`：本核 FPNEW 配置。
- `rtl/vendor/pulp_platform_fpnew/src/*.sv`：FPNEW 操作分组、多格式结构、内部 FMA/非计算/转换/divsqrt 结构。
- `rtl/vendor/pulp_platform_fpnew/vendor/opene906/E906_RTL_FACTORY/gen_rtl/fdsu/rtl/*.v`：OpenE906 FDSU/SRT 除法平方根实现。
