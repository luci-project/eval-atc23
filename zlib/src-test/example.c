/* example.c -- usage example of the zlib compression library
 * Copyright (C) 1995-2006, 2011, 2016 Jean-loup Gailly
 * For conditions of distribution and use, see copyright notice in zlib.h
 */

/* @(#) $Id$ */

#include "zlib.h"
#include <stdio.h>
#include <time.h>
#include <sys/time.h>

#ifdef STDC
#  include <string.h>
#  include <stdlib.h>
#endif

#if defined(VMS) || defined(RISCOS)
#  define TESTFILE "foo-gz"
#else
#  define TESTFILE "foo.gz"
#endif

#define CHECK_ERR(err, msg) { \
    if (err != Z_OK) { \
        fprintf(stderr, "%s error: %d\n", msg, err); \
        return 1; \
    } \
}

static z_const char hello[] = "hello, hello!";
/* "hello world" would be more standard, but the repeated "hello"
 * stresses the compression code better, sorry...
 */

static const char dictionary[] = "hello";
static uLong dictId;    /* Adler32 value of the dictionary */

int test_deflate       OF((Byte *compr, uLong comprLen));
int test_inflate       OF((Byte *compr, uLong comprLen,
                            Byte *uncompr, uLong uncomprLen));
int test_large_deflate OF((Byte *compr, uLong comprLen,
                            Byte *uncompr, uLong uncomprLen));
int test_large_inflate OF((Byte *compr, uLong comprLen,
                            Byte *uncompr, uLong uncomprLen));
int test_flush         OF((Byte *compr, uLong *comprLen));
int test_sync          OF((Byte *compr, uLong comprLen,
                            Byte *uncompr, uLong uncomprLen));
int test_dict_deflate  OF((Byte *compr, uLong comprLen));
int test_dict_inflate  OF((Byte *compr, uLong comprLen,
                            Byte *uncompr, uLong uncomprLen));
int  main               OF((int argc, char *argv[]));


static alloc_func zalloc = (alloc_func)0;
static free_func zfree = (free_func)0;

int test_compress      OF((Byte *compr, uLong comprLen,
                            Byte *uncompr, uLong uncomprLen));
int test_gzio          OF((const char *fname,
                            Byte *uncompr, uLong uncomprLen));

/* ===========================================================================
 * Test compress() and uncompress()
 */
int test_compress(compr, comprLen, uncompr, uncomprLen)
    Byte *compr, *uncompr;
    uLong comprLen, uncomprLen;
{
    int err;
    uLong len = (uLong)strlen(hello)+1;

    err = compress(compr, &comprLen, (const Bytef*)hello, len);
    CHECK_ERR(err, "compress");

    strcpy((char*)uncompr, "garbage");

    err = uncompress(uncompr, &uncomprLen, compr, comprLen);
    CHECK_ERR(err, "uncompress");

    if (strcmp((char*)uncompr, hello)) {
        fprintf(stderr, "bad uncompress\n");
        return 1;
    } else {
        printf("uncompress(): %s\n", (char *)uncompr);
    }

    return 0;
}

/* ===========================================================================
 * Test read/write of .gz files
 */
int test_gzio(fname, uncompr, uncomprLen)
    const char *fname; /* compressed file name */
    Byte *uncompr;
    uLong uncomprLen;
{
#ifdef NO_GZCOMPRESS
    fprintf(stderr, "NO_GZCOMPRESS -- gz* functions cannot compress\n");
#else
    int err;
    int len = (int)strlen(hello)+1;
    gzFile file;
    z_off_t pos;

    file = gzopen(fname, "wb");
    if (file == NULL) {
        fprintf(stderr, "gzopen error\n");
        return 1;
    }
    gzputc(file, 'h');
    if (gzputs(file, "ello") != 4) {
        fprintf(stderr, "gzputs err: %s\n", gzerror(file, &err));
        return 1;
    }
    if (gzprintf(file, ", %s!", "hello") != 8) {
        fprintf(stderr, "gzprintf err: %s\n", gzerror(file, &err));
        return 1;
    }
    gzseek(file, 1L, SEEK_CUR); /* add one zero byte */
    gzclose(file);

    file = gzopen(fname, "rb");
    if (file == NULL) {
        fprintf(stderr, "gzopen error\n");
        return 1;
    }
    strcpy((char*)uncompr, "garbage");

    if (gzread(file, uncompr, (unsigned)uncomprLen) != len) {
        fprintf(stderr, "gzread err: %s\n", gzerror(file, &err));
        return 1;
    }
    if (strcmp((char*)uncompr, hello)) {
        fprintf(stderr, "bad gzread: %s\n", (char*)uncompr);
        return 1;
    } else {
        printf("gzread(): %s\n", (char*)uncompr);
    }

    pos = gzseek(file, -8L, SEEK_CUR);
    if (pos != 6 || gztell(file) != pos) {
        fprintf(stderr, "gzseek error, pos=%ld, gztell=%ld\n",
                (long)pos, (long)gztell(file));
        return 1;
    }

/* // The gzungetc symbol is not available in v1.2.0 and v1.2.0.1, and this will segfault in < 1.2.3.6
    if (gzgetc(file) != ' ') {
        fprintf(stderr, "gzgetc error\n");
        return 1;
    }

    if (gzungetc(' ', file) != ' ') {
        fprintf(stderr, "gzungetc error\n");
        return 1;
    }
*/
    gzgets(file, (char*)uncompr, (int)uncomprLen);
    if (strlen((char*)uncompr) != 7) { /* " hello!" */
        fprintf(stderr, "gzgets err after gzseek: %s\n", gzerror(file, &err));
        return 1;
    }
    if (strcmp((char*)uncompr, hello + 6)) {
        fprintf(stderr, "bad gzgets after gzseek\n");
        return 1;
    } else {
        printf("gzgets() after gzseek: %s\n", (char*)uncompr);
    }

    gzclose(file);
#endif
    return 0;
}


/* ===========================================================================
 * Test deflate() with small buffers
 */
int test_deflate(compr, comprLen)
    Byte *compr;
    uLong comprLen;
{
    z_stream c_stream; /* compression stream */
    int err;
    uLong len = (uLong)strlen(hello)+1;

    c_stream.zalloc = zalloc;
    c_stream.zfree = zfree;
    c_stream.opaque = (voidpf)0;

    err = deflateInit(&c_stream, Z_DEFAULT_COMPRESSION);
    CHECK_ERR(err, "deflateInit");

    c_stream.next_in  = (z_const unsigned char *)hello;
    c_stream.next_out = compr;

    while (c_stream.total_in != len && c_stream.total_out < comprLen) {
        c_stream.avail_in = c_stream.avail_out = 1; /* force small buffers */
        err = deflate(&c_stream, Z_NO_FLUSH);
        CHECK_ERR(err, "deflate");
    }
    /* Finish the stream, still forcing small buffers: */
    for (;;) {
        c_stream.avail_out = 1;
        err = deflate(&c_stream, Z_FINISH);
        if (err == Z_STREAM_END) break;
        CHECK_ERR(err, "deflate");
    }

    err = deflateEnd(&c_stream);
    CHECK_ERR(err, "deflateEnd");

    return 0;
}

/* ===========================================================================
 * Test inflate() with small buffers
 */
int test_inflate(compr, comprLen, uncompr, uncomprLen)
    Byte *compr, *uncompr;
    uLong comprLen, uncomprLen;
{
    int err;
    z_stream d_stream; /* decompression stream */

    strcpy((char*)uncompr, "garbage");

    d_stream.zalloc = zalloc;
    d_stream.zfree = zfree;
    d_stream.opaque = (voidpf)0;

    d_stream.next_in  = compr;
    d_stream.avail_in = 0;
    d_stream.next_out = uncompr;

    err = inflateInit(&d_stream);
    CHECK_ERR(err, "inflateInit");

    while (d_stream.total_out < uncomprLen && d_stream.total_in < comprLen) {
        d_stream.avail_in = d_stream.avail_out = 1; /* force small buffers */
        err = inflate(&d_stream, Z_NO_FLUSH);
        if (err == Z_STREAM_END) break;
        CHECK_ERR(err, "inflate");
    }

    err = inflateEnd(&d_stream);
    CHECK_ERR(err, "inflateEnd");

    if (strcmp((char*)uncompr, hello)) {
        fprintf(stderr, "bad inflate\n");
        return 1;
    } else {
        printf("inflate(): %s\n", (char *)uncompr);
    }

    return 0;
}

/* ===========================================================================
 * Test deflate() with large buffers and dynamic change of compression level
 */
int test_large_deflate(compr, comprLen, uncompr, uncomprLen)
    Byte *compr, *uncompr;
    uLong comprLen, uncomprLen;
{
    z_stream c_stream; /* compression stream */
    int err;

    c_stream.zalloc = zalloc;
    c_stream.zfree = zfree;
    c_stream.opaque = (voidpf)0;

    err = deflateInit(&c_stream, Z_BEST_SPEED);
    CHECK_ERR(err, "deflateInit");

    c_stream.next_out = compr;
    c_stream.avail_out = (uInt)comprLen;

    /* At this point, uncompr is still mostly zeroes, so it should compress
     * very well:
     */
    c_stream.next_in = uncompr;
    c_stream.avail_in = (uInt)uncomprLen;
    err = deflate(&c_stream, Z_NO_FLUSH);
    CHECK_ERR(err, "deflate");
    if (c_stream.avail_in != 0) {
        fprintf(stderr, "deflate not greedy\n");
        return 1;
    }

    /* Feed in already compressed data and switch to no compression: */
    deflateParams(&c_stream, Z_NO_COMPRESSION, Z_DEFAULT_STRATEGY);
    c_stream.next_in = compr;
    c_stream.avail_in = (uInt)comprLen/2;
    err = deflate(&c_stream, Z_NO_FLUSH);
    CHECK_ERR(err, "deflate");

    /* Switch back to compressing mode: */
    deflateParams(&c_stream, Z_BEST_COMPRESSION, Z_FILTERED);
    c_stream.next_in = uncompr;
    c_stream.avail_in = (uInt)uncomprLen;
    err = deflate(&c_stream, Z_NO_FLUSH);
    CHECK_ERR(err, "deflate");

    err = deflate(&c_stream, Z_FINISH);
    if (err != Z_STREAM_END) {
        fprintf(stderr, "deflate should report Z_STREAM_END\n");
        return 1;
    }
    err = deflateEnd(&c_stream);
    CHECK_ERR(err, "deflateEnd");

    return 0;
}

/* ===========================================================================
 * Test inflate() with large buffers
 */
int test_large_inflate(compr, comprLen, uncompr, uncomprLen)
    Byte *compr, *uncompr;
    uLong comprLen, uncomprLen;
{
    int err;
    z_stream d_stream; /* decompression stream */

    strcpy((char*)uncompr, "garbage");

    d_stream.zalloc = zalloc;
    d_stream.zfree = zfree;
    d_stream.opaque = (voidpf)0;

    d_stream.next_in  = compr;
    d_stream.avail_in = (uInt)comprLen;

    err = inflateInit(&d_stream);
    CHECK_ERR(err, "inflateInit");

    for (;;) {
        d_stream.next_out = uncompr;            /* discard the output */
        d_stream.avail_out = (uInt)uncomprLen;
        err = inflate(&d_stream, Z_NO_FLUSH);
        if (err == Z_STREAM_END) break;
        CHECK_ERR(err, "large inflate");
    }

    err = inflateEnd(&d_stream);
    CHECK_ERR(err, "inflateEnd");

    if (d_stream.total_out != 2*uncomprLen + comprLen/2) {
        fprintf(stderr, "bad large inflate: %ld\n", d_stream.total_out);
        return 1;
    } else {
        printf("large_inflate(): OK\n");
    }

    return 0;
}

/* ===========================================================================
 * Test deflate() with full flush
 */
int test_flush(compr, comprLen)
    Byte *compr;
    uLong *comprLen;
{
    z_stream c_stream; /* compression stream */
    int err;
    uInt len = (uInt)strlen(hello)+1;

    c_stream.zalloc = zalloc;
    c_stream.zfree = zfree;
    c_stream.opaque = (voidpf)0;

    err = deflateInit(&c_stream, Z_DEFAULT_COMPRESSION);
    CHECK_ERR(err, "deflateInit");

    c_stream.next_in  = (z_const unsigned char *)hello;
    c_stream.next_out = compr;
    c_stream.avail_in = 3;
    c_stream.avail_out = (uInt)*comprLen;
    err = deflate(&c_stream, Z_FULL_FLUSH);
    CHECK_ERR(err, "deflate");

    compr[3]++; /* force an error in first compressed block */
    c_stream.avail_in = len - 3;

    err = deflate(&c_stream, Z_FINISH);
    if (err != Z_STREAM_END) {
        CHECK_ERR(err, "deflate");
    }
    err = deflateEnd(&c_stream);
    CHECK_ERR(err, "deflateEnd");

    *comprLen = c_stream.total_out;

    return 0;
}

/* ===========================================================================
 * Test inflateSync()
 */
int test_sync(compr, comprLen, uncompr, uncomprLen)
    Byte *compr, *uncompr;
    uLong comprLen, uncomprLen;
{
    int err;
    z_stream d_stream; /* decompression stream */

    strcpy((char*)uncompr, "garbage");

    d_stream.zalloc = zalloc;
    d_stream.zfree = zfree;
    d_stream.opaque = (voidpf)0;

    d_stream.next_in  = compr;
    d_stream.avail_in = 2; /* just read the zlib header */

    err = inflateInit(&d_stream);
    CHECK_ERR(err, "inflateInit");

    d_stream.next_out = uncompr;
    d_stream.avail_out = (uInt)uncomprLen;

    err = inflate(&d_stream, Z_NO_FLUSH);
    CHECK_ERR(err, "inflate");

    d_stream.avail_in = (uInt)comprLen-2;   /* read all compressed data */
    err = inflateSync(&d_stream);           /* but skip the damaged part */
    CHECK_ERR(err, "inflateSync");

    err = inflate(&d_stream, Z_FINISH);
    if (err != Z_STREAM_END) {
        fprintf(stderr, "inflate should report Z_STREAM_END\n");
        return 1;
    }
    err = inflateEnd(&d_stream);
    CHECK_ERR(err, "inflateEnd");

    printf("after inflateSync(): hel%s\n", (char *)uncompr);

    return 0;
}

/* ===========================================================================
 * Test deflate() with preset dictionary
 */
int test_dict_deflate(compr, comprLen)
    Byte *compr;
    uLong comprLen;
{
    z_stream c_stream; /* compression stream */
    int err;

    c_stream.zalloc = zalloc;
    c_stream.zfree = zfree;
    c_stream.opaque = (voidpf)0;

    err = deflateInit(&c_stream, Z_BEST_COMPRESSION);
    CHECK_ERR(err, "deflateInit");

    err = deflateSetDictionary(&c_stream,
                (const Bytef*)dictionary, (int)sizeof(dictionary));
    CHECK_ERR(err, "deflateSetDictionary");

    dictId = c_stream.adler;
    c_stream.next_out = compr;
    c_stream.avail_out = (uInt)comprLen;

    c_stream.next_in = (z_const unsigned char *)hello;
    c_stream.avail_in = (uInt)strlen(hello)+1;

    err = deflate(&c_stream, Z_FINISH);
    if (err != Z_STREAM_END) {
        fprintf(stderr, "deflate should report Z_STREAM_END\n");
        return 1;
    }
    err = deflateEnd(&c_stream);
    CHECK_ERR(err, "deflateEnd");

    return 0;
}

/* ===========================================================================
 * Test inflate() with a preset dictionary
 */
int test_dict_inflate(compr, comprLen, uncompr, uncomprLen)
    Byte *compr, *uncompr;
    uLong comprLen, uncomprLen;
{
    int err;
    z_stream d_stream; /* decompression stream */

    strcpy((char*)uncompr, "garbage");

    d_stream.zalloc = zalloc;
    d_stream.zfree = zfree;
    d_stream.opaque = (voidpf)0;

    d_stream.next_in  = compr;
    d_stream.avail_in = (uInt)comprLen;

    err = inflateInit(&d_stream);
    CHECK_ERR(err, "inflateInit");

    d_stream.next_out = uncompr;
    d_stream.avail_out = (uInt)uncomprLen;

    for (;;) {
        err = inflate(&d_stream, Z_NO_FLUSH);
        if (err == Z_STREAM_END) break;
        if (err == Z_NEED_DICT) {
            if (d_stream.adler != dictId) {
                fprintf(stderr, "unexpected dictionary");
                return 1;
            }
            err = inflateSetDictionary(&d_stream, (const Bytef*)dictionary,
                                       (int)sizeof(dictionary));
        }
        CHECK_ERR(err, "inflate with dict");
    }

    err = inflateEnd(&d_stream);
    CHECK_ERR(err, "inflateEnd");

    if (strcmp((char*)uncompr, hello)) {
        fprintf(stderr, "bad inflate with dict\n");
        return 1;
    } else {
        printf("inflate with dictionary: %s\n", (char *)uncompr);
    }

    return 0;
}

/* ===========================================================================
 * Usage:  example [output.gz  [input.gz]]
 */

int main(argc, argv)
    int argc;
    char *argv[];
{

    char buf[64] = { 0 };
    for (unsigned long n = 1; ; n++) {
        struct timeval now;
        gettimeofday(&now, NULL);
        unsigned long start =  now.tv_sec * 1000000UL + now.tv_usec;
        struct tm * nowtm = gmtime(&now.tv_sec);
        strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", nowtm);
        printf("\nRun %ld (at %s):\n", n, buf);

        printf("zlib version: %s\n", zlibVersion());

        uLong comprLen = 10000000*sizeof(int);
        uLong uncomprLen = comprLen;
        int failed = 0;
        Byte *compr    = (Byte*)calloc((uInt)comprLen, 1);
        Byte *uncompr  = (Byte*)calloc((uInt)uncomprLen, 1);
        /* compr and uncompr are cleared to avoid reading uninitialized
         * data and to ensure that uncompr compresses well.
         */
        if (compr == Z_NULL || uncompr == Z_NULL) {
            printf("out of memory\n");
            return 1;
        }

        failed += test_compress(compr, comprLen, uncompr, uncomprLen);

        failed += test_gzio((argc > 1 ? argv[1] : TESTFILE), uncompr, uncomprLen);

        failed += test_deflate(compr, comprLen);
        failed += test_inflate(compr, comprLen, uncompr, uncomprLen);

        failed += test_large_deflate(compr, comprLen, uncompr, uncomprLen);
        failed += test_large_inflate(compr, comprLen, uncompr, uncomprLen);

        failed += test_flush(compr, &comprLen);
        failed += test_sync(compr, comprLen, uncompr, uncomprLen);
        comprLen = uncomprLen;

        failed += test_dict_deflate(compr, comprLen);
        failed += test_dict_inflate(compr, comprLen, uncompr, uncomprLen);

        free(compr);
        free(uncompr);

        printf("Failed: %d\n", failed);

        gettimeofday(&now, NULL);
        unsigned long end =  now.tv_sec * 1000000UL + now.tv_usec;
        printf("[Duration: %lu ms]\n", (end - start + 500) / 1000);
        fflush(stdout);
    }

    return 0;
}
