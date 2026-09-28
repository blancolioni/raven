;;  (scheme lazy): promises.  delay and delay-force make one, force
;;  asks it, and make-promise makes one that is already answered.
;;  promise? asks whether something is one, which it can since a
;;  promise is a record of its own (#168).  These were the base
;;  library's until #153, and are (raven base)'s, offered here where
;;  R7RS puts them.

(define-library (scheme lazy)

  (import (raven base))

  (export delay delay-force force make-promise promise?))
