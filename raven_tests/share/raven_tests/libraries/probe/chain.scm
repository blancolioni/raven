;;  A library that offers what (probe reexport) offers, which is itself
;;  what that library imported: two steps back to where it is defined.

(define-library (probe chain)

  (import (scheme base)
          (rename (probe reexport) (reexport-renamed chained)))

  (export chained reexport-twice))
