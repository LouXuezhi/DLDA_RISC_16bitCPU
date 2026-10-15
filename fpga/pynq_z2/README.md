# PYNQ-Z2

单周期核上板。`pynq_top.v` 是 `cpu_core.v` 的接线加上板级内存映射：
写 `M[0xFF]` → LED0–3，读 `M[0xFE]` → SW0–1。125 MHz 分频到约 30 Hz，BTN0 复位。

```sh
python3 ../../bench/asm.py counter.s > build/prog.hex
cd build && vivado -mode batch -nojournal -source ../build.tcl
openFPGALoader -b pynq_z2 build/pynq_top.bit
```

`counter.s`：LED 上一个 4 位计数器，SW0 = 1 时倒数。
