
#ifndef LIBRARY1_EXPORT_H
#define LIBRARY1_EXPORT_H

#ifdef LIBRARY1_STATIC_DEFINE
#  define LIBRARY1_EXPORT
#  define LIBRARY1_NO_EXPORT
#else
#  ifndef LIBRARY1_EXPORT
#    ifdef LIBRARY1_EXPORTS
        /* We are building this library */
#      define LIBRARY1_EXPORT __attribute__((visibility("default")))
#    else
        /* We are using this library */
#      define LIBRARY1_EXPORT __attribute__((visibility("default")))
#    endif
#  endif

#  ifndef LIBRARY1_NO_EXPORT
#    define LIBRARY1_NO_EXPORT __attribute__((visibility("hidden")))
#  endif
#endif

#ifndef LIBRARY1_DEPRECATED
#  define LIBRARY1_DEPRECATED __attribute__ ((__deprecated__))
#endif

#ifndef LIBRARY1_DEPRECATED_EXPORT
#  define LIBRARY1_DEPRECATED_EXPORT LIBRARY1_EXPORT LIBRARY1_DEPRECATED
#endif

#ifndef LIBRARY1_DEPRECATED_NO_EXPORT
#  define LIBRARY1_DEPRECATED_NO_EXPORT LIBRARY1_NO_EXPORT LIBRARY1_DEPRECATED
#endif

/* NOLINTNEXTLINE(readability-avoid-unconditional-preprocessor-if) */
#if 0 /* DEFINE_NO_DEPRECATED */
#  ifndef LIBRARY1_NO_DEPRECATED
#    define LIBRARY1_NO_DEPRECATED
#  endif
#endif

#endif /* LIBRARY1_EXPORT_H */
