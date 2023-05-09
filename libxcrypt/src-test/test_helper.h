#define _GNU_SOURCE
/* explicit-bzero requires memmem */
#include <string.h>
#include <assert.h>

/* Helper: internal function from ib/util-xstrcpy.c required for crypt-gost-yescrypt */
static inline size_t _crypt_strcpy_or_abort (void *dst, size_t d_size, const void *src) {
	assert (dst != NULL);
	assert (src != NULL);
	size_t s_size = strlen ((const char *)src);
	assert (d_size >= s_size + 1);

	memcpy (dst, src, s_size);
	memset (((char *)dst) + s_size, 0, d_size - s_size);
	return s_size;
}

#ifndef strcpy_or_abort 
#define strcpy_or_abort _crypt_strcpy_or_abort
#endif
