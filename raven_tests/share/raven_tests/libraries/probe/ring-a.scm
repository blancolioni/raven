;;  Two libraries that ask for each other.  Neither can be read before
;;  the other, so the one that asks second gets what has been read of
;;  the first so far, and the loader says so.
;;
;;  Each offers ring-shared, which neither defines: a name that goes
;;  round the ring and is defined nowhere.

(define-library (probe ring-a)
  (import (scheme base) (probe ring-b))
  (export ring-a-name ring-shared)
  (begin
    (define ring-a-name 'ring-a)))
