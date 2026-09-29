(import (scheme base) (scheme cxr) (scheme inexact) (scheme write) (scheme lazy)
        (only (raven base) gensym xcons))

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
          (write-string "FAIL  ") (write-string name) (write-string ": expected ") (display expect)
          (write-string ", got ")
          (display expr)
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
;;  number, and say whether it is exact (#159).

(test "an exactness prefix makes a number" 1 '#e1)
(test "the other exactness prefix makes an inexact one" #t (inexact? '#i1))

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
(test "a negative exponent without a point" #t (eqv? 1e-2 0.01))
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

;;  An inexact number is a double (#103), kept as the immediate float
;;  when that holds it exactly -- a single's mantissa and six bits of
;;  exponent -- and boxed in the heap when it does not.  So 1.5 and
;;  1500.0 are immediates, and 0.1, which no single holds exactly, is a
;;  boxed double: the double 0.1 and not the single one.  Two of those
;;  written apart are two objects, so it is eqv? that says they are the
;;  same number; eq? on numbers is not a question R7RS answers.

(test "a float near the top of the range" #t (number? 1.0e9))
(test "a float near the bottom of the range" #t (number? 1.0e-9))
(test "a float written with an exponent is a float" #t (number? 1.5e3))
(test "and is the number it says" #t (eq? 1.5e3 1500.0))

(test "the same double written twice is the same number" #t (eqv? 0.1 0.1))
(test "and the same float the same object, when it is an immediate" #t
      (eq? 0.5 0.5))
(test "a double past what the immediate holds" #t (number? 1.0e300))
(test "and one below it" #t (= (* 1.0e-200 1.0e200) 1.0))
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

;;  Comments.  R7RS has three kinds and raven had one; the other two
;;  were not merely absent, but read as code.  # is a character an
;;  identifier may be made of and | is not, so #| was the identifier #
;;  followed by a bad token and every word of the comment after it was
;;  read as a program.

#| a block comment |#
(test "a block comment on its own" 1 1)

(test "a block comment inside a form" 3 (+ 1 #| two |# 2))
(test "a block comment where an element would be" '(1 2)
      (list 1 #| between |# 2))

;;  R7RS says the pairs nest, so this counts them rather than stopping
;;  at the first |# it meets.

#| outer #| inner |# still the outer one |#
(test "a nested block comment" 2 2)
(test "a nested block comment inside a form" 7 (+ 3 #| a #| b |# c |# 4))

;;  A block comment runs to its close and not to the end of a line.

#| this comment
   goes on over
   three lines |#
(test "a block comment over several lines" 3 3)

;;  #; takes out the datum after it, whatever that datum turns out to
;;  be.  It used to read as the identifier # and then a line comment,
;;  which took the rest of the line with it -- so the parentheses that
;;  closed the form went too, and the reader ate the form after it
;;  looking for them.

(test "a datum comment in the middle" '(1 3) (list 1 #;2 3))
(test "a datum comment at the end" '(1 2) (list 1 2 #;3))
(test "a datum comment at the front" '(2 3) (list #;1 2 3))
(test "two datum comments in a row" '(3) (list #;1 #;2 3))
(test "a datum comment over a compound datum" '(1 2)
      (list 1 #;(a b (c d)) 2))
(test "a datum comment over a string" '(1 2) (list 1 #;"gone" 2))
(test "a datum comment inside a nested list" '(1 (2 4))
      (list 1 (list 2 #;3 4)))

;;  And one at the top level takes out the whole form after it.

#;(this form is not evaluated and would fail if it were)
(test "a datum comment over a top level form" 4 4)

;;  Neither of them is a comment inside a string, where # and | are
;;  ordinary characters.

(test "a block comment opener in a string" 6 (string-length "a #| b"))
(test "a block comment closer in a string" 6 (string-length "a |# b"))
(test "a datum comment in a string" 6 (string-length "a #; b"))

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

;;  = asks about numbers, where it used to ask about identity and
;;  answer for anything at all.  And it is the machine's comparison
;;  now rather than eq?, which was numeric equality only while every
;;  number was one word: two equal bignums will be two objects.

(test "= over equal integers" #t (= 1 1))
(test "= over unequal integers" #f (= 1 2))
(test "= over three the same" #t (= 1 1 1))
(test "= over three not quite" #f (= 1 1 2))
(test "= over equal floats" #t (= 2.5 2.5))
(test "= over unequal floats" #f (= 2.5 2.0))

;;  And across the two: = compares numbers, not how they are held, so
;;  (= 2.0 2) is #t.  It was #f while = on a float was identity.

(test "= over a float and an integer that look equal" #t (= 2.0 2))
(test "but they are not eqv?, being exact and inexact" #f (eqv? 2.0 2))

;;  Exact integers past 29 bits are bignums, and are the same numbers
;;  a program would expect: they compare, they are integers, and two
;;  equal ones made separately are =, eqv? and equal? though they are
;;  two objects.

(define probe-big (expt 2 100))

(test "a bignum is a number" #t (number? probe-big))
(test "and an integer" #t (integer? probe-big))
(test "and an exact one" #t (exact-integer? probe-big))
(test "and written as its digits" "1267650600228229401496703205376"
      (number->string probe-big))
(test "two equal bignums are =" #t (= probe-big (expt 2 100)))
(test "and eqv?" #t (eqv? probe-big (expt 2 100)))
(test "and equal?" #t (equal? (list probe-big) (list (expt 2 100))))
(test "and memv finds one" #t (if (memv (expt 2 100) (list 1 probe-big)) #t #f))
(test "a bignum and a fixnum are not =" #f (= probe-big 1))
(test "a bignum is more than any fixnum" #t (> probe-big 536870911))
(test "and a negative one less" #t (< (- probe-big) -536870912))
(test "bignums order" #t (< (expt 2 99) probe-big (expt 2 101)))
(test "the largest fixnum and one past" #t (< 536870911 536870912))
(test "gcd of two bignums" 4294967296 (gcd (expt 2 32) (expt 2 40)))
(test "a factorial" "30414093201713378043612608166064768844377641568960512000000000000"
      (number->string
       ((lambda (f) (f f 50))
        (lambda (self n) (if (= n 0) 1 (* n (self self (- n 1))))))))

;;  And it is the heap's: a collection moves it and it is the same
;;  number afterwards.

(define (probe-big-churn n)
  (if (= n 0) '() (cons n (probe-big-churn (- n 1)))))

(define probe-kept-big (* probe-big 3))
(probe-big-churn 3000)
(test "a bignum survives a collection" "3802951800684688204490109616128"
      (number->string probe-kept-big))

;;  number->string and string->number, which there were none of, so no
;;  number could be turned into text a program could hold.

(test "number->string" "42" (number->string 42))
(test "number->string of a negative" "-42" (number->string -42))
(test "number->string in binary" "101010" (number->string 42 2))
(test "and octal" "52" (number->string 42 8))
(test "and hexadecimal" "2a" (number->string 42 16))
(test "a bignum in hexadecimal" "10000000000000000000000000"
      (number->string probe-big 16))
(test "number->string of a float" "1.5" (number->string 1.5))
(test "number->string of a float reads back" 1.5
      (string->number (number->string 1.5)))

;;  Inexact arithmetic (#103).  An inexact number is a double, and an
;;  operation with any inexact argument answers inexact: the answer can
;;  be no more exact than what it was worked out from.

(test "a float added" 4.0 (+ 1.5 2.5))
(test "contagion: an integer and a float" 3.5 (+ 1 2.5))
(test "and the answer is inexact even when whole" #f (exact? (+ 1 2.0)))
(test "a float multiplied" 3.75 (* 1.5 2.5))
(test "a float subtracted" -1.0 (- 1.5 2.5))
(test "division with a float divides" 3.5 (/ 7 2.0))
(test "and exact division is exact" 7/2 (/ 7 2))
(test "floats compare" #t (< 1.5 2.5))
(test "across exactness" #t (< 1 1.5 2))
(test "a float and a bignum" #t (< 1.0e20 (expt 10 21)))
(test "0.1 is the double 0.1" "0.30000000000000004"
      (number->string (+ 0.1 0.2)))

;;  Written as the shortest decimal that reads back as the same double,
;;  with a point always and an exponent only far from one.

(test "a double written" "0.1" (number->string 0.1))
(test "a whole double written" "100.0" (number->string 100.0))
(test "a large one" "1e+30" (number->string 1e30))
(test "a small one" "1.5e-10" (number->string 1.5e-10))
(test "a negative one" "-2.5" (number->string -2.5))
(test "minus nought" "-0.0" (number->string -0.0))

;;  exact? and inexact?, and each kind as the other.

(test "exact? of an integer" #t (exact? 1))
(test "exact? of a bignum" #t (exact? (expt 2 100)))
(test "exact? of a float" #f (exact? 1.5))
(test "inexact? of a float" #t (inexact? 1.5))
(test "inexact of an integer" 2.0 (inexact 2))
(test "and it is inexact" #t (inexact? (inexact 2)))
(test "inexact of a bignum" 1.2676506002282294e30 (inexact (expt 2 100)))
(test "exact of a whole float" 2 (exact 2.0))
(test "and it is exact" #t (exact? (exact 2.0)))
(test "exact of a large whole double, which is the double's own number"
      1000000000000000019884624838656 (exact 1e30))
(test "integer? of a whole float" #t (integer? 2.0))
(test "integer? of one that is not" #f (integer? 2.5))
(test "exact-integer? of a whole float" #f (exact-integer? 2.0))

;;  floor, ceiling, truncate and round, which were the identity.

(test "floor of a float" 2.0 (floor 2.5))
(test "floor of a negative" -3.0 (floor -2.5))
(test "ceiling" 3.0 (ceiling 2.5))
(test "truncate" -2.0 (truncate -2.5))
(test "round to even, down" 2.0 (round 2.5))
(test "round to even, up" 4.0 (round 3.5))
(test "round of a negative" -2.0 (round -2.5))
(test "floor of an integer is the integer" 7 (floor 7))
(test "and exact" #t (exact? (floor 7)))

;;  min and max answer inexact when any argument is.

(test "max of exact numbers is exact" 3 (max 1 3 2))
(test "max with a float among them" 3.0 (max 3 2.0))
(test "and inexact" #f (exact? (max 3 2.0)))
(test "min with a float" 1.0 (min 1 2.0))

;;  Exact rationals (#104).  / is exact for exact arguments, and an
;;  answer whose denominator is one is the integer: (/ 6 2) is 3.

(test "a rational" 5/6 (+ 1/2 1/3))
(test "multiplied" 1/2 (* 2/3 3/4))
(test "and subtracted to nothing, which is the integer" 0 (- 1/2 1/2))
(test "and that is exact and an integer" #t (exact-integer? (- 1/2 1/2)))
(test "a division that comes out even is an integer" 3 (/ 6 2))
(test "and one that does not is in lowest terms" 3/2 (/ 6 4))
(test "a negative one" -1/2 (/ 1 -2))
(test "with a float it is inexact" 1.0 (+ 1/2 0.5))
(test "read in lowest terms" -1/2 -3/6)
(test "read as an integer when it is one" 2 6/3)
(test "read in a radix" 1/10 #x1/a)
(test "a rational is a number" #t (number? 1/2))
(test "and rational" #t (rational? 1/2))
(test "and real" #t (real? 1/2))
(test "and exact" #t (exact? 1/2))
(test "and not an integer" #f (integer? 1/2))
(test "rationals compare" #t (< 1/3 1/2 2/3))
(test "against integers" #t (< 1/2 1))
(test "= across exactness" #t (= 1/2 0.5))
(test "but not eqv?" #f (eqv? 1/2 0.5))
(test "eqv? of two made apart" #t (eqv? 1/2 (/ 2 4)))
(test "equal? of lists of them" #t (equal? (list 1/2) (list (/ 3 6))))

;;  numerator and denominator, in lowest terms.

(test "numerator" 3 (numerator 6/4))
(test "denominator" 2 (denominator 6/4))
(test "numerator of a negative" -1 (numerator -1/2))
(test "denominator of an integer" 1 (denominator 5))
(test "denominator of a double" 2.0 (denominator 0.5))

;;  Rounding a rational gives an exact integer.

(test "floor of a rational" 3 (floor 7/2))
(test "floor of a negative one" -4 (floor -7/2))
(test "ceiling" 4 (ceiling 7/2))
(test "truncate" -3 (truncate -7/2))
(test "round to even, up" 4 (round 7/2))
(test "round to even, down" 2 (round 5/2))
(test "round of one not halfway" 1 (round 4/3))
(test "and exact" #t (exact? (floor 7/2)))

;;  Every double is an exact rational, so exact always answers.

(test "exact of a half" 1/2 (exact 0.5))
(test "exact of a tenth, which is not a tenth"
      3602879701896397/36028797018963968 (exact 0.1))
(test "inexact of a third" 0.3333333333333333 (inexact 1/3))

;;  Written and read.

(test "number->string of a rational" "7/2" (number->string 7/2))
(test "in binary" "11/100" (number->string 3/4 2))
(test "string->number of one" 7/2 (string->number "7/2"))
(test "of one over nought" #f (string->number "1/0"))
(test "of one with no denominator" #f (string->number "1/"))

;;  expt by squaring, with a negative power the reciprocal.

(test "expt to a negative power" 1/8 (expt 2 -3))
(test "expt of a rational" 4/9 (expt 2/3 2))
(test "expt of a double" 8.0 (expt 2.0 3))
(test "expt to an inexact power is inexact" 8.0 (expt 2 3.0))
(test "expt to a large power" #t (= (expt 2 1000) (* (expt 2 500) (expt 2 500))))

;;  rationalize: the simplest rational within the tolerance, which is
;;  R7RS's own example.

(test "rationalize" 1/3 (rationalize 3/10 1/10))
(test "rationalize of an inexact" 0.3333333333333333 (rationalize 0.3 1/10))
(test "rationalize of a negative" -1/3 (rationalize -3/10 1/10))

;;  Quotient and the rest are still integer division.

(test "quotient" 3 (quotient 7 2))
(test "remainder" 1 (remainder 7 2))
(test "modulo" 1 (modulo -7 2))

;;  A rational whose parts are bignums, and one that a collection has
;;  moved.

(define probe-big-ratio (/ (expt 2 100) 3))
(test "a rational of a bignum" "1267650600228229401496703205376/3"
      (number->string probe-big-ratio))
(test "and back to the bignum" #t (= (* probe-big-ratio 3) (expt 2 100)))
(define probe-kept-ratio (/ 22 7))
(probe-big-churn 3000)
(test "a rational survives a collection" 22/7 probe-kept-ratio)
(test "and so does one of bignums" "1267650600228229401496703205376/3"
      (number->string probe-big-ratio))

;;  Multiple values (#48).  One value is the value; several are taken
;;  apart by call-with-values, and are not a list a program could walk.

(test "values of one is the value" 5 (values 5))
(test "call-with-values" 3 (call-with-values (lambda () (values 1 2)) +))
(test "of none" '() (call-with-values (lambda () (values)) list))
(test "of one" '(7) (call-with-values (lambda () 7) list))
(test "of three" '(1 2 3) (call-with-values (lambda () (values 1 2 3)) list))
(test "several values are not a pair" #f (pair? (values 1 2)))
(test "and are written as what they are" "#<values 1 2>"
      (raven-write-text (values 1 2)))

(test "let-values" 3 (let-values (((a b) (values 1 2))) (+ a b)))
(test "let-values of several" '(1 2 3 4)
      (let-values (((a b) (values 1 2)) ((c d) (values 3 4))) (list a b c d)))
(test "let-values with a rest" '(1 (2 3))
      (let-values (((a . rest) (values 1 2 3))) (list a rest)))
(test "let-values of a name for all" '(1 2)
      (let-values ((all (values 1 2))) all))
(test "let-values does not let one see another" 1
      (let ((a 1))
        (let-values (((a) (values 10)) ((b) (values a))) b)))
(test "let*-values does" 10
      (let ((a 1))
        (let*-values (((a) (values 10)) ((b) (values a))) b)))
(test "let-values with a body of several" 2
      (let-values (((a) (values 1))) (set! a 2) a))

(define-values (probe-q probe-r) (floor/ 17 5))
(test "define-values" '(3 2) (list probe-q probe-r))
(define-values (probe-first . probe-others) (values 1 2 3))
(test "define-values with a rest" '(1 (2 3)) (list probe-first probe-others))
(test "define-values inside a body" 7
      ((lambda () (define-values (x y) (values 3 4)) (+ x y))))

(test "floor/" '(-4 3) (call-with-values (lambda () (floor/ -13 4)) list))
(test "truncate/" '(-3 -1)
      (call-with-values (lambda () (truncate/ -13 4)) list))
(test "exact-integer-sqrt" '(4 1)
      (call-with-values (lambda () (exact-integer-sqrt 17)) list))
(test "of a square" '(5 0)
      (call-with-values (lambda () (exact-integer-sqrt 25)) list))
(test "of a bignum" #t
      (let-values (((s r) (exact-integer-sqrt (+ (expt 10 40) 7))))
        (and (= s (expt 10 20)) (= r 7))))

;;  Continuations (#47).  A continuation is the machine's registers as
;;  they were, and invoking one puts them back: out of a computation,
;;  or back into one that has already returned.

(test "call/cc escaping" 3 (+ 1 (call/cc (lambda (k) (+ 10 (k 2))))))
(test "call/cc not escaping" 11 (+ 1 (call/cc (lambda (k) 10))))
(test "call/cc in tail position" 5 ((lambda () (call/cc (lambda (k) (k 5))))))
(test "call-with-current-continuation by its long name" 4
      (call-with-current-continuation (lambda (k) (k 4))))

(define (probe-find-first pred xs)
  (call/cc
   (lambda (return)
     (for-each (lambda (x) (if (pred x) (return x))) xs)
     #f)))

(test "an early way out of a loop" 4 (probe-find-first even? '(1 3 4 5 6)))
(test "and none" #f (probe-find-first even? '(1 3 5)))

(test "re-entering a continuation" '(3 2 1)
      (let ((k #f) (seen '()))
        (let ((n (call/cc (lambda (c) (set! k c) 1))))
          (set! seen (cons n seen))
          (if (< n 3) (k (+ n 1)) seen))))

(test "several values through a continuation" '(1 2)
      (call-with-values (lambda () (call/cc (lambda (k) (k 1 2)))) list))
(test "call/cc is a procedure" #t (procedure? call/cc))
(test "and so is a continuation" #t (call/cc procedure?))

;;  dynamic-wind, which call/cc consults on the way out and back in.

(test "dynamic-wind in order" '(before during after)
      (let ((log '()))
        (dynamic-wind (lambda () (set! log (cons 'before log)))
                      (lambda () (set! log (cons 'during log)))
                      (lambda () (set! log (cons 'after log))))
        (reverse log)))
(test "and answers with the thunk's value" 7
      (dynamic-wind (lambda () #f) (lambda () 7) (lambda () #f)))
(test "or its values" '(1 2)
      (call-with-values
          (lambda ()
            (dynamic-wind (lambda () #f) (lambda () (values 1 2)) (lambda () #f)))
        list))
(test "escaping out runs the after" '(before after out)
      (let ((log '()))
        (let ((answer
               (call/cc
                (lambda (k)
                  (dynamic-wind (lambda () (set! log (cons 'before log)))
                                (lambda () (k 'out) (set! log (cons 'never log)))
                                (lambda () (set! log (cons 'after log))))))))
          (reverse (cons answer log)))))

;;  R7RS's own example: going back in runs the before again.

(test "re-entering runs the before again"
      '(connect talk1 disconnect connect talk2 disconnect)
      (let ((path '()) (c #f))
        (let ((add (lambda (s) (set! path (cons s path)))))
          (dynamic-wind (lambda () (add 'connect))
                        (lambda () (add (call/cc (lambda (c0) (set! c c0) 'talk1))))
                        (lambda () (add 'disconnect)))
          (if (< (length path) 4) (c 'talk2) (reverse path)))))

;;  Exceptions (#46).  error raises an error object, raise raises
;;  anything, and guard catches either, as do the errors the machine
;;  finds itself.

(test "guard catches an error" "boom"
      (guard (e (#t (error-object-message e))) (error "boom" 1 2)))
(test "with its irritants" '(1 2)
      (guard (e ((error-object? e) (error-object-irritants e)))
        (error "boom" 1 2)))
(test "guard catches what is raised" '(caught oops)
      (guard (e ((symbol? e) (list 'caught e))) (raise 'oops)))
(test "a clause with =>" 42
      (guard (e ((assq 'a e) => cdr) ((assq 'b e)))
        (raise (list (cons 'a 42)))))
(test "a clause of a test alone" '(b . 23)
      (guard (e ((assq 'a e) => cdr) ((assq 'b e)))
        (raise (list (cons 'b 23)))))
(test "else" 'other (guard (e (else 'other)) (raise 1)))
(test "no clause matching goes further out" 'outer
      (guard (e (#t 'outer))
        (guard (e ((string? e) 'inner)) (raise 'not-a-string))))
(test "guard of nothing raised is the body" 3 (guard (e (#t 'no)) (+ 1 2)))
(test "or its values" '(1 2)
      (call-with-values (lambda () (guard (e (#t 0)) (values 1 2))) list))

;;  The machine's own errors are catchable, and are error objects.

(test "car of what is not a pair" #t
      (guard (e (#t (error-object? e))) (car 1)))
(test "with the machine's message" #t
      (guard (e (#t (string? (error-object-message e)))) (car 1)))
(test "a name nothing defines" 'undefined
      (guard (e (#t 'undefined)) (probe-name-nothing-defines 1)))
(test "a primitive refusing" 'caught
      (guard (e (#t 'caught)) (vector-ref (vector 1) 5)))
(test "and the program goes on" 5 (+ 2 3))

;;  with-exception-handler, raise-continuable, and a handler that
;;  returns from raise, which is a second error.

(test "raise-continuable answers with the handler's value" 43
      (with-exception-handler
       (lambda (c) 42)
       (lambda () (+ (raise-continuable 'c) 1))))
(test "a handler returning from raise is an error" #t
      (guard (e (#t (error-object? e)))
        (with-exception-handler (lambda (c) 'ignored)
                                (lambda () (raise 'x)))))
(test "a handler raising goes further out" 'further
      (guard (e ((eq? e 'again) 'further))
        (with-exception-handler (lambda (c) (raise 'again))
                                (lambda () (raise 'first)))))

;;  Leaving by an exception leaves the extents it is inside.

(test "dynamic-wind's after runs when a guard catches" '(before after caught)
      (let ((log '()))
        (guard (e (#t (set! log (cons 'caught log))))
          (dynamic-wind (lambda () (set! log (cons 'before log)))
                        (lambda () (error "out"))
                        (lambda () (set! log (cons 'after log)))))
        (reverse log)))

(test "error-object? of what is not one" #f (error-object? 'x))

;;  An error object is a record of its own (#172), where it was a
;;  vector a program could take apart and write into.

(define caught-error (guard (e (#t e)) (error "caught" 1 2)))
(test "an error object is not a vector" #f (vector? caught-error))
(test "nor a pair" #f (pair? caught-error))
(test "and is still an error object" #t (error-object? caught-error))
(test "with its message" "caught" (error-object-message caught-error))
(test "and its irritants" '(1 2) (error-object-irritants caught-error))
(test "a vector that looks like one is not one" #f
      (error-object? (vector (list 'error-object) "caught" '(1 2))))
(test "an error object written" "#<error-object>"
      (let ((port (open-output-string)))
        (write caught-error port)
        (get-output-string port)))
(test "one the machine raised is one too" #f
      (guard (e (#t (vector? e))) (car 1)))
(test "file-error?" #f (guard (e (#t (file-error? e))) (error "x")))
(test "read-error?" #f (guard (e (#t (read-error? e))) (error "x")))

;;  (scheme inexact) (#105).  A square root is exact when the number is
;;  and its root is; everything else here is inexact.

(test "sqrt of a square" 3 (sqrt 9))
(test "and it is exact" #t (exact? (sqrt 9)))
(test "sqrt of a bignum square" (expt 10 20) (sqrt (expt 10 40)))
(test "sqrt of a rational square" 2/3 (sqrt 4/9))
(test "sqrt of what is not a square" 1.4142135623730951 (sqrt 2))
(test "and that is inexact" #f (exact? (sqrt 2)))
(test "sqrt of a double" 1.5 (sqrt 2.25))
(test "sqrt of nought" 0 (sqrt 0))
(test "exp of nought" 1.0 (exp 0))
(test "exp of one" 2.718281828459045 (exp 1))
(test "log of e" 1.0 (log (exp 1)))
(test "log to a base" 3.0 (log 8 2))
(test "sin of nought" 0.0 (sin 0))
(test "cos of nought" 1.0 (cos 0))
(test "tan of nought" 0.0 (tan 0))
(test "asin of one" 1.5707963267948966 (asin 1))
(test "acos of one" 0.0 (acos 1))
(test "atan of one" 0.7853981633974483 (atan 1))
(test "atan of two, in the second quadrant" 2.356194490192345 (atan 1 -1))
(test "and in the third" -2.356194490192345 (atan -1 -1))
(test "expt to a fractional power" 1.4142135623730951 (expt 2 0.5))
(test "expt of a rational to one" 2.0 (expt 4 1/2))
(test "finite?" #t (finite? 1.5))
(test "infinite?" #f (infinite? 1e300))
(test "nan?" #f (nan? 0.0))

;;  A boxed double is the heap's, and is the same number after a
;;  collection has moved it.

(define probe-kept-double (* 0.1 3))
(probe-big-churn 3000)
(test "a boxed double survives a collection" "0.30000000000000004"
      (number->string probe-kept-double))
(test "and a double past the immediate's range is written back" "1e+300"
      (number->string 1e300))
(test "string->number" 42 (string->number "42"))
(test "string->number of a negative" -42 (string->number "-42"))
(test "string->number in a radix" 42 (string->number "2a" 16))
(test "string->number with a prefix" 42 (string->number "#x2a"))
(test "string->number of a bignum" #t
      (= probe-big (string->number "1267650600228229401496703205376")))
(test "string->number of a float" 1.5 (string->number "1.5"))
(test "string->number of a float with an exponent" 1500.0
      (string->number "1.5e3"))
(test "string->number of what is not a number" #f (string->number "abc"))
(test "string->number of a digit the radix has not" #f
      (string->number "19" 8))
(test "string->number of nothing" #f (string->number ""))
(test "and back" "-1267650600228229401496703205376"
      (number->string (string->number (number->string (- probe-big)))))

;;  Numbers arrived at differently are still the same number.

(test "= over a sum and a literal" #t (= (+ 1 1) 2))
(test "= over two products" #t (= (* 23170 23170) (* 23170 23170)))
(test "= at the edge" #t (= (- 536870911 1) 536870910))

;;  - and / want an argument.  + and * do not, because there is a
;;  number that leaves a sum or a product alone and there is no such
;;  number for subtracting or dividing.

(test "+ with no arguments" 0 (+))
(test "* with no arguments" 1 (*))
(test "- with one argument negates" -5 (- 5))
(test "- with two subtracts" 7 (- 10 3))
(test "/ with one argument inverts" 1/2 (/ 2))
(test "/ with two divides" 3 (/ 6 2))

;;  for-each is map without the answer: it is asked for what the
;;  procedure does, in the order the list is written.

(define for-each-seen '())
(for-each (lambda (x) (set! for-each-seen (cons x for-each-seen))) '(1 2 3))
(test "for-each visits every element" '(1 2 3) (reverse for-each-seen))

(define for-each-count 0)
(for-each (lambda (x) (set! for-each-count (+ for-each-count 1))) '())
(test "for-each over nothing does nothing" 0 for-each-count)

;;  eqv? is eq? for everything but numbers, where it asks whether they
;;  are the same number and equally exact.  For what raven has so far
;;  those answer the same way, and these say they still do.

(test "eqv? of a symbol with itself" #t (eqv? 'a 'a))
(test "eqv? of a sum and a literal" #t (eqv? (+ 1 1) 2))
(test "eqv? of a number and a symbol" #f (eqv? 1 'a))
(test "eqv? of a symbol and a number" #f (eqv? 'a 1))
(test "eqv? of a float with itself" #t (eqv? 1.5 1.5))
(test "eqv? of an integer and a float" #f (eqv? 2 2.0))
(test "eqv? of two strings" #f (eqv? "a" "a"))
(test "memv of a number arrived at" '(2 3) (memv (+ 1 1) '(1 2 3)))
(test "equal? of lists of numbers arrived at" #t
      (equal? '(1 2) (list 1 (+ 1 1))))
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

;;  The rest of what R7RS asks of a string, all of it written on
;;  string->list and list->string the way string-append already was.

(test "string-ref" #\e (string-ref "hello" 1))
(test "string-ref at the front" #\h (string-ref "hello" 0))
(test "string-ref at the end" #\o (string-ref "hello" 4))

;;  substring and string-copy are one procedure under two names.
;;  Neither could be written until string->list took notice of where
;;  to start and where to stop, which it had always been given and
;;  always ignored.

(test "substring" "el" (substring "hello" 1 3))
(test "substring of the whole" "hello" (substring "hello" 0 5))
(test "substring of nothing" "" (substring "hello" 2 2))
(test "string-copy with no bounds" "hello" (string-copy "hello"))
(test "string-copy from an index" "llo" (string-copy "hello" 2))
(test "string-copy between two" "el" (string-copy "hello" 1 3))
(test "a copy is as long as it says" 3 (string-length (string-copy "hello" 2)))

(test "string" "ab" (string #\a #\b))
(test "string of nothing" "" (string))
(test "make-string" "zzz" (make-string 3 #\z))
(test "make-string of nothing" "" (make-string 0 #\z))
(test "make-string with no fill is still that long" 3
      (string-length (make-string 3)))

;;  A string is compared by its characters, and a shorter one that
;;  matches as far as it goes comes first -- which is what length
;;  alone could not say.

(test "string=? over the same" #t (string=? "abc" "abc"))
(test "string=? over different" #f (string=? "abc" "abd"))
(test "string=? over different lengths" #f (string=? "ab" "abc"))
(test "string=? over two empty" #t (string=? "" ""))
(test "string<?" #t (string<? "abc" "abd"))
(test "string<? the other way" #f (string<? "abd" "abc"))
(test "string<? over a prefix" #t (string<? "ab" "abc"))
(test "string<? over a prefix the other way" #f (string<? "abc" "ab"))
(test "string<? over the same" #f (string<? "abc" "abc"))
(test "string>?" #t (string>? "abd" "abc"))
(test "string<=? over the same" #t (string<=? "abc" "abc"))
(test "string<=? over less" #t (string<=? "abc" "abd"))
(test "string<=? over more" #f (string<=? "abd" "abc"))
(test "string>=? over the same" #t (string>=? "abc" "abc"))
(test "string>=? over less" #f (string>=? "abc" "abd"))

;;  And they are chains, the way = and < are.

(test "string<? over three" #t (string<? "a" "b" "c"))
(test "string<? over three that do not rise" #f (string<? "a" "c" "b"))
(test "string=? over three" #t (string=? "a" "a" "a"))

;;  A string is compared by the codes of its characters, which puts
;;  every capital before every small letter and ASCII before the rest.

(test "string<? by the code of a character" #t (string<? "Z" "a"))
(test "string<? past ASCII" #t (string<? "z" "λ"))
(test "string-ref past ASCII" 955 (char->integer (string-ref "aλb" 1)))

;;  A string of Latin-1 is held a byte to a character and any other is
;;  held four, which a program cannot see and these say it cannot: the
;;  same characters are the same string however they were come by, and
;;  one of each kind compares by its characters.

(test "a Latin-1 string past ASCII" 233 (char->integer (string-ref "café" 3)))
(test "and as long as its characters" 4 (string-length "café"))
(test "a narrow part of a wide string is that string" #t
      (string=? (substring "λab" 1 3) "ab"))
(test "and equal? says so too" #t (equal? (substring "λab" 1 3) "ab"))
(test "one of each compares by characters" #t (string<? "ab" "aλ"))
(test "and the other way" #f (string<? "aλ" "ab"))
(test "one of each is never the same" #f (string=? "a" "λ"))
(test "a string made of one Latin-1 character" #t
      (string=? (make-string 2 (integer->char 233)) "éé"))
(test "and of one past it" 955
      (char->integer (string-ref (make-string 2 (integer->char 955)) 1)))
(test "list->string of both kinds" "aλ"
      (list->string (list #\a (integer->char 955))))

;;  string-ref, substring and the comparisons are arithmetic.  They
;;  were written on string->list, which made a pair for every character
;;  of the string to reach one of them, so this loop -- the obvious
;;  way to look at every character -- made a hundred million pairs.

(define probe-long-string (make-string 10000 #\a))

(define (probe-count-a s i n)
  (if (= i (string-length s))
      n
      (probe-count-a s (+ i 1) (if (eq? (string-ref s i) #\a) (+ n 1) n))))

(test "string-ref over every one of ten thousand" 10000
      (probe-count-a probe-long-string 0 0))
(test "the end of a long string" "aaa" (substring probe-long-string 9997 10000))
(test "string=? over two long strings" #t
      (string=? probe-long-string (make-string 10000 #\a)))
(test "string<? over two long strings" #t
      (string<? (make-string 9999 #\a) probe-long-string))

;;  string-map and string-for-each take as many strings as they are
;;  given and stop at the shortest, because map and for-each do.

(test "string-map" "bcd"
      (string-map (lambda (c) (integer->char (+ 1 (char->integer c)))) "abc"))
(test "string-map over nothing" "" (string-map (lambda (c) c) ""))
(test "string-map stops at the shorter" "a"
      (string-map (lambda (a b) a) "ab" "x"))
(test "string-map takes from both" "xb"
      (string-map (lambda (a b) (if (eq? a #\a) b a)) "ab" "xy"))

(define string-seen '())
(string-for-each (lambda (c) (set! string-seen (cons c string-seen))) "abc")
(test "string-for-each walks every character" '(#\a #\b #\c)
      (reverse string-seen))

(define string-pairs '())
(string-for-each
 (lambda (a b) (set! string-pairs (cons (list a b) string-pairs)))
 "abc" "xy")
(test "string-for-each stops at the shorter" 2 (length string-pairs))

;;  string->list itself, which is what all of the above stand on.

(test "string->list" '(#\a #\b #\c) (string->list "abc"))
(test "string->list from an index" '(#\b #\c) (string->list "abc" 1))
(test "string->list between two" '(#\b) (string->list "abc" 1 2))
(test "string->list of nothing" '() (string->list ""))
(test "string->list of an empty range" '() (string->list "abc" 1 1))
(test "list->string undoes it" "abc" (list->string (string->list "abc")))

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

;;  And the other half (#24): a name a template writes and does not
;;  bind means what it meant where the macro was written, whatever the
;;  caller binds the name to.  The template has an alias of it, which a
;;  binding of the caller's cannot be.

(define (twice-it x) (+ x x))
(define-syntax uses-twice-it (syntax-rules () ((_ x) (twice-it x))))

(test "a template's name, called" 10 (uses-twice-it 5))
(test "is not the caller's lambda parameter" 10
      ((lambda (twice-it) (uses-twice-it 5)) (lambda (y) 99)))
(test "nor the caller's let" 10
      (let ((twice-it (lambda (y) 99))) (uses-twice-it 5)))

(define-syntax pair-up (syntax-rules () ((_ a b) (list a b))))

(test "a template's list is list" '(1 2)
      (let ((list (lambda args 'mine))) (pair-up 1 2)))
(test "and the caller's list in what it passed is the caller's" '(mine 2)
      (let ((list (lambda args 'mine))) (pair-up (list) 2)))

;;  The forms a template writes -- begin, set!, cond and its else --
;;  are those forms, and a name it sets is its own.

(define set-it-probe 0)
(define-syntax set-it
  (syntax-rules () ((_ v) (begin (set! set-it-probe v) set-it-probe))))

(test "a template's set! sets the template's name" '((7 5) 7)
      (let* ((inside (let ((set-it-probe 5))
                       (let* ((set-to (set-it 7))) (list set-to set-it-probe))))
             (outside set-it-probe))
        (list inside outside)))

(define-syntax pick
  (syntax-rules ()
    ((_ x) (cond ((= x 1) 'one) (else 'other)))))
(test "a template's cond and else" '(one other) (list (pick 1) (pick 2)))

;;  What a template quotes, quasiquotes or hands case is the name as
;;  written.

(define-syntax name-of (syntax-rules () ((_) 'template-name)))
(test "a template's quoted name" #t (eq? (name-of) 'template-name))

(define-syntax binds-and-quasiquotes
  (syntax-rules () ((_) (let ((tmp 1)) `(tmp ,tmp)))))
(test "a name a template binds, quasiquoted, is the name" #t
      (let ((v (binds-and-quasiquotes)))
        (and (eq? (car v) 'tmp) (= (cadr v) 1))))
(test "and does not take the caller's" '(tmp 1 caller)
      (let ((tmp 'caller))
        (append (binds-and-quasiquotes) (list tmp))))

(define-syntax tagged (syntax-rules () ((_ x) `(tag ,x))))
(test "a template's quasiquoted name" #t
      (let ((v (tagged 5))) (and (eq? (car v) 'tag) (= (cadr v) 5))))

(define-syntax kind
  (syntax-rules ()
    ((_ x) (case x ((red green) 'colour) (else 'other)))))
(test "a template's case data" '(colour other) (list (kind 'red) (kind 'blue)))

;;  A macro written in a body still means that body's names by its
;;  template, and a name the template writes may be defined after the
;;  macro is.

(test "a macro in a body means the body's names" 5
      (let ((n 5))
        (let-syntax ((get-n (syntax-rules () ((_) n))))
          (get-n))))

;;  A literal matches a name that means what the literal means where the
;;  macro was written (#179): an else the caller has bound is a variable,
;;  and the clause it heads is a test of it.

(test "a literal the caller has bound is not the literal" #f
      (let ((else #f)) (cond (#f 'no) (else 'taken))))
(test "nor is => the caller has bound" 'ok
      (let ((=> #f)) (cond (#t => 'ok))))
(test "and an else no one has bound still is" 'taken
      (cond (#f 'no) (else 'taken)))

(define-syntax call-later (syntax-rules () ((_) (defined-after-the-macro))))
(define (defined-after-the-macro) 'later)
(test "a template's name defined after the macro" 'later (call-later))

;;  An ellipsis of its own (#41): syntax-rules may name the identifier
;;  it repeats with, and ... is then a name like any other.

(define-syntax colon-list (syntax-rules ::: () ((_ x :::) (list x :::))))
(test "an ellipsis of its own" '(1 2 3) (colon-list 1 2 3))
(test "over nothing" '() (colon-list))

(define-syntax pairs-of
  (syntax-rules ::: ()
    ((_ (a b :::) :::) '((a (b :::)) :::))))
(test "an ellipsis of its own inside itself" '((1 (2 3)) (4 (5)))
      (pairs-of (1 2 3) (4 5)))

(define-syntax dots-are-a-name (syntax-rules ::: () ((_ ...) (list ...))))
(test "... is a name when the ellipsis is another" '(5) (dots-are-a-name 5))

;;  An ellipsis among the literals is a literal, and there is none.

(define-syntax dots-literal
  (syntax-rules (...)
    ((_ ...) 'dots)
    ((_ x) 'other)))
(test "an ellipsis that is a literal" '(dots other)
      (list (dots-literal ...) (dots-literal 1)))

;;  (... template) is the template with no ellipsis in it, so (... ...)
;;  is the ellipsis itself -- which is how a macro writes another
;;  macro's rules.

(define-syntax make-lister
  (syntax-rules ()
    ((_ name)
     (define-syntax name
       (syntax-rules () ((_ x (... ...)) (list x (... ...))))))))
(make-lister lister)
(test "(... ...) writes an ellipsis" '(1 2 3) (lister 1 2 3))

(define-syntax quoted-dots (syntax-rules () ((_) '(... ...))))
(test "and is the name ... as data" #t (eq? (quoted-dots) '...))

;;  A vector pattern matches a vector whose elements match it, and a
;;  vector template makes one.

(define-syntax vector-sum (syntax-rules () ((_ #(x ...)) (+ x ...))))
(test "a vector pattern" 6 (vector-sum #(1 2 3)))

(define-syntax vector-or-list
  (syntax-rules ()
    ((_ #(x ...)) 'vector)
    ((_ (x ...)) 'list)))
(test "a vector pattern is not a list pattern" '(vector list)
      (list (vector-or-list #(1)) (vector-or-list (1))))

(define-syntax as-vector (syntax-rules () ((_ x ...) '#(x ...))))
(test "a vector template" #(1 2 3) (as-vector 1 2 3))

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

;;  The derived syntax R7RS asks for, all of it written with
;;  syntax-rules and none of it wanting anything the machine did not
;;  already have.

;;  cond.  else and => are literals, so which kind of clause a clause
;;  is decided by what is written in it.

(test "cond takes the first that holds" 2 (cond (#f 1) (#t 2) (else 3)))
(test "cond falls through to else" 3 (cond (#f 1) (#f 2) (else 3)))
(test "cond with nothing that holds" #f (cond (#f 1) (#f 2)))
(test "cond with several results" 3 (cond (#t 1 2 3) (else 'no)))
(test "cond answers the test when that is all there is" '(b c)
      (cond ((memq 'b '(a b c))) (else 'no)))
(test "cond asks a test that does not hold once" #f
      (cond ((memq 'z '(a b c))) (else #f)))
(test "cond hands the test to what follows the arrow" 'b
      (cond ((memq 'b '(a b c)) => car) (else 'no)))
(test "cond with an arrow that is not reached" 'no
      (cond ((memq 'z '(a b c)) => car) (else 'no)))
(test "cond with an arrow and nothing after it" #f
      (cond ((memq 'z '(a b c)) => car)))

;;  cond holds a test it means to answer with in a name, so it is
;;  asked once.

(define cond-asked 0)
(define (cond-counted x) (set! cond-asked (+ cond-asked 1)) x)
(test "cond answers with a test" 7 (cond ((cond-counted 7)) (else 'no)))
(test "and asked it once" 1 cond-asked)

;;  case, which asks memv of each clause's data.

(test "case takes the clause its key is in" 'mid
      (case 3 ((1 2) 'low) ((3 4) 'mid) (else 'high)))
(test "case falls through to else" 'high
      (case 9 ((1 2) 'low) ((3 4) 'mid) (else 'high)))
(test "case with one clause" 'yes (case 1 ((1) 'yes)))
(test "case with one clause and no match" #f (case 9 ((1) 'yes)))
(test "case over symbols" 'found (case 'b ((a) 'no) ((b c) 'found) (else 'no)))
(test "case over characters" 'letter
      (case #\a ((#\a #\b) 'letter) (else 'other)))
(test "case with several results" 3 (case 1 ((1) 1 2 3) (else 'no)))
(test "case hands the key to an arrow" 5 (case 5 ((5) => (lambda (k) k))))

;;  And works its key out once however many clauses it is compared
;;  against, which is why it holds it in a name.

(define case-asked 0)
(define (case-counted x) (set! case-asked (+ case-asked 1)) x)
(test "case over three clauses" 'third
      (case (case-counted 3) ((1) 'first) ((2) 'second) ((3) 'third)))
(test "asked its key once" 1 case-asked)

;;  let* is a let inside a let, so each value sees the ones before it.

(test "let* sees what came before" '(1 2 3)
      (let* ((a 1) (b (+ a 1)) (c (+ b 1))) (list a b c)))
(test "let* with one binding" 1 (let* ((a 1)) a))
(test "let* with none" 'body (let* () 'body))
(test "let* shadows outwards" 2 (let ((a 1)) (let* ((a 2)) a)))

;;  letrec, where every name is bound before any value is worked out,
;;  so each value may name any of the others.

(test "letrec over two that call each other" #t
      (letrec ((probe-even? (lambda (n) (if (= n 0) #t (probe-odd? (- n 1)))))
               (probe-odd? (lambda (n) (if (= n 0) #f (probe-even? (- n 1))))))
        (probe-even? 10)))
(test "letrec over one that calls itself" 120
      (letrec ((fact (lambda (n) (if (= n 0) 1 (* n (fact (- n 1)))))))
        (fact 5)))
(test "letrec* is the same thing" 120
      (letrec* ((fact (lambda (n) (if (= n 0) 1 (* n (fact (- n 1)))))))
        (fact 5)))
(test "letrec* sees what came before it" 3
      (letrec* ((a 1) (b (+ a 2))) b))

;;  A named let is a letrec around a lambda applied where it stands.
;;  A bare name cannot match a list of bindings, so which let is meant
;;  is decided by the shape of what follows.

(test "a named let loops" '(0 1 2)
      (let loop ((i 0) (acc '()))
        (if (= i 3) (reverse acc) (loop (+ i 1) (cons i acc)))))
(test "a named let with one binding" 55
      (let sum ((n 10)) (if (= n 0) 0 (+ n (sum (- n 1))))))
(test "an ordinary let is still one" 3 (let ((a 1) (b 2)) (+ a b)))
(test "an ordinary let with no bindings" 'body (let () 'body))

;;  do, which is a named let with the steps written out.

(test "do with a step" '(0 1 2)
      (do ((i 0 (+ i 1)) (acc '() (cons i acc)))
          ((= i 3) (reverse acc))))
(test "do with a variable that has no step" 5
      (do ((i 0 (+ i 1)) (n 5)) ((= i 3) n)))
(test "do with commands in its body" 6
      (let ((total 0))
        (do ((i 1 (+ i 1))) ((= i 4) total) (set! total (+ total i)))))
(test "do with no result at all" #f (do ((i 0 (+ i 1))) ((= i 3))))
(test "do that runs no times" 'start (do ((i 0 (+ i 1))) (#t 'start)))
(test "a do inside a do" 6
      (do ((i 0 (+ i 1))
           (t 0 (+ t (do ((j 0 (+ j 1)) (s 0 (+ s j))) ((= j 3) s)))))
          ((= i 2) t)))

;;  None of them takes a name the caller is using, which is what the
;;  expander renames a template's own bindings for.  do is the one
;;  that needed the expander told: a named let binds its tag, and the
;;  tag is what do writes its loop as.

(define probe-again 'the-callers-again)
(define probe-value 'the-callers-value)

(test "do does not take the caller's loop name" 'the-callers-again
      (begin (do ((i 0 (+ i 1))) ((= i 2) 'done)) probe-again))
(test "cond does not take the caller's name" 'the-callers-value
      (cond (#f 1) (else probe-value)))
(test "an arrow clause does not either" '((1) the-callers-value)
      (cond ((list 1) => (lambda (x) (list x probe-value)))))
(test "case does not take the caller's name" 'the-callers-value
      (case 1 ((1) probe-value) (else 'no)))
(test "a named let may use a name the caller has" 'inner
      (let probe-again ((n 2))
        (if (= n 0) 'inner (probe-again (- n 1)))))

;;  A promise answers the same thing every time and works it out once.

(test "force answers what was delayed" 3 (force (delay (+ 1 2))))
(test "force answers the same twice" '(3 3)
      (let ((p (delay (+ 1 2)))) (list (force p) (force p))))

(define delay-asked 0)
(define delayed-probe
  (delay (begin (set! delay-asked (+ delay-asked 1)) 7)))
(test "a promise answers" 7 (force delayed-probe))
(test "and again" 7 (force delayed-probe))
(test "and worked it out once" 1 delay-asked)

(test "make-promise of a value" 42 (force (make-promise 42)))
(test "delay-force" 3 (force (delay-force (delay (+ 1 2)))))
(test "a promise is not worked out until it is forced" 0
      (let ((n 0))
        (delay (set! n 1))
        n))

;;  A promise is an object of its own (#168), so it can be told from a
;;  procedure, and make-promise of a procedure is a promise of it.

(test "promise? of a delay" #t (promise? (delay 1)))
(test "promise? of a delay-force" #t (promise? (delay-force (delay 1))))
(test "promise? of make-promise" #t (promise? (make-promise 1)))
(test "promise? of a procedure" #f (promise? (lambda () 1)))
(test "promise? of a number" #f (promise? 5))
(test "a promise is not a procedure" #f (procedure? (delay 1)))
(test "make-promise of a procedure is a promise of it" #t
      (let ((f (lambda () 1))) (eq? (force (make-promise f)) f)))
(test "make-promise of a promise is that promise" #t
      (let ((p (delay 1))) (eq? (make-promise p) p)))
(test "force of what is not a promise is itself" 5 (force 5))
(test "a promise written" "#<promise>"
      (let ((port (open-output-string)))
        (write (delay 1) port)
        (get-output-string port)))

;;  R7RS's own example: a promise whose thunk forces it again.  The
;;  first answer to arrive is the promise's.

(define reentrant-count 0)
(define reentrant-x 5)
(define reentrant-p
  (delay (begin (set! reentrant-count (+ reentrant-count 1))
                (if (> reentrant-count reentrant-x)
                    reentrant-count
                    (force reentrant-p)))))
(test "a promise forced from its own thunk" 6 (force reentrant-p))
(test "and it keeps that answer" 6
      (begin (set! reentrant-x 10) (force reentrant-p)))

;;  A chain of delay-force runs in the space of one link, so a loop
;;  written with it is as deep as the program likes.  Twenty thousand
;;  links is past what the heap holds of calls that have not returned.

(define (promise-loop n)
  (delay-force (if (= n 0) (delay 'done) (promise-loop (- n 1)))))
(test "a long chain of delay-force" 'done (force (promise-loop 20000)))

;;  A name passed to a library's macro that the caller has not defined
;;  yet is the caller's, and means what the caller goes on to define.
;;  It was read in the macro's library, where nothing defines it, so a
;;  stream -- a procedure that delays a call of itself -- was undefined.

(define (integers-from n) (delay (cons n (integers-from (+ n 1)))))
(test "a delay of a call of the procedure it is in" 3
      (car (force (cdr (force (cdr (force (integers-from 1))))))))
(define forward-probe (delay later-defined-probe))
(define later-defined-probe 'defined-later)
(test "a delay of a name defined after it" 'defined-later
      (force forward-probe))

;;  Parameters (#155).  R7RS's own example: a radix whose converter
;;  refuses what is not one, and a procedure that reads it.

(define radix
  (make-parameter 10 (lambda (x)
                       (if (and (exact-integer? x) (<= 2 x 16))
                           x
                           (error "invalid radix" x)))))
(define (radix-text n) (number->string n (radix)))

(test "a parameter answers its value" 10 (radix))
(test "which a procedure reads" "12" (radix-text 12))
(test "parameterize gives it another" "1100"
      (parameterize ((radix 2)) (radix-text 12)))
(test "for the body only" "12" (radix-text 12))
(test "the converter refuses what it refuses" "invalid radix"
      (guard (e ((error-object? e) (error-object-message e)))
        (parameterize ((radix 0)) (radix-text 12))))
(test "and the value is as it was" 10 (radix))
(test "a parameter is a procedure" #t (procedure? radix))
(test "that takes no arguments" "a parameter takes no arguments"
      (guard (e ((error-object? e) (error-object-message e))) (radix 5)))

(define converted (make-parameter "5" string->number))

(test "the converter makes the first value" 5 (converted))
(test "and each value parameterize gives" 7
      (parameterize ((converted "7")) (converted)))
(test "nested, the inner one" '(1 2 1)
      (let ((p (make-parameter 0)))
        (parameterize ((p 1))
          (list (p) (parameterize ((p 2)) (p)) (p)))))
(test "several at once" '(a b)
      (let ((p (make-parameter 0)) (q (make-parameter 0)))
        (parameterize ((p 'a) (q 'b)) (list (p) (q)))))

;;  Leaving the body by an error or a continuation puts the old value
;;  back, which is what dynamic-wind is for.

(define escaping (make-parameter 'outside))
(guard (e (#t #f))
  (parameterize ((escaping 'inside)) (error "leave")))
(test "an error leaving the body puts it back" 'outside (escaping))
(call/cc (lambda (k) (parameterize ((escaping 'inside)) (k 'left))))
(test "and so does a continuation" 'outside (escaping))
(test "coming back into the body puts the new value back" '(in in out)
      (let ((p (make-parameter 'out)) (k #f) (seen '()))
        (let ((v (parameterize ((p 'in))
                   (call/cc (lambda (c) (set! k c)))
                   (p))))
          (set! seen (cons v seen))
          (if (< (length seen) 2) (k #f))
          (reverse (cons (p) seen)))))

;;  The current ports are parameters, so what is written can be sent
;;  somewhere else for the extent of a body.

(test "parameterize the current output port" "hi42"
      (let ((port (open-output-string)))
        (parameterize ((current-output-port port))
          (write-string "hi")
          (display 42))
        (get-output-string port)))
(test "and it is the host's again after" #t
      (let ((before (current-output-port)))
        (parameterize ((current-output-port (open-output-string))) 1)
        (eq? before (current-output-port))))
(test "read from a string as the current input port" #\x
      (parameterize ((current-input-port (open-input-string "xyz")))
        (read-char)))
(test "the current output port takes only an output port"
      "current-output-port: expected a port"
      (guard (e ((error-object? e) (error-object-message e)))
        (parameterize ((current-output-port 5)) 1)))

;;  Changing a string (#158).  A string a procedure made can be
;;  changed; a literal, and the name symbol->string answers with,
;;  cannot, because a literal is one object however often it is read.

(define (message-of thunk)
  (guard (e ((error-object? e) (error-object-message e))) (thunk)))

(test "string-set!" "aba"
      (let ((s (make-string 3 #\a))) (string-set! s 1 #\b) s))
(test "string-set! of a string made by string" "xb"
      (let ((s (string #\a #\b))) (string-set! s 0 #\x) s))
(test "string-set! of a copy of a literal" "xbc"
      (let ((s (string-copy "abc"))) (string-set! s 0 #\x) s))
(test "string-set! of what string-append made" "abx"
      (let ((s (string-append "a" "bc"))) (string-set! s 2 #\x) s))
(test "string-set! of a literal is an error"
      "string-set!: a literal string cannot be changed: \"abc\""
      (message-of (lambda () (string-set! "abc" 0 #\x))))
(test "and of a symbol's name"
      "string-set!: a literal string cannot be changed: \"abc\""
      (message-of (lambda () (string-set! (symbol->string 'abc) 0 #\x))))
(test "string-set! past the end is an error"
      "string-set!: 5 is not an index of a string of 2"
      (message-of (lambda () (string-set! (make-string 2 #\a) 5 #\b))))
(test "string-set! of what is not a character is an error"
      "string-set!: not a character: 1"
      (message-of (lambda () (string-set! (make-string 2 #\a) 0 1))))

;;  A character that does not fit a byte, into a string held a byte to
;;  a character, makes it wide; every name for the string sees that,
;;  and it compares by its characters whichever way it is held.

(test "a wide character into a narrow string" "\x3BB;a"
      (let ((s (make-string 2 #\a))) (string-set! s 0 #\x3BB) s))
(test "is seen by every name for the string" #\x3BB
      (let* ((s (make-string 2 #\a)) (t s))
        (string-set! s 0 #\x3BB)
        (string-ref t 0)))
(test "and compares by its characters after" '(#t #t #t)
      (let ((s (make-string 2 #\a)))
        (string-set! s 0 #\x3BB)
        (string-set! s 0 #\b)
        (list (equal? s "ba") (string=? s "ba") (string<? s "bb"))))

;;  A string made wide is put in the place of the one it was, and the
;;  table's own note of it went with the old one: the next collection
;;  swept a value it could not name.

(define (string-churn n)
  (if (= n 0)
      'done
      (begin (make-string 4 #\a) (list 1 2 3) (string-churn (- n 1)))))
(test "a string made wide survives a collection" '(#\x3BB #\a)
      (let ((s (make-string 2 #\a)))
        (string-set! s 0 #\x3BB)
        (string-churn 4000)
        (list (string-ref s 0) (string-ref s 1))))

(test "string-fill!" "zzzz"
      (let ((s (make-string 4 #\a))) (string-fill! s #\z) s))
(test "string-fill! of a part" "ayya"
      (let ((s (make-string 4 #\a))) (string-fill! s #\y 1 3) s))
(test "string-fill! of a literal is an error"
      "string-fill!: a literal string cannot be changed: \"ab\""
      (message-of (lambda () (string-fill! "ab" #\x))))

(test "string-copy!" "-abc-"
      (let ((to (make-string 5 #\-))) (string-copy! to 1 "abc") to))
(test "string-copy! of a part" "el---"
      (let ((to (make-string 5 #\-))) (string-copy! to 0 "hello" 1 3) to))
(test "string-copy! within a string, forwards" "aabce"
      (let ((s (string-copy "abcde"))) (string-copy! s 1 s 0 3) s))
(test "string-copy! within a string, backwards" "cdede"
      (let ((s (string-copy "abcde"))) (string-copy! s 0 s 2 5) s))
(test "string-copy! of wide characters" "a\x3BB;\x3BC;"
      (let ((to (make-string 3 #\a))) (string-copy! to 1 "\x3BB;\x3BC;") to))
(test "string-copy! past the end is an error"
      "string-copy!: 2 and 3 characters are not within a string of 3"
      (message-of (lambda () (string-copy! (make-string 3 #\a) 2 "abc"))))
(test "string-copy! into a literal is an error"
      "string-copy!: a literal string cannot be changed: \"abc\""
      (message-of (lambda () (string-copy! "abc" 0 "x"))))

;;  R7RS's own example.

(define (made-string) (make-string 3 #\*))
(define (literal-string) "***")
(test "a made string can be changed" "?**"
      (let ((s (made-string))) (string-set! s 0 #\?) s))
(test "a literal cannot" #t
      (string? (message-of (lambda () (string-set! (literal-string) 0 #\?)))))

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

;;  A closure is an object of its own kind now, where it used to be a
;;  pair of the code and the environment it captured.  So it can be
;;  asked about, which is what procedure? wanted, and it cannot be
;;  taken apart, which is what car and cdr were doing to one.

(test "procedure? of a lambda" #t (procedure? (lambda (x) x)))
(test "procedure? of a name that holds one" #t (procedure? car))
(test "procedure? of a foreign function" #t (procedure? equal?))
(test "procedure? of one the library wrote" #t (procedure? map))
(test "procedure? of a list" #f (procedure? '(1 2)))
(test "procedure? of nothing" #f (procedure? '()))
(test "procedure? of a number" #f (procedure? 7))
(test "procedure? of a symbol" #f (procedure? 'car))
(test "procedure? of a string" #f (procedure? "car"))
(test "procedure? of a character" #f (procedure? #\a))

;;  Which is the other half of it: a procedure is not a pair, so
;;  nothing that walks pairs walks into one.

(test "a procedure is not a pair" #f (pair? (lambda (x) x)))
(test "a procedure is not a list" #f (list? (lambda (x) x)))
(test "a procedure is not nothing" #f (null? (lambda (x) x)))

;;  And it shows as what it is rather than as the whole of its code
;;  and everything it closed over.

(test "a procedure writes as one" "#procedure"
      (raven-write-text (lambda (x) x)))

;;  A procedure is still itself, and two of them are not each other.

(test "a procedure is eq? to itself" #t
      ((lambda (f) (eq? f f)) (lambda (x) x)))
(test "two procedures are not eq?" #f
      (eq? (lambda (x) x) (lambda (x) x)))
(test "a procedure is equal? to itself" #t
      ((lambda (f) (equal? f f)) (lambda (x) x)))
(test "two procedures are not equal?" #f
      (equal? (lambda (x) x) (lambda (x) x)))

;;  The collector leaves a forwarding pointer written as a pair, so a
;;  closure that has been copied would come back a list if what it
;;  gave back did not carry the tag it arrived with.  Three thousand
;;  cells of rubbish is several collections.

(define (probe-churn n) (if (= n 0) '() (cons n (probe-churn (- n 1)))))
(define probe-kept (lambda (x) (+ x 1)))
(probe-churn 3000)

(test "a procedure survives a collection" 42 (probe-kept 41))
(test "and is still a procedure" #t (procedure? probe-kept))
(test "and is still not a pair" #f (pair? probe-kept))

;;  One the collector has to reach through, rather than one a name
;;  holds directly: its code and its environment are cells like any
;;  other and are walked the same way.

(define (probe-adder n) (lambda (x) (+ x n)))
(define probe-add-five (probe-adder 5))
(probe-churn 3000)
(test "a closure over a captured value survives" 12 (probe-add-five 7))

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

;;  A name written between vertical bars, which may hold anything at
;;  all -- the spaces and the characters that would otherwise end it
;;  included.  The bar was in no branch of the scanner, so each one was
;;  a bad token and the words between them were read as separate names.

(test "a name with spaces in it" #t (symbol? '|a bar name|))
(test "and it is one name" #t (eq? '|a bar name| '|a bar name|))
(test "a name with a bracket in it" #t (symbol? '|a (b) c|))
(test "a name with a quote in it" #t (symbol? '|it's|))
(test "a name with no characters at all" #t (symbol? '||))
(test "an ordinary name written between bars" #t (eq? '|abc| 'abc))

;;  Which is what it is for, now that a symbol can be made from a
;;  string: a name with a space in it could be built and there was no
;;  way to write it down and read it back.

(test "a symbol with a space survives the round trip" #t
      (eq? (string->symbol "a bar name") '|a bar name|))
(test "and its name is what was put in" "a bar name"
      (symbol->string '|a bar name|))
(test "a symbol built from an awkward name writes as one" #t
      (eq? (string->symbol "(") '|(|))

;;  What is between the bars is a name and nothing else, which is why
;;  it is a token of its own: these would all be something other than
;;  a symbol without the bars.

(test "a boolean between bars is a name" #t (symbol? '|#t|))
(test "and not the boolean" #f (eq? '|#t| #t))
(test "a number between bars is a name" #t (symbol? '|123|))
(test "and not the number" #f (eq? '|123| 123))

;;  R7RS gives all four spellings of the booleans and only the two
;;  short ones were matched, so #true and #false were interned as
;;  ordinary names.

(test "#true is true" #t #true)
(test "#false is false" #f #false)
(test "#true is the short one" #t (eq? #true #t))
(test "#false is the short one" #t (eq? #false #f))
(test "#true is a boolean" #t (boolean? #true))
(test "#false is a boolean" #t (boolean? #false))
(test "and the short ones are what they were" #t (if #t #t #f))

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

;;  A symbol is its name as written (#160).  Every name was folded to
;;  lower case as it was interned, so Foo and foo were one symbol and
;;  string->symbol could not give back the string it was handed.

(test "case tells symbols apart" #f (eq? 'Foo 'foo))
(test "a name keeps its case" "Foo" (symbol->string 'Foo))
(test "string->symbol keeps its case" "mISSISSIppi"
      (symbol->string (string->symbol "mISSISSIppi")))
(test "and reads as the name written" #t
      (eq? 'bitBlt (string->symbol "bitBlt")))
(test "a name in capitals is not the keyword" #t
      (let ((IF 1) (Lambda 2)) (= (+ IF Lambda) 3)))

;;  After #!fold-case a name is read folded to lower case, and a
;;  character name too; a name between bars is not.  #!no-fold-case
;;  puts it back, which is how the rest of this file is read.

#!fold-case
(test "#!fold-case folds a name" #t (eq? 'ABC 'abc))
(TEST "and every name" "abc" (Symbol->String 'AbC))
(test "and a character name" #\space #\SPACE)
(test "but not a character" #f (eqv? #\A #\a))
(test "nor a name between bars" "ABC" (symbol->string '|ABC|))
(test "nor a string" "ABC" (string-copy "ABC"))
#!no-fold-case
(test "#!no-fold-case reads names as written again" #f (eq? 'ABC 'abc))

;;  And a name is its name as written wherever it is bound, not only
;;  as a symbol.  The environments, the translator's scopes and the
;;  macro table still folded case, so Foo and foo were one variable, and
;;  binding both in one let was refused.

(define Case-Probe 1)
(define case-probe 2)
(test "two definitions that differ by case are two" '(1 2)
      (list Case-Probe case-probe))
(test "and two let bindings" '(1 2) (let ((Foo 1) (foo 2)) (list Foo foo)))
(test "and two parameters" '(1 2) ((lambda (Bar bar) (list Bar bar)) 1 2))

(define-syntax Pair-Twice (syntax-rules () ((_ x) (list x x))))
(define (pair-twice x) 'procedure)
(test "a macro and a procedure that differ by case are two" '((1 1) procedure)
      (list (Pair-Twice 1) (pair-twice 1)))

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

;;  The character comparisons, which were written here in scheme on
;;  these two and are the base library's now (#157).  Each takes any
;;  number of characters and compares code points.

(test "char=?" #t (char=? #\a #\a))
(test "char=? that says no" #f (char=? #\a #\b))
(test "char=? of three" #t (char=? #\a #\a #\a))
(test "char=? of three, one different" #f (char=? #\a #\a #\b))
(test "char=? is case-sensitive" #f (char=? #\a #\A))
(test "char<?" #t (char<? #\a #\b))
(test "char<? of three in order" #t (char<? #\a #\b #\c))
(test "char<? of three out of order" #f (char<? #\a #\c #\b))
(test "char<? of the same" #f (char<? #\a #\a))
(test "char>?" #t (char>? #\b #\a))
(test "char<=? of the same" #t (char<=? #\a #\a #\b))
(test "char<=? out of order" #f (char<=? #\b #\a))
(test "char>=? of the same" #t (char>=? #\b #\b #\a))
(test "char>=? out of order" #f (char>=? #\a #\b))
(test "char<? past the ASCII range" #t (char<? #\z #\x3BB))
(test "char=? of something else is an error" "expected a character"
      (guard (e ((error-object? e) (error-object-message e)))
        (char=? #\a 1)))

;;  boolean=? and symbol=?, the same shape.

(test "boolean=?" #t (boolean=? #t #t))
(test "boolean=? of two falses" #t (boolean=? #f #f))
(test "boolean=? that says no" #f (boolean=? #t #f))
(test "boolean=? of three" #t (boolean=? #f #f #f))
(test "boolean=? of three, one different" #f (boolean=? #f #f #t))
(test "boolean=? of something else is an error" "boolean=?: expected booleans"
      (guard (e ((error-object? e) (error-object-message e)))
        (boolean=? #t 1)))
(test "symbol=?" #t (symbol=? 'a 'a))
(test "symbol=? that says no" #f (symbol=? 'a 'b))
(test "symbol=? of three" #t (symbol=? 'a 'a 'a))
(test "symbol=? of three, one different" #f (symbol=? 'a 'a 'b))
(test "symbol=? of a made symbol" #t (symbol=? 'probe (string->symbol "probe")))
(test "symbol=? of something else is an error" "symbol=?: expected symbols"
      (guard (e ((error-object? e) (error-object-message e)))
        (symbol=? 'a "a")))

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

;;  R7RS has two ways of turning an object into text and they differ
;;  on exactly two kinds of it: a string has its quotation marks and
;;  its escapes when it is to be read back and not when it is to be
;;  read, and a character has its #\ and its name.
;;
;;  There was one renderer and display was it, so write was display
;;  with nothing added -- which made write right about strings,
;;  because the renderer quoted them, and display wrong about them for
;;  the same reason.
;;
;;  raven-write-text and raven-display-text are what write and display
;;  write.  R7RS has no way of asking for the text without writing it,
;;  so they are not names a program is offered; a test that says what
;;  something writes as has to hold the answer to compare it.

(test "write quotes a string" "\"a b\"" (raven-write-text "a b"))
(test "display does not" "a b" (raven-display-text "a b"))
(test "write quotes an empty string" "\"\"" (raven-write-text ""))
(test "display of an empty string is nothing" "" (raven-display-text ""))

(test "write marks a character" "#\\a" (raven-write-text #\a))
(test "display gives the character" "a" (raven-display-text #\a))
(test "write names a character that has one" "#\\space"
      (raven-write-text #\space))
(test "display gives that character too" " " (raven-display-text #\space))
(test "write names a newline" "#\\newline" (raven-write-text #\newline))
(test "write names a tab" "#\\tab" (raven-write-text #\tab))
(test "write does not name a digit" "#\\7" (raven-write-text #\7))

;;  The two things they agree about, which is everything else.

(test "write and display agree about a number" #t
      (string=? (raven-write-text 42) (raven-display-text 42)))
(test "write and display agree about a symbol" #t
      (string=? (raven-write-text 'abc) (raven-display-text 'abc)))
(test "write and display agree about nil" #t
      (string=? (raven-write-text '()) (raven-display-text '())))
(test "write and display agree about a boolean" #t
      (string=? (raven-write-text #t) (raven-display-text #t)))

;;  And they differ all the way down a list rather than only at the
;;  top of one.

(test "write inside a list" "(1 \"two\" #\\3 four)"
      (raven-write-text (list 1 "two" #\3 'four)))
(test "display inside a list" "(1 two 3 four)"
      (raven-display-text (list 1 "two" #\3 'four)))
(test "write inside a list inside a list" "(\"a\" (#\\b \"c\"))"
      (raven-write-text (list "a" (list #\b "c"))))
(test "display inside a list inside a list" "(a (b c))"
      (raven-display-text (list "a" (list #\b "c"))))
(test "write down an improper tail" "(1 . \"two\")"
      (raven-write-text (cons 1 "two")))

;;  A string that holds what would end it, or what would be read as an
;;  escape, is written with escapes -- so that what write produces is
;;  something the reader takes back.  It used to be the quotation
;;  marks alone, so such a string wrote as something that would not
;;  read.

(test "write escapes a quotation mark" 4
      (string-length (raven-write-text (string (integer->char 34)))))
(test "and display does not" 1
      (string-length (raven-display-text (string (integer->char 34)))))
(test "write escapes a backslash" 4
      (string-length (raven-write-text (string (integer->char 92)))))
(test "and display does not" 1
      (string-length (raven-display-text (string (integer->char 92)))))
(test "write escapes a newline" 4
      (string-length (raven-write-text (string #\newline))))
(test "write escapes a tab" 4
      (string-length (raven-write-text (string #\tab))))
(test "write leaves an ordinary character alone" 3
      (string-length (raven-write-text "a")))

;;  What write puts round a character is a backslash, which is one
;;  character and not two.

(test "write of a backslash character" 3
      (string-length (raven-write-text (integer->char 92))))
(test "write of a quotation mark character" 3
      (string-length (raven-write-text (integer->char 34))))

;;  Both of them write now and answer nothing in particular, where
;;  display used to answer with the text and write nothing.  Writing
;;  an empty string writes nothing, so this says what it answers
;;  without saying anything.

(test "display answers nothing in particular" '() (display ""))
(test "write answers nothing in particular" '() (write ""))

;;  Vectors.  A vector's elements are in the cells after its length,
;;  so an index is arithmetic and not a walk, which is what tells one
;;  from a list and what #43 was really about.

(test "vector? of a vector" #t (vector? (vector 1 2)))
(test "vector? of a list" #f (vector? '(1 2)))
(test "vector? of nothing" #f (vector? '()))
(test "vector? of a string" #f (vector? "ab"))
(test "a vector is not a pair" #f (pair? (vector 1)))
(test "a vector is not a list" #f (list? (vector 1)))

(test "make-vector" '#(z z z) (make-vector 3 'z))
(test "make-vector of none" '#() (make-vector 0 'z))
(test "make-vector with no fill is still that long" 3
      (vector-length (make-vector 3)))
(test "vector" '#(1 2 3) (vector 1 2 3))
(test "vector of none" '#() (vector))
(test "vector-length" 3 (vector-length (vector 1 2 3)))
(test "vector-length of none" 0 (vector-length (vector)))

(test "vector-ref at the front" 1 (vector-ref (vector 1 2 3) 0))
(test "vector-ref in the middle" 2 (vector-ref (vector 1 2 3) 1))
(test "vector-ref at the end" 3 (vector-ref (vector 1 2 3) 2))

(test "vector-set!" '#(a 2 3)
      (let ((v (vector 1 2 3))) (vector-set! v 0 'a) v))
(test "vector-set! at the end" '#(1 2 c)
      (let ((v (vector 1 2 3))) (vector-set! v 2 'c) v))
(test "vector-set! answers with the vector" #t
      (let ((v (vector 1))) (eq? v (vector-set! v 0 'a))))

;;  An odd length leaves half a cell over, which has to be as safe to
;;  walk as any other.

(test "a vector of an odd length" '#(1 2 3 4 5) (vector 1 2 3 4 5))
(test "the last element of an odd one" 5 (vector-ref (vector 1 2 3 4 5) 4))

;;  Between a vector and a list, both ways, with and without a range.

(test "vector->list" '(1 2 3) (vector->list (vector 1 2 3)))
(test "vector->list of none" '() (vector->list (vector)))
(test "vector->list from an index" '(2 3) (vector->list (vector 1 2 3) 1))
(test "vector->list between two" '(2 3) (vector->list (vector 1 2 3 4) 1 3))
(test "vector->list of an empty range" '() (vector->list (vector 1 2) 1 1))
(test "list->vector" '#(1 2 3) (list->vector '(1 2 3)))
(test "list->vector of nothing" '#() (list->vector '()))

(test "vector-copy" '#(1 2 3) (vector-copy (vector 1 2 3)))
(test "vector-copy from an index" '#(2 3) (vector-copy (vector 1 2 3) 1))
(test "vector-copy between two" '#(2 3) (vector-copy (vector 1 2 3 4) 1 3))
(test "a copy is a different vector" #f
      (let ((v (vector 1 2))) (eq? v (vector-copy v))))

(test "vector-append" '#(1 2 3) (vector-append (vector 1 2) (vector 3)))
(test "vector-append of none" '#() (vector-append))
(test "vector-append of one" '#(1) (vector-append (vector 1)))
(test "vector-append with an empty one" '#(1 2)
      (vector-append (vector 1) (vector) (vector 2)))

(test "vector-fill!" '#(x x x)
      (let ((v (make-vector 3 0))) (vector-fill! v 'x) v))
(test "vector-fill! from an index" '#(0 x x)
      (let ((v (make-vector 3 0))) (vector-fill! v 'x 1) v))
(test "vector-fill! between two" '#(0 x 0)
      (let ((v (make-vector 3 0))) (vector-fill! v 'x 1 2) v))

;;  vector-copy! may be given one vector twice with the ranges lying
;;  over one another, and R7RS says it works as though everything
;;  read were read before anything is written.

(test "vector-copy!" '#(1 9 8 4)
      (let ((v (vector 1 2 3 4))) (vector-copy! v 1 (vector 9 8)) v))
(test "vector-copy! over itself, forwards" '#(2 3 4 4 5)
      (let ((v (vector 1 2 3 4 5))) (vector-copy! v 0 v 1 4) v))
(test "vector-copy! over itself, backwards" '#(1 1 2 3 5)
      (let ((v (vector 1 2 3 4 5))) (vector-copy! v 1 v 0 3) v))

(test "vector->string" "ab" (vector->string (vector #\a #\b)))
(test "string->vector" '#(#\a #\b) (string->vector "ab"))
(test "string->vector between two" '#(#\b) (string->vector "abc" 1 2))

;;  map and for-each over as many vectors as they are given, stopping
;;  at the shortest, because the list ones do.

(test "vector-map" '#(2 3 4)
      (vector-map (lambda (x) (+ x 1)) (vector 1 2 3)))
(test "vector-map over none" '#() (vector-map (lambda (x) x) (vector)))
(test "vector-map over two" '#((1 x) (2 y))
      (vector-map (lambda (a b) (list a b)) '#(1 2) '#(x y)))
(test "vector-map stops at the shorter" 2
      (vector-length (vector-map (lambda (a b) a) '#(1 2 3) '#(x y))))

(define vector-seen '())
(vector-for-each (lambda (x) (set! vector-seen (cons x vector-seen)))
                 '#(1 2 3))
(test "vector-for-each walks every element" '(1 2 3) (reverse vector-seen))

(define vector-pairs 0)
(vector-for-each (lambda (a b) (set! vector-pairs (+ vector-pairs 1)))
                 '#(1 2 3) '#(x y))
(test "vector-for-each stops at the shorter" 2 vector-pairs)

;;  equal? walks a vector the way it walks a pair.

(test "equal? over two the same" #t (equal? '#(1 2) '#(1 2)))
(test "equal? over two that differ" #f (equal? '#(1 2) '#(1 3)))
(test "equal? over different lengths" #f (equal? '#(1 2) '#(1 2 3)))
(test "equal? over two empty" #t (equal? '#() '#()))
(test "equal? all the way down" #t (equal? '#(1 #(2 "a")) '#(1 #(2 "a"))))
(test "equal? of a vector and a list" #f (equal? '#(1 2) '(1 2)))
(test "eq? of two vectors that read alike" #f (eq? (vector 1) (vector 1)))

;;  A vector written out is a literal, so its elements are data.  It
;;  read as a call of vector, which made them expressions: #(1 2 3)
;;  came out right because a number stands for itself, and #(a b) was
;;  "undefined: a".

(test "a vector of numbers" '#(1 2 3) (vector 1 2 3))
(test "a vector of names" #t (symbol? (vector-ref '#(a b) 0)))
(test "and the name is the name" 'a (vector-ref '#(a b) 0))
(test "a vector of several kinds" 4 (vector-length '#(1 "two" #\3 four)))
(test "an empty vector written out" 0 (vector-length '#()))
(test "a vector inside a vector" 3 (vector-ref (vector-ref '#(1 #(2 3)) 1) 1))
(test "a vector inside a list" #t (vector? (car (cdr (list 1 '#(2))))))
(test "a vector written out is quoted by the reader" '#(a) '#(a))

;;  What it writes as, which is what the reader takes back.

(test "a vector writes as one" "#(1 2 3)" (raven-write-text '#(1 2 3)))
(test "an empty vector writes as one" "#()" (raven-write-text '#()))
(test "write goes down a vector" "#(\"a\" #\\b)"
      (raven-write-text (vector "a" #\b)))
(test "display goes down one too" "#(a b)"
      (raven-display-text (vector "a" #\b)))

;;  And all of it survives a collection: a vector is as many cells as
;;  it has elements and the collector copies them together, so what
;;  comes back has to be a vector again and not the pair its
;;  forwarding pointer was written as.

(define (vector-churn n)
  (if (= n 0) '() (cons n (vector-churn (- n 1)))))

(define kept-vector (vector 1 2 3))
(define kept-big (make-vector 400 0))
(vector-set! kept-big 399 'last)
(define kept-mixed (vector "a string" (lambda (x) x) (vector 9)))

(vector-churn 3000)

(test "a vector survives a collection" '#(1 2 3) kept-vector)
(test "and is still a vector" #t (vector? kept-vector))
(test "a long vector survives one" 400 (vector-length kept-big))
(test "with what was put at the end of it" 'last (vector-ref kept-big 399))
(test "a vector of things that move survives" "a string"
      (vector-ref kept-mixed 0))
(test "including a procedure" #t (procedure? (vector-ref kept-mixed 1)))
(test "and a vector" '#(9) (vector-ref kept-mixed 2))

;;  Bytevectors, laid out the way a vector is and one element to a
;;  slot.  What tells them apart is what may go into one, which is
;;  said where it is put in rather than by the shape of the thing
;;  holding it.

(test "bytevector? of a bytevector" #t (bytevector? (bytevector 1 2)))
(test "bytevector? of a vector" #f (bytevector? (vector 1 2)))
(test "vector? of a bytevector" #f (vector? (bytevector 1 2)))
(test "bytevector? of a list" #f (bytevector? '(1 2)))
(test "a bytevector is not a pair" #f (pair? (bytevector 1)))

(test "make-bytevector" '#u8(7 7 7) (make-bytevector 3 7))
(test "make-bytevector of none" '#u8() (make-bytevector 0 7))
(test "make-bytevector with no fill is zero" '#u8(0 0) (make-bytevector 2))
(test "bytevector" '#u8(1 2 3) (bytevector 1 2 3))
(test "bytevector of none" '#u8() (bytevector))
(test "bytevector-length" 3 (bytevector-length (bytevector 1 2 3)))
(test "bytevector-length of none" 0 (bytevector-length (bytevector)))

(test "bytevector-u8-ref" 20 (bytevector-u8-ref '#u8(10 20 30) 1))
(test "bytevector-u8-ref at the front" 10 (bytevector-u8-ref '#u8(10 20) 0))
(test "bytevector-u8-ref of the largest byte" 255
      (bytevector-u8-ref '#u8(0 255) 1))
(test "bytevector-u8-set!" '#u8(99 0)
      (let ((v (make-bytevector 2 0))) (bytevector-u8-set! v 0 99) v))
(test "bytevector-u8-set! of the largest byte" '#u8(255)
      (let ((v (make-bytevector 1 0))) (bytevector-u8-set! v 0 255) v))

(test "bytevector-copy" '#u8(1 2 3) (bytevector-copy '#u8(1 2 3)))
(test "bytevector-copy from an index" '#u8(2 3)
      (bytevector-copy '#u8(1 2 3) 1))
(test "bytevector-copy between two" '#u8(2 3)
      (bytevector-copy '#u8(1 2 3 4) 1 3))
(test "a copy is a different bytevector" #f
      (let ((v (bytevector 1 2))) (eq? v (bytevector-copy v))))

(test "bytevector-append" '#u8(1 2 3)
      (bytevector-append '#u8(1 2) '#u8(3)))
(test "bytevector-append of none" '#u8() (bytevector-append))
(test "bytevector-append with an empty one" '#u8(1 2)
      (bytevector-append '#u8(1) '#u8() '#u8(2)))

(test "bytevector-copy!" '#u8(1 9 8 4)
      (let ((v (bytevector 1 2 3 4))) (bytevector-copy! v 1 '#u8(9 8)) v))
(test "bytevector-copy! over itself" '#u8(2 3 4 4)
      (let ((v (bytevector 1 2 3 4))) (bytevector-copy! v 0 v 1 4) v))

;;  A string and the bytes it comes to.  Raven holds a string as
;;  characters and writes it out as UTF-8, so these are that, said.

(test "string->utf8" '#u8(97 98 99) (string->utf8 "abc"))
(test "string->utf8 of nothing" '#u8() (string->utf8 ""))
(test "utf8->string" "abc" (utf8->string '#u8(97 98 99)))
(test "utf8->string of nothing" "" (utf8->string '#u8()))
(test "a string survives the round trip" "hello"
      (utf8->string (string->utf8 "hello")))

;;  And a character that is more than one byte is more than one byte,
;;  which is the whole of why utf8->string is not string->list.

(test "a character of two bytes" 2
      (bytevector-length (string->utf8 (string (integer->char 233)))))
(test "and it is the two it should be" '#u8(195 169)
      (string->utf8 (string (integer->char 233))))
(test "a character of three bytes" 3
      (bytevector-length (string->utf8 (string (integer->char 8364)))))
(test "one of two survives the round trip" #t
      (eq? (integer->char 233)
           (string-ref (utf8->string
                        (string->utf8 (string (integer->char 233)))) 0)))
(test "one of three does too" #t
      (eq? (integer->char 8364)
           (string-ref (utf8->string
                        (string->utf8 (string (integer->char 8364)))) 0)))

;;  equal? walks one the way it walks a vector, and a bytevector is
;;  not a vector however alike they read.

(test "equal? over two the same" #t (equal? '#u8(1 2) '#u8(1 2)))
(test "equal? over two that differ" #f (equal? '#u8(1 2) '#u8(1 3)))
(test "equal? over different lengths" #f (equal? '#u8(1) '#u8(1 2)))
(test "equal? of a bytevector and a vector" #f (equal? '#u8(1 2) '#(1 2)))

;;  #u8(1 2) read as a call of bytevector, so its elements were
;;  expressions, and #u8() was a bad token.

(test "a bytevector written out" '#u8(1 2 255) (bytevector 1 2 255))
(test "an empty one written out" 0 (bytevector-length '#u8()))
(test "one inside a list" #t (bytevector? (car (cdr (list 1 '#u8(2))))))
(test "what one writes as" "#u8(1 2)" (raven-write-text '#u8(1 2)))
(test "an empty one writes as one" "#u8()" (raven-write-text '#u8()))

;;  And it survives a collection, the way a vector does and for the
;;  same reason: the tag has to come back with it.

(define kept-bytes (bytevector 1 2 3))
(define kept-long-bytes (make-bytevector 300 9))

(vector-churn 3000)

(test "a bytevector survives a collection" '#u8(1 2 3) kept-bytes)
(test "and is still a bytevector" #t (bytevector? kept-bytes))
(test "a long one survives too" 300 (bytevector-length kept-long-bytes))
(test "with what was put in it" 9 (bytevector-u8-ref kept-long-bytes 299))

;;  A bytevector's bytes are packed, as many to an object as its
;;  payload holds, where they were one to an object: eight bytes of heap
;;  for every two of data.  Each byte has its own place in the object it
;;  shares, and setting one leaves the others as they were.

(define probe-packed (make-bytevector 8 0))

(define (probe-fill-packed! bv i)
  (if (= i (bytevector-length bv))
      bv
      (begin
        (bytevector-u8-set! bv i (- 255 (* 30 i)))
        (probe-fill-packed! bv (+ i 1)))))

(probe-fill-packed! probe-packed 0)

(test "every byte in its own place" '#u8(255 225 195 165 135 105 75 45)
      probe-packed)

(bytevector-u8-set! probe-packed 4 0)

(test "setting one leaves the one before" 165
      (bytevector-u8-ref probe-packed 3))
(test "and the one after" 105 (bytevector-u8-ref probe-packed 5))
(test "and is itself" 0 (bytevector-u8-ref probe-packed 4))

;;  What comes out is an integer like any other, made on the way out:
;;  the object the bytes are packed in is never what is handed back.

(test "a byte read back is an integer" #t
      (integer? (bytevector-u8-ref probe-packed 0)))
(test "and the same integer as any other 255" #t
      (eq? (bytevector-u8-ref probe-packed 0) 255))

;;  How much a large bytevector saves is tested in a VM of its own, in
;;  the library suite: here it depended on how much of the heap the rest
;;  of this suite was holding, which grows as the suite does.

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
  (if (= n 0) '() (cons (raven-display-text n) (probe-strings (- n 1)))))

(test "five hundred live strings" 500 (length (probe-strings 500)))

;;  And past 9,999, which was the ceiling after that: a number with
;;  nothing to do with the encoding, which has room for sixteen
;;  million.  A vector holds them, because it holds two to a cell
;;  where a list takes a cell each, and ten thousand pairs is a good
;;  part of the heap the suite runs in.

(define (probe-fill-strings v n)
  (if (= n 0)
      v
      (begin
        (vector-set! v (- n 1) (raven-display-text n))
        (probe-fill-strings v (- n 1)))))

(define probe-ten-thousand (probe-fill-strings (make-vector 10001 #f) 10001))

(test "ten thousand and one live strings" "10001"
      (vector-ref probe-ten-thousand 10000))
(test "and the first of them is still itself" "1"
      (vector-ref probe-ten-thousand 0))

;;  Once they are gone their ids come back, and as many again can be
;;  made in the same places.

(set! probe-ten-thousand #f)

(test "and as many again after them" "10001"
      (vector-ref (probe-fill-strings (make-vector 10001 #f) 10001) 10000))

;;  Ports.  Everything raven wrote went to the one place the host
;;  gave it, through one foreign function, and nothing could be read
;;  at all.  Every PASS line above goes through the default output
;;  port, so that much is said by the whole of the rest of this file;
;;  what is here is the ports that are named.

(test "the host's output is a port" #t (port? (current-output-port)))
(test "and an output port" #t (output-port? (current-output-port)))
(test "and not an input port" #f (input-port? (current-output-port)))
(test "the host's errors go to one too" #t (output-port? (current-error-port)))
(test "the host's input is an input port" #t (input-port? (current-input-port)))
(test "and not an output port" #f (output-port? (current-input-port)))
(test "asking twice asks for the same port" #t
      (eq? (current-output-port) (current-output-port)))
(test "a port is textual" #t (textual-port? (current-output-port)))
(test "and none of them is binary yet" #f (binary-port? (current-output-port)))
(test "a number is not a port" #f (port? 4))
(test "a string is not a port" #f (port? "x"))
(test "nil is not a port" #f (port? '()))
(test "input-port? of something else" #f (input-port? 4))
(test "output-port? of something else" #f (output-port? "x"))

;;  The end of a port is one object and nothing else is it.

(test "the end of a port is itself" #t (eof-object? (eof-object)))
(test "and is the same object each time" #t (eq? (eof-object) (eof-object)))
(test "nil is not it" #f (eof-object? '()))
(test "false is not it" #f (eof-object? #f))
(test "a string is not it" #f (eof-object? ""))
(test "what it writes as" "#eof" (raven-write-text (eof-object)))

;;  A port opened on a string it is building up.

(test "an output string port is a port" #t (port? (open-output-string)))
(test "and an output one" #t (output-port? (open-output-string)))
(test "and not an input one" #f (input-port? (open-output-string)))
(test "and is open" #t (output-port-open? (open-output-string)))
(test "with nothing in it" "" (get-output-string (open-output-string)))
(test "two of them are two ports" #f
      (eq? (open-output-string) (open-output-string)))

(test "write-char to one" "a"
      (let ((p (open-output-string))) (write-char #\a p) (get-output-string p)))
(test "write-string to one" "hello"
      (let ((p (open-output-string)))
        (write-string "hello" p) (get-output-string p)))
(test "display to one" "42"
      (let ((p (open-output-string))) (display 42 p) (get-output-string p)))
(test "newline to one" #\newline
      (let ((p (open-output-string)))
        (newline p) (string-ref (get-output-string p) 0)))
(test "write puts a string in quotes" 3
      (let ((p (open-output-string)))
        (write "a" p) (string-length (get-output-string p))))
(test "and display does not" 1
      (let ((p (open-output-string)))
        (display "a" p) (string-length (get-output-string p))))

(test "what is written runs together" "ab1"
      (let ((p (open-output-string)))
        (write-char #\a p) (write-string "b" p) (display 1 p)
        (get-output-string p)))
(test "reading it out does not empty it" "aa"
      (let ((p (open-output-string)))
        (write-char #\a p) (get-output-string p) (write-char #\a p)
        (get-output-string p)))
(test "two ports are written to separately" "a"
      (let ((p (open-output-string)) (q (open-output-string)))
        (write-char #\a p) (write-char #\b q) (get-output-string p)))
(test "and the other has its own" "b"
      (let ((p (open-output-string)) (q (open-output-string)))
        (write-char #\a p) (write-char #\b q) (get-output-string q)))

(test "a closed port is not open" #f
      (let ((p (open-output-string))) (close-port p) (output-port-open? p)))
(test "but is still a port" #t
      (let ((p (open-output-string))) (close-port p) (port? p)))
(test "and still has what was written to it" "a"
      (let ((p (open-output-string)))
        (write-char #\a p) (close-port p) (get-output-string p)))
(test "close-output-port closes one" #f
      (let ((p (open-output-string)))
        (close-output-port p) (output-port-open? p)))
(test "close-input-port closes one" #f
      (let ((p (open-input-string "a")))
        (close-input-port p) (input-port-open? p)))
(test "an output port is not an open input port" #f
      (input-port-open? (open-output-string)))
(test "an input port is not an open output port" #f
      (output-port-open? (open-input-string "a")))

;;  Closing what the host reads and writes is not this program's to
;;  do, and every line printed after this one says it did not happen.

(test "the host's port does not close" #t
      (begin (close-port (current-output-port))
             (output-port-open? (current-output-port))))

;;  A port opened on a string being read out of.

(test "an input string port is a port" #t (port? (open-input-string "a")))
(test "and an input one" #t (input-port? (open-input-string "a")))
(test "and not an output one" #f (output-port? (open-input-string "a")))

(test "read-char" #\a (read-char (open-input-string "abc")))
;;  The order two reads happen in has to be said: R7RS leaves the
;;  order arguments are evaluated in open, and raven evaluates them
;;  right to left, so (list (read-char p) (read-char p)) reads the
;;  second character first.

(test "reading goes on from where it got to" '(#\a #\b)
      (let* ((p (open-input-string "ab"))
             (a (read-char p))
             (b (read-char p)))
        (list a b)))
(test "read-char of an empty port is the end" #t
      (eof-object? (read-char (open-input-string ""))))
(test "and so is reading past the last" #t
      (let ((p (open-input-string "a")))
        (read-char p) (eof-object? (read-char p))))
(test "the end stays the end" #t
      (let ((p (open-input-string "")))
        (read-char p) (eof-object? (read-char p))))

(test "peek-char does not take the character" '(#\a #\a)
      (let* ((p (open-input-string "ab"))
             (a (peek-char p))
             (b (read-char p)))
        (list a b)))
(test "so peeking twice peeks at the same one" #\a
      (let ((p (open-input-string "ab"))) (peek-char p) (peek-char p)))
(test "and the read after it goes on" #\b
      (let ((p (open-input-string "ab")))
        (peek-char p) (read-char p) (read-char p)))
(test "peek-char at the end is the end" #t
      (eof-object? (peek-char (open-input-string ""))))

(test "a string port always has a character ready" #t
      (char-ready? (open-input-string "a")))
(test "even when it has run out" #t (char-ready? (open-input-string "")))

(test "a port read to the end" '(#\a #\b #\c)
      (let* ((p (open-input-string "abc"))
             (a (read-char p))
             (b (read-char p))
             (c (read-char p)))
        (list a b c)))
(test "and then it stays at the end" #t
      (let* ((p (open-input-string "a"))
             (a (read-char p))
             (b (read-char p)))
        (and (eof-object? b) (eof-object? (read-char p)))))

;;  A line is up to the next newline, which is read and thrown away.

(define two-lines (string #\a #\b #\newline #\c #\d))

(test "read-line" "ab" (read-line (open-input-string two-lines)))
(test "and then the next one" "cd"
      (let ((p (open-input-string two-lines))) (read-line p) (read-line p)))
(test "and then the end" #t
      (let ((p (open-input-string two-lines)))
        (read-line p) (read-line p) (eof-object? (read-line p))))
(test "the newline is not left behind" #\c
      (let ((p (open-input-string two-lines))) (read-line p) (read-char p)))
(test "a line with no newline after it is a line" "ab"
      (read-line (open-input-string "ab")))
(test "a line with nothing on it" ""
      (read-line (open-input-string (string #\newline #\a))))
(test "read-line of nothing is the end" #t
      (eof-object? (read-line (open-input-string ""))))

;;  And a string of up to this many characters.

(test "read-string" "ab" (read-string 2 (open-input-string "abcd")))
(test "which takes what it read" #\c
      (let ((p (open-input-string "abcd"))) (read-string 2 p) (read-char p)))
(test "read-string past the end is what there was" "ab"
      (read-string 9 (open-input-string "ab")))
(test "read-string of none is nothing" ""
      (read-string 0 (open-input-string "ab")))
(test "and takes nothing" #\a
      (let ((p (open-input-string "ab"))) (read-string 0 p) (read-char p)))
(test "read-string at the end is the end" #t
      (eof-object? (read-string 2 (open-input-string ""))))

;;  call-with-port closes the port after the call, and answers with
;;  what the call answered with.

(test "call-with-port hands the port over" #\a
      (call-with-port (open-input-string "a") read-char))
(test "and answers with what was done" 7
      (call-with-port (open-output-string) (lambda (p) 7)))
(test "and closes it after" #f
      (let ((p (open-output-string)))
        (call-with-port p (lambda (q) (write-char #\a q)))
        (output-port-open? p)))
(test "nothing is held back, so nothing is pushed out" '()
      (flush-output-port (current-output-port)))

;;  Binary ports: a port opened on a bytevector, read and written a
;;  byte at a time.  Every port used to be textual, so binary-port?
;;  answered #f whatever it was given and textual-port? was port?
;;  under another name.

(test "an output bytevector port is a port" #t
      (port? (open-output-bytevector)))
(test "and a binary one" #t (binary-port? (open-output-bytevector)))
(test "and not a textual one" #f (textual-port? (open-output-bytevector)))
(test "and an output one" #t (output-port? (open-output-bytevector)))
(test "and not an input one" #f (input-port? (open-output-bytevector)))

(test "an input bytevector port is binary" #t
      (binary-port? (open-input-bytevector '#u8(1))))
(test "and an input one" #t (input-port? (open-input-bytevector '#u8(1))))
(test "and not an output one" #f
      (output-port? (open-input-bytevector '#u8(1))))

;;  And the ports that were here already are still textual.

(test "a string port is textual" #t (textual-port? (open-output-string)))
(test "and not binary" #f (binary-port? (open-output-string)))
(test "the host's port is textual" #t (textual-port? (current-output-port)))
(test "and not binary" #f (binary-port? (current-output-port)))
(test "the host's input is textual too" #t
      (textual-port? (current-input-port)))
(test "a number is not a binary port" #f (binary-port? 4))
(test "a number is not a textual port" #f (textual-port? 4))

;;  Writing a byte at a time.

(test "nothing written yet" '#u8()
      (get-output-bytevector (open-output-bytevector)))
(test "write-u8" '#u8(7)
      (let ((p (open-output-bytevector)))
        (write-u8 7 p) (get-output-bytevector p)))
(test "several of them" '#u8(1 2 3)
      (let ((p (open-output-bytevector)))
        (write-u8 1 p) (write-u8 2 p) (write-u8 3 p)
        (get-output-bytevector p)))
(test "the largest byte" '#u8(255)
      (let ((p (open-output-bytevector)))
        (write-u8 255 p) (get-output-bytevector p)))
(test "and the smallest" '#u8(0)
      (let ((p (open-output-bytevector)))
        (write-u8 0 p) (get-output-bytevector p)))
(test "reading it out does not empty it" '#u8(1 1)
      (let ((p (open-output-bytevector)))
        (write-u8 1 p) (get-output-bytevector p) (write-u8 1 p)
        (get-output-bytevector p)))
(test "two of them are two ports" #f
      (eq? (open-output-bytevector) (open-output-bytevector)))

(test "write-bytevector" '#u8(1 2 3)
      (let ((p (open-output-bytevector)))
        (write-bytevector '#u8(1 2 3) p) (get-output-bytevector p)))
(test "write-bytevector of nothing" '#u8()
      (let ((p (open-output-bytevector)))
        (write-bytevector '#u8() p) (get-output-bytevector p)))
(test "write-bytevector from an index" '#u8(2 3)
      (let ((p (open-output-bytevector)))
        (write-bytevector '#u8(1 2 3) p 1) (get-output-bytevector p)))
(test "write-bytevector between two" '#u8(2)
      (let ((p (open-output-bytevector)))
        (write-bytevector '#u8(1 2 3) p 1 2) (get-output-bytevector p)))
(test "write-bytevector onto what is there" '#u8(1 2)
      (let ((p (open-output-bytevector)))
        (write-u8 1 p) (write-bytevector '#u8(2) p)
        (get-output-bytevector p)))

;;  Reading a byte at a time.  The order two reads happen in has to be
;;  said, the same as it does for characters.

(test "read-u8" 1 (read-u8 (open-input-bytevector '#u8(1 2))))
(test "reading goes on from where it got to" '(1 2)
      (let* ((p (open-input-bytevector '#u8(1 2)))
             (a (read-u8 p))
             (b (read-u8 p)))
        (list a b)))
(test "read-u8 of an empty port is the end" #t
      (eof-object? (read-u8 (open-input-bytevector '#u8()))))
(test "and so is reading past the last" #t
      (let* ((p (open-input-bytevector '#u8(1)))
             (a (read-u8 p)))
        (eof-object? (read-u8 p))))
(test "a byte of zero is not the end" #f
      (eof-object? (read-u8 (open-input-bytevector '#u8(0)))))

(test "peek-u8 does not take the byte" '(1 1)
      (let* ((p (open-input-bytevector '#u8(1 2)))
             (a (peek-u8 p))
             (b (read-u8 p)))
        (list a b)))
(test "so peeking twice peeks at the same one" 1
      (let* ((p (open-input-bytevector '#u8(1 2)))
             (a (peek-u8 p)))
        (peek-u8 p)))
(test "peek-u8 at the end is the end" #t
      (eof-object? (peek-u8 (open-input-bytevector '#u8()))))

(test "a bytevector port always has a byte ready" #t
      (u8-ready? (open-input-bytevector '#u8(1))))
(test "even when it has run out" #t
      (u8-ready? (open-input-bytevector '#u8())))

;;  And a bytevector of up to this many bytes.

(test "read-bytevector" '#u8(1 2)
      (read-bytevector 2 (open-input-bytevector '#u8(1 2 3))))
(test "which takes what it read" 3
      (let* ((p (open-input-bytevector '#u8(1 2 3)))
             (v (read-bytevector 2 p)))
        (read-u8 p)))
(test "read-bytevector past the end is what there was" '#u8(1 2)
      (read-bytevector 9 (open-input-bytevector '#u8(1 2))))
(test "read-bytevector of none is nothing" '#u8()
      (read-bytevector 0 (open-input-bytevector '#u8(1))))
(test "and takes nothing" 1
      (let* ((p (open-input-bytevector '#u8(1)))
             (v (read-bytevector 0 p)))
        (read-u8 p)))
(test "read-bytevector at the end is the end" #t
      (eof-object? (read-bytevector 2 (open-input-bytevector '#u8()))))

;;  Into a bytevector that is already there, between start and end,
;;  which are read the way bytevector-copy! reads them.

(test "read-bytevector! says how many arrived" 2
      (read-bytevector! (make-bytevector 2 0)
                        (open-input-bytevector '#u8(9 8 7))))
(test "and puts them in" '#u8(9 8)
      (let ((v (make-bytevector 2 0)))
        (read-bytevector! v (open-input-bytevector '#u8(9 8 7)))
        v))
(test "fewer than asked for when the port runs out" 2
      (read-bytevector! (make-bytevector 3 0)
                        (open-input-bytevector '#u8(9 8))))
(test "and the rest is left alone" '#u8(9 8 0)
      (let ((v (make-bytevector 3 0)))
        (read-bytevector! v (open-input-bytevector '#u8(9 8)))
        v))
(test "read-bytevector! from an index" '#u8(0 9 8)
      (let ((v (make-bytevector 3 0)))
        (read-bytevector! v (open-input-bytevector '#u8(9 8 7)) 1)
        v))
(test "read-bytevector! between two" '#u8(0 9 0)
      (let ((v (make-bytevector 3 0)))
        (read-bytevector! v (open-input-bytevector '#u8(9 8 7)) 1 2)
        v))
(test "read-bytevector! takes only what it put in" 7
      (let* ((p (open-input-bytevector '#u8(9 8 7)))
             (n (read-bytevector! (make-bytevector 2 0) p)))
        (read-u8 p)))
(test "read-bytevector! with no room is none" 0
      (read-bytevector! (make-bytevector 0 0)
                        (open-input-bytevector '#u8(1))))
(test "read-bytevector! at the end is the end" #t
      (eof-object? (read-bytevector! (make-bytevector 2 0)
                                     (open-input-bytevector '#u8()))))

;;  Closing one is closing a port, the same as any other, and what it
;;  holds can still be asked for after.

(test "a closed binary port is not open" #f
      (let ((p (open-output-bytevector))) (close-port p)
           (output-port-open? p)))
(test "and still has what was written to it" '#u8(1)
      (let ((p (open-output-bytevector)))
        (write-u8 1 p) (close-port p) (get-output-bytevector p)))

;;  What one writes as says which it is.

(test "what a binary input port writes as" "#binary-input-port"
      (raven-write-text (open-input-bytevector '#u8())))
(test "and a binary output port" "#binary-output-port"
      (raven-write-text (open-output-bytevector)))
(test "a textual one still says what it said" "#output-port"
      (raven-write-text (open-output-string)))

;;  A port is a foreign value, so it is collected, and its place in
;;  the machine's table has to come back with it -- which is what made
;;  Free start being called at all.  Two thousand ports, only one of
;;  them named at a time, where there is room for under a thousand.

(define kept-port (open-output-string))
(write-char #\a kept-port)

(define kept-binary-port (open-output-bytevector))
(write-u8 1 kept-binary-port)

(define (churn-ports n)
  (if (= n 0)
      'done
      (begin (open-output-string) (vector-churn 20) (churn-ports (- n 1)))))

(test "a port no longer named gives its place back" 'done (churn-ports 2000))
(test "a port survives a collection" "a" (get-output-string kept-port))
(test "and is still open" #t (output-port-open? kept-port))
(test "and can still be written to" "ab"
      (begin (write-char #\b kept-port) (get-output-string kept-port)))
(test "a binary port survives one too" '#u8(1)
      (get-output-bytevector kept-binary-port))
(test "and is still binary" #t (binary-port? kept-binary-port))

;;  What this raven is.  features answers with the identifiers R7RS's
;;  appendix names, as far as they are true here, and raven's own; the
;;  numeric ones are absent until the numeric tower makes them true,
;;  which is what a program is meant to be able to find out.

(define (probe-has? f) (if (memq f (features)) #t #f))

(test "features is a list of symbols" #t
      (and (list? (features)) (symbol? (car (features)))))
(test "raven is one" #t (probe-has? 'raven))
(test "and full-unicode" #t (probe-has? 'full-unicode))
(test "and ratios, since exact rationals" #t (probe-has? 'ratios))
(test "but not exact-complex" #f (probe-has? 'exact-complex))
(test "but exact-closed, since bignums" #t (probe-has? 'exact-closed))
(test "and ieee-float, since doubles" #t (probe-has? 'ieee-float))

;;  cond-expand as an expression, which chooses where it is expanded:
;;  a clause not chosen is never read as code, so it may use what is
;;  not here at all.

(test "cond-expand takes a feature it has" 'yes
      (cond-expand (raven 'yes) (else 'no)))
(test "and passes one it has not" 'no
      (cond-expand (exact-complex 'yes) (else 'no)))
(test "and the first that holds" 1
      (cond-expand (raven 1) (full-unicode 2)))
(test "and a clause of several" 3 (cond-expand (raven 1 2 3)))
(test "and" 1 (cond-expand ((and raven full-unicode) 1) (else 2)))
(test "and one that does not" 2
      (cond-expand ((and raven exact-complex) 1) (else 2)))
(test "or" 1 (cond-expand ((or exact-complex raven) 1) (else 2)))
(test "not" 1 (cond-expand ((not exact-complex) 1) (else 2)))
(test "a library that is here" 1
      (cond-expand ((library (scheme base)) 1) (else 2)))
(test "and one that is not" 2
      (cond-expand ((library (no such library)) 1) (else 2)))
(test "a clause not chosen is not read" 'fine
      (cond-expand (exact-complex (no-such-procedure 1)) (else 'fine)))

;;  And as a definition, where it stands among definitions.

(cond-expand (raven (define probe-expanded 'defined)))

(test "cond-expand around a definition" 'defined probe-expanded)

;;  Records (#154).  A record is a thing of its own: not a vector, a
;;  pair or a procedure, and only its own type's predicate knows it.

(define-record-type <point>
  (make-point x y)
  point?
  (x point-x set-point-x!)
  (y point-y))

(define a-point (make-point 1 2))

(test "a record answers its predicate" #t (point? a-point))
(test "a number does not" #f (point? 5))
(test "nor a vector of the same fields" #f (point? (vector <point> 1 2)))
(test "an accessor" 1 (point-x a-point))
(test "the other accessor" 2 (point-y a-point))
(set-point-x! a-point 10)
(test "a modifier" 10 (point-x a-point))
(test "and leaves the other field alone" 2 (point-y a-point))
(test "a record is not a vector" #f (vector? a-point))
(test "nor a pair" #f (pair? a-point))
(test "nor a procedure" #f (procedure? a-point))
(test "nor its type" #f (point? <point>))
(test "a record is itself" #t (eq? a-point a-point))
(test "and two with the same fields are two" #f
      (equal? (make-point 1 2) (make-point 1 2)))
(test "a record written" "#<<point>>"
      (let ((port (open-output-string)))
        (write (make-point 1 2) port)
        (get-output-string port)))
(test "its type written" "#<record-type <point>>"
      (let ((port (open-output-string)))
        (write <point> port)
        (get-output-string port)))

;;  A constructor may take fewer fields than there are, and in another
;;  order; a field it does not take can be set later.

(define-record-type <node>
  (make-node value)
  node?
  (next node-next set-node-next!)
  (value node-value))

(define a-node (make-node 'first))

(test "a constructor of fewer fields" 'first (node-value a-node))
(set-node-next! a-node (make-node 'second))
(test "and the field it did not take, set" 'second
      (node-value (node-next a-node)))
(test "types with fields of their own are told apart" #f (point? a-node))

(define-record-type <swapped> (swapped b a) swapped? (a swapped-a) (b swapped-b))

(test "a constructor's fields in its own order" '(2 1)
      (let ((s (swapped 1 2))) (list (swapped-a s) (swapped-b s))))

(define-record-type <nothing> (make-nothing) nothing?)

(test "a record of no fields" #t (nothing? (make-nothing)))
(test "is told from another" #f (nothing? a-point))

;;  Asking the wrong record, or giving a constructor the wrong number
;;  of fields, is an error that says which procedure it was.

(test "an accessor of the wrong record" "point-x: expected a <point>"
      (guard (e ((error-object? e) (error-object-message e)))
        (point-x a-node)))
(test "a modifier of something else" "set-point-x!: expected a <point>"
      (guard (e ((error-object? e) (error-object-message e)))
        (set-point-x! 5 1)))
(test "a constructor given too few" "make-point: expected 2 arguments"
      (guard (e ((error-object? e) (error-object-message e)))
        (make-point 1)))

;;  And a record survives a collection with its type and fields.

(define kept-point (make-point 'kept (make-point 3 4)))
(vector-churn 3000)
(test "a record survives a collection" #t (point? kept-point))
(test "with its fields" 4 (point-y (point-y kept-point)))
(test "and its type" #t (point? (point-y kept-point)))

;;  define-record-type is a definition, so it may stand in a body too.

(define (local-record-field)
  (define-record-type <local> (make-local a) local? (a local-a))
  (local-a (make-local 5)))

(test "a record type defined in a body" 5 (local-record-field))

;;  What #159 found missing of the optional arguments: the part of a
;;  string or a bytevector utf8->string, string->utf8 and write-string
;;  take between start and end.

(test "utf8->string from start" "bc" (utf8->string (bytevector 97 98 99) 1))
(test "utf8->string between" "b" (utf8->string (bytevector 97 98 99) 1 2))
(test "string->utf8 from start" (bytevector 98 99) (string->utf8 "abc" 1))
(test "string->utf8 between" (bytevector 98) (string->utf8 "abc" 1 2))
(test "write-string from start" "cd"
      (let ((p (open-output-string))) (write-string "abcd" p 2) (get-output-string p)))
(test "write-string between" "bc"
      (let ((p (open-output-string))) (write-string "abcd" p 1 3) (get-output-string p)))

;;  A number may say whether it is exact, before or after its radix.

(test "#e of a decimal is exact" 1/2 #e0.5)
(test "#i of a rational is inexact" 0.5 #i1/2)
(test "#e is exact" #t (exact? #e1.5))
(test "#i is inexact" #t (inexact? #i3))
(test "#x then #e" 255 #x#eFF)
(test "#e then #x" 255 #e#xff)
(test "and in either case" 1/4 #E0.25)
(test "string->number with #e" 1/2 (string->number "#e0.5"))
(test "string->number with #i" 3.0 (string->number "#i3"))
(test "string->number with two radixes is not a number" #f
      (string->number "#x#x1"))

;;  A string may go over more than one line, and each line ending is a
;;  newline in it.  A backslash at the end of a line, and the blanks at
;;  the start of the next, are nothing.

(test "a string over two lines" 3 (string-length "a
b"))
(test "holds the line ending" #\newline (string-ref "a
b" 1))
(test "and a line that was empty" 4 (string-length "a

b"))
(test "a string that starts at the end of a line" "
x" (string #\newline #\x))
(test "a line continuation" "ab" "a\
      b")
(test "an escape at the end of a line" 4 (string-length "x\t
y"))

;;  write writes a name between bars when it would not read back as
;;  the same symbol otherwise, and display writes it as it is.

(define (written x)
  (let ((p (open-output-string))) (write x p) (get-output-string p)))
(define (displayed x)
  (let ((p (open-output-string))) (display x p) (get-output-string p)))

(test "a plain name is written plainly" "abc" (written 'abc))
(test "a name with a space" "|a b|" (written (string->symbol "a b")))
(test "the empty name" "||" (written (string->symbol "")))
(test "a name that starts with a digit" "|1abc|" (written (string->symbol "1abc")))
(test "a name that reads as a number" "|+5|" (written (string->symbol "+5")))
(test "a dot" "|.|" (written (string->symbol ".")))
(test "a name that starts with #" "|#t|" (written (string->symbol "#t")))
(test "a bar in a name is escaped" "|a\\|b|" (written (string->symbol "a|b")))
(test "the peculiar names are plain" "(+ - ... ->x)" (written '(+ - ... ->x)))
(test "display writes the name as it is" "a b" (displayed (string->symbol "a b")))

;;  Datum labels (#167).  #n= names the datum after it, and #n# is that
;;  datum again, so a datum read in can share structure or run back into
;;  itself.

(define shared-read '(#0=(1 2) #0#))
(test "a label read twice is one object" #t
      (eq? (car shared-read) (cadr shared-read)))
(test "and is what it names" '(1 2) (car shared-read))

(define circular-read '#0=(a b . #0#))
(test "a list that runs back into itself" '(a b a b a)
      (list (car circular-read) (cadr circular-read) (caddr circular-read)
            (cadddr circular-read) (car (cddddr circular-read))))
(test "a vector that holds itself" #t
      (let ((v '#0=#(1 #0#))) (eq? v (vector-ref v 1))))
(test "labels inside labels" #t
      (let ((x '#0=(a #1=(b #0#) #1#)))
        (and (eq? (cadr (cadr x)) x) (eq? (cadr x) (caddr x)))))

(define labelled-first '#0=(x))
(test "labels are their datum's own" '(y y) '(#0=y #0#))

;;  write labels what a datum runs back into, so that writing it comes
;;  to an end, and display does the same; write-shared labels whatever
;;  it reaches more than once, numbered as they are written.

(define (written-shared x)
  (let ((p (open-output-string))) (write-shared x p) (get-output-string p)))

(test "write of a list that runs back into itself" "#0=(a b . #0#)"
      (written circular-read))
(test "display of it" "#0=(a b . #0#)" (displayed circular-read))
(test "write of a vector that holds itself" "#0=#(1 #0#)"
      (written (let ((v (vector 1 2))) (vector-set! v 1 v) v)))
(test "write of a list whose car runs back" "#0=(#0# 1)"
      (written (let ((p (list 1 1))) (set-car! p p) p)))
(test "write of what is shared but does not run back" "((1 2) (1 2))"
      (written shared-read))
(test "write-shared of it" "(#0=(1 2) #0#)" (written-shared shared-read))
(test "write-shared numbers its labels in order" "(#0=(1) #0# #1=(2) #1#)"
      (let ((a (list 1)) (b (list 2))) (written-shared (list a a b b))))
(test "write-shared of what shares nothing" "(1 (2) #(3))"
      (written-shared (list 1 (list 2) (vector 3))))

(write-string "Tests: ")
(display num-tests)
(write-string ", Passed: ")
(display passed-tests)
(write-string ", Failed: ")
(display failed-tests)
(newline)

