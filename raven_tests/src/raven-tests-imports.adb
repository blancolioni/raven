with Ada.Exceptions;
with Ada.Text_IO;

with Raven.Target;

package body Raven.Tests.Imports is

   procedure Evaluate
     (VM         : Raven_VM;
      Expression : String);

   procedure Test_Name
     (VM         : Raven_VM;
      Expression : String;
      Expected   : String);

   procedure Test_Number
     (VM         : Raven_VM;
      Expression : String;
      Expected   : Integer);

   procedure Test_Undefined
     (VM         : Raven_VM;
      Expression : String);

   --------------
   -- Evaluate --
   --------------

   procedure Evaluate
     (VM         : Raven_VM;
      Expression : String)
   is
   begin
      VM.Evaluate (Expression);
   exception
      when E : others =>
         Ada.Text_IO.Put (Expression);
         Ada.Text_IO.Set_Col (74);
         Ada.Text_IO.Put (Ada.Exceptions.Exception_Message (E));
         Ada.Text_IO.New_Line;
         raise;
   end Evaluate;

   ---------------
   -- Run_Tests --
   ---------------

   procedure Run_Tests (VM : Raven_VM) is
   begin
      --  Nothing of a library is here until it is asked for.

      Test_Undefined (VM, "alpha-name");

      Evaluate (VM, "(import (probe alpha))");

      --  What the library offers.

      Test_Name (VM, "alpha-name", "alpha");
      Test_Number (VM, "alpha-shared", 1);

      --  What it keeps.  This is the whole of the issue: before
      --  libraries, everything a file defined was everyone's.

      Test_Undefined (VM, "(alpha-helper 1)");

      --  A macro whose rules name what its own library keeps to
      --  itself still reaches it, because the macro carries the
      --  library its rules were written in.

      Test_Number (VM, "(alpha-twice 21)", 42);

      --  A second library defines a name the first one defines, and
      --  each keeps its own.  Here the most recent import is the one
      --  that answers.

      Evaluate (VM, "(import (probe beta))");
      Test_Name (VM, "beta-name", "beta");
      Test_Number (VM, "alpha-shared", 2);

      --  (probe beta) imports (probe alpha) itself, and what it read
      --  there is what it has.

      Test_Name (VM, "beta-alpha-name", "alpha");

      --  A definition here takes the name from what was imported, and
      --  leaves the libraries it came from alone.

      Evaluate (VM, "(define alpha-shared 99)");
      Test_Number (VM, "alpha-shared", 99);
      Test_Number (VM, "(alpha-twice 21)", 42);

      --  define-syntax is a macro of the base library, used here.

      Evaluate
        (VM,
         "(define-syntax probe-thrice"
         & " (syntax-rules () ((_ x) (+ x x x))))");
      Test_Number (VM, "(probe-thrice 5)", 15);

      --  A library that is not there is reported and is not fatal.

      Evaluate (VM, "(import (probe nowhere))");
      Test_Name (VM, "alpha-name", "alpha");

      --  Two libraries that ask for each other: the second to ask
      --  gets what has been read of the first so far, which is
      --  reported, and both are readable afterwards.

      Evaluate (VM, "(import (probe ring-a))");
      Test_Name (VM, "ring-a-name", "ring-a");
      Evaluate (VM, "(import (probe ring-b))");
      Test_Name (VM, "ring-b-name", "ring-b");

      --  The base library's list procedures are written on walks it
      --  keeps to itself: one for the member family and one for the
      --  assoc family, each taking the question to ask.  Those are how
      --  the exported names are written, not names a program may take.

      Test_Undefined (VM, "(member-by eq? 1 '(1))");
      Test_Undefined (VM, "(assoc-by eq? 1 '((1 . 2)))");
      Test_Undefined (VM, "(reverse-onto '(1) '())");

      --  What they are written for is exported, and answers here.

      Test_Number (VM, "(car (reverse '(1 2 3)))", 3);
      Test_Number (VM, "(cdr (assv 2 '((1 . 10) (2 . 20))))", 20);
      Test_Number (VM, "(car (memv 2 '(1 2 3)))", 2);

      --  The same holds of the arithmetic: the walk min and max share
      --  and the pieces the division names are built from are how
      --  they are written, not names a program may take.

      Test_Undefined (VM, "(extreme < '(1 2))");
      Test_Undefined (VM, "(gcd2 4 6)");
      Test_Undefined (VM, "(lcm2 4 6)");
      Test_Undefined (VM, "(floor-adjust 4 1 1)");

      --  truncate/ and floor/ each answer two values, and there are
      --  no multiple values yet, so neither is here.

      Test_Undefined (VM, "(truncate/ 13 4)");
      Test_Undefined (VM, "(floor/ 13 4)");

      --  What is here answers, and a negative number now reads.

      Test_Number (VM, "(modulo -13 4)", 3);
      Test_Number (VM, "(remainder -13 4)", -1);
      Test_Number (VM, "(max 3 1 2)", 3);
      Test_Number (VM, "(gcd 32 -36)", 4);

      --  list? walks twice over at two speeds so that it comes back
      --  from a list that runs back into itself.  The second walk is
      --  how it is written and not a name a program may take.

      Test_Undefined (VM, "(list-walk? '(1) '(1))");

      --  The primitives the machine could always do and had no name
      --  for.  Each answers here, which is also where a host's own
      --  forms are translated, so they are the library's and not
      --  something only the suite can see.

      Test_Number (VM, "(char->integer #\A)", 65);
      Test_Name (VM, "(symbol->string 'probe-name)", "probe-name");
      Test_Number (VM, "(apply + '(1 2 3))", 6);
      Test_Number (VM, "(apply + 1 2 '(3 4))", 10);
      Test_Number (VM, "(car (list-set! (list 1 2) 0 7))", 7);
      Test_Number (VM, "(if (char? #\a) 1 0)", 1);
      Test_Number (VM, "(if (exact-integer? 1) 1 0)", 1);

      --  (apply +) is refused by the translator, and there is no
      --  asserting that here: Translate reports what it raised and
      --  returns, so Execute is handed the code that was emitted
      --  before the refusal and fails on it.  Nothing of this issue
      --  can fix that, and a test of it would take the harness down.

      --  A standard library asked for by name, off the same path the
      --  base library came from.  caddr is (scheme cxr)'s: R7RS takes
      --  the base library two deep and no further, so this is what a
      --  program that wants it has to say.

      Test_Undefined (VM, "(caddr '(1 2 3))");
      Evaluate (VM, "(import (scheme cxr))");
      Test_Number (VM, "(caddr '(1 2 3))", 3);
      Test_Number (VM, "(cadddr '(1 2 3 4))", 4);
   end Run_Tests;

   ---------------
   -- Test_Name --
   ---------------

   procedure Test_Name
     (VM         : Raven_VM;
      Expression : String;
      Expected   : String)
   is
   begin
      Evaluate (VM, Expression);
      Test ("library: " & Expression, VM.Get_Slot (1), Expected);
   end Test_Name;

   -----------------
   -- Test_Number --
   -----------------

   procedure Test_Number
     (VM         : Raven_VM;
      Expression : String;
      Expected   : Integer)
   is
   begin
      Evaluate (VM, Expression);
      Test ("library: " & Expression,
            Integer'Image (VM.Get_Slot (1)),
            Integer'Image (Expected));
   end Test_Number;

   --------------------
   -- Test_Undefined --
   --------------------

   procedure Test_Undefined
     (VM         : Raven_VM;
      Expression : String)
   is
   begin
      VM.Evaluate (Expression);
      Test ("library: " & Expression & " is not here", False);
   exception
      when Raven.Target.Undefined_Symbol =>
         Test ("library: " & Expression & " is not here", True);
   end Test_Undefined;

end Raven.Tests.Imports;
