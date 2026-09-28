;;  A library that defines a record type (#154) and offers some of it:
;;  the constructor, the predicate and one accessor, but not the
;;  modifier or the other accessor, which stay the library's own.

(define-library (probe records)

  (import (scheme base))

  (export make-pair-of pair-of? pair-of-left pair-of-sum)

  (begin

    (define-record-type <pair-of>
      (make-pair-of left right)
      pair-of?
      (left pair-of-left set-pair-of-left!)
      (right pair-of-right))

    (define (pair-of-sum p) (+ (pair-of-left p) (pair-of-right p)))))
