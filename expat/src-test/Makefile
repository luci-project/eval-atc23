TARGET_DIR ?= .
BUILD_ROOT ?= /builds/target/fbc46fa2be307280648147543c053d05910f7a85/

$(TARGET_DIR)/runtests: runtests.c chardata.c internal.c structdata.c memcheck.c minicheck.c
	gcc -o $@ $^ -L $(BUILD_ROOT)/lib -I $(BUILD_ROOT)/include -lexpat
