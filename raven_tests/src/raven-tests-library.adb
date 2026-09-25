package body Raven.Tests.Library is

   procedure Test_Error
     (VM         : Raven_VM;
      Expression : String);

   procedure Test_Library
     (VM         : Raven_VM;
      Expression : String;
      Expected   : Boolean);

   procedure Test_Value
     (VM         : Raven_VM;
      Expression : String;
      Expected   : Integer);

   procedure Probe_False (VM : Raven_VM);

   procedure Probe_True (VM : Raven_VM);

   ---------------
   -- Run_Tests --
   ---------------

   procedure Run_Tests (VM : Raven_VM) is
   begin
      Test_Library (VM, "(not #f)", True);
      Test_Library (VM, "(not #t)", False);
      Test_Library (VM, "(and #f #f)", False);
      Test_Library (VM, "(and #t #f)", False);
      Test_Library (VM, "(and #f #t)", False);
      Test_Library (VM, "(and #t #t)", True);
      Test_Library (VM, "(or #f #f)", False);
      Test_Library (VM, "(or #f #t)", True);
      Test_Library (VM, "(or #t #f)", True);
      Test_Library (VM, "(or #t #t)", True);

      --  car refused something that was not a pair and cdr did not,
      --  so a cdr of one was an assertion failure out of the machine
      --  with contracts on and an arbitrary cell with them off.  Both
      --  say what happened now.

      Test_Error (VM, "(car 5)");
      Test_Error (VM, "(cdr 5)");
      Test_Error (VM, "(car '())");
      Test_Error (VM, "(cdr '())");
      Test_Error (VM, "(car 'a)");
      Test_Error (VM, "(cdr 'a)");
      Test_Error (VM, "(car #\a)");
      Test_Error (VM, "(cdr #\a)");

      --  And a pair still comes apart.

      Test_Value (VM, "(car '(1 2))", 1);
      Test_Value (VM, "(car (cdr '(1 2)))", 2);
      Test_Value (VM, "(car (cdr (cons 1 (cons 2 '()))))", 2);

      --  Which is the point of it: every list procedure walks with
      --  cdr, so this is the check that decides whether a program that
      --  runs off the end of a list is told.

      Test_Error (VM, "(length 5)");
      Test_Error (VM, "(list-tail '(1 2) 5)");
      Test_Error (VM, "(list-ref '(1 2) 5)");
      Test_Error (VM, "(map car 5)");

      --  A walk that stops where it should is unaffected.

      Test_Value (VM, "(length '(1 2 3))", 3);
      Test_Value (VM, "(list-ref '(1 2 3) 2)", 3);

      --  A closure is not a pair any more, so the two that take a pair
      --  apart refuse one.  That was the whole of #52: car handed back
      --  a procedure's code, and a pair whose car happened to be a
      --  code list could then be called.

      Test_Error (VM, "(car (lambda (x) x))");
      Test_Error (VM, "(cdr (lambda (x) x))");
      Test_Error (VM, "(car car)");
      Test_Error (VM, "(length (lambda (x) x))");

      --  So the forgery in the issue cannot be built at all: it began
      --  by taking the car of a procedure.

      Test_Error (VM, "(cons (car (lambda (x) x)) '())");

      --  Nor written to, which is what set-car! would have allowed
      --  once it existed -- a program changing another procedure's
      --  code or what it had captured.

      Test_Error (VM, "(set-car! (lambda (x) x) 1)");
      Test_Error (VM, "(set-cdr! (lambda (x) x) 1)");

      --  And a list is not callable, which is the same check from the
      --  other side.  AP asked whether it had a pair, which every
      --  list is.

      Test_Error (VM, "((list 1 2) 3)");
      Test_Error (VM, "('(1 2) 3)");

      --  What is callable still is.

      Test_Value (VM, "((lambda (x) x) 7)", 7);
      Test_Value (VM, "((lambda (x) (+ x 1)) 41)", 42);
      Test_Value (VM, "(car '(1 2))", 1);

      --  An index has to be one the vector has.  Reading past the end
      --  would read the cell after it, which belongs to whatever was
      --  made next.

      Test_Error (VM, "(vector-ref (vector 1 2) 2)");
      Test_Error (VM, "(vector-ref (vector 1 2) 5)");
      Test_Error (VM, "(vector-ref (vector) 0)");
      Test_Error (VM, "(vector-set! (vector 1 2) 2 'x)");
      Test_Error (VM, "(vector-ref '(1 2) 0)");
      Test_Error (VM, "(vector-length '(1 2))");
      Test_Error (VM, "(make-vector -1 'x)");

      --  And a vector is not a pair, so the two that take a pair
      --  apart refuse one.

      Test_Error (VM, "(car (vector 1 2))");
      Test_Error (VM, "(cdr (vector 1 2))");

      --  What is within it answers.

      Test_Value (VM, "(vector-ref (vector 7 8) 0)", 7);
      Test_Value (VM, "(vector-ref (vector 7 8) 1)", 8);
      Test_Value (VM, "(vector-length (make-vector 5 0))", 5);

      --  Only a byte goes into a bytevector, which is what tells one
      --  from a vector laid out the same way.

      Test_Error (VM, "(bytevector-u8-set! (make-bytevector 1 0) 0 256)");
      Test_Error (VM, "(bytevector-u8-set! (make-bytevector 1 0) 0 -1)");
      Test_Error (VM, "(make-bytevector 1 256)");
      Test_Error (VM, "(make-bytevector -1 0)");
      Test_Error (VM, "(bytevector-u8-ref (make-bytevector 2 0) 2)");
      Test_Error (VM, "(bytevector-u8-ref (vector 1 2) 0)");
      Test_Error (VM, "(bytevector-length (vector 1 2))");
      Test_Error (VM, "(utf8->string (vector 1 2))");
      Test_Error (VM, "(string->utf8 (vector 1 2))");

      --  And the byte at either end of the range goes in.

      Test_Value (VM, "(bytevector-u8-ref (make-bytevector 1 255) 0)", 255);
      Test_Value (VM, "(bytevector-u8-ref (make-bytevector 1 0) 0)", 0);

      --  A port is read from or written to and not both, and what is
      --  not a port is not one.

      Test_Error (VM, "(read-char (open-output-string))");
      Test_Error (VM, "(peek-char (open-output-string))");
      Test_Error (VM, "(write-char #\a (open-input-string ""x""))");
      Test_Error (VM, "(read-char 4)");
      Test_Error (VM, "(write-char #\a 4)");
      Test_Error (VM, "(close-port 4)");
      Test_Error (VM, "(char-ready? ""x"")");
      Test_Error (VM, "(char-ready? (open-output-string))");
      Test_Error (VM, "(open-input-string 4)");
      Test_Error (VM, "(get-output-string 4)");

      --  get-output-string is for a port opened on a string it is
      --  building up, and no other kind answers for one.

      Test_Error (VM, "(get-output-string (open-input-string ""x""))");
      Test_Error (VM, "(get-output-string (current-output-port))");

      --  A closed port is not written to or read from, though what it
      --  holds can still be asked for.

      Test_Error
        (VM,
         "(write-char #\a (let ((p (open-output-string)))"
         & " (close-port p) p))");
      Test_Error
        (VM,
         "(read-char (let ((p (open-input-string ""x"")))"
         & " (close-port p) p))");
      Test_Error
        (VM,
         "(peek-char (let ((p (open-input-string ""x"")))"
         & " (close-port p) p))");
      Test_Value
        (VM,
         "(string-length (let ((p (open-output-string)))"
         & " (write-char #\a p) (close-port p) (get-output-string p)))",
         1);

      --  A binary port answers for none of the textual operations and
      --  a textual one for none of the binary.  R7RS lets a port be
      --  both; none here is, and the host's three are textual.

      Test_Error (VM, "(read-u8 (open-input-string ""x""))");
      Test_Error (VM, "(peek-u8 (open-input-string ""x""))");
      Test_Error (VM, "(u8-ready? (open-input-string ""x""))");
      Test_Error (VM, "(write-u8 1 (open-output-string))");
      Test_Error (VM, "(read-char (open-input-bytevector '#u8(1)))");
      Test_Error (VM, "(peek-char (open-input-bytevector '#u8(1)))");
      Test_Error (VM, "(char-ready? (open-input-bytevector '#u8(1)))");
      Test_Error (VM, "(write-char #\a (open-output-bytevector))");
      Test_Error (VM, "(read-u8 (current-input-port))");
      Test_Error (VM, "(write-u8 1 (current-output-port))");

      --  And a binary port is read from or written to and not both.

      Test_Error (VM, "(read-u8 (open-output-bytevector))");
      Test_Error (VM, "(peek-u8 (open-output-bytevector))");
      Test_Error (VM, "(write-u8 1 (open-input-bytevector '#u8(1)))");
      Test_Error (VM, "(read-u8 4)");
      Test_Error (VM, "(write-u8 1 4)");

      --  Only a byte goes into one, which is what tells it from a
      --  textual port the way it tells a bytevector from a vector.

      Test_Error (VM, "(write-u8 256 (open-output-bytevector))");
      Test_Error (VM, "(write-u8 -1 (open-output-bytevector))");

      Test_Value
        (VM,
         "(bytevector-u8-ref (let ((p (open-output-bytevector)))"
         & " (write-u8 255 p) (get-output-bytevector p)) 0)",
         255);
      Test_Value
        (VM,
         "(bytevector-u8-ref (let ((p (open-output-bytevector)))"
         & " (write-u8 0 p) (get-output-bytevector p)) 0)",
         0);

      --  Each of the two answers for what it was opened on and not
      --  for the other.

      Test_Error (VM, "(get-output-bytevector (open-output-string))");
      Test_Error (VM, "(get-output-string (open-output-bytevector))");
      Test_Error
        (VM, "(get-output-bytevector (open-input-bytevector '#u8()))");
      Test_Error (VM, "(get-output-bytevector 4)");
      Test_Error (VM, "(open-input-bytevector ""x"")");
      Test_Error (VM, "(open-input-bytevector (vector 1 2))");
      Test_Error (VM, "(open-input-bytevector 4)");

      --  A closed binary port is not written to or read from either.

      Test_Error
        (VM,
         "(write-u8 1 (let ((p (open-output-bytevector)))"
         & " (close-port p) p))");
      Test_Error
        (VM,
         "(read-u8 (let ((p (open-input-bytevector '#u8(1))))"
         & " (close-port p) p))");

      --  The library asks for the host's three by number.  Nothing
      --  else should ask at all, and asking for any other number used
      --  to hand out a port on a place in the table no one had opened.

      Test_Error (VM, "(raven-standard-port 0)");
      Test_Error (VM, "(raven-standard-port 4)");
      Test_Error (VM, "(raven-standard-port 900)");

      --  A foreign function can be bound again under the same name,
      --  and the new handler is the one that runs.

      VM.Bind_Foreign_Function ("probe-answer", Probe_False'Access, 0);
      Test_Library (VM, "(probe-answer)", False);
      VM.Bind_Foreign_Function ("probe-answer", Probe_True'Access, 0);
      Test_Library (VM, "(probe-answer)", True);
   end Run_Tests;

   -----------------
   -- Probe_False --
   -----------------

   procedure Probe_False (VM : Raven_VM) is
   begin
      VM.Set_Slot (1, False);
   end Probe_False;

   ----------------
   -- Probe_True --
   ----------------

   procedure Probe_True (VM : Raven_VM) is
   begin
      VM.Set_Slot (1, True);
   end Probe_True;

   ----------------
   -- Test_Error --
   ----------------

   procedure Test_Error
     (VM         : Raven_VM;
      Expression : String)
   is
   begin
      VM.Evaluate (Expression);
      Test (Expression & " is an error", False);
   exception
      when Constraint_Error =>
         Test (Expression & " is an error", True);
   end Test_Error;

   ------------------
   -- Test_Library --
   ------------------

   procedure Test_Library
     (VM         : Raven_VM;
      Expression : String;
      Expected   : Boolean)
   is
   begin
      VM.Evaluate (Expression);
      Test (Expression, VM.Get_Slot (1) = Expected);
   end Test_Library;

   ----------------
   -- Test_Value --
   ----------------

   procedure Test_Value
     (VM         : Raven_VM;
      Expression : String;
      Expected   : Integer)
   is
   begin
      VM.Evaluate (Expression);
      Test (Expression,
            Integer'Image (VM.Get_Slot (1)),
            Integer'Image (Expected));
   end Test_Value;

end Raven.Tests.Library;
