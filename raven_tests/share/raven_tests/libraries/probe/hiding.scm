;;  A library that leaves vector-ref out of what it takes from (scheme
;;  base), and takes it again under a prefix (#166).  The name as
;;  written is not here; the prefixed one is, and so is everything the
;;  import set did not leave out.

(define-library (probe hiding)

  (import (except (scheme base) vector-ref)
          (prefix (only (scheme base) vector-ref) b:))

  (export hiding-first hiding-prefixed hiding-length)

  (begin

    (define (hiding-first v) (vector-ref v 0))

    (define (hiding-prefixed v) (b:vector-ref v 0))

    (define (hiding-length v) (vector-length v))))
