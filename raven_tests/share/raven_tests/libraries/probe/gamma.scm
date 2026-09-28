;;  A library for import sets to choose from (#27): nothing imports it
;;  whole, so what an import set leaves out is not here by another way.
;;  gamma-twice is a macro whose template names what the library keeps,
;;  so taking it under another name has to leave it reading here.

(define-library (probe gamma)

  (import (scheme base))

  (export gamma-a gamma-b gamma-c gamma-twice)

  (begin

    (define gamma-a 'a)
    (define gamma-b 'b)
    (define gamma-c 'c)

    (define (gamma-helper x) (+ x x))

    (define-syntax gamma-twice
      (syntax-rules ()
        ((_ x) (gamma-helper x))))))
