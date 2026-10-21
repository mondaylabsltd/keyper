// Regenerates test-vectors/compact.tsv: ICU's long compact notation ("61 thousand", "6.1万"), which
// Android's CompactDecimalFormat writes and the iOS app reproduces, for English and Chinese.
// Uses the ICU that ships with macOS:
//
//     clang -o /tmp/compact-icu reference/compact_icu.c -licucore && /tmp/compact-icu > test-vectors/compact.tsv
#include <stdio.h>
#include <stdint.h>
typedef uint16_t UChar;
typedef int UErrorCode;
typedef struct UNumberFormatter UNumberFormatter;
typedef struct UFormattedNumber UFormattedNumber;
UNumberFormatter *unumf_openForSkeletonAndLocale(const UChar *skeleton, int32_t skeletonLen, const char *locale, UErrorCode *ec);
UFormattedNumber *unumf_openResult(UErrorCode *ec);
void unumf_formatDouble(const UNumberFormatter *f, double value, UFormattedNumber *r, UErrorCode *ec);
int32_t unumf_resultToString(const UFormattedNumber *r, UChar *buffer, int32_t capacity, UErrorCode *ec);

static void utf8(const UChar *s, int n) {
    for (int i = 0; i < n; i++) {
        unsigned c = s[i];
        if (c < 0x80) putchar(c);
        else if (c < 0x800) { putchar(0xC0 | c >> 6); putchar(0x80 | (c & 63)); }
        else { putchar(0xE0 | c >> 12); putchar(0x80 | (c >> 6 & 63)); putchar(0x80 | (c & 63)); }
    }
}

int main(void) {
    const char *skeleton = "compact-long";
    UChar sk[32]; int n = 0; for (; skeleton[n]; n++) sk[n] = skeleton[n];
    double values[] = {1, 1.04, 1.05, 1.15, 1.5, 2.25, 9.94, 9.95, 9.96, 12.3, 12.5, 13.5, 99.5, 300, 999, 999.4, 999.5, 1000, 1234, 1250, 1350,
        5000, 9999, 9999.5, 10000, 12345, 30500, 61234, 99999, 170999, 305000, 999499, 999500, 999999, 1e6, 1.5e6, 21e9, 21.2e9, 60.4e9, 1.38e10,
        6.1e4, 6.15e4, 6.25e4, 1e12, 1.23e12, 99.4e12, 99.6e12, 3.2e11, 3.13e8, 7.5, 0.5e9};
    printf("# value\ten\tzh\n");
    for (unsigned i = 0; i < sizeof values / sizeof *values; i++) {
        printf("%.17g", values[i]);
        const char *locales[] = {"en", "zh"};
        for (int l = 0; l < 2; l++) {
            UErrorCode ec = 0;
            UNumberFormatter *f = unumf_openForSkeletonAndLocale(sk, n, locales[l], &ec);
            UFormattedNumber *r = unumf_openResult(&ec);
            unumf_formatDouble(f, values[i], r, &ec);
            UChar out[128]; int32_t len = unumf_resultToString(r, out, 128, &ec);
            putchar('\t'); utf8(out, len);
            if (ec > 0) printf("!%d", ec);
        }
        putchar('\n');
    }
}
