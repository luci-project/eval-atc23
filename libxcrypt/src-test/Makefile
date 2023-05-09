BUILD_DIR ?= .

CRYPT_SOURCE_DIR ?= libxcrypt
CRYPT_LDFLAGS := -L$(CRYPT_SOURCE_DIR)/.libs -lcrypt

CFLAGS := -DHAVE_CONFIG_H -I. -I$(CRYPT_SOURCE_DIR) -O2
LDFLAGS := -lpthread -ldl $(CRYPT_LDFLAGS)

TEST_KNOWN_ANSWER := $(CRYPT_SOURCE_DIR)/test/ka-tester.c
TEST_KNOWN_ANSWER_ALGORITHMS := bcrypt bcrypt_a bcrypt_x bcrypt_y bigcrypt bsdicrypt descrypt gost_yescrypt md5crypt nt scrypt sha1crypt sha256crypt sha512crypt sunmd5 yescrypt
TEST_CFLAGS := $(CFLAGS) -include test_helper.h -I$(CRYPT_SOURCE_DIR)/lib -fPIC -shared 
TEST_LDFLAGS := -L$(CRYPT_SOURCE_DIR)/.libs -lcrypt
TEST_PREFIX := $(BUILD_DIR)/test-

# Testcases causing fatal issues on older libraries like memory leaks or div/0:
TEST_SKIP := $(CRYPT_SOURCE_DIR)/test/crypt-badargs.c $(CRYPT_SOURCE_DIR)/test/explicit-bzero.c $(CRYPT_SOURCE_DIR)/test/gensalt.c 

TEST_SO = $(patsubst $(CRYPT_SOURCE_DIR)/test/%.c, $(TEST_PREFIX)%.so, $(filter-out $(TEST_KNOWN_ANSWER) $(TEST_SKIP), $(wildcard $(CRYPT_SOURCE_DIR)/test/*.c))) $(patsubst %, $(TEST_PREFIX)ka-%.so, $(TEST_KNOWN_ANSWER_ALGORITHMS))

TARGET := $(BUILD_DIR)/runtests

all: $(TARGET) $(TEST_SO)

foo:
	@echo  $(TARGET) $(TEST_SO)

$(TARGET): main.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

$(TEST_PREFIX)%.so: $(CRYPT_SOURCE_DIR)/test/%.c
	$(CC) $(TEST_CFLAGS) -o $@ $< $(CRYPT_LDFLAGS)

$(TEST_PREFIX)ka-%.so: $(TEST_KNOWN_ANSWER)
	$(CC) $(TEST_CFLAGS) -DTEST_$* -o $@ $< $(CRYPT_LDFLAGS)

clean:
	rm -f $(TARGET) $(TEST_SO)

.PHONY: all clean
