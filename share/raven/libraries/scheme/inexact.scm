;;  (scheme inexact): the square root, the exponential and logarithm,
;;  the trigonometric functions, and the three questions about whether
;;  a number is finite.  R7RS keeps them out of the base library, so
;;  that a program which wants no floating point does not get it.
;;
;;  Each is the machine's, through Raven.Numbers.  Every answer is
;;  inexact but a square root: an exact number with an exact root has
;;  it, so (sqrt 9) is 3 and (sqrt 1/4) is 1/2, while (sqrt 2) is the
;;  double.  There are no complex numbers here, so what has only a
;;  complex answer -- the square root or logarithm of a negative
;;  number, the arcsine of 2 -- is refused and says why.

(define-library (scheme inexact)

  (import (scheme base))

  (export sqrt exp log sin cos tan asin acos atan finite? infinite? nan?)

  (begin

    (define (sqrt z) (raven-sqrt z))

    ;;  The positions of Raven.Numbers.Elementary.

    (define (exp z) (raven-elementary z 0))
    (define (sin z) (raven-elementary z 2))
    (define (cos z) (raven-elementary z 3))
    (define (tan z) (raven-elementary z 4))
    (define (asin z) (raven-elementary z 5))
    (define (acos z) (raven-elementary z 6))

    ;;  log of two arguments is the logarithm to the second as a base,
    ;;  and atan of two is the angle of the point (x, y), which knows
    ;;  its quadrant where the one-argument atan of y/x does not.  A
    ;;  second argument not given is nil.

    (define (log z base)
      (if (null? base)
          (raven-elementary z 1)
          (/ (raven-elementary z 1) (raven-elementary base 1))))

    (define (atan y x)
      (if (null? x)
          (raven-elementary y 7)
          (raven-atan2 y x)))

    ;;  Every number here is finite.  An infinity or a NaN is what a
    ;;  double makes of an overflow or of 0.0/0.0, and raven refuses those
    ;;  rather than making one, so there is nothing for infinite? or nan?
    ;;  to say yes to.  They are here so that a program that asks can.

    (define (finite? z)
      (if (number? z) #t (error "finite?: not a number" z)))

    (define (infinite? z)
      (if (number? z) #f (error "infinite?: not a number" z)))

    (define (nan? z)
      (if (number? z) #f (error "nan?: not a number" z)))))
