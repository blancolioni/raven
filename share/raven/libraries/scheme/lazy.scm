;;  (scheme lazy): promises.  delay and delay-force make one, force
;;  asks it, and make-promise makes one that is already answered.
;;  These were the base library's until #153, and are (raven base)'s,
;;  offered here where R7RS puts them.
;;
;;  promise? is not here yet.  A promise is a procedure, so nothing can
;;  tell one from any other procedure; telling them apart wants a
;;  promise to be an object of its own.

(define-library (scheme lazy)

  (import (raven base))

  (export delay delay-force force make-promise))
