# class_cpu —— 仿真 / 测试 / 看波形
#
#   make sim              跑仿真，生成 addi.vcd
#   make sim TB=<file>    换一个 testbench（默认 testbench/tb_addi_wave.v）
#   make test             跑 testbench/ 下的全部测试程序
#   make wave             sim + 起 surver。波形在 Mac 的 Surfer 里看
#   make serve            只起/重起 surver（波形没变、Surfer 掉线时用）
#   make stop             停掉本项目的 surver
#   make url              打印 Surfer 要填的地址和 ssh 隧道命令
#   make lint             verilator 静态检查
#   make clean            清掉仿真产物
#
# 波形怎么看：服务器只管仿真和 surver，图形界面在你的 Mac 上。
#   1. Mac 上开隧道：  ssh -L 8912:localhost:8912 louxuezhi@LouLinux
#   2. Mac 的 Surfer 里打开 make url 打印的那个地址
# token 存在 .surver-token（已 gitignore），只生成一次，所以重起 surver
# 之后地址不变 —— Surfer 里不用重新填。
#
# RISC-V-CPU 用 8911，这里用 8912，两个项目可以同时开着。

IVERILOG ?= iverilog
VERILATOR ?= verilator
SURVER   ?= $(HOME)/.local/surver-070/bin/surver

PORT     ?= 8912
HOST     ?= louxuezhi@LouLinux
TOKENF   := .surver-token

SRC      := $(wildcard src/*.v)
TB       ?= testbench/tb_addi_wave.v
VCD      := addi.vcd
BUILD    := build

.PHONY: sim test wave serve stop url lint clean help
.DEFAULT_GOAL := help

$(BUILD):
	@mkdir -p $(BUILD)

sim: | $(BUILD)
	$(IVERILOG) -g2005 -Isrc -o $(BUILD)/sim $(TB) $(SRC)
	@./$(BUILD)/sim
	@echo && ls -lh $(VCD)

# testbench/ 下每个 tb_*.v 各跑一遍。程序和期望值写在各自的 testbench 里。
test: | $(BUILD)
	@fail=0; \
	for tb in testbench/tb_*.v; do \
	  echo "=== $$tb ==="; \
	  $(IVERILOG) -g2005 -Isrc -o $(BUILD)/t.out $$tb $(SRC) 2>&1 | grep -v "Not enough words" || true; \
	  ./$(BUILD)/t.out 2>&1 | grep -v "^WARNING\|^VCD" || fail=1; \
	done; \
	if [ $$fail -eq 0 ]; then echo && echo "全部跑完"; else echo && echo "有失败"; exit 1; fi

wave: sim serve

$(TOKENF):
	@head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n' > $(TOKENF)
	@echo "生成 token -> $(TOKENF)（只此一次，之后地址不变）"

serve: $(TOKENF)
	@pkill -f "[s]urver .*--port $(PORT)" 2>/dev/null || true
	@sleep 0.3
	@nohup $(SURVER) --port $(PORT) --bind-address 127.0.0.1 \
	    --token $$(cat $(TOKENF)) $(PWD)/$(VCD) > $(BUILD)/surver.log 2>&1 & \
	  sleep 1
	@$(MAKE) --no-print-directory url

stop:
	@pkill -f "[s]urver .*--port $(PORT)" 2>/dev/null && echo "已停 (port $(PORT))" || echo "本来就没在跑"

url: $(TOKENF)
	@echo
	@echo "1. Mac 上开隧道（保持这个终端别关）："
	@echo "     ssh -L $(PORT):localhost:$(PORT) $(HOST)"
	@echo
	@echo "2. Mac 的 Surfer 里打开："
	@echo "     http://127.0.0.1:$(PORT)/$$(cat $(TOKENF))"
	@echo
	@echo "   重跑 make wave 之后，Surfer 窗口里 reload 一下即可，地址不变。"
	@echo

lint:
	$(VERILATOR) --lint-only -Isrc --top-module cpu_core $(SRC)

clean:
	rm -rf $(BUILD)
	rm -f $(VCD) *.vcd

help:
	@sed -n "2,11p" $(MAKEFILE_LIST)
