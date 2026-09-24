(import (scheme base) (scheme cxr))

(define num-tests 0)
(define passed-tests 0)
(define failed-tests 0)

(define (test name expect expr)
  (if (equal? expr expect)
        (begin
          (write-string (string-append "PASS  " name))
          (newline)
          (set! passed-tests (+ 1 passed-tests)))
        (begin
          (write-string "FAIL  ") (write-string name) (write-string ": expected ") (write-string (display expect))
          (write-string ", got ")
          (write-string (display expr))
          (newline)
          (set! failed-tests (+ 1 failed-tests))))
  (set! num-tests (+ 1 num-tests)))

(define (test-production expect expr)
  (test "production" expect expr))

;;  Captured before anything else in the session allocates a string, so
;;  that they are the first foreign values of the run.  Each one needs
;;  its own id: if a later value reuses an earlier one's id, both names
;;  end up denoting the same string.

(define first-append  (string-append "first"  "-append"))
(define second-append (string-append "second" "-append"))
(define third-append  (string-append "third"  "-append"))
(define fourth-append (string-append "fourth" "-append"))

(test "nil is not truthy" #f (boolean? '()))
(test "false is not truthy" #t (if #f #f #t))
(test "true is truthy" #t (if #t #t #f))
(test "integer self-equality" #t (eq? 4 (+ 2 2)))
(test "1 = 1" #t (= 1 1))
(test "(= 1 1 1)" #t (= 1 1 1))
(test "(= 1 1 2)" #f (= 1 1 2))

;;  Integer arithmetic.

;;  A negative number written out.  The reader classifies -13 as one
;;  integer token and read its value back as a Natural, which raised
;;  a range check out of the reader, so a negative number could not be
;;  written at all and had to be said as (- 13).

(test "a negative literal reads" -13 (- 13))
(test "a negative literal is the number" #t (= -13 (- 0 13)))
(test "a positive literal may be signed" 13 +13)
(test "a negative literal in a quotation" '(-1 -2) (list -1 -2))
(test "arithmetic on a negative literal" -10 (+ -13 3))

;;  The comparisons.  raven-leq was bound and nothing in scheme used
;;  it; these are it, turned around and negated.  Each is a chain, the
;;  way = is.

(test "1 < 2" #t (< 1 2))
(test "2 < 1" #f (< 2 1))
(test "1 < 1" #f (< 1 1))
(test "(< 1 2 3)" #t (< 1 2 3))
(test "(< 1 3 2)" #f (< 1 3 2))
(test "< over negatives" #t (< -2 -1))

(test "2 > 1" #t (> 2 1))
(test "1 > 2" #f (> 1 2))
(test "1 > 1" #f (> 1 1))
(test "(> 3 2 1)" #t (> 3 2 1))
(test "(> 3 1 2)" #f (> 3 1 2))
(test "> over negatives" #t (> -1 -2))

(test "1 <= 1" #t (<= 1 1))
(test "1 <= 2" #t (<= 1 2))
(test "2 <= 1" #f (<= 2 1))
(test "(<= 1 1 2)" #t (<= 1 1 2))
(test "(<= 1 2 1)" #f (<= 1 2 1))

(test "1 >= 1" #t (>= 1 1))
(test "2 >= 1" #t (>= 2 1))
(test "1 >= 2" #f (>= 1 2))
(test "(>= 2 1 1)" #t (>= 2 1 1))
(test "(>= 2 1 3)" #f (>= 2 1 3))

(test "zero? of zero" #t (zero? 0))
(test "zero? of one" #f (zero? 1))
(test "zero? of a negative" #f (zero? -1))

(test "positive? of one" #t (positive? 1))
(test "positive? of zero" #f (positive? 0))
(test "positive? of a negative" #f (positive? -1))

(test "negative? of a negative" #t (negative? -1))
(test "negative? of zero" #f (negative? 0))
(test "negative? of one" #f (negative? 1))

(test "even? of zero" #t (even? 0))
(test "even? of two" #t (even? 2))
(test "even? of three" #f (even? 3))
(test "even? of a negative even" #t (even? -4))
(test "even? of a negative odd" #f (even? -3))

(test "odd? of three" #t (odd? 3))
(test "odd? of zero" #f (odd? 0))
(test "odd? of a negative odd" #t (odd? -3))

(test "abs of a positive" 3 (abs 3))
(test "abs of a negative" 3 (abs -3))
(test "abs of zero" 0 (abs 0))

(test "square" 16 (square 4))
(test "square of a negative" 16 (square -4))
(test "square of zero" 0 (square 0))

(test "min of one" 3 (min 3))
(test "min" 1 (min 3 1 2))
(test "min over negatives" -2 (min -1 -2))
(test "max of one" 3 (max 3))
(test "max" 3 (max 3 1 2))
(test "max over negatives" -1 (max -1 -2))

;;  Division.  quotient truncates towards zero and floor-quotient
;;  rounds down, so the two differ exactly when the division does not
;;  come out even and the answer is negative.  remainder takes the
;;  sign of what was divided and modulo takes the sign of what it was
;;  divided by, which is the whole reason for having both.

(test "quotient" 3 (quotient 13 4))
(test "quotient, negative over positive" -3 (quotient -13 4))
(test "quotient, positive over negative" -3 (quotient 13 -4))
(test "quotient, negative over negative" 3 (quotient -13 -4))
(test "quotient that comes out even" -3 (quotient -12 4))

(test "remainder" 1 (remainder 13 4))
(test "remainder, negative over positive" -1 (remainder -13 4))
(test "remainder, positive over negative" 1 (remainder 13 -4))
(test "remainder, negative over negative" -1 (remainder -13 -4))
(test "remainder that comes out even" 0 (remainder 12 4))

(test "modulo" 1 (modulo 13 4))
(test "modulo, negative over positive" 3 (modulo -13 4))
(test "modulo, positive over negative" -3 (modulo 13 -4))
(test "modulo, negative over negative" -1 (modulo -13 -4))
(test "modulo that comes out even" 0 (modulo 12 4))

(test "floor-quotient" 3 (floor-quotient 13 4))
(test "floor-quotient, negative over positive" -4 (floor-quotient -13 4))
(test "floor-quotient, positive over negative" -4 (floor-quotient 13 -4))
(test "floor-quotient, negative over negative" 3 (floor-quotient -13 -4))
(test "floor-quotient that comes out even" -3 (floor-quotient -12 4))

;;  The R7RS spellings are the same procedures under the older names.

(test "truncate-quotient is quotient" #t
      (= (truncate-quotient -13 4) (quotient -13 4)))
(test "truncate-remainder is remainder" #t
      (= (truncate-remainder -13 4) (remainder -13 4)))
(test "floor-remainder is modulo" #t
      (= (floor-remainder -13 4) (modulo -13 4)))

;;  What holds of every division: the quotient and the remainder put
;;  the number back together, whichever way the quotient was rounded.

(test "truncating division puts 13 and 4 back together" 13
      (+ (* 4 (truncate-quotient 13 4)) (truncate-remainder 13 4)))
(test "flooring division puts -13 and 4 back together" -13
      (+ (* 4 (floor-quotient -13 4)) (floor-remainder -13 4)))

(test "gcd of nothing" 0 (gcd))
(test "gcd of one" 32 (gcd 32))
(test "gcd" 4 (gcd 32 36))
(test "gcd is never negative" 4 (gcd 32 -36))
(test "gcd of a negative alone" 4 (gcd -4))
(test "gcd with zero" 5 (gcd 0 5))
(test "gcd of three" 2 (gcd 12 18 8))

(test "lcm of nothing" 1 (lcm))
(test "lcm of one" 32 (lcm 32))
(test "lcm" 288 (lcm 32 36))
(test "lcm is never negative" 288 (lcm 32 -36))
(test "lcm with zero" 0 (lcm 0 5))
(test "lcm of three" 12 (lcm 2 3 4))

(test "expt to the zeroth" 1 (expt 2 0))
(test "expt to the first" 5 (expt 5 1))
(test "expt" 1024 (expt 2 10))
(test "expt of a negative base, even power" 4 (expt -2 2))
(test "expt of a negative base, odd power" -8 (expt -2 3))
(test "expt of zero to the zeroth" 1 (expt 0 0))

;;  Two bits of tag leave thirty of payload, so an exact integer has
;;  four times the range it had.  Every one of these was past the end
;;  of the road: going over used to fail a postcondition out of the
;;  machine rather than answer or raise.

(test "what used to be the largest integer" 134217727 (+ 134217726 1))
(test "one past it" 134217728 (+ 134217727 1))
(test "well past it" 400000000 (* 20000 20000))
(test "and negative" -400000000 (- 0 (* 20000 20000)))
(test "the largest integer there is now" 536870911 (+ 536870910 1))
(test "the smallest" -536870912 (- -536870911 1))

;;  A number written in another base.  The scanner knew the four
;;  prefixes and checked the digits against them, and then the whole
;;  text went to Ada's Value, which takes 16#1F# and not #x1F -- so
;;  every one of them was recognised as a number and could not be read.

(test "hexadecimal" 31 #x1F)
(test "hexadecimal, lower case digits" 255 #xff)
(test "hexadecimal, a larger one" 65536 #x10000)
(test "binary" 10 #b1010)
(test "octal" 15 #o17)
(test "decimal, said out loud" 42 #d42)
(test "and a decimal not said out loud is the same" #t (eq? #d42 42))

;;  R7RS spells the prefix in either case.

(test "an upper case prefix" 31 #X1F)
(test "an upper case prefix and digits" 255 #XFF)

;;  R7RS puts the sign after the prefix.  This took it only before,
;;  where #x-1F was a name; both orders read now.

(test "a sign after the prefix" -31 #x-1F)
(test "a sign before the prefix" -31 -#x1F)
(test "a plus after the prefix" 31 #x+1F)

;;  A digit the base does not have is not a number, which is what the
;;  scanner was already careful about and what must stay true.

(test "a two in a binary number is a name" #t (symbol? '#b12))
(test "a g in a hexadecimal number is a name" #t (symbol? '#x1g))
(test "an eight in an octal number is a name" #t (symbol? '#o18))

;;  #e and #i are the other two things that can follow a # on a
;;  number, and stay names while there is no exactness to change.

(test "an exactness prefix is still a name" #t (symbol? '#e1))
(test "the other exactness prefix is still a name" #t (symbol? '#i1))

;;  And a number with no prefix is what it was.

(test "a plain integer" 42 42)
(test "a plain negative integer" -42 -42)

;;  A float keeps every mantissa bit of a single now and gives up
;;  range instead, so a float with bits at the bottom reads.  0.1 is
;;  the one that could not: the encoding masked its last four bits off
;;  to make room for the tag, which broke the round trip the spec
;;  promised, and the form did not read at all.

(test "a float literal reads" #t (number? 0.1))
(test "a negative float literal reads" #t (number? -0.1))
(test "a float is not an integer" #f (integer? 0.1))
(test "a float without a fraction is an integer" #t (integer? 2.0))
(test "but it is not an exact integer" #f (exact-integer? 2.0))
(test "a float is not an exact integer either" #f (exact-integer? 0.1))

;;  The shapes of number the reader would not take.  An exponent was
;;  reachable only through a decimal point, so 1e2 stopped being a
;;  number at the e and came back a name; and a number could only begin
;;  with a digit, a sign or a #, so .5 was a name too.  Both are
;;  ordinary numbers raven could already hold.

(test "an exponent without a point" #t (number? 1e2))
(test "and it is the number it says" #t (eq? 1e2 100.0))
(test "an exponent written with a capital" #t (eq? 1E2 100.0))
(test "a negative exponent without a point" #t (eq? 1e-2 0.01))
(test "a signed number with an exponent" #t (eq? -1e2 -100.0))

(test "a decimal with no zero in front" #t (number? .5))
(test "and it is the number it says" #t (eq? .5 0.5))
(test "a negative decimal with no zero in front" #t (eq? -.5 -0.5))
(test "a decimal with nothing after the point" #t (eq? 1. 1.0))

;;  A point with no digit after it is still a name, which is what
;;  keeps the ellipsis working.

(test "the ellipsis is a name" #t (symbol? '...))
(test "a name that begins with a point" #t (symbol? '.foo))
(test "the ellipsis still ends a syntax-rules pattern" '(1 2 3)
      (let-syntax ((listing (syntax-rules () ((_ x ...) (list x ...)))))
        (listing 1 2 3)))

;;  And the shapes that always read still do.

(test "a plain decimal" #t (eq? 1.5 1.5))
(test "a decimal with an exponent" #t (eq? 1.5e3 1500.0))
(test "a plain integer is still an integer" #t (exact-integer? 123))
(test "a number with an exponent is not" #f (exact-integer? 1e2))

;;  What it gives up for keeping the mantissa is range: six bits of
;;  exponent reach from about 2**-30 up to just short of 2**32, and a
;;  number outside that is reported where it is written and read as
;;  nil rather than quietly losing its bottom bits.

(test "a float near the top of the range" #t (number? 1.0e9))
(test "a float near the bottom of the range" #t (number? 1.0e-9))
(test "a float written with an exponent is a float" #t (number? 1.5e3))
(test "and is the number it says" #t (eq? 1.5e3 1500.0))

(test "the same float written twice is the same object" #t (eq? 0.1 0.1))
(test "two different floats are not" #f (eq? 0.1 0.2))
(test "equal? over floats" #t (equal? 0.25 0.25))
(test "equal? over floats that differ" #f (equal? 0.25 0.5))

;;  An integer and a float are different kinds of thing, and the tags
;;  say so: they are 0 and 1, which is also what lets number? ask
;;  about both with one mask.

(test "a float and an integer are not eq?" #f (eq? 2.0 2))
(test "a float and an integer are not equal?" #f (equal? 2.0 2))
(test "number? of an integer" #t (number? 2))
(test "number? of a float" #t (number? 2.0))
(test "number? of a character" #f (number? #\a))
(test "number? of a symbol" #f (number? 'a))
(test "number? of nil" #f (number? '()))
(test "number? of a list" #f (number? '(1)))
(test "number? of a boolean" #f (number? #t))

;;  Everything that is not an integer, a float or a pair shares one
;;  escape in the primary tag, so telling two of those apart takes the
;;  whole eight bits.  equal? is what that is for: it asks whether two
;;  things are the same kind before it asks anything else, and a
;;  string against a character is the pair that would go wrong -- the
;;  character would be read as a foreign value id.

(test "a string and a character are not equal?" #f (equal? "a" #\a))
(test "a character and a string are not equal?" #f (equal? #\a "a"))
(test "a string and a symbol are not equal?" #f (equal? "a" 'a))
(test "a symbol and a character are not equal?" #f (equal? 'a #\a))
(test "a character and nil are not equal?" #f (equal? #\a '()))
(test "a string and a number are not equal?" #f (equal? "1" 1))

;;  And the kinds that are the same still are.

(test "two equal strings are equal?" #t (equal? "abc" "abc"))
(test "two equal characters are equal?" #t (equal? #\a #\a))
(test "two equal symbols are equal?" #t (equal? 'abc 'abc))
(test "two equal lists are equal?" #t (equal? '(1 (2 3)) '(1 (2 3))))

;;  A character is a code point and has twenty four bits to be one in,
;;  which is every code point there is with room over.

(test "the last code point survives" 1114111
      (char->integer (integer->char 1114111)))
(test "and reads back as itself" #t
      (eq? (integer->char 1114111) (integer->char 1114111)))

;;  Rounding an integer gives it back.  These are here so that a
;;  program which says where it expects a fraction runs.

(test "floor of an integer" 5 (floor 5))
(test "ceiling of an integer" 5 (ceiling 5))
(test "truncate of an integer" 5 (truncate 5))
(test "round of an integer" 5 (round 5))
(test "floor of a negative integer" -5 (floor -5))
(test "round of a negative integer" -5 (round -5))
(test "boolean? true" #t (boolean? #t))
(test "boolean? false" #t (boolean? #f))
(test "boolean? non-boolean" #f (boolean? 42))
(test "cons" '(a) (cons 'a '()))
(test "cons" '((a) b c d) (cons '(a) '(b c d)))
;;(test "cons" '("a" b c) (cons "a" '(b c)))
(test "cons" '(a . 3) (cons 'a 3))
(test "cons" '((a b) . c) (cons '(a b) 'c))
(test "list" '(a 7 c) (list 'a (+ 3 4) 'c))
(test "empty list" '() (list))
(test "xcons" '(a b c) (xcons '(b c) 'a))
(test "make-list" '(c c c c) (make-list 4 'c))
(test "pair-1" #t (pair? '(a . b)))
(test "pair-2" #t (pair? '(a b c)))
(test "pair-3" #f (pair? '()))
;;(test "pair-4" #f (pair? '#(a b)))
(test "pair-5" #f (pair? 7))
(test "pair-6" #f (pair? 'a))
;;  pair? is a form the translator knows, so a call written out is an
;;  instruction and no library had to offer one.  What that left was a
;;  name with no value, which nothing could be handed -- (map pair? xs)
;;  was undefined: pair?.  It is defined now, the way car and cdr are,
;;  and a call still compiles to the instruction.

(test "pair? handed to map" '(#f #t #f) (map pair? '(1 (2) 3)))
(test "pair? handed to a procedure" #t
      ((lambda (f) (f '(1))) pair?))
(test "pair? handed to a procedure, and no" #f
      ((lambda (f) (f 1)) pair?))
(test "pair? held in a name" #t ((lambda (p) (p '(a . b))) pair?))
(test "pair? applied over a list of arguments" #t (apply pair? '((1 2))))
(test "pair? is one thing, not two" #t (eq? pair? pair?))

;;  And the call written out is what it always was.

(test "pair? called on a pair" #t (pair? '(a . b)))
(test "pair? called on nothing" #f (pair? '()))

(test "car-1" 'a (car '(a b c)))
(test "cdr-1" '(b c)   (cdr '(a b c)))
(test "car-2" '(a) (car '((a) b c d)))
(test "cdr-2" '(b c d) (cdr '((a) b c d)))
(test "car-3" '1 (car '(1 . 2)))
(test "cdr-3" '2 (cdr '(1 . 2)))

;;  quote written out means what the reader's ' means

(test "quote written out, atom" 5 (quote 5))
(test "quote written out, symbol" 'a (quote a))
(test "quote written out, list" '(1 2 3) (quote (1 2 3)))
(test "quote written out, nil" '() (quote ()))
(test "quote written out, nested" '(quote a) (quote (quote a)))
(test "quote and ' agree" #t (equal? '(1 2) (quote (1 2))))

;;  a quotation the reader never saw: the macro builds one

(define-macro (quoting-macro x) (list 'quote x))
(test "macro builds a quotation" '(a b) (quoting-macro (a b)))

(test "append-1" '(1 2 3 4 5 6) (append '(1 2 3) '(4 5 6)))

;;  The list procedures R7RS asks the base library for.  Each is here
;;  on an ordinary list, on the empty list, and -- where the answer
;;  turns on it -- on a list that does not end in nil.

(test "reverse" '(3 2 1) (reverse '(1 2 3)))
(test "reverse of one" '(1) (reverse '(1)))
(test "reverse of nothing" '() (reverse '()))
(test "reverse leaves its argument alone" '(1 2 3)
      ((lambda (xs) (reverse xs) xs) (list 1 2 3)))
(test "reverse builds pairs of its own" #f
      ((lambda (xs) (eq? (reverse xs) xs)) (list 1)))

(test "list-tail, none of it" '(1 2 3) (list-tail '(1 2 3) 0))
(test "list-tail, some of it" '(3) (list-tail '(1 2 3) 2))
(test "list-tail, all of it" '() (list-tail '(1 2 3) 3))

(test "list-ref, the first" 1 (list-ref '(1 2 3) 0))
(test "list-ref, the last" 3 (list-ref '(1 2 3) 2))

(test "list-copy" '(1 2 3) (list-copy '(1 2 3)))
(test "list-copy of nothing" '() (list-copy '()))
(test "list-copy is a copy" #f
      ((lambda (xs) (eq? xs (list-copy xs))) (list 1 2 3)))
(test "list-copy keeps an improper tail" '(1 2 . 3) (list-copy '(1 2 . 3)))
(test "list-copy of what is not a pair" 7 (list-copy 7))

(test "list? of a list" #t (list? '(1 2 3)))
(test "list? of nothing" #t (list? '()))
(test "list? of an improper list" #f (list? '(1 2 . 3)))
(test "list? of a pair that is not a list" #f (list? '(1 . 2)))
(test "list? of what is not a pair at all" #f (list? 7))

;;  map takes as many lists as it is given and stops at the shortest,
;;  which is what R7RS asks and what one list was not.

(test "map over two lists" '(11 22) (map + '(1 2) '(10 20)))
(test "map over two lists, building" '((1 a) (2 b))
      (map list '(1 2) '(a b)))
(test "map over three lists" '(111) (map + '(1) '(10) '(100)))
(test "map stops at the shorter, second" '(11 22) (map + '(1 2 3) '(10 20)))
(test "map stops at the shorter, first" '(11 22) (map + '(1 2) '(10 20 30)))
(test "map over two empty lists" '() (map + '() '()))
(test "map when one of them is empty" '() (map + '(1 2) '()))
(test "map over one list still walks it" '(1 3)
      (map car '((1 2) (3 4))))
(test "map over one list is what it was" '(2 3 4) (map (lambda (x) (+ x 1)) '(1 2 3)))

;;  for-each is map without the answer.

(define two-list-seen '())
(for-each (lambda (a b) (set! two-list-seen (cons (list a b) two-list-seen)))
          '(1 2) '(a b))
(test "for-each over two lists" '((1 a) (2 b)) (reverse two-list-seen))

(define shortest-seen 0)
(for-each (lambda (a b) (set! shortest-seen (+ shortest-seen 1)))
          '(1 2 3) '(10 20))
(test "for-each stops at the shorter" 2 shortest-seen)

;;  = asks about numbers now, where it used to ask about identity and
;;  answer for anything at all.  Within a type it is what it was,
;;  because a number is an immediate and two equal ones are one word.

(test "= over equal integers" #t (= 1 1))
(test "= over unequal integers" #f (= 1 2))
(test "= over three the same" #t (= 1 1 1))
(test "= over three not quite" #f (= 1 1 2))
(test "= over equal floats" #t (= 2.5 2.5))
(test "= over unequal floats" #f (= 2.5 2.0))

;;  Across the two it is not, and cannot be here: raven-leq takes two
;;  integers and is the only comparison the machine has, so (= 2.0 2)
;;  is written down as what happens rather than left to be found.

(test "= over a float and an integer that look equal" #f (= 2.0 2))

;;  - and / want an argument.  + and * do not, because there is a
;;  number that leaves a sum or a product alone and there is no such
;;  number for subtracting or dividing.

(test "+ with no arguments" 0 (+))
(test "* with no arguments" 1 (*))
(test "- with one argument negates" -5 (- 5))
(test "- with two subtracts" 7 (- 10 3))
(test "/ with one argument inverts" 0 (/ 2))
(test "/ with two divides" 3 (/ 6 2))

;;  for-each is map without the answer: it is asked for what the
;;  procedure does, in the order the list is written.

(define for-each-seen '())
(for-each (lambda (x) (set! for-each-seen (cons x for-each-seen))) '(1 2 3))
(test "for-each visits every element" '(1 2 3) (reverse for-each-seen))

(define for-each-count 0)
(for-each (lambda (x) (set! for-each-count (+ for-each-count 1))) '())
(test "for-each over nothing does nothing" 0 for-each-count)

;;  eqv? is eq? for everything raven has, and answers the same
;;  questions.

(test "eqv? of a symbol with itself" #t (eqv? 'a 'a))
(test "eqv? of two symbols" #f (eqv? 'a 'b))
(test "eqv? of a number with itself" #t (eqv? 42 42))
(test "eqv? of two numbers" #f (eqv? 42 43))
(test "eqv? of nil with nil" #t (eqv? '() '()))
(test "eqv? of two lists that read alike" #f (eqv? (list 1) (list 1)))
(test "eqv? of a list with itself" #t
      ((lambda (xs) (eqv? xs xs)) (list 1)))

;;  memq, memv and member: the sublist that starts where the thing was
;;  found, and #f when it is not there.  member is the one that looks
;;  inside what it is comparing, and the one that takes a question of
;;  its own.

(test "memq finds a symbol" '(b c) (memq 'b '(a b c)))
(test "memq of what is not there" #f (memq 'z '(a b c)))
(test "memq of nothing" #f (memq 'a '()))
(test "memq answers with the tail itself" #t
      ((lambda (xs) (eq? (memq 'b xs) (cdr xs))) '(a b c)))

(test "memv finds a number" '(2 3) (memv 2 '(1 2 3)))
(test "memv of what is not there" #f (memv 9 '(1 2 3)))

(test "member looks inside" '((1 2) (3 4)) (member '(1 2) '((0) (1 2) (3 4))))
(test "memq does not look inside" #f (memq '(1 2) '((0) (1 2) (3 4))))
(test "member of what is not there" #f (member '(9) '((0) (1 2))))
;;  A compare of the caller's own is asked (compare obj element),
;;  which is the order R7RS gives it and the only order that lets it
;;  mean anything but sameness.

(test "member with a question of its own" '((b 2) (c 3))
      (member 'b '((a 1) (b 2) (c 3))
              (lambda (key entry) (eq? key (car entry)))))

;;  assq, assv and assoc: the pair whose car matches, and #f when
;;  there is none.

(define probe-alist '((a 1) (b 2) (c 3)))

(test "assq finds a key" '(b 2) (assq 'b probe-alist))
(test "assq of what is not there" #f (assq 'z probe-alist))
(test "assq of nothing" #f (assq 'a '()))
(test "assq answers with the pair itself" #t
      ((lambda (al) (eq? (assq 'a al) (car al))) probe-alist))

(test "assv finds a number key" '(2 two) (assv 2 '((1 one) (2 two))))
(test "assv of what is not there" #f (assv 9 '((1 one) (2 two))))

(test "assoc looks inside a key" '((1 2) found)
      (assoc '(1 2) '(((0) zero) ((1 2) found))))
(test "assq does not look inside a key" #f
      (assq '(1 2) '(((0) zero) ((1 2) found))))
(test "assoc of what is not there" #f (assoc '(9) '(((0) zero))))
(test "assoc with a question of its own" '((b y) 2)
      (assoc 'b '(((a x) 1) ((b y) 2))
             (lambda (key k) (eq? key (car k)))))

;;  The expander is written with memq and assq, so the tests above are
;;  not the only thing that would notice if they stopped answering.
;;  The macros below are expanded either way; this says so out loud.

(define-syntax probe-after-memq
  (syntax-rules (literally)
    ((_ literally x) (list 'literally x))
    ((_ x ...) (list x ...))))
(test "the expander still reads a literal" '(literally 1)
      (probe-after-memq literally 1))
(test "the expander still reads an ellipsis" '(1 2 3)
      (probe-after-memq 1 2 3))
(test "string-1" "Hello, world!" (string-append "Hello, " "world!"))
(test "string-2" "abcde" (string-append "a" "b" "c" "d" "e"))
(test "string-3" "" (string-append ""))

(test "first string of a session"  "first-append"  first-append)
(test "second string of a session" "second-append" second-append)
(test "third string of a session"  "third-append"  third-append)
(test "fourth string of a session" "fourth-append" fourth-append)
(test "distinct strings do not alias" #f (equal? first-append second-append))

(define x 33)
(test "define" 33 x)
(set! x 34)
(test "set!" 34 x)

(test "not #f" #t (not #f))
(test "not #t" #f (not #t))
(test "not 0"  #f (not 0))

(test "and no args"    #t  (and))
(test "and one arg"    42  (and 42))
(test "and true true"  99  (and #t 99))
(test "and false true" #f  (and #f 99))
(test "and true false" #f  (and #t #f))
(test "and multi"      3   (and 1 2 3))
(test "and short-circuit" #f (and #f (error "should not evaluate")))

(test "or no args"     #f  (or))
(test "or one arg"     42  (or 42))
(test "or false false" #f  (or #f #f))
(test "or true false"  #t  (or #t #f))
(test "or false true"  #t  (or #f #t))
(test "or multi"       1   (or 1 2 3))
(test "or short-circuit" #t (or #t (error "should not evaluate")))

(test "when true"  42 (when #t 42))
(test "when false" #f (when #f 42))
(test "when multi" 2  (when #t 1 2))

(test "unless false" 42 (unless #f 42))
(test "unless true"  #f (unless #t 42))
(test "unless multi" 2  (unless #f 1 2))

;;  A lexical binding shadows a macro of the same name: the innermost
;;  binding wins, whichever kind it is.

(test "parameter shadows macro" 3
      ((lambda (when) (when 1 2)) (lambda (a b) (+ a b))))
(test "rest parameter shadows macro" '(1 2)
      ((lambda and and) 1 2))
(test "macro still works outside the shadow" 42 (when #t 42))

;;  define-macro defines in the region it appears in, not in the whole
;;  program: a branch that is never reached defines nothing outside it.

(if #f (define-macro (dead-macro x) '99) '())
(test "unreachable define-macro does not leak" 7
      ((lambda (dead-macro) (dead-macro 7)) (lambda (v) v)))

(define (local-macro-host)
  (define-macro (inner-macro x) '55)
  (inner-macro 1))
(test "local macro works in its own body" 55 (local-macro-host))
(test "local macro does not escape" 8
      ((lambda (inner-macro) (inner-macro 8)) (lambda (v) v)))

(define (shadowing-host)
  (define-macro (when test . body) ''shadowed)
  (when #t 'ignored))
(test "local macro shadows global" 'shadowed (shadowing-host))
(test "global macro survives the shadow" 42 (when #t 42))

(define (outer-host)
  (define-macro (m x) ''outer)
  (define (inner-host)
    (define-macro (m x) ''inner)
    (m 1))
  (cons (m 1) (inner-host)))
(test "nested macro scopes" '(outer . inner) (outer-host))

;;  A macro defined at top level is still in scope inside a body.

(define-macro (doubled x) `(+ ,x ,x))
(define (uses-global-macro n) (doubled n))
(test "global macro reaches into a body" 10 (uses-global-macro 5))

;;  Defining a name takes it back from the macro that held it.

(define-macro (takeable x) ''macro-version)
(test "macro before define" 'macro-version (takeable 1))
(define (takeable x) 'procedure-version)
(test "define undefines the macro" 'procedure-version (takeable 1))

;;  Expanding a macro allocates, so a definition has to survive a
;;  collection that happens while its own region is being translated.

(define (macro-under-collection)
  (define-macro (build a b c) `(list (list ,a ,b ,c) (list ,c ,b ,a)))
  (append (build 1 2 3) (build 4 5 6) (build 7 8 9)
          (build 1 2 3) (build 4 5 6) (build 7 8 9)
          (build 1 2 3) (build 4 5 6) (build 7 8 9)
          (build 1 2 3) (build 4 5 6) (build 7 8 9)))
(test "local macro survives collection" '(1 2 3)
      (car (macro-under-collection)))
(test "local macro survives collection, reversed copy" '(3 2 1)
      (car (cdr (macro-under-collection))))

;;  An unquote belongs to the innermost quasiquote around it.  A
;;  quasiquote inside a quasiquote is data, and so is an unquote that
;;  belongs to it: only an unquote that reaches back out to this level
;;  is evaluated here.

(define qq-value 4)
(define qq-list (list 7 8))

(test "quasiquote, one level" '(1 2 3) `(1 ,(+ 1 1) 3))
(test "quasiquote splices" '(1 7 8) `(1 ,@qq-list))
(test "quasiquote splices in the middle" '(1 7 8 9) `(1 ,@qq-list 9))
(test "quasiquote splices twice" '(7 8 7 8) `(,@qq-list ,@qq-list))
(test "quasiquote splices an empty list" '(1 9) `(1 ,@'() 9))
(test "nested quasiquote is data" '(a (quasiquote b)) `(a `b))
(test "unquote one level in is data" '(1 (quasiquote (2 (unquote qq-value))))
      `(1 `(2 ,qq-value)))
(test "unquote-splicing one level in is data"
      '(1 (quasiquote (2 (unquote-splicing qq-list))))
      `(1 `(2 ,@qq-list)))

;;  Only the innermost unquote belongs to the outer quasiquote: the
;;  call it sits in is reproduced, and never made.

(test "an unquote inside an unquote reaches back out"
      '(a (quasiquote (b (unquote (c 4)))))
      `(a `(b ,(c ,qq-value))))

(test "an unquote two levels in is data twice over"
      '(a (quasiquote (b (quasiquote (c (unquote qq-value))))))
      `(a `(b `(c ,qq-value))))
(test "an unquote of an unquote is evaluated where it lands"
      '(a (quasiquote (b (unquote 4))))
      `(a `(b ,,qq-value)))
(test "an unquote in the tail of a template" '(1 . 4) `(1 . ,qq-value))

;;  symbol? and gensym.  A generated symbol has a name, so that an
;;  expansion can be read, but it is not the symbol that name reads
;;  as: nothing written at the call site can capture it.

(test "symbol? of a symbol" #t (symbol? 'a))
(test "symbol? of a number" #f (symbol? 1))
(test "symbol? of a list" #f (symbol? '(a)))
(test "symbol? of nil" #f (symbol? '()))
(test "symbol? of a generated symbol" #t (symbol? (gensym)))

(test "a generated symbol is not another" #f (eq? (gensym) (gensym)))
(test "a generated symbol is itself"
      #t ((lambda (g) (eq? g g)) (gensym)))
(test "a generated symbol is not the name it was made from"
      #f (eq? (gensym 'a) 'a))

;;  The name a macro introduces does not take over a name the caller
;;  is using: the macro binds a generated symbol, and the x in its
;;  template still means the caller's x.

(define captured-x 10)
(define-macro (add-to-captured-x y)
  ((lambda (tmp) `((lambda (,tmp) (+ ,tmp captured-x)) ,y))
   (gensym 'captured-x)))
(test "a generated name does not capture" 13 (add-to-captured-x 3))

;;  There are more symbols to be had than the few hundred a session
;;  interns, which is what generating one per expansion needs.

(define (generate-symbols n)
  (if (= n 0) '() (cons (gensym) (generate-symbols (- n 1)))))
(test "a thousand generated symbols" 1000 (length (generate-symbols 1000)))

;;  define-syntax and syntax-rules.  A pattern is matched against the
;;  form that used the macro, and the first rule that matches gives the
;;  template that takes its place.

(define-syntax unless-not
  (syntax-rules ()
    ((_ test then otherwise) (if test otherwise then))))
(test "syntax-rules, a fixed pattern" 'yes (unless-not #f 'yes 'no))

(define-syntax listing
  (syntax-rules ()
    ((_ x ...) (list x ...))))
(test "syntax-rules, an ellipsis" '(1 2 3) (listing 1 2 3))
(test "syntax-rules, an ellipsis over nothing" '() (listing))

(define-syntax second-of
  (syntax-rules ()
    ((_ _ y) y)))
(test "syntax-rules, a wildcard" 2 (second-of 1 2))

(define-syntax went
  (syntax-rules (to from)
    ((_ to x) (list 'went-to x))
    ((_ from x) (list 'came-from x))))
(test "syntax-rules, a literal" '(went-to 1) (went to 1))
(test "syntax-rules, another literal" '(came-from 2) (went from 2))

(define-syntax any-of
  (syntax-rules ()
    ((_) #f)
    ((_ a) a)
    ((_ a b ...) (if a a (any-of b ...)))))
(test "syntax-rules, the first rule that matches" #f (any-of))
(test "syntax-rules, a rule that uses its own macro" 3 (any-of #f #f 3))

(define-syntax unzip
  (syntax-rules ()
    ((_ (a b) ...) (list (list a ...) (list b ...)))))
(test "syntax-rules, an ellipsis over a pattern" '((1 3) (2 4))
      (unzip (1 2) (3 4)))

(define-syntax first-and-last
  (syntax-rules ()
    ((_ a b ... c) (list a c))))
(test "syntax-rules, a pattern after an ellipsis" '(1 4)
      (first-and-last 1 2 3 4))

;;  A name a template binds is renamed, so a form the caller hands the
;;  macro keeps its own meaning inside it.  Each of these answers the
;;  other thing if the binder takes the caller's name over.

(define caught 9)

(define-syntax holds-a-lambda
  (syntax-rules ()
    ((_ e) ((lambda (caught) (list caught e)) 1))))
(test "a lambda in a template does not capture" '(1 9) (holds-a-lambda caught))

(define-syntax holds-a-let
  (syntax-rules ()
    ((_ e) (let ((caught 1)) (list caught e)))))
(test "a let in a template does not capture" '(1 9) (holds-a-let caught))

;;  or, written the way R7RS writes it, which needs both: a name to
;;  hold the value it tests, and that name not to be the caller's.

(define-syntax an-or
  (syntax-rules ()
    ((_) #f)
    ((_ a) a)
    ((_ a b ...) (let ((caught a)) (if caught caught (an-or b ...))))))
(test "or over a name the template also binds" 9 (an-or #f caught))
(test "or takes the first of its arguments that holds" 2 (an-or #f 2 3))

;;  A name the template only refers to is left alone, and a quoted name
;;  is data.

(define-syntax quotes-a-name
  (syntax-rules ()
    ((_ x) (list 'caught x))))
(test "a quoted name in a template is data" '(caught 9) (quotes-a-name caught))

;;  The library's own macros are written with syntax-rules now.  or
;;  holds what it tests in a name of its own, which it could not do
;;  while a name a template binds was the caller's.

(test "let binds" 3 (let ((a 1) (b 2)) (+ a b)))
(test "let takes a body of several forms" 2 (let ((a 1)) 9 2))

(define or-calls 0)
(define (counted v)
  (set! or-calls (+ or-calls 1))
  v)
(test "or answers with the first argument that holds" 7 (or (counted 7) 9))
(test "or asked for it once" 1 or-calls)

;;  let-syntax binds macros for a body and no further, and the macros
;;  it binds are in scope for each other.

(test "let-syntax binds for its body" 42
      (let-syntax ((twice-of (syntax-rules () ((_ x) (+ x x)))))
        (twice-of 21)))
(test "let-syntax does not escape" 5
      ((lambda (twice-of) (twice-of 5)) (lambda (v) v)))
(test "letrec-syntax, one macro using another" 12
      (letrec-syntax ((double (syntax-rules () ((_ x) (+ x x))))
                      (quadruple (syntax-rules () ((_ x) (double (double x))))))
        (quadruple 3)))

;;  define-syntax is a define-macro, so it takes the scope define-macro
;;  takes: one written in a body belongs to that body.

(define (uses-local-syntax)
  (define-syntax twice (syntax-rules () ((_ x) (+ x x))))
  (twice 21))
(test "define-syntax in a body" 42 (uses-local-syntax))
(test "define-syntax in a body does not escape" 5
      ((lambda (twice) (twice 5)) (lambda (v) v)))

;;  A name under two ellipses holds a list of lists, and repeats twice
;;  over on the way out.

(define-syntax rows
  (syntax-rules ()
    ((_ (a ...) ...) (list (list a ...) ...))))
(test "syntax-rules, an ellipsis inside an ellipsis" '((1 2) (3 4))
      (rows (1 2) (3 4)))

;;  Two names repeating together, which is what a binding form needs.

(define-syntax my-let
  (syntax-rules ()
    ((_ ((name value) ...) body ...)
     ((lambda (name ...) body ...) value ...))))
(test "syntax-rules, two names repeating together" 3
      (my-let ((x 1) (y 2)) (+ x y)))
(test "syntax-rules, a body of more than one form" 2 (my-let ((x 1)) 9 2))

;;  A pattern can end in a name, which takes whatever is left.

(define-syntax with-rest
  (syntax-rules ()
    ((_ a . rest) (list a (list . rest)))))
(test "syntax-rules, a pattern that ends in a name" '(1 (2 3))
      (with-rest 1 2 3))

;;  A name the base library keeps to itself is not this library's to
;;  take.  The expander its macros are written with is the case that
;;  matters: before there were libraries, defining sr-expand here made
;;  every syntax-rules macro expand to whatever it answered.  A macro
;;  is read in the library it was written in, so it still finds the
;;  expander, and the definition below is ours and only ours.

(define (sr-expand a b c) 42)

(define-syntax probe-still-expands
  (syntax-rules ()
    ((_ x) (+ x 1))))

(test "a private expander cannot be taken" 8 (probe-still-expands 7))
(test "and the name is still ours" 42 (sr-expand 1 2 3))

;;  (scheme cxr): every composition of car and cdr three and four
;;  deep.  cxr-tree is four deep and its sixteen leaves are all
;;  different, so each accessor has an answer of its own and one
;;  that reaches the wrong place shows it.

(define cxr-tree
  '((((1 . 2) . (3 . 4)) . ((5 . 6) . (7 . 8)))
    .
    (((9 . 10) . (11 . 12)) . ((13 . 14) . (15 . 16)))))

(test "caaar" '(1 . 2) (caaar cxr-tree))
(test "caadr" '(9 . 10) (caadr cxr-tree))
(test "cadar" '(5 . 6) (cadar cxr-tree))
(test "caddr" '(13 . 14) (caddr cxr-tree))
(test "cdaar" '(3 . 4) (cdaar cxr-tree))
(test "cdadr" '(11 . 12) (cdadr cxr-tree))
(test "cddar" '(7 . 8) (cddar cxr-tree))
(test "cdddr" '(15 . 16) (cdddr cxr-tree))
(test "caaaar" 1 (caaaar cxr-tree))
(test "caaadr" 9 (caaadr cxr-tree))
(test "caadar" 5 (caadar cxr-tree))
(test "caaddr" 13 (caaddr cxr-tree))
(test "cadaar" 3 (cadaar cxr-tree))
(test "cadadr" 11 (cadadr cxr-tree))
(test "caddar" 7 (caddar cxr-tree))
(test "cadddr" 15 (cadddr cxr-tree))
(test "cdaaar" 2 (cdaaar cxr-tree))
(test "cdaadr" 10 (cdaadr cxr-tree))
(test "cdadar" 6 (cdadar cxr-tree))
(test "cdaddr" 14 (cdaddr cxr-tree))
(test "cddaar" 4 (cddaar cxr-tree))
(test "cddadr" 12 (cddadr cxr-tree))
(test "cdddar" 8 (cdddar cxr-tree))
(test "cddddr" 16 (cddddr cxr-tree))

;;  The same names on a proper list, which is what they are for.

(test "caddr of a list" 3 (caddr '(1 2 3)))
(test "cadddr of a list" 4 (cadddr '(1 2 3 4)))
(test "cdddr of a list" '(4) (cdddr '(1 2 3 4)))
(test "cddddr of a list" '(5) (cddddr '(1 2 3 4 5)))

;;  Primitives the machine could always do and offered no name for.

;;  set-car! and set-cdr! write a cell, which is what RAP has always
;;  done.  The pair is written in place, so every name for it sees the
;;  writing.

(define mutable-pair (cons 1 2))
(test "set-car! answers with the pair" #t
      (eq? mutable-pair (set-car! mutable-pair 9)))
(test "set-car!" 9 (car mutable-pair))
(set-cdr! mutable-pair 8)
(test "set-cdr!" 8 (cdr mutable-pair))
(test "the pair is the pair it was" '(9 . 8) mutable-pair)

(define shared-pair (cons 1 2))
(define another-name-for-it shared-pair)
(set-car! shared-pair 42)
(test "a writing is seen through another name" 42 (car another-name-for-it))
(test "and it is the same pair" #t (eq? shared-pair another-name-for-it))

(define grows (list 1))
(set-cdr! grows (list 2 3))
(test "set-cdr! makes a list longer" '(1 2 3) grows)
(test "and length says so" 3 (length grows))

;;  list-set! is what set-car! was wanted for: list-ref with the
;;  reading replaced by a writing.

(define settable (list 1 2 3))
(list-set! settable 1 'two)
(test "list-set!" '(1 two 3) settable)
(list-set! settable 0 'one)
(test "list-set! at the front" '(one two 3) settable)
(list-set! settable 2 'three)
(test "list-set! at the end" '(one two three) settable)

;;  And what set-cdr! makes possible for the first time: a list that
;;  runs back into itself.  list? has to come back from one, which is
;;  why it walks twice over at two speeds; before set-cdr! there was
;;  no way to build one and a single walk was the whole of it.

(define circular (list 1 2 3))
(set-cdr! (cddr circular) circular)
(test "list? of a list that runs back into itself" #f (list? circular))

(define self-loop (list 1))
(set-cdr! self-loop self-loop)
(test "list? of a one element loop" #f (list? self-loop))

(define loops-after-two (list 1 2 3 4))
(set-cdr! (cdddr loops-after-two) (cdr loops-after-two))
(test "list? of a list with a tail that loops" #f (list? loops-after-two))

(test "list? still says yes to a list" #t (list? '(1 2 3)))
(test "list? still says yes to nothing" #t (list? '()))
(test "list? still says no to an improper list" #f (list? '(1 2 . 3)))

;;  symbol->string and string->symbol.  The symbol table already read
;;  a name both ways; these are the two directions of it.

(test "symbol->string" "abc" (symbol->string 'abc))
(test "string->symbol" 'abc (string->symbol "abc"))
(test "string->symbol reads the name" #t (eq? 'abc (string->symbol "abc")))
(test "a symbol survives the round trip" #t
      (eq? 'hello (string->symbol (symbol->string 'hello))))
(test "the same name twice is the same symbol" #t
      (eq? (string->symbol "probe-interned") (string->symbol "probe-interned")))
(test "different names are different symbols" #f
      (eq? (string->symbol "probe-a") (string->symbol "probe-b")))
(test "symbol->string of a name with punctuation" "set-car!"
      (symbol->string 'set-car!))

;;  A generated symbol has a name so that it can be shown, and is not
;;  the symbol that name reads as.  string->symbol is what finally
;;  lets that be asked.

(test "a generated symbol is not what its name reads as" #f
      ((lambda (g) (eq? g (string->symbol (symbol->string g))))
       (gensym 'probe-gen)))

;;  char->integer and integer->char.  A character is an immediate
;;  holding its own code point, so these two are that, said.

(test "char->integer" 65 (char->integer #\A))
(test "integer->char" #\A (integer->char 65))
(test "char->integer of a lower case letter" 97 (char->integer #\a))
(test "a character survives the round trip" #t
      (eq? #\z (integer->char (char->integer #\z))))
(test "char->integer of a newline" 10 (char->integer #\newline))
(test "integer->char of a newline" #\newline (integer->char 10))
(test "integer->char of a space" #\space (integer->char 32))
(test "characters order by code point" #t
      (< (char->integer #\a) (char->integer #\b)))

;;  char=? and the rest of the character comparisons are scheme now
;;  that these two are here, which is what they were wanted for.

(define (char=? a b) (= (char->integer a) (char->integer b)))
(define (char<? a b) (< (char->integer a) (char->integer b)))
(test "a char=? written in scheme" #t (char=? #\a #\a))
(test "a char=? that says no" #f (char=? #\a #\b))
(test "a char<? written in scheme" #t (char<? #\a #\b))

;;  The questions that go with them.  string? and symbol? were bound
;;  already and are the shape these follow.

(test "char? of a character" #t (char? #\a))
(test "char? of the number it holds" #f (char? 97))
(test "char? of a string" #f (char? "a"))
(test "char? of a symbol" #f (char? 'a))
(test "char? of nil" #f (char? '()))

(test "integer? of an integer" #t (integer? 42))
(test "integer? of a negative integer" #t (integer? -42))
(test "integer? of zero" #t (integer? 0))
(test "integer? of a character" #f (integer? #\a))
(test "integer? of a symbol" #f (integer? 'a))
(test "integer? of a string" #f (integer? "42"))
(test "integer? of nil" #f (integer? '()))
(test "integer? of a boolean" #f (integer? #t))

(test "number? of an integer" #t (number? 42))
(test "number? of a character" #f (number? #\a))
(test "number? of a symbol" #f (number? 'a))
(test "number? of a string" #f (number? "42"))

(test "exact-integer? of an integer" #t (exact-integer? 42))
(test "exact-integer? of a negative integer" #t (exact-integer? -42))
(test "exact-integer? of a character" #f (exact-integer? #\a))
(test "exact-integer? of a symbol" #f (exact-integer? 'a))

;;  A float is the one thing integer? and exact-integer? answer
;;  differently for.  Nothing here makes one -- there is no float
;;  arithmetic -- but the reader reads one, so the question can be put.

(test "number? of a float" #t (number? 2.5))
(test "integer? of a float with a fraction" #f (integer? 2.5))
(test "integer? of a float without one" #t (integer? 2.0))
(test "exact-integer? of a float without one" #f (exact-integer? 2.0))

;;  Both of these have to survive a collection.  A writing puts a new
;;  object into a cell that is already old, which is the case a
;;  generational collector wants a write barrier for; this one copies
;;  everything every time, so it wants nothing, and that is worth
;;  saying out loud rather than assuming.  A list that runs back into
;;  itself is the other case: the collector has to come back from one
;;  too, and it does, because a cell it has already copied leaves a
;;  forwarding pointer behind.

(define (probe-churn n) (if (= n 0) '() (cons n (probe-churn (- n 1)))))

(define written-into (cons 'before '()))
(set-car! written-into (probe-churn 200))
(probe-churn 2000)
(test "what was written survives a collection" 200
      (length (car written-into)))

(define loops-through-collection (list 1 2 3))
(set-cdr! (cddr loops-through-collection) loops-through-collection)
(probe-churn 2000)
(test "a list that loops survives a collection" #f
      (list? loops-through-collection))
(test "and is the list it was" 1 (car loops-through-collection))
(test "and still runs back to its own first pair" #t
      (eq? loops-through-collection (cdddr loops-through-collection)))

;;  apply.  A call already builds a list of its arguments and hands AP
;;  the list, so a call whose list is built already is that same
;;  sequence with the building left out.

(test "apply" 6 (apply + '(1 2 3)))
(test "apply over nothing" 0 (apply + '()))
(test "apply of a lambda" 3 (apply (lambda (a b) (+ a b)) '(1 2)))
(test "apply of a name that is a list" '(1 2 3) (apply list '(1 2 3)))
(test "apply over a list held in a name" 6
      ((lambda (xs) (apply + xs)) (list 1 2 3)))

;;  R7RS lets arguments be written in front of the list, and they go
;;  on the front of it.

(test "apply with one leading argument" 6 (apply + 1 '(2 3)))
(test "apply with two leading arguments" 10 (apply + 1 2 '(3 4)))
(test "apply with leading arguments and nothing else" 3 (apply + 1 2 '()))
(test "apply keeps the order it was written" '(1 2 3 4)
      (apply list 1 2 '(3 4)))

;;  apply is a form the translator knows, like car and cons, so the
;;  name is defined as well and can be handed to something.

(test "apply passed as a value" 6 ((lambda (f) (f + '(1 2 3))) apply))
(test "apply applied to itself" 6 (apply apply (list + '(1 2 3))))
(test "apply mapped over a list of argument lists" '(3 7)
      (map (lambda (xs) (apply + xs)) '((1 2) (3 4))))

;;  What apply is for: a procedure that takes any number of arguments,
;;  called with a list of however many there turn out to be.

(define (call-with-all f xs) (apply f xs))
(test "a list of arguments decided at run time" 15
      (call-with-all + (list 1 2 3 4 5)))
(test "and none of them" 0 (call-with-all + '()))

;;  Tail calls.  A call whose value is the value of the body it stands
;;  in has nothing to come back for, so the machine saves nothing on
;;  the dump and the callee returns straight past it.  A loop written
;;  as a self-call then runs in the space of one call rather than of
;;  all of them.
;;
;;  Every count below was out of reach before: the dump held three
;;  cells a call, and somewhere past four thousand of them the machine
;;  said "out of memory" and took the host with it.

(define (countdown n) (if (= n 0) 'done (countdown (- n 1))))
(test "a hundred thousand tail calls" 'done (countdown 100000))

;;  The space is not the only thing to get right: the answer has to
;;  come back too, through however many frames were not kept.

(define (sum-to n acc) (if (= n 0) acc (sum-to (- n 1) (+ acc n))))
(test "an accumulator over a hundred" 5050 (sum-to 100 0))
(test "an accumulator over a thousand" 500500 (sum-to 1000 0))
(test "an accumulator over ten thousand" 50005000 (sum-to 10000 0))

;;  Ten thousand is where the total stops rather than where the loop
;;  does: an object holds a 28 bit integer, and (sum-to 50000 0) is
;;  past it.  That is the numeric tower and not this.

;;  Where tail position is.  A body answers with its last form, so
;;  that is the one, and a begin inside it answers with its last form
;;  for the same reason.  The forms before are dropped, which is also
;;  what leaves the stack empty for the last one to be a tail call.

(define (through-begin n)
  (if (= n 0) 'done (begin 'dropped (through-begin (- n 1)))))
(test "a tail call through begin" 'done (through-begin 50000))

(define (work-first n acc)
  (if (= n 0) acc (begin (+ 1 1) (work-first (- n 1) (+ acc 1)))))
(test "a begin whose earlier forms are dropped" 100 (work-first 100 0))

;;  Whichever branch an if takes is what the if answers with, so both
;;  branches are in tail position exactly when the if is.  This is the
;;  case the whole thing turns on: a loop is an if in tail position,
;;  and a tail call that did not reach inside one would fire for
;;  nothing anybody writes.

(define (either-branch n)
  (if (= n 0)
      'done
      (if (even? n) (either-branch (- n 1)) (either-branch (- n 1)))))
(test "a tail call in either branch" 'done (either-branch 50000))

;;  Two procedures that call each other, neither of which returns
;;  until the other does.  The dump holds neither.

(define (ping n) (if (= n 0) 'ping (pong (- n 1))))
(define (pong n) (if (= n 0) 'pong (ping (- n 1))))
(test "mutual tail recursion" 'ping (ping 50000))
(test "mutual tail recursion, landing on the other" 'pong (ping 50001))

;;  A lambda applied where it stands is a call like any other, and
;;  the last form of its body is in tail position.

(define (through-lambda n)
  (if (= n 0) 'done ((lambda (m) (through-lambda m)) (- n 1))))
(test "a tail call from an applied lambda" 'done (through-lambda 50000))

;;  let is that lambda, written by a macro, so its body is a body too.
;;
;;  through-let is declared before it is defined because the recursive
;;  call sits inside the expansion: a name an expansion refers to that
;;  the use site has not defined yet is looked for in the macro's own
;;  library, where there is no through-let.  Declaring it first is
;;  what there is to do about that, and it is #24 rather than this.

(define through-let '())
(define (through-let n)
  (if (= n 0) 'done (let ((m (- n 1))) (through-let m))))
(test "a tail call from inside a let" 'done (through-let 50000))

;;  What a macro expands to stands where the macro stood, so a call it
;;  leaves in tail position is a tail call.

(define-syntax tail-if
  (syntax-rules () ((_ test then otherwise) (if test then otherwise))))
(define (through-macro n)
  (tail-if (= n 0) 'done (through-macro (- n 1))))
(test "a tail call out of a macro expansion" 'done (through-macro 50000))

;;  apply is a call with its argument list built already, and is a
;;  tail call in tail position like any other.

(define (through-apply n)
  (if (= n 0) 'done (apply through-apply (list (- n 1)))))
(test "a tail call through apply" 'done (through-apply 50000))

;;  A foreign function has nothing to transfer control to: it answers
;;  where it stands.  So a tail call of one is the call and the return
;;  done together, which is a path of its own in the machine.

(define (code-of c) (char->integer c))
(test "a foreign function in tail position" 65 (code-of #\A))

(define (code-or-zero c) (if (char? c) (char->integer c) 0))
(test "a foreign function in a tail branch" 97 (code-or-zero #\a))
(test "and the other branch of it" 0 (code-or-zero 'not-a-char))

;;  What is not in tail position is still not, and still works.  The
;;  call below answers to the + around it rather than to its caller,
;;  so every one of them is on the dump and the depth it manages is
;;  the depth it always managed.  R7RS asks nothing else of it.

(define (not-in-tail-position n)
  (if (= n 0) 0 (+ 1 (not-in-tail-position (- n 1)))))
(test "a call that is not a tail call still works" 1000
      (not-in-tail-position 1000))

;;  Which is the line through the library as well.  reverse, memq and
;;  the rest of the accumulator walks are loops now and reach the end
;;  of a list no dump could have held; length and map cons on the way
;;  out and are not loops, so it is length rather than reverse that
;;  decides how long a list can be asked about.
;;
;;  Nothing below is held in a name.  The heap is 32768 cells and a
;;  list of five thousand is five thousand of them, so keeping one
;;  would be measuring the heap rather than the dump.

(define (build-list n acc) (if (= n 0) acc (build-list (- n 1) (cons n acc))))

(test "a list built by a tail recursion" 1 (car (build-list 5000 '())))
(test "reverse walks all of one" 5000 (car (reverse (build-list 5000 '()))))
(test "memq reaches the end of one" #f (memq 'absent (build-list 5000 '())))
(test "memq finds what is at the end" 5000
      (car (memq 5000 (build-list 5000 '()))))

;;  A string written in the source is one object, made when it is
;;  read.  It used to read as the form that builds a string, so every
;;  evaluation of a literal spent another of the foreign values there
;;  are a limited number of -- which is what made a loop holding
;;  strings run out so quickly.

(define (probe-literal) "shared")

(test "a literal is one object" #t (eq? (probe-literal) (probe-literal)))
(test "two literals are two" #f (eq? "a" "a"))

;;  And there is room for more than a handful of them.  Five hundred
;;  strings, all live at once because the list holds them: this was an
;;  error, out of the machine and past anything scheme could do about
;;  it, once there were ninety-nine.

(define (probe-strings n)
  (if (= n 0) '() (cons (display n) (probe-strings (- n 1)))))

(test "five hundred live strings" 500 (length (probe-strings 500)))

(write-string "Tests: ")
(write-string (display num-tests))
(write-string ", Passed: ")
(write-string (display passed-tests))
(write-string ", Failed: ")
(write-string (display failed-tests))
(newline)

