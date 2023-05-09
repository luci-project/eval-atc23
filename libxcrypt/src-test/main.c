#define _GNU_SOURCE
#include <unistd.h>
#include <stddef.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/time.h>
#include <limits.h>
#include <time.h>
#include <errno.h>
#include <crypt.h>
#include <dlfcn.h>
#include <assert.h>
#include <pthread.h>

typedef int (*func_t)(int, const char ** );
static const char *func_symbol = "main";

/* Wrapper for MT unsafe interface */
#define strong_alias(name, aliasname) extern __typeof (name) aliasname __THROW __attribute__ ((alias (#name)))

char *crypt(const char *key, const char *salt) {
	static __thread struct crypt_data data;
	return crypt_r(key, salt, &data);
}
strong_alias(crypt, xcrypt);

char * crypt_gensalt(const char *prefix, unsigned long count, const char *rbytes, int nrbytes) {
	static __thread char output[CRYPT_GENSALT_OUTPUT_SIZE];
	return crypt_gensalt_rn(prefix, count, rbytes, nrbytes, output, sizeof(output));
}
strong_alias(crypt_gensalt, xcrypt_gensalt);

/* Test */
static FILE * stderr_new = NULL;
long total = 0;
static long runtest(const char * file) {
	char fullpath[PATH_MAX+1];
	errno = 0;
	if (realpath(file, fullpath) == NULL) {
		fprintf(stderr_new, "Unable to resolve path for %s: %s\n", file, strerror(errno));
		return -1;
	}

	void * handle = dlopen(fullpath, RTLD_NOW | RTLD_LOCAL);
	if (handle == NULL) {
		fprintf(stderr_new, "Opening %s (%s) failed: %s\n", file, fullpath, dlerror());
		return -2;
	}

	func_t func = (func_t) dlsym(handle, func_symbol);
	if (func == NULL) {
		fprintf(stderr_new, "Resolving %s symbol in %s failed: %s\n", func_symbol, file, dlerror());
		return -3;
	}

	pid_t tid = gettid();
	char buf[64] = { 0 };
	long success = 0;
	for (long n = 1; total < 0 || n <= total ; n++) {

		struct timeval then, now;
		gettimeofday(&then, NULL);
		unsigned long start =  then.tv_sec * 1000000UL + then.tv_usec;

		int r = func(1, &file);

		gettimeofday(&now, NULL);
		unsigned long end =  now.tv_sec * 1000000UL + now.tv_usec;
		struct tm * nowtm = gmtime(&then.tv_sec);
		strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", nowtm);
		fprintf(stderr_new, "[%s @ %d] %s run %lu with result %d took %lu us\n", buf, tid, file, n, r, end - start);
		
		if (r == 0)
			success++;

		// 100ms delay to relax the scheduler
		usleep(100000);
	}
	return success;
}

int main(int argc, char * argv[]) {
	if (argc < 3) {
		fprintf(stderr, "Usage: %s [num] [test.so [...]]\n", argv[0]);
		return 1;
	} else {
		// Redirect stderr to stdout for test apps (but use stderr for main output)
		fflush(stderr);
		errno = 0;
		int err_new = dup(2);
		if (err_new == -1)
			perror("Unable to duplicate stderr");
		else if (dup2(1, 2) == -1)
			perror("Unable to replace stderr with stdout");
		else if ((stderr_new = fdopen(err_new, "w")) == NULL)
			perror("Unable to open stderr file stream");

		if (stderr_new == NULL)
			stderr_new = stderr;

		// parse test case number argument
		total = atol(argv[1]);
		if (total < 0) {
			fprintf(stderr_new, "unlimited runs per testcase\n");
		} else {
			fprintf(stderr_new, "%ld runs per testcase\n", total);
		}
		
		// Create test threads
		pthread_t threads[argc];
		for (int i = 2; i < argc; i++) {
			int r = pthread_create(threads + i, NULL, (void *(*)(void *)) runtest, argv[i]);
			if (r != 0) {
				fprintf(stderr_new, "Starting pthread for %s failed: %s\n", argv[i], strerror(r));
				return 1;
			}
		}

		// join threads
		fputs("Waiting for threads\n", stderr_new);
		int load_failed = 0;
		int success = 0;
		for (int i = 2; i < argc; i++) {
			long val = 0;
			int r = pthread_join(threads[i], (void**) &val);
			if (r == 0) {
				if (val < 0) {
					fprintf(stderr_new, "Testcase %s could not be executed (error %ld)\n", argv[i], val);
					load_failed++;
				} else if (total > 0) {
					long per = val * 100 / total;
					fprintf(stderr_new, "Testcase %s successful in %ld / %ld (%ld%%)\n", argv[i], val, total, per);
					if (total == val)
						success++;
				}
			} else {
				fprintf(stderr_new, "Joining pthread for %s failed: %s\n", argv[i], strerror(r));
				return 1;
			}
		}
		int per = load_failed == argc - 2 ? 0 : (success * 100 / (argc - 2 - load_failed));
		fprintf(stderr_new, "%d of %d (%d%%) loaded testcases were successful (%d failed loading)\n", success, argc - 2 - load_failed, per, load_failed);
		return success == argc - 2 ? 0 : 1;
	}
}
