;;  A library that imports through an import set, which is the same
;;  declaration as at the host, read inside a define-library.

(define-library (probe sets)

  (import (scheme base)
          (prefix (only (probe gamma) gamma-a gamma-twice) in-))

  (export sets-name sets-twice)

  (begin

    (define sets-name in-gamma-a)

    (define (sets-twice x) (in-gamma-twice x))))
