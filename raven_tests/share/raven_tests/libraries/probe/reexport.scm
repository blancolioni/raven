;;  A library that offers what it imported (#140), plainly and under
;;  another name, and a macro under another name.  It defines nothing,
;;  so every name it offers is found in (probe gamma).

(define-library (probe reexport)

  (import (scheme base) (probe gamma))

  (export gamma-b
          (rename gamma-c reexport-renamed)
          (rename gamma-twice reexport-twice)))
