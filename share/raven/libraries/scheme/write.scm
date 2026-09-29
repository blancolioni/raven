;;  (scheme write): writing a datum to a port, as it reads back and as
;;  a person reads it.  These were the base library's until #153, and
;;  are (raven base)'s, offered here where R7RS puts them.
;;
;;  write marks with a datum label a pair or vector a datum runs back
;;  into, so that writing a circular list comes to an end, and
;;  write-shared marks every one it reaches more than once (#167).
;;  write-simple is write.

(define-library (scheme write)

  (import (raven base))

  (export write write-simple write-shared display))
