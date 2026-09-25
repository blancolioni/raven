;;  A file of loose forms rather than a library that says what it is,
;;  two of which cannot be run.  Read_Forms carries on at the form
;;  after a bad one the way a library's begin now does, and the file
;;  is a library all the same, so nothing imports this either.

(probe-no-such-thing 1)

(define loose-between 2)

(probe-no-such-other-thing 3)
