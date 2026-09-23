;;  Two libraries that ask for each other.  Neither can be read before
;;  the other, so the one that asks second gets what has been read of
;;  the first so far, and the loader says so.

(define-library (probe ring-a)
  (import (scheme base) (probe ring-b))
  (export ring-a-name)
  (begin
    (define ring-a-name 'ring-a)))
