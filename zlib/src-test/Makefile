TARGET_DIR ?= .
BUILD_ROOT ?= /builds/target/04f42ceca40f73e2978b50e93806c2a18c1281fc/

$(TARGET_DIR)/runtests: example.c
	gcc -o $@ $^ -L $(BUILD_ROOT)/lib -I $(BUILD_ROOT)/include -lz
