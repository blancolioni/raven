;;  A library that imports nothing (#166).  define, lambda and quote are
;;  the translator's, so it can still say something; vector-ref is a
;;  library's to offer, and nothing here was offered it.  bare-name says
;;  the library was read whole, so that bare-first failing is about
;;  vector-ref and not about a form given up on.

(define-library (probe bare)

  (export bare-name bare-first)

  (begin

    (define bare-name 'bare)

    (define (bare-first v) (vector-ref v 0))))
