;;  (scheme write): writing a datum to a port, as it reads back and as
;;  a person reads it.  These were the base library's until #153, and
;;  are (raven base)'s, offered here where R7RS puts them.
;;
;;  write-simple is write: neither marks structure that a datum shares
;;  or that runs back into itself.  write-shared, which marks it with
;;  datum labels, is not here yet.

(define-library (scheme write)

  (import (raven base))

  (export write write-simple display))
