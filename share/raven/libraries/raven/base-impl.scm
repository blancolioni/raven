(define (eq? x y) (raven-eq? x y))

;;  gensym is raven's own, and (raven base)'s to offer.  The machine's
;;  is bound as raven-gensym, because a foreign function's name is seen
;;  by every library whatever it imports, and one bound as gensym was
;;  there in a program that asked only for (scheme base) (#153).

(define (gensym prefix) (raven-gensym prefix))

;;  The rest of what the machine does for this library under an R7RS
;;  name, which it binds under a raven- one for the same reason
;;  (#166): a foreign function is in every library, so one bound as
;;  vector-ref was there in a library that imported nothing, and no
;;  import set could leave it out.  Each is the machine's procedure
;;  itself, offered under the name a program writes.

(define binary-port? raven-binary-port?)
(define bytevector-length raven-bytevector-length)
(define bytevector-u8-ref raven-bytevector-u8-ref)
(define bytevector-u8-set! raven-bytevector-u8-set!)
(define bytevector? raven-bytevector?)
(define char->integer raven-char->integer)
(define char? raven-char?)
(define equal? raven-equal?)
(define exact-integer? raven-exact-integer?)
(define get-output-bytevector raven-get-output-bytevector)
(define get-output-string raven-get-output-string)
(define input-port? raven-input-port?)
(define integer->char raven-integer->char)
(define integer? raven-integer?)
(define number? raven-number?)
(define open-input-bytevector raven-open-input-bytevector)
(define open-input-string raven-open-input-string)
(define open-output-bytevector raven-open-output-bytevector)
(define open-output-string raven-open-output-string)
(define output-port? raven-output-port?)
(define port? raven-port?)
(define procedure? raven-procedure?)
(define set-car! raven-set-car!)
(define set-cdr! raven-set-cdr!)
(define string->symbol raven-string->symbol)
(define string->utf8 raven-string->utf8)
(define string? raven-string?)
(define symbol->string raven-symbol->string)
(define symbol? raven-symbol?)
(define textual-port? raven-textual-port?)
(define utf8->string raven-utf8->string)
(define vector-length raven-vector-length)
(define vector-ref raven-vector-ref)
(define vector-set! raven-vector-set!)
(define vector? raven-vector?)

;;  eqv? is eq? for everything but numbers, where R7RS asks whether
;;  they are the same number and equally exact -- which is not identity
;;  once a number can be boxed, because two equal bignums are two
;;  objects.  So two numbers are the machine's to compare.  The same
;;  word is the same thing whatever it is, so that is asked first.

(define (eqv? x y)
  (if (eq? x y)
      #t
      (if (number? x)
	  (if (number? y) (raven-num-eqv x y) #f)
	  #f)))

(define (null? x) (eq? x '()))

(define (list . xs) xs)
(define (xcons xs x) (cons x xs))

(define (append2 xs ys) (if (null? xs) ys (cons (car xs) (append (cdr xs) ys))))
(define (concatenate xxs) (if (null? xxs) '()
			      (append2 (car xxs) (concatenate (cdr xxs)))))
(define (append . xxs) (concatenate xxs))

(define (length xs) (if (null? xs) 0 (+ 1 (length (cdr xs)))))
(define (make-list n e) (if (= n 0) '() (cons e (make-list (- n 1) e))))

(define (reverse xs) (reverse-onto xs '()))
(define (reverse-onto xs ys)
  (if (null? xs) ys (reverse-onto (cdr xs) (cons (car xs) ys))))

(define (list-tail xs k) (if (= k 0) xs (list-tail (cdr xs) (- k 1))))
(define (list-ref xs k) (car (list-tail xs k)))

;;  list-set! waited for set-car!, which the machine could always do
;;  and had no name for.  It is list-ref with the reading replaced by
;;  a writing, and walks to the same pair.

(define (list-set! xs k value) (set-car! (list-tail xs k) value))

;;  list-copy copies the pairs and nothing else: what the last cdr is
;;  is what it stays, and something that is not a pair at all is its
;;  own copy.

(define (list-copy x) (if (pair? x) (cons (car x) (list-copy (cdr x))) x))

;;  Whether something is a list is decided by the last cdr, so there
;;  is no answering it without walking to the end.  Two things can
;;  stop the walk short of one: leaving the pairs, and never leaving
;;  them at all.
;;
;;  The second is why this is two walks rather than one.  There used
;;  to be no way to make a list that runs back into itself, so a walk
;;  that got going ended and the plain recursion was the whole of it;
;;  set-cdr! is the way, and now a list? that only looked for the end
;;  would not come back.  So a slow walk and a fast one go together,
;;  the fast one two pairs at a time, and the fast one catches the
;;  slow one exactly when the list has no end to find.

(define (list? x) (list-walk? x x))

(define (list-walk? slow fast)
  (if (null? fast)
      #t
      (if (pair? fast)
          (if (null? (cdr fast))
              #t
              (if (pair? (cdr fast))
                  (if (eq? (cddr fast) (cdr slow))
                      #f
                      (list-walk? (cdr slow) (cddr fast)))
                  #f))
          #f)))

(define (not x) (if x #f #t))
(define (xor x y) (if x (not y) y))

(define (fold f k xs) (if (null? xs) k (f (car xs) (fold f k (cdr xs)))))

(define (all-left-assoc op z xs)
  (if (null? xs) z
      (if (null? (cdr xs)) z
	  (if (op (car xs) (car (cdr xs)))
	      (all-left-assoc op z (cdr xs))
	      #f))))

;;  = asks about numbers, where it used to ask about identity and
;;  answer for anything at all: (= 'a 'a) was #t.
;;
;;  = is the machine's comparison, through the same seam as the rest
;;  of arithmetic.  It was eq?, which was numeric equality only while
;;  every number was an immediate: two equal bignums are two objects.
;;  What is not a number is refused there, and says which it was.

(define (= . xs) (all-left-assoc num-eq? #t xs))

(define (num-eq? a b) (raven-num-eq a b))

;;  A number as text and text as a number, in radix 2, 8, 10 or 16.
;;  string->number answers #f for text that is not a number.

(define (number->string n radix)
  (raven-number->string n (optional radix 10)))

(define (string->number s radix)
  (raven-string->number s (optional radix 10)))


(define (+ . xs) (fold raven-add 0 xs))
(define (* . xs) (fold raven-mul 1 xs))

;;  + and * have an answer for no arguments at all, because there is a
;;  number that leaves a sum or a product alone.  - and / have none:
;;  one argument means negate or invert and two or more means subtract
;;  or divide, so with nothing to start from there is nothing to do.
;;  They used to answer 0 and 1, which are the identities of the other
;;  two operations.

(define (- . xs) (apply-subtract xs))
(define (apply-subtract xs)
  (if (null? xs)
      (error "-: expected at least one argument")
      (if (null? (cdr xs)) (raven-sub 0 (car xs))
	  (raven-sub (car xs) (fold raven-add 0 (cdr xs))))))

(define (/ . xs) (apply-divide xs))
(define (apply-divide xs)
  (if (null? xs)
      (error "/: expected at least one argument")
      (if (null? (cdr xs)) (raven-div 1 (car xs))
	  (raven-div (car xs) (fold raven-mul 1 (cdr xs))))))

;;  Comparison.  raven-leq is the only one the machine has and the
;;  other three are it with the arguments turned around, negated, or
;;  both.  Each is a chain, the way = is: (< 1 2 3) asks whether the
;;  whole row rises, and asks it of each neighbouring pair.

(define (< . xs) (all-left-assoc (lambda (x y) (not (raven-leq y x))) #t xs))
(define (> . xs) (all-left-assoc (lambda (x y) (not (raven-leq x y))) #t xs))
(define (<= . xs) (all-left-assoc raven-leq #t xs))
(define (>= . xs) (all-left-assoc (lambda (x y) (raven-leq y x)) #t xs))

(define (zero? x) (= x 0))
(define (positive? x) (< 0 x))
(define (negative? x) (< x 0))
(define (even? x) (zero? (remainder x 2)))
(define (odd? x) (not (even? x)))

(define (abs x) (if (negative? x) (- x) x))
(define (square x) (* x x))

;;  min and max are one walk given which of two to keep.  Each holds
;;  the answer for the rest of the list in a name rather than asking
;;  for it twice, which would be a walk of the list for every element
;;  of it.

;;  min and max answer inexact when any argument is, as every other
;;  operation does: the answer can be no more exact than what it was
;;  chosen from.  (max 1 2.0) is 2.0 and (max 3 2.0) is 3.0.

(define (min . xs) (inexact-if-any xs (extreme < xs)))
(define (max . xs) (inexact-if-any xs (extreme > xs)))

(define (inexact-if-any xs x)
  (if (null? xs)
      x
      (if (raven-exact? (car xs))
          (inexact-if-any (cdr xs) x)
          (raven-inexact x))))

(define (extreme better? xs)
  (if (null? (cdr xs))
      (car xs)
      ((lambda (rest) (if (better? (car xs) rest) (car xs) rest))
       (extreme better? (cdr xs)))))

;;  Division.  The machine divides towards zero, so what raven-quotient
;;  does is the truncating quotient, and the remainder follows from it
;;  without dividing again.

(define (truncate-quotient x y) (raven-quotient x y))
(define (truncate-remainder x y) (- x (* y (truncate-quotient x y))))

(define (quotient x y) (truncate-quotient x y))
(define (remainder x y) (truncate-remainder x y))

;;  Flooring division differs from truncating division in exactly one
;;  case: the division did not come out even and the answer is
;;  negative, where truncating rounds up towards zero and flooring
;;  rounds down away from it.  So it is the truncating quotient, one
;;  less when that case holds, and the remainder is what is left over
;;  from the quotient that was actually taken.

(define (floor-quotient x y)
  (floor-adjust y (truncate-quotient x y) (truncate-remainder x y)))

(define (floor-adjust y q r)
  (if (if (zero? r) #f (xor (negative? r) (negative? y))) (- q 1) q))

(define (floor-remainder x y) (- x (* y (floor-quotient x y))))

(define (modulo x y) (floor-remainder x y))

;;  truncate/ and floor/ are the other half of each of these: one call
;;  answering both the quotient and the remainder, as two values.  They
;;  are written with values, at the end of this file.

;;  gcd and lcm are chains over any number of arguments, and the
;;  answer of each is never negative.  gcd of nothing is 0 and lcm of
;;  nothing is 1, which are the values that leave a chain of one
;;  argument alone.

(define (gcd . xs) (fold gcd2 0 xs))
(define (gcd2 a b) (if (zero? b) (abs a) (gcd2 b (remainder a b))))

(define (lcm . xs) (fold lcm2 1 xs))
(define (lcm2 a b)
  (if (if (zero? a) #t (zero? b))
      0
      (abs (quotient (* a b) (gcd2 a b)))))

;;  expt raises to a whole power by squaring, which is a multiplication
;;  for every bit of the power rather than one for every unit of it, and
;;  a tail call, so a large power neither takes long nor goes deep.  A
;;  negative power is the reciprocal, which is exact for an exact base:
;;  (expt 2 -3) is 1/8.  A power that is not an integer is the machine's,
;;  as a double: (expt 2 0.5) is the square root of two, and a negative
;;  number to one is a complex number, which raven has none of.

(define (expt base power)
  (if (integer? power)
      ((lambda (answer) (if (exact? power) answer (inexact answer)))
       (if (negative? power)
           (/ 1 (expt-by-squaring base (exact (- power)) 1))
           (expt-by-squaring base (exact power) 1)))
      (raven-power base power)))

(define (expt-by-squaring base power acc)
  (if (zero? power)
      acc
      (if (even? power)
          (expt-by-squaring (* base base) (quotient power 2) acc)
          (expt-by-squaring base (- power 1) (* acc base)))))

;;  A number is rational, real and complex here: every number raven has
;;  is a finite real, and there is no infinity or NaN to be the one that
;;  is real and not rational.

(define (rational? x) (number? x))
(define (real? x) (number? x))
(define (complex? x) (number? x))

;;  A rational's parts in lowest terms, with the denominator positive.
;;  An integer is itself over one, and an inexact number's parts are its
;;  exact ones made inexact: (denominator 0.5) is 2.0.

(define (numerator q) (raven-numerator q))
(define (denominator q) (raven-denominator q))

;;  The simplest rational within y of x, which is the one with the
;;  smallest denominator, and the smallest numerator of those: the
;;  Stern-Brocot search, written without let because let is not here
;;  yet.  (rationalize 3/10 1/10) is 1/3, and inexact if either argument
;;  is.

(define (rationalize x y) (simplest-between (- x y) (+ x y)))

(define (simplest-between lo hi)
  (if (< hi lo)
      (simplest-between hi lo)
      (if (= lo hi)
          lo
          (if (positive? lo)
              (simplest-positive lo hi)
              (if (negative? hi)
                  (- (simplest-positive (- hi) (- lo)))
                  (if (if (exact? lo) (exact? hi) #f) 0 0.0))))))

(define (simplest-positive lo hi)
  ((lambda (fl)
     (if (= fl lo)
         fl
         (if (< fl (floor hi))
             (+ fl 1)
             (+ fl (/ 1 (simplest-positive (/ 1 (- hi fl))
                                           (/ 1 (- lo fl))))))))
   (floor lo)))

;;  Rounding, which gives an exact number back as it is and rounds an
;;  inexact one to a whole inexact number: (floor 2.5) is 2.0, not 2.
;;  round goes to the even one of two that are as near, as R7RS asks,
;;  so (round 2.5) is 2.0 and (round 3.5) is 4.0.  They were the
;;  identity while every number was an integer.

(define (floor x) (raven-round x 0))
(define (ceiling x) (raven-round x 1))
(define (truncate x) (raven-round x 2))
(define (round x) (raven-round x 3))

;;  Exactness.  An operation with any inexact argument answers inexact,
;;  which the machine does; these ask which a number is and give the
;;  other kind of it.  exact of a double that is not a whole number has
;;  nothing to answer with until there are exact fractions (#104).

(define (exact? z) (raven-exact? z))
(define (inexact? z) (not (raven-exact? z)))
(define (exact z) (raven-exact z))
(define (inexact z) (raven-inexact z))

(define (optional value default) (if (eq? value '()) default value))

(define string-length raven-string-length)

(define list->string raven-list->string)

(define (string->list string start end)
   (raven-string->list string (optional start 0) (optional end (string-length string))))

(define (string-append . strings)
   (list->string (concatenate (map string->list strings))))

;;  The rest of what R7RS asks of a string.  What can be done by
;;  arithmetic is done by arithmetic, in the machine: an index, a slice,
;;  a comparison, a string of one character over and over.  These were
;;  written on string->list, which conses a pair for every character,
;;  so a loop over a string with string-ref made the square of its
;;  length in garbage.  string-append still walks, because it has to
;;  touch every character anyway.

(define (string . chars) (list->string chars))

(define (make-string n fill) (raven-make-string n (optional fill #\space)))

(define string-ref raven-string-ref)

;;  substring and string-copy are one procedure under two names, which
;;  is what R7RS says they are, and string-copy fills in the whole
;;  string when it is not told where to start and stop.

(define (substring string start end) (raven-substring string start end))

(define (string-copy string start end)
  (raven-substring string
		   (optional start 0)
		   (optional end (string-length string))))

;;  Comparison.  A string is compared by its characters and a shorter
;;  string that matches as far as it goes comes first.

(define (str=? a b) (= (raven-string-compare a b) 0))
(define (str<? a b) (< (raven-string-compare a b) 0))

(define (string=? . ss) (all-left-assoc str=? #t ss))
(define (string<? . ss) (all-left-assoc str<? #t ss))
(define (string>? . ss) (all-left-assoc (lambda (a b) (str<? b a)) #t ss))
(define (string<=? . ss)
  (all-left-assoc (lambda (a b) (not (str<? b a))) #t ss))
(define (string>=? . ss)
  (all-left-assoc (lambda (a b) (not (str<? a b))) #t ss))

;;  string-map and string-for-each take as many strings as they are
;;  given and stop at the shortest, because map and for-each do: each
;;  is the list one with the strings taken apart on the way in.

;;  Vectors.  The machine holds a vector's elements in the cells after
;;  its length, so make-vector, vector-length, vector-ref and
;;  vector-set! are arithmetic rather than walks, and everything below
;;  is written on those four.
;;
;;  #(1 2 3) reads as a call of vector, which is why vector is the one
;;  that has to exist for the syntax to mean anything.

(define (make-vector n fill) (raven-make-vector n (optional fill '())))

(define (vector . elements) (list->vector elements))

(define (list->vector elements)
  (fill-vector (make-vector (length elements) '()) 0 elements))

(define (fill-vector v at elements)
  (if (null? elements)
      v
      (begin (vector-set! v at (car elements))
	     (fill-vector v (+ at 1) (cdr elements)))))

(define (vector->list v start end)
  (vector-onto v (optional start 0) (- (optional end (vector-length v)) 1)))

;;  Backwards, so that what is built up is what comes out and nothing
;;  has to be turned round afterwards.

(define (vector-onto v first last)
  (if (< last first)
      '()
      (vector-tail v first last '())))

(define (vector-tail v first at acc)
  (if (< at first)
      acc
      (vector-tail v first (- at 1) (cons (vector-ref v at) acc))))

(define (vector-copy v start end)
  (list->vector (vector->list v start end)))

(define (vector-append . vs)
  (list->vector (concatenate (map vector->list vs))))

(define (vector-fill! v fill start end)
  (fill-range v fill
	      (optional start 0)
	      (- (optional end (vector-length v)) 1)))

(define (fill-range v fill at last)
  (if (> at last)
      v
      (begin (vector-set! v at fill) (fill-range v fill (+ at 1) last))))

;;  vector-copy! may be given the same vector twice with the ranges
;;  over one another, and R7RS says it works as though what is read
;;  were read before any of it is written.  Going through a list is
;;  what makes that so.

(define (vector-copy! to at from start end)
  (fill-vector-at to at (vector->list from start end)))

(define (fill-vector-at v at elements)
  (if (null? elements)
      v
      (begin (vector-set! v at (car elements))
	     (fill-vector-at v (+ at 1) (cdr elements)))))

(define (vector->string v start end)
  (list->string (vector->list v start end)))

(define (string->vector string start end)
  (list->vector (string->list string start end)))

(define (vector-map f . vs)
  (list->vector (apply map f (map vector->list vs))))

(define (vector-for-each f . vs)
  (apply for-each f (map vector->list vs)))

;;  Bytevectors.  Laid out the way a vector is and one element to a
;;  slot, so a bytevector is as large as a vector of the same length;
;;  what tells them apart is what may go into one, which is said where
;;  it is put in.

(define (make-bytevector n fill) (raven-make-bytevector n (optional fill 0)))

(define (bytevector . bytes) (list->bytevector bytes))

(define (list->bytevector bytes)
  (fill-bytevector (make-bytevector (length bytes) 0) 0 bytes))

(define (fill-bytevector v at bytes)
  (if (null? bytes)
      v
      (begin (bytevector-u8-set! v at (car bytes))
	     (fill-bytevector v (+ at 1) (cdr bytes)))))

(define (bytevector->list v start end)
  (bytevector-onto v (optional start 0)
		   (- (optional end (bytevector-length v)) 1)))

(define (bytevector-onto v first last)
  (if (< last first) '() (bytevector-tail v first last '())))

(define (bytevector-tail v first at acc)
  (if (< at first)
      acc
      (bytevector-tail v first (- at 1) (cons (bytevector-u8-ref v at) acc))))

(define (bytevector-copy v start end)
  (list->bytevector (bytevector->list v start end)))

(define (bytevector-append . vs)
  (list->bytevector (concatenate (map bytevector->list vs))))

;;  Through a list, so that one bytevector given twice with the ranges
;;  lying over one another works as though everything read were read
;;  before anything is written.

(define (bytevector-copy! to at from start end)
  (fill-bytevector to at (bytevector->list from start end)))

(define (string-map f . ss)
  (list->string (apply map f (map string->list ss))))

(define (string-for-each f . ss)
  (apply for-each f (map string->list ss)))

;;  map and for-each take as many lists as they are given and stop at
;;  the shortest of them, which is what R7RS asks and what one list was
;;  not.  One list is still its own walk rather than the general one:
;;  the general one builds a list of the heads for every element it
;;  answers, and one list is what the library itself asks for
;;  everywhere -- the expander and string-append included.

(define (map f . xss)
  (if (null? xss)
      (error "map: expected at least one list")
      (if (null? (cdr xss))
	  (map1 f (car xss))
	  (map-lists f xss))))

(define (map1 f xs) (if (null? xs) '() (cons (f (car xs)) (map1 f (cdr xs)))))

(define (map-lists f xss)
  (if (any-null? xss)
      '()
      (cons (apply f (heads xss)) (map-lists f (rests xss)))))

(define (for-each f . xss)
  (if (null? xss)
      (error "for-each: expected at least one list")
      (if (null? (cdr xss))
	  (for-each1 f (car xss))
	  (for-each-lists f xss))))

(define (for-each1 f xs)
  (if (null? xs) '() (begin (f (car xs)) (for-each1 f (cdr xs)))))

(define (for-each-lists f xss)
  (if (any-null? xss)
      '()
      (begin (apply f (heads xss)) (for-each-lists f (rests xss)))))

;;  Stopping at the shortest is asking whether any of them has run out,
;;  and stepping them is taking the car and the cdr of each.

(define (any-null? xss)
  (if (null? xss)
      #f
      (if (null? (car xss)) #t (any-null? (cdr xss)))))

(define (heads xss) (if (null? xss) '() (cons (caar xss) (heads (cdr xss)))))
(define (rests xss) (if (null? xss) '() (cons (cdar xss) (rests (cdr xss)))))

;;  R7RS has two ways of turning an object into text and they differ
;;  on exactly two kinds of it: a string has its quotation marks and
;;  its escapes when it is to be read back and not when it is to be
;;  read, and a character has its #\ and its name.
;;
;;  There was one renderer and display was it, so write was display
;;  with nothing added -- which made write right about strings, since
;;  the renderer quoted them, and display wrong about them for the
;;  same reason.  Each was right half the time.
;;
;;  And display answered with the text rather than writing it, which
;;  is what object->string would do and not what display does.  Both
;;  of them write now, and answer nothing in particular.


(define (sum-list xs) (if (null? xs) 0 (+ (car xs) (sum-list (cdr xs)))))
(define sum (lambda xs (sum-list xs)))

;;  Odds and ends the macro expander needs, and that a base library
;;  wants in any case.

;;  car, cdr, cons and pair? are forms the translator knows, which
;;  compiles them to an instruction, so the names have no value to pass
;;  to anything.  Defining them gives the name a procedure as well: a
;;  call written out still compiles to the instruction, and (map car xs)
;;  now has a car to map.

(define (car x) (car x))
(define (cdr x) (cdr x))
(define (cons x y) (cons x y))
(define (pair? x) (pair? x))

;;  apply is one of those forms too, for the same reason and with the
;;  same remedy.  A call already builds a list of its arguments and
;;  hands AP the list, so a call whose list is built already is that
;;  sequence with the building left out, and the translator writes it
;;  without a procedure to call.  This gives the name one, so that
;;  apply can be passed to something.

(define (apply f args) (apply f args))

(define (caar x) (car (car x)))
(define (cadr x) (car (cdr x)))
(define (cdar x) (cdr (car x)))
(define (cddr x) (cdr (cdr x)))
(define (caddr x) (car (cddr x)))

;;  The three member procedures are one walk, and so are the three
;;  assoc procedures: what tells them apart is only how they ask
;;  whether two things are the same.  member and assoc take that
;;  question from the caller, and ask equal? when the caller leaves it
;;  out.  The question is asked with what was looked for first, which
;;  is the order R7RS gives a compare of one's own.

(define (member-by same? x xs)
  (if (null? xs)
      #f
      (if (same? x (car xs))
          xs
          (member-by same? x (cdr xs)))))

(define (memq x xs) (member-by eq? x xs))
(define (memv x xs) (member-by eqv? x xs))
(define (member x xs compare) (member-by (optional compare equal?) x xs))

(define (assoc-by same? key alist)
  (if (null? alist)
      #f
      (if (same? key (caar alist))
          (car alist)
          (assoc-by same? key (cdr alist)))))

(define (assq key alist) (assoc-by eq? key alist))
(define (assv key alist) (assoc-by eqv? key alist))
(define (assoc key alist compare)
  (assoc-by (optional compare equal?) key alist))

;;  syntax-rules
;;
;;  (define-syntax name (syntax-rules (literal ...) (pattern template) ...))
;;
;;  Each pattern is matched against the form that used the macro, and
;;  the first one that matches gives the template that takes its place.
;;  The head of a pattern is not matched, _ matches anything without
;;  binding it, a literal matches only itself, and a pattern followed by
;;  ... matches any number of forms in a row.
;;
;;  A match is a list of (name depth value).  At depth zero the value is
;;  what the name matched; at depth n it is a list of depth n-1 values,
;;  one for each repetition, which is what a name under n ellipses holds.
;;
;;  define-syntax is a define-macro, so it inherits what define-macro
;;  guarantees, which is nothing: a name a template introduces means
;;  whatever it means where the macro is used.  Generate one with gensym
;;  where that matters.

(define sr-none (gensym 'no-match))

(define (sr-ellipsis? x)
  (if (pair? x) (eq? (car x) '...) #f))

(define (sr-vars pattern literals)
  (if (symbol? pattern)
      (if (eq? pattern '_)
          '()
          (if (eq? pattern '...)
              '()
              (if (eq? (memq pattern literals) #f)
                  (list pattern)
                  '())))
      (if (pair? pattern)
          (append (sr-vars (car pattern) literals)
                  (sr-vars (cdr pattern) literals))
          '())))

;;  Splitting a form for an ellipsis, without counting: step a lead
;;  pointer as far into the form as the pattern after the ellipsis
;;  reaches, then walk both until the lead runs out.  What the first
;;  pointer passed over is what repeats.

(define (sr-advance xs n)
  (if (pair? n)
      (if (pair? xs)
          (sr-advance (cdr xs) (cdr n))
          sr-none)
      xs))

(define (sr-walk xs lead)
  (if (pair? lead)
      ((lambda (rest)
         (cons (cons (car xs) (car rest)) (cdr rest)))
       (sr-walk (cdr xs) (cdr lead)))
      (cons '() xs)))

(define (sr-split form tail)
  ((lambda (lead)
     (if (eq? lead sr-none)
         sr-none
         (sr-walk form lead)))
   (sr-advance form tail)))

(define (sr-match pattern form literals depth bindings)
  (if (eq? bindings sr-none)
      sr-none
      (if (symbol? pattern)
          (sr-match-name pattern form literals depth bindings)
          (if (pair? pattern)
              (if (sr-ellipsis? (cdr pattern))
                  (sr-match-repeated (car pattern) (cddr pattern) form
                                     literals depth bindings)
                  (if (pair? form)
                      (sr-match (cdr pattern) (cdr form) literals depth
                                (sr-match (car pattern) (car form)
                                          literals depth bindings))
                      sr-none))
              (if (equal? pattern form) bindings sr-none)))))

(define (sr-match-name pattern form literals depth bindings)
  (if (eq? pattern '_)
      bindings
      (if (eq? (memq pattern literals) #f)
          (cons (list pattern depth form) bindings)
          (if (eq? form pattern) bindings sr-none))))

(define (sr-match-repeated sub tail form literals depth bindings)
  ((lambda (split)
     (if (eq? split sr-none)
         sr-none
         ((lambda (matches)
            (if (eq? matches sr-none)
                sr-none
                (sr-match tail (cdr split) literals depth
                          (append (sr-gather (sr-vars sub literals)
                                             sub matches depth)
                                  bindings))))
          (sr-match-each sub (car split) literals depth))))
   (sr-split form tail)))

(define (sr-match-each sub forms literals depth)
  (if (null? forms)
      '()
      ((lambda (first)
         (if (eq? first sr-none)
             sr-none
             ((lambda (rest)
                (if (eq? rest sr-none)
                    sr-none
                    (cons first rest)))
              (sr-match-each sub (cdr forms) literals depth))))
       (sr-match sub (car forms) literals depth '()))))

;;  How many ellipses of a pattern a name sits under.  That is what its
;;  depth goes up by when the pattern it is in repeats: a name two deep
;;  holds a list of lists.

(define (sr-under name pattern)
  (if (pair? pattern)
      (if (eq? (memq name (sr-vars (car pattern) '())) #f)
          (if (sr-ellipsis? (cdr pattern))
              (sr-under name (cddr pattern))
              (sr-under name (cdr pattern)))
          (if (sr-ellipsis? (cdr pattern))
              (+ 1 (sr-under name (car pattern)))
              (sr-under name (car pattern))))
      0))

(define (sr-gather names sub matches depth)
  (if (null? names)
      '()
      (cons (list (car names)
                  (+ depth 1 (sr-under (car names) sub))
                  (map (lambda (m) (caddr (assq (car names) m))) matches))
            (sr-gather (cdr names) sub matches depth))))

;;  The names a template binds are renamed, each to a symbol nothing
;;  can write, so that what the caller hands the macro keeps its own
;;  meaning inside them.  Only what the template binds is renamed: a
;;  name it merely refers to still means whatever it means where the
;;  macro is used, which is what define-macro means and no more.
;;
;;  A name that came from the pattern is the caller's own and is left
;;  alone.  lambda and let are the forms looked at: a binding the
;;  expander does not recognise is left alone too, which costs the
;;  caller nothing it had before.
;;
;;  A name written inside a quasiquote in a template is renamed as
;;  though it were code, where hygiene would hand back the name as
;;  written.  A quote is read properly; a quasiquote is not, yet.

(define (sr-names x)
  (if (symbol? x)
      (if (eq? x '...)
          '()
          (if (eq? x '_) '() (list x)))
      (if (pair? x)
          (append (sr-names (car x)) (sr-names (cdr x)))
          '())))

(define (sr-let-names bindings)
  (if (pair? bindings)
      (if (pair? (car bindings))
          (if (symbol? (caar bindings))
              (cons (caar bindings) (sr-let-names (cdr bindings)))
              (sr-let-names (cdr bindings)))
          (sr-let-names (cdr bindings)))
      '()))

;;  A named let binds its tag as well as the names in its bindings,
;;  and the tag is what do writes its loop as -- so without this a
;;  program with a name of its own where the tag lands would have it
;;  taken over.

(define (sr-bound-here template)
  (if (eq? (car template) 'lambda)
      (if (pair? (cdr template)) (sr-names (cadr template)) '())
      (if (eq? (car template) 'let)
	  (if (pair? (cdr template))
	      (if (symbol? (cadr template))
		  (cons (cadr template)
			(if (pair? (cddr template))
			    (sr-let-names (caddr template))
			    '()))
		  (sr-let-names (cadr template)))
	      '())
	  '())))

(define (sr-binders template)
  (if (pair? template)
      (append (sr-bound-here template)
              (append (sr-binders (car template))
                      (sr-binders (cdr template))))
      '()))

(define (sr-introduced names bindings)
  (if (null? names)
      '()
      (if (eq? (assq (car names) bindings) #f)
          (cons (car names) (sr-introduced (cdr names) bindings))
          (sr-introduced (cdr names) bindings))))

(define (sr-fresh names)
  (if (null? names)
      '()
      (cons (cons (car names) (gensym (car names)))
            (sr-fresh (cdr names)))))

(define (sr-renames template bindings)
  (sr-fresh (sr-introduced (sr-binders template) bindings)))

(define (sr-instantiate template bindings renames)
  (if (symbol? template)
      ((lambda (found)
         (if (eq? found #f)
             ((lambda (renamed)
                (if (eq? renamed #f) template (cdr renamed)))
              (assq template renames))
             (caddr found)))
       (assq template bindings))
      (if (pair? template)
          (if (eq? (car template) 'quote)

              ;;  Quoted names are data, and stay as they were written.
              ;;  What the pattern bound still goes in.

              (cons 'quote (sr-instantiate (cdr template) bindings '()))
              (if (sr-ellipsis? (cdr template))
                  (append (sr-repeat (car template) bindings renames)
                          (sr-instantiate (cddr template) bindings renames))
                  (cons (sr-instantiate (car template) bindings renames)
                        (sr-instantiate (cdr template) bindings renames))))
          template)))

(define (sr-repeat sub bindings renames)
  ((lambda (names)
     (if (null? names)
         (error "syntax-rules: ... follows nothing that repeats")
         (sr-repeat-each sub names bindings renames)))
   (sr-repeated (sr-vars sub '()) bindings)))

(define (sr-repeated names bindings)
  (if (null? names)
      '()
      ((lambda (found)
         (if (eq? found #f)
             (sr-repeated (cdr names) bindings)
             (if (= (cadr found) 0)
                 (sr-repeated (cdr names) bindings)
                 (cons (car names) (sr-repeated (cdr names) bindings)))))
       (assq (car names) bindings))))

;;  A repetition is over when any of the names it runs through has
;;  nothing left.

(define (sr-spent? names bindings)
  (if (null? names)
      #f
      (if (null? (caddr (assq (car names) bindings)))
          #t
          (sr-spent? (cdr names) bindings))))

(define (sr-heads names bindings)
  (map (lambda (b)
         (if (eq? (memq (car b) names) #f)
             b
             (list (car b) (- (cadr b) 1) (car (caddr b)))))
       bindings))

(define (sr-rests names bindings)
  (map (lambda (b)
         (if (eq? (memq (car b) names) #f)
             b
             (list (car b) (cadr b) (cdr (caddr b)))))
       bindings))

(define (sr-repeat-each sub names bindings renames)
  (if (sr-spent? names bindings)
      '()
      (cons (sr-instantiate sub (sr-heads names bindings) renames)
            (sr-repeat-each sub names (sr-rests names bindings) renames))))

(define (sr-expand literals rules args)
  (if (null? rules)
      (error "syntax-rules: no rule matches this form")
      ((lambda (rule)
         ((lambda (bindings)
            (if (eq? bindings sr-none)
                (sr-expand literals (cdr rules) args)
                (sr-instantiate (cadr rule) bindings
                                (sr-renames (cadr rule) bindings))))
          (sr-match (cdr (car rule)) args literals 0 '())))
       (car rules))))

(define (sr-syntax-rules? spec)
  (if (pair? spec) (eq? (car spec) 'syntax-rules) #f))

;;  define-syntax writes a define-macro that hands the form it was used
;;  on to the expander, along with the literals and the rules.  So a
;;  macro defined this way is a macro like any other: it takes the scope
;;  define-macro takes, and it is expanded where it stands.
;;
;;  This is the one macro here that is not written with syntax-rules,
;;  and it is the one that cannot be: a rule of its own is what it
;;  would have to be read by.  Everything above it is written without
;;  the macros it defines, for the same reason -- the expander cannot
;;  use what only it can expand.

(define-macro (define-syntax sr-name sr-rules)
  (if (sr-syntax-rules? sr-rules)
      (if (symbol? (cadr sr-rules))
          (error "define-syntax: syntax-rules with an ellipsis of its own is not here yet")
          `(define-macro (,sr-name . sr-form)
             (sr-expand ',(cadr sr-rules) ',(cddr sr-rules) sr-form)))
      (error "define-syntax: expected (syntax-rules (literal ...) rule ...)")))

;;  The forms above are all define-syntax has to be written with.  What
;;  follows is written with it, and is what R7RS asks for rather than
;;  what was quickest to write by hand: or no longer evaluates the
;;  argument it answers with twice, because it can hold it in a name of
;;  its own and trust the name to stay its own.

;;  let, and the named let that is a letrec around a lambda applied
;;  where it stands.  A bare name cannot match a list of bindings, so
;;  which of the two is meant is decided by the shape of what follows.

(define-syntax let
  (syntax-rules ()
    ((_ ((name value) ...) body ...)
     ((lambda (name ...) body ...) value ...))
    ((_ tag ((name value) ...) body ...)
     ((letrec ((tag (lambda (name ...) body ...))) tag) value ...))))

;;  let-syntax binds macros for a body and no further.  A body is a
;;  region and a macro defined in one belongs to it, so the body of a
;;  procedure applied on the spot is all it takes.  The macros are in
;;  scope for each other, which is what letrec-syntax asks for and more
;;  than let-syntax promises, so one template serves for both.

(define-syntax let-syntax
  (syntax-rules ()
    ((_ ((name spec) ...) body ...)
     ((lambda () (define-syntax name spec) ... body ...)))))

(define-syntax letrec-syntax
  (syntax-rules ()
    ((_ ((name spec) ...) body ...)
     ((lambda () (define-syntax name spec) ... body ...)))))

(define-syntax when
  (syntax-rules ()
    ((_ test body ...) (if test (begin body ...) #f))))

(define-syntax unless
  (syntax-rules ()
    ((_ test body ...) (if test #f (begin body ...)))))

(define-syntax and
  (syntax-rules ()
    ((_) #t)
    ((_ a) a)
    ((_ a b ...) (if a (and b ...) #f))))

(define-syntax or
  (syntax-rules ()
    ((_) #f)
    ((_ a) a)
    ((_ a b ...) (let ((value a)) (if value value (or b ...))))))

;;  letrec and letrec*.  The machine has DUM and RAP for this and the
;;  translator emits neither, and neither is wanted: a name bound to
;;  nothing and then assigned is a letrec, and set! on a name the
;;  machine holds on the stack has worked since #26.
;;
;;  What letrec asks is that each value may name any of the others,
;;  which holds because all the names are bound before any value is
;;  worked out.  letrec* asks for that and for the values to be worked
;;  out in the order they are written, which is what this does, so one
;;  definition answers both.

(define-syntax letrec
  (syntax-rules ()
    ((_ ((name value) ...) body ...)
     (let ((name #f) ...)
       (set! name value) ...
       body ...))))

(define-syntax letrec*
  (syntax-rules ()
    ((_ ((name value) ...) body ...)
     (letrec ((name value) ...) body ...))))

;;  let* is a let inside a let, as deep as it has bindings, so each
;;  value sees the ones before it.

(define-syntax let*
  (syntax-rules ()
    ((_ () body ...) (let () body ...))
    ((_ ((name value)) body ...) (let ((name value)) body ...))
    ((_ ((name value) rest ...) body ...)
     (let ((name value)) (let* (rest ...) body ...)))))

;;  cond.  else and => are literals, so a clause is told from a test
;;  by what is written in it rather than by what it evaluates to.
;;  The rules that take => come before the general one, because
;;  (test => f) also reads as a test and two results.
;;
;;  A clause of a test alone answers with the test, which is why that
;;  one holds it in a name: it is asked once and answered with.

(define-syntax cond
  (syntax-rules (else =>)
    ((_ (else result ...)) (begin result ...))
    ((_ (test => receiver)) (let ((value test)) (if value (receiver value) #f)))
    ((_ (test => receiver) clause ...)
     (let ((value test)) (if value (receiver value) (cond clause ...))))
    ((_ (test)) test)
    ((_ (test) clause ...) (let ((value test)) (if value value (cond clause ...))))
    ((_ (test result ...)) (if test (begin result ...) #f))
    ((_ (test result ...) clause ...)
     (if test (begin result ...) (cond clause ...)))))

;;  case asks memv of each clause's data, and holds the key in a name
;;  so that it is worked out once however many clauses it is compared
;;  against.  The rule for one clause comes first, because the rule
;;  for several matches one as well with nothing left over.

(define-syntax case
  (syntax-rules (else =>)
    ((_ key (else => receiver)) (receiver key))
    ((_ key (else result ...)) (begin result ...))
    ((_ key ((datum ...) => receiver))
     (if (memv key '(datum ...)) (receiver key) #f))
    ((_ key ((datum ...) result ...))
     (if (memv key '(datum ...)) (begin result ...) #f))
    ((_ key ((datum ...) result ...) clause ...)
     (let ((k key))
       (if (memv k '(datum ...)) (begin result ...) (case k clause ...))))))

;;  do is a named let: the variables are what it loops on, the step is
;;  what each becomes, and a variable written without one stays as it
;;  was.  That last is what do-next is for -- a step is optional, and
;;  a pattern cannot say so without somewhere to put the two shapes.

(define-syntax do-next
  (syntax-rules ()
    ((_ variable) variable)
    ((_ variable step) step)))

(define-syntax do
  (syntax-rules ()
    ((_ ((variable init step ...) ...) (test result ...) command ...)
     (let again ((variable init) ...)
       (if test
	   (begin #f result ...)
	   (begin
	     command ...
	     (again (do-next variable step ...) ...)))))))

;;  Records (#154).  A record is an object of its own, laid out as a
;;  vector is with its type in front, so that nothing else answers for
;;  it: it is not a vector, a pair or a procedure.  A record type is a
;;  record too, with #f where its type would be; its fields are its
;;  name and the names of the fields of its records.
;;
;;  define-record-type makes the type and then asks it for each
;;  procedure, which is worked out once, when the type is defined: the
;;  constructor knows which fields it fills and the accessors which
;;  field they read.  Each says which of them it is when it is handed
;;  something that is not a record of its type.

(define (make-record-type name fields)
  (let ((type (raven-make-record #f 2)))
    (raven-record-set! type 0 name)
    (raven-record-set! type 1 fields)
    type))

(define (record-type-name type) (raven-record-ref type 0))
(define (record-type-fields type) (raven-record-ref type 1))

(define (record-of? type x)
  (if (raven-record? x) (eq? (raven-record-type x) type) #f))

(define (record-field-index type field who)
  (let loop ((fields (record-type-fields type)) (index 0))
    (cond ((null? fields)
           (error (string-append (symbol->string who) ": "
                                 (symbol->string field)
                                 " is not a field of "
                                 (symbol->string (record-type-name type)))))
          ((eq? (car fields) field) index)
          (else (loop (cdr fields) (+ index 1))))))

(define (record-check type x who)
  (if (not (record-of? type x))
      (error (string-append (symbol->string who) ": expected a "
                            (symbol->string (record-type-name type)))
             x)))

(define (record-constructor type fields who)
  (let ((count (length (record-type-fields type)))
        (indices (map (lambda (field) (record-field-index type field who))
                      fields)))
    (lambda args
      (if (not (= (length args) (length indices)))
          (error (string-append (symbol->string who) ": expected "
                                (number->string (length indices))
                                " arguments")
                 args))
      (let ((record (raven-make-record type count)))
        (for-each (lambda (index arg) (raven-record-set! record index arg))
                  indices args)
        record))))

(define (record-accessor type field who)
  (let ((index (record-field-index type field who)))
    (lambda (record)
      (record-check type record who)
      (raven-record-ref record index))))

(define (record-modifier type field who)
  (let ((index (record-field-index type field who)))
    (lambda (record value)
      (record-check type record who)
      (raven-record-set! record index value)
      (if #f #f))))

;;  Each field spec is (field accessor) or (field accessor modifier),
;;  one at a time, so that the two shapes can be told apart.

(define-syntax record-field-procedures
  (syntax-rules ()
    ((_ type (field accessor))
     (define accessor (record-accessor type 'field 'accessor)))
    ((_ type (field accessor modifier))
     (begin
       (define accessor (record-accessor type 'field 'accessor))
       (define modifier (record-modifier type 'field 'modifier))))
    ((_ type spec more ...)
     (begin
       (record-field-procedures type spec)
       (record-field-procedures type more ...)))))

(define-syntax define-record-type
  (syntax-rules ()
    ((_ type (constructor field ...) predicate)
     (begin
       (define type (make-record-type 'type '()))
       (define constructor
         (record-constructor type '(field ...) 'constructor))
       (define (predicate x) (record-of? type x))))
    ((_ type (constructor field ...) predicate spec ...)
     (begin
       (define type (make-record-type 'type (map car '(spec ...))))
       (define constructor
         (record-constructor type '(field ...) 'constructor))
       (define (predicate x) (record-of? type x))
       (record-field-procedures type spec ...)))))

;;  Promises (#168).  A promise is a record of its own, so promise?
;;  can tell one from a procedure and make-promise of a procedure is a
;;  promise of it.  What it holds is a box, a pair of whether it is done
;;  and either its value or the thunk that will work it out: forcing a
;;  promise whose thunk answers another promise hands the other's box
;;  to this one, so that a chain of delay-force runs in the space of
;;  one, as R7RS asks and as its own implementation of them does.
;;
;;  A thunk that forces its own promise again may have finished it by
;;  the time it answers; that answer is the promise's, and the later
;;  one is not.

(define-record-type promise
  (raven-promise box)
  promise?
  (box promise-box set-promise-box!))

(define (make-promise-box done? value) (raven-promise (cons done? value)))
(define (promise-done? p) (car (promise-box p)))
(define (promise-value p) (cdr (promise-box p)))

(define (promise-update! new old)
  (set-car! (promise-box old) (promise-done? new))
  (set-cdr! (promise-box old) (promise-value new))
  (set-promise-box! new (promise-box old)))

;;  What is not a promise is its own value, which R7RS allows.

(define (force p)
  (if (not (promise? p))
      p
      (if (promise-done? p)
          (promise-value p)
          (let ((next ((promise-value p))))
            (if (not (promise-done? p))
                (promise-update! next p))
            (force p)))))

(define (make-promise value)
  (if (promise? value) value (make-promise-box #t value)))

(define-syntax delay-force
  (syntax-rules ()
    ((_ expression) (make-promise-box #f (lambda () expression)))))

(define-syntax delay
  (syntax-rules ()
    ((_ expression) (delay-force (make-promise-box #t expression)))))

;;  boolean? waits here for or rather than sitting with the other
;;  predicates, because or is now one of the forms above.

(define (boolean? x) (or (eq? x #t) (eq? x #f)))

;;  The comparisons of booleans, symbols and characters (#157), each
;;  taking any number of arguments as = does.  Each says what it was
;;  given when that is not what it compares, rather than answering #f
;;  for a question that was never about the same kind of thing.  A
;;  character is compared by its code point.

(define (bool=? a b)
  (if (and (boolean? a) (boolean? b))
      (eq? a b)
      (error "boolean=?: expected booleans" a b)))

(define (sym=? a b)
  (if (and (symbol? a) (symbol? b))
      (eq? a b)
      (error "symbol=?: expected symbols" a b)))

(define (char-code c)
  (if (char? c)
      (char->integer c)
      (error "expected a character" c)))

(define (boolean=? . bs) (all-left-assoc bool=? #t bs))
(define (symbol=? . ss) (all-left-assoc sym=? #t ss))

(define (char=? . cs)
  (all-left-assoc (lambda (a b) (= (char-code a) (char-code b))) #t cs))
(define (char<? . cs)
  (all-left-assoc (lambda (a b) (< (char-code a) (char-code b))) #t cs))
(define (char>? . cs)
  (all-left-assoc (lambda (a b) (> (char-code a) (char-code b))) #t cs))
(define (char<=? . cs)
  (all-left-assoc (lambda (a b) (<= (char-code a) (char-code b))) #t cs))
(define (char>=? . cs)
  (all-left-assoc (lambda (a b) (>= (char-code a) (char-code b))) #t cs))

;;  Parameters (#155).  A parameter is a procedure that answers its
;;  value, which is its converter's answer to what it was made with.
;;  parameterize gives it another for the dynamic extent of a body: the
;;  new values are converted first, then swapped in and out by
;;  dynamic-wind, so that leaving the body by an error or a continuation
;;  puts the old ones back and coming into it again puts the new ones
;;  back in.  What a parameter keeps is reached through markers nothing
;;  else has, so a program can only ask a parameter its value.

(define raven-parameter-set (list 'parameter-set))
(define raven-parameter-converter (list 'parameter-converter))

(define (make-parameter value converter)
  (let* ((convert (optional converter (lambda (x) x)))
         (current (convert value)))
    (lambda args
      (cond ((null? args) current)
            ((eq? (car args) raven-parameter-set)
             (set! current (car (cdr args))))
            ((eq? (car args) raven-parameter-converter) convert)
            (else (error "a parameter takes no arguments" args))))))

(define (raven-parameterize parameters values thunk)
  (let ((held (map (lambda (p v) ((p raven-parameter-converter) v))
                   parameters values)))
    (let ((swap (lambda ()
                  (set! held
                        (map (lambda (p v)
                               (let ((old (p)))
                                 (p raven-parameter-set v)
                                 old))
                             parameters held)))))
      (dynamic-wind swap thunk swap))))

(define-syntax parameterize
  (syntax-rules ()
    ((_ ((parameter value) ...) body ...)
     (raven-parameterize (list parameter ...) (list value ...)
                         (lambda () body ...)))))

;;  Ports.  Everything raven could write went to one place through
;;  one foreign function, and nothing could read at all.
;;
;;  They come after the derived syntax because they are written with
;;  let, and let is derived here.  Above it, (let ((x ...)) ...) is
;;  not a binding form at all but a call of something named let, and
;;  every procedure written with one failed at the name it had bound
;;  -- quietly, because a form that names something undefined is
;;  reported and passed over, so the tests of it simply did not run.
;;
;;  The host's three keep their places in the machine's table, so
;;  asking for one twice is asking for the same port; they are held in
;;  names here so that asking for one does not make another object
;;  every time.

(define raven-the-eof-object (raven-eof-object))

(define raven-output-port (raven-standard-port 1))
(define raven-error-port (raven-standard-port 2))
(define raven-input-port (raven-standard-port 3))

;;  The current ports are parameters, as R7RS has them, so that
;;  parameterize can send what is written somewhere else (#155).  Each
;;  takes only the kind of port it is.

(define (raven-port-converter who kind?)
  (lambda (p)
    (if (kind? p) p (error (string-append who ": expected a port") p))))

(define current-output-port
  (make-parameter raven-output-port
                  (raven-port-converter "current-output-port" output-port?)))
(define current-error-port
  (make-parameter raven-error-port
                  (raven-port-converter "current-error-port" output-port?)))
(define current-input-port
  (make-parameter raven-input-port
                  (raven-port-converter "current-input-port" input-port?)))

;;  textual-port? and binary-port? are the machine's to answer now.
;;  Every port was textual, so one was port? and the other was #f.

(define (close-port p) (raven-close-port p))
(define (close-input-port p) (raven-close-port p))
(define (close-output-port p) (raven-close-port p))

(define (input-port-open? p) (if (input-port? p) (raven-port-open? p) #f))
(define (output-port-open? p) (if (output-port? p) (raven-port-open? p) #f))

(define (call-with-port p f) (let ((answer (f p))) (close-port p) answer))

;;  Nothing is held back, so there is nothing to push out.

(define (flush-output-port p) '())

;;  Reading and writing.  Each of these takes the port to use and
;;  uses the one the host gave when it is not given one.

(define (eof-object) raven-the-eof-object)
(define (eof-object? x) (eq? x raven-the-eof-object))

(define (write-char ch port)
  (raven-write-char-to ch (optional port (current-output-port))))

(define (write-char-list chars port)
  (if (null? chars)
      '()
      (begin (write-char (car chars) port)
	     (write-char-list (cdr chars) port))))

(define (write-string string port)
  (write-char-list (string->list string)
		   (optional port (current-output-port))))

(define (newline port) (write-char #\newline port))

(define (write x port) (write-string (raven-write-text x) port))
(define (write-simple x port) (write x port))
(define (display x port) (write-string (raven-display-text x) port))

;;  A port that has run out answers with the end of file object, which
;;  is one object and nothing else.

(define (read-char port)
  (raven-read-char (optional port (current-input-port))))

(define (peek-char port)
  (raven-peek-char (optional port (current-input-port))))

(define (char-ready? port)
  (raven-char-ready? (optional port (current-input-port))))

;;  A line is up to the next newline, which is read and thrown away.
;;  A port with nothing left at all answers with the end of it; one
;;  with a line and no newline after it answers with the line.

(define (read-line-onto p ch acc)
  (if (eof-object? ch)
      acc
      (if (eq? ch #\newline)
	  acc
	  (read-line-onto p (read-char p) (cons ch acc)))))

(define (read-line-from p)
  (let ((first (read-char p)))
    (if (eof-object? first)
	first
	(list->string (reverse (read-line-onto p first '()))))))

(define (read-line port)
  (read-line-from (optional port (current-input-port))))

;;  And a string of up to this many characters, which is shorter when
;;  the port runs out first and the end of it when it had already.

(define (read-chars p k acc)
  (if (= k 0)
      acc
      (let ((ch (read-char p)))
	(if (eof-object? ch) acc (read-chars p (- k 1) (cons ch acc))))))

(define (read-string-from k p)
  (let ((chars (reverse (read-chars p k '()))))
    (if (null? chars)
	(if (= k 0) "" (eof-object))
	(list->string chars))))

(define (read-string k port)
  (read-string-from k (optional port (current-input-port))))

;;  And the same over again a byte at a time, for a port opened on a
;;  bytevector.  A binary port answers for none of the above and a
;;  textual one for none of these: R7RS lets a port be both, and none
;;  here is.
;;
;;  The host's three are textual, so (read-u8) with no port is an
;;  error rather than a read of the terminal -- which is what R7RS
;;  says a binary read of a textual port is.

(define (write-u8 byte port)
  (raven-write-u8-to byte (optional port (current-output-port))))

(define (write-u8-list bytes port)
  (if (null? bytes)
      '()
      (begin (write-u8 (car bytes) port)
	     (write-u8-list (cdr bytes) port))))

(define (write-bytevector v port start end)
  (write-u8-list (bytevector->list v (optional start 0)
				   (optional end (bytevector-length v)))
		 (optional port (current-output-port))))

(define (read-u8 port)
  (raven-read-u8 (optional port (current-input-port))))

(define (peek-u8 port)
  (raven-peek-u8 (optional port (current-input-port))))

(define (u8-ready? port)
  (raven-u8-ready? (optional port (current-input-port))))

;;  Up to this many bytes, which is fewer when the port runs out first
;;  and the end of it when it had already.

(define (read-u8s p k acc)
  (if (= k 0)
      acc
      (let ((byte (read-u8 p)))
	(if (eof-object? byte) acc (read-u8s p (- k 1) (cons byte acc))))))

(define (read-bytevector-from k p)
  (let ((bytes (reverse (read-u8s p k '()))))
    (if (null? bytes)
	(if (= k 0) (bytevector) (eof-object))
	(list->bytevector bytes))))

(define (read-bytevector k port)
  (read-bytevector-from k (optional port (current-input-port))))

;;  Into a bytevector that is already there rather than into a new
;;  one, between start and end, answering with how many bytes arrived.
;;  start and end are read the way bytevector-copy! reads them.

(define (read-bytevector-into v p at end)
  (let ((bytes (reverse (read-u8s p (- end at) '()))))
    (if (null? bytes)
	(if (= at end) 0 (eof-object))
	(begin (fill-bytevector v at bytes) (length bytes)))))

(define (read-bytevector! v port start end)
  (read-bytevector-into v (optional port (current-input-port))
			(optional start 0)
			(optional end (bytevector-length v))))

;;  What this raven is: the feature identifiers R7RS's appendix names,
;;  as far as they are true here, and raven's own.  The list is the
;;  machine's, because what a raven has is decided where it is built.

(define (features) (raven-features))

;;  cond-expand as an expression, which chooses where it is expanded
;;  rather than where it is run: the clauses not chosen are never read
;;  as code at all, so one may use a name that does not exist here.
;;  Which clause holds is asked of the machine, which is where the
;;  define-library declaration of the same name asks it too.  None
;;  holding is left unspecified by R7RS, and here is nothing.

(define (cond-expand-choose clauses)
  (if (null? clauses)
      '(if #f #f)
      (if (if (eq? (car (car clauses)) 'else)
	      #t
	      (raven-feature-requirement? (car (car clauses))))
	  (cons 'begin (cdr (car clauses)))
	  (cond-expand-choose (cdr clauses)))))

(define-macro (cond-expand . clauses)
  (cond-expand-choose clauses))

;;  Multiple values (#48).  Several values are one object of their own,
;;  which is not a pair, so a program cannot take them for a list; and
;;  one value is the value itself, so a procedure that answers one never
;;  makes one of these.  call-with-values is what takes them apart.
;;
;;  R7RS calls handing several values to a continuation that wants one
;;  an error.  Raven lets it through, and the object is written as
;;  #<values 1 2> where it turns up, which is the shape most
;;  implementations start from.

(define (values . xs)
  (if (if (pair? xs) (null? (cdr xs)) #f)
      (car xs)
      (raven-make-values xs)))

(define (call-with-values producer consumer)
  (let ((v (producer)))
    (if (raven-values? v)
        (apply consumer (raven-values-list v))
        (consumer v))))

;;  let*-values binds each set of formals in turn, so each expression
;;  sees the ones before it: a call-with-values inside the last.

(define-macro (let*-values bindings . body)
  (if (null? bindings)
      `(let () ,@body)
      `(call-with-values (lambda () ,(cadr (car bindings)))
         (lambda ,(car (car bindings))
           (let*-values ,(cdr bindings) ,@body)))))

;;  let-values evaluates every expression where the let-values is, so
;;  none of them sees the others' formals.  Each set is bound first to
;;  names made fresh with gensym, which nothing can have written, and
;;  the formals are bound to those only around the body.  Formals are a
;;  list, a name for all of them, or a list with a name for the rest.

(define (values-rename formals)
  (if (null? formals)
      (cons '() '())
      (if (symbol? formals)
          (let ((fresh (gensym formals)))
            (cons fresh (list (list formals fresh))))
          (let ((fresh (gensym (car formals)))
                (rest (values-rename (cdr formals))))
            (cons (cons fresh (car rest))
                  (cons (list (car formals) fresh) (cdr rest)))))))

(define (let-values-expand bindings renamings body)
  (if (null? bindings)
      `(let ,renamings ,@body)
      (let ((renamed (values-rename (car (car bindings)))))
        `(call-with-values (lambda () ,(cadr (car bindings)))
           (lambda ,(car renamed)
             ,(let-values-expand (cdr bindings)
                                 (append renamings (cdr renamed))
                                 body))))))

(define-macro (let-values bindings . body)
  (let-values-expand bindings '() body))

;;  define-values defines every name its formals have, and then sets
;;  them from the values, so they are defined where the define-values is
;;  whether it is at the top of a library or inside a body.

(define-macro (define-values formals expr)
  (let ((renamed (values-rename formals)))
    `(begin
       ,@(map (lambda (pair) `(define ,(car pair) #f)) (cdr renamed))
       (call-with-values (lambda () ,expr)
         (lambda ,(car renamed)
           ,@(map (lambda (pair) `(set! ,(car pair) ,(cadr pair)))
                  (cdr renamed))
           #f)))))

;;  The procedures that answer two values, which were left out while
;;  there were no multiple values to answer with.

(define (floor/ n d)
  (values (floor-quotient n d) (floor-remainder n d)))

(define (truncate/ n d)
  (values (truncate-quotient n d) (truncate-remainder n d)))

;;  The largest exact integer whose square is no more than k, and what
;;  is left over, so that k is the first squared and the second added.

(define (exact-integer-sqrt k)
  (let ((root (raven-exact-integer-sqrt k)))
    (values root (- k (* root root)))))
;;  Continuations (#47).  The machine's registers are objects on the
;;  heap and its dump is a list, so a continuation is the registers
;;  consed up and invoking one is putting them back.  raven-call/cc is
;;  the machine's own procedure that does it; call/cc wraps what it
;;  captures so that the dynamic-wind extent is right on the way.
;;
;;  dynamic-wind keeps a list of the before and after thunks of every
;;  extent the program is inside, innermost first.  A continuation
;;  remembers the list it was captured under, and invoking one travels
;;  from where the program is to where it was: out of every extent it is
;;  leaving, running each after, and into every extent it is entering,
;;  running each before, outermost first.
;;
;;  The list is kept by the machine, in the second of its dynamic
;;  registers, so that a run inside a host's callback puts it back and
;;  an error that reaches the host clears it (#46).

(define (raven-winders) (raven-dynamic 1))
(define (raven-set-winders! x) (raven-set-dynamic! 1 x))

(define (raven-travel-to here there)
  (cond ((eq? here there) #t)
        ((< (length here) (length there))
         (raven-travel-to here (cdr there))
         ((car (car there)))
         (raven-set-winders! there))
        (else
         (raven-set-winders! (cdr here))
         ((cdr (car here)))
         (raven-travel-to (cdr here) there))))

(define (call-with-current-continuation f)
  (raven-call/cc
   (lambda (k)
     (let ((saved (raven-winders)))
       (f (lambda answers
            (raven-travel-to (raven-winders) saved)
            (apply k answers)))))))

(define call/cc call-with-current-continuation)

(define (dynamic-wind before thunk after)
  (before)
  (raven-set-winders! (cons (cons before after) (raven-winders)))
  (call-with-values thunk
    (lambda answers
      (raven-set-winders! (cdr (raven-winders)))
      (after)
      (apply values answers))))

;;  Exceptions (#46).  The handlers a program has installed are a stack
;;  the machine keeps, in the first of its dynamic registers: each is the
;;  handler and the run of the machine it was installed in, innermost
;;  first.  with-exception-handler installs one for the extent of a
;;  thunk, by dynamic-wind, so that leaving the thunk by a continuation
;;  uninstalls it as returning does.
;;
;;  raise calls the innermost handler in the extent of the raise, with
;;  that handler taken off so that one it raises goes further out.  A
;;  handler that returns from raise has nowhere to return to, and is a
;;  second error raised where the handler was.  raise-continuable is
;;  raise whose handler's answer is its own.
;;
;;  A handler is only for the run it was installed in.  A raise in a run
;;  with none -- the top of a program, or a host's callback inside one
;;  that has -- goes out as the machine's errors always have, to the
;;  host or to the loader, which say where and count it; the object goes
;;  with it, and the run further out that has a handler raises it there.
;;
;;  The errors the machine finds itself -- (car 1), a name nothing
;;  defines, a primitive given what it cannot take -- come here too: the
;;  machine applies raven-raise-from-machine where the error was, when
;;  there is a handler in this run to raise it to.

(define (raven-handlers) (raven-dynamic 0))
(define (raven-set-handlers! x) (raven-set-dynamic! 0 x))

(define (with-exception-handler handler thunk)
  (let ((outer (raven-handlers)))
    (dynamic-wind
     (lambda ()
       (raven-set-handlers! (cons (cons handler (raven-run-depth)) outer)))
     thunk
     (lambda () (raven-set-handlers! outer)))))

(define (raven-with-handlers handlers thunk)
  (let ((inner (raven-handlers)))
    (dynamic-wind
     (lambda () (raven-set-handlers! handlers))
     thunk
     (lambda () (raven-set-handlers! inner)))))

(define (raven-raise obj continuable)
  (let ((handlers (raven-handlers)))
    (if (if (pair? handlers) (= (cdr (car handlers)) (raven-run-depth)) #f)
        (raven-with-handlers
         (cdr handlers)
         (lambda ()
           (let ((answer ((car (car handlers)) obj)))
             (if continuable
                 answer
                 (raise (make-error-object
                         "a handler returned from a raise that it cannot"
                         (list obj)))))))
        (raven-uncaught obj (raven-describe obj)))))

(define (raise obj) (raven-raise obj #f))
(define (raise-continuable obj) (raven-raise obj #t))

;;  An error object: what error raises, with the message and irritants
;;  kept as they were given rather than formatted into a string that a
;;  handler would have to take apart again.  It is a record of its own
;;  (#172), so it is not a vector that a program could take apart or
;;  write into, and it is written as #<error-object>.

(define-record-type error-object
  (make-error-object message irritants)
  error-object?
  (message error-object-message)
  (irritants error-object-irritants))

(define (error message . irritants)
  (raise (make-error-object message irritants)))

;;  Raven has no errors of reading or of files apart from the others, so
;;  no error object is one of those.

(define (file-error? x) #f)
(define (read-error? x) #f)

;;  What an error that reaches the host says: an error object's message
;;  and its irritants written after it, and anything else raised said to
;;  be that.

(define (raven-describe obj)
  (if (error-object? obj)
      (apply string-append
             (raven-display-text (error-object-message obj))
             (map (lambda (i) (string-append " " (raven-write-text i)))
                  (error-object-irritants obj)))
      (string-append "uncaught raise of " (raven-write-text obj))))

(define (raven-raise-from-machine raised? x)
  (raise (if raised? x (make-error-object x '()))))

(raven-set-dynamic! 2 raven-raise-from-machine)

;;  guard, as R7RS gives it: the body is run with a handler that goes
;;  back to where the guard was and tries the clauses there, with the
;;  guard's own handlers.  A clause that matches is the guard's answer;
;;  when none does, the raise goes on from where it was, continuably,
;;  to whatever handler was further out.  The names it makes are fresh,
;;  so a body or a clause cannot take one of them.

(define (raven-guard-clauses clauses reraise)
  (if (null? clauses)
      reraise
      (if (eq? (car (car (reverse clauses))) 'else)
          `(cond ,@clauses)
          `(cond ,@clauses (else ,reraise)))))

(define-macro (guard spec . body)
  (let ((var (car spec))
        (clauses (cdr spec))
        (guard-k (gensym 'guard-k))
        (handler-k (gensym 'handler-k))
        (condition (gensym 'condition))
        (answers (gensym 'answers)))
    `((call/cc
       (lambda (,guard-k)
         (with-exception-handler
          (lambda (,condition)
            ((call/cc
              (lambda (,handler-k)
                (,guard-k
                 (lambda ()
                   (let ((,var ,condition))
                     ,(raven-guard-clauses
                       clauses
                       `(,handler-k
                         (lambda () (raise-continuable ,condition)))))))))))
          (lambda ()
            (call-with-values (lambda () ,@body)
              (lambda ,answers
                (,guard-k (lambda () (apply values ,answers))))))))))))
