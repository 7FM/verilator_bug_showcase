SRC ?= src
INCLUDE_DIR ?= include
SIM_SRC ?= sim_src
V_DIR ?= sim_build

SIM_DEFS ?= -DRUN_SIM

DEFAULT_TOP_MODULE := top

VERILATOR_PREFIX ?=
VERILATOR := $(VERILATOR_PREFIX)verilator

rwildcard=$(foreach d,$(wildcard $(1:=/*)),$(call rwildcard,$d,$2) $(filter $(subst *,%,$2),$d))

srcs := $(call rwildcard,$(INCLUDE_DIR),*.v)
srcs += $(call rwildcard,$(INCLUDE_DIR),*.sv)
srcs += $(call rwildcard,$(SRC),*.v)
srcs += $(call rwildcard,$(SRC),*.sv)

#sim_srcs := $(call rwildcard,$(SIM_SRC),*.cpp)
sim_targets := $(wildcard $(SIM_SRC)/sim_*.cpp)
sim_tops := $(patsubst sim_%.cpp,%,$(notdir $(sim_targets)))

deps := $(call rwildcard,$(V_DIR),*.d)

PWD := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

.PHONY: all clean sim

all: sim

define GEN_SIM_RULES
.PHONY: sim_$(sim_top)

sim_$(sim_top): $$(V_DIR)/$(sim_top)/Vsim_$(sim_top).mk $$(SIM_SRC)/sim_$(sim_top).cpp $$(call rwildcard,$$(SIM_SRC)/$(sim_top),*.cpp) $$(call rwildcard,$$(SIM_SRC)/$(sim_top),*.c) $$(srcs)
	@make -j$$(shell nproc) -C $$(V_DIR)/$(sim_top) -f V$(sim_top).mk V$(sim_top)
	@echo "============================================================================================"

$$(V_DIR)/$(sim_top)/Vsim_$(sim_top).mk: $$(call rwildcard,$$(SIM_SRC)/$(sim_top),*.cpp) $$(call rwildcard,$$(SIM_SRC)/$(sim_top),*.c) $$(srcs)
	@mkdir -p $$(V_DIR)/$(sim_top)
	@mkdir -p $$(V_DIR)/$(sim_top)/$$(SIM_SRC)
	$$(VERILATOR) \
		-Wall -Werror-IMPLICIT -Werror-PINMISSING \
		$$(V_FLAGS) \
		--MMD --MP $$(SIM_DEFS) \
	 	--Mdir $$(V_DIR)/$(sim_top) --cc -O3 \
		-CFLAGS "$$(V_CCFLAGS) -I$$(PWD)$$(SIM_SRC)/$(sim_top)" \
	 	-LDFLAGS "$$(V_LDFLAGS)" \
		-I$$(SRC) \
		--exe $$(PWD)$$(SIM_SRC)/sim_$(sim_top).cpp $$(call rwildcard,$$(PWD)$$(SIM_SRC)/$(sim_top),*.cpp) $$(call rwildcard,$$(PWD)$$(SIM_SRC)/$(sim_top),*.c) \
		-sv --top-module $(sim_top) --trace --trace-structs --trace-underscore $$(srcs) || true
	@echo "============================================================================================"
endef

$(foreach sim_top,$(sim_tops), \
	$(eval $(GEN_SIM_RULES)) \
)

sim: sim_$(DEFAULT_TOP_MODULE)

clean:
	rm -rf $(V_DIR)

-include $(deps)
