;;  A second library that defines a name the first one defines, and
;;  imports the first one as well.  alpha-shared is 1 in (probe alpha)
;;  and 2 here, and beta-alpha-shared shows which one this library
;;  means: its own, because a definition takes the name from anything
;;  imported under it.

(define-library (probe beta)

  (import (scheme base) (probe alpha))

  (export beta-name alpha-shared beta-alpha-name)

  (begin

    (define beta-name 'beta)

    (define alpha-shared 2)

    (define beta-alpha-name alpha-name)))
