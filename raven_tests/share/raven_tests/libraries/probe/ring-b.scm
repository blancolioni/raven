(define-library (probe ring-b)
  (import (scheme base) (probe ring-a))
  (export ring-b-name ring-shared)
  (begin
    (define ring-b-name 'ring-b)))
