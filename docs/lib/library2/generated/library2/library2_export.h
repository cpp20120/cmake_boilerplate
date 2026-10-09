
#ifndef LIBRARY2_EXPORT_H
#define LIBRARY2_EXPORT_H

#ifdef LIBRARY2_STATIC_DEFINE
#  define LIBRARY2_EXPORT
#  define LIBRARY2_NO_EXPORT
#else
#  ifndef LIBRARY2_EXPORT
#    ifdef LIBRARY2_EXPORTS
        /* We are building this library */
#      define LIBRARY2_EXPORT __attribute__((visibility("default")))
#    else
        /* We are using this library */
#      define LIBRARY2_EXPORT __attribute__((visibility("default")))
#    endif
#  endif

#  ifndef LIBRARY2_NO_EXPORT
#    define LIBRARY2_NO_EXPORT __attribute__((visibility("hidden")))
#  endif
#endif

#ifndef LIBRARY2_DEPRECATED
#  define LIBRARY2_DEPRECATED __attribute__ ((__deprecated__))
#endif

#ifndef LIBRARY2_DEPRECATED_EXPORT
#  define LIBRARY2_DEPRECATED_EXPORT LIBRARY2_EXPORT LIBRARY2_DEPRECATED
#endif

#ifndef LIBRARY2_DEPRECATED_NO_EXPORT
#  define LIBRARY2_DEPRECATED_NO_EXPORT LIBRARY2_NO_EXPORT LIBRARY2_DEPRECATED
#endif

/* NOLINTNEXTLINE(readability-avoid-unconditional-preprocessor-if) */
#if 0 /* DEFINE_NO_DEPRECATED */
#  ifndef LIBRARY2_NO_DEPRECATED
#    define LIBRARY2_NO_DEPRECATED
#  endif
#endif

#endif /* LIBRARY2_EXPORT_H */
