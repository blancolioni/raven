(define (eq? x y) (raven-eq? x y))
(define (null? x) (eq? x '()))

(define-macro (when test . body)
  `(if ,test (begin ,@body) #f))

(define-macro (unless test . body)
  `(if ,test #f (begin ,@body)))

(define-macro (and . args)
  (if (null? args)
      #t
      (if (null? (cdr args))
          (car args)
          `(if ,(car args) (and ,@(cdr args)) #f))))

(define-macro (or . args)
  (if (null? args)
      #f
      (if (null? (cdr args))
          (car args)
          `(if ,(car args) ,(car args) (or ,@(cdr args))))))

(define (boolean? x) (or (eq? x #t) (eq? x #f)))

(define (list . xs) xs)
(define (xcons xs x) (cons x xs))

(define (append2 xs ys) (if (null? xs) ys (cons (car xs) (append (cdr xs) ys))))
(define (concatenate xxs) (if (null? xxs) '()
			      (append2 (car xxs) (concatenate (cdr xxs)))))
(define (append . xxs) (concatenate xxs))

(define (length xs) (if (null? xs) 0 (+ 1 (length (cdr xs)))))
(define (make-list n e) (if (= n 0) '() (cons e (make-list (- n 1) e))))

(define (not x) (if x #f #t))
(define (xor x y) (if x (not y) y))

(define (fold f k xs) (if (null? xs) k (f (car xs) (fold f k (cdr xs)))))

(define (all-left-assoc op z xs)
  (if (null? xs) z
      (if (null? (cdr xs)) z
	  (if (op (car xs) (car (cdr xs)))
	      (all-left-assoc op z (cdr xs))
	      #f))))

(define (= . xs) (all-left-assoc eq? #t xs))


(define (+ . xs) (fold raven-add 0 xs))
(define (* . xs) (fold raven-mul 0 xs))

(define (- . xs) (apply-subtract xs))
(define (apply-subtract xs) (if (null? xs) 0
				(if (null? (cdr xs)) (raven-sub 0 (car xs))
				    (raven-sub (car xs) (fold raven-add 0 (cdr xs))))))

(define (/ . xs) (apply-divide xs))
(define (apply-divide xs) (if (null? xs) 1
			      (if (null? (cdr xs)) (raven-div 1 (car xs))
				  (raven-div (car xs) (fold raven-mul 1 (cdr xs))))))

(define (optional value default) (if (eq? value '()) default value))

(define string-length raven-string-length)

(define list->string raven-list->string)

(define (string->list string start end)
   (raven-string->list string (optional start 0) (optional end (string-length string))))

(define (string-append . strings)
   (list->string (concatenate (map string->list strings))))

(define (map f xs) (if (null? xs) '() (cons (f (car xs)) (map f (cdr xs)))))

(define (write x) (write-string (display x)))

(define (write-char ch) (raven-write-char ch))

(define (write-char-list chars) (if (null? chars) '() (begin (write-char (car chars)) (write-char-list (cdr chars)))))

(define (write-string string) (write-char-list (string->list string)))

(define (newline) (write-char #\newline))

(define (sum-list xs) (if (null? xs) 0 (+ (car xs) (sum-list (cdr xs)))))
(define sum (lambda xs (sum-list xs)))
