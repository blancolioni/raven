;;  A library with something to offer and something to keep.
;;
;;  alpha-twice is the case worth having: a macro written here whose
;;  template names alpha-helper, which nothing outside here can see.
;;  It works because a macro carries the library its rules were
;;  written in, and what it expands to is read there for any name the
;;  use site cannot account for.

(define-library (probe alpha)

  (import (scheme base))

  (export alpha-name alpha-shared alpha-twice)

  (begin

    (define alpha-name 'alpha)

    (define alpha-shared 1)

    (define (alpha-helper x) (+ x x))

    (define-syntax alpha-twice
      (syntax-rules ()
        ((_ x) (alpha-helper x))))))
