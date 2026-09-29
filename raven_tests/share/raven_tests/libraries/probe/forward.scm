;;  A library with a name of its own, forward-helper, and a macro that
;;  calls what it is handed (#178).  A caller that hands it a name the
;;  caller has not defined yet means its own, even though this library
;;  has one of the name: the name came from the caller, not from the
;;  template.

(define-library (probe forward)

  (import (scheme base))

  (export call-it forward-own)

  (begin

    (define (forward-helper) 'library)

    (define (forward-own) (forward-helper))

    (define-syntax call-it
      (syntax-rules ()
        ((_ f) (f))))))
