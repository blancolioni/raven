with Ada.Exceptions;
with Ada.Text_IO;

package body Raven.Tests.Define is

   procedure Evaluate
     (VM         : Raven_VM;
      Expression : String);

   procedure Test_Define
     (VM         : Raven_VM;
      Expression : String;
      Expected   : Integer);

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
      --  A procedure body is an implicit begin: every form is compiled,
      --  and the value of the last one is returned.

      Evaluate (VM, "(define (three-forms) 1 2 3)");
      Test_Define (VM, "(three-forms)", 3);

      --  Leading body forms must actually run, not just the last one.

      Evaluate (VM, "(define counter 0)");
      Evaluate (VM,
                "(define (bump)"
                & " (set! counter (+ counter 1))"
                & " (set! counter (+ counter 10))"
                & " counter)");
      Test_Define (VM, "(bump)", 11);
      Test_Define (VM, "counter", 11);

      --  Every intermediate form runs, not only the first and the last.

      Evaluate (VM, "(define total 0)");
      Evaluate (VM,
                "(define (add-four)"
                & " (set! total (+ total 1))"
                & " (set! total (+ total 2))"
                & " (set! total (+ total 4))"
                & " (set! total (+ total 8))"
                & " total)");
      Test_Define (VM, "(add-four)", 15);

      --  Body forms see the procedure's parameters.

      Evaluate (VM, "(define accumulator 0)");
      Evaluate (VM,
                "(define (accumulate x y)"
                & " (set! accumulator (+ accumulator x))"
                & " (set! accumulator (+ accumulator y))"
                & " accumulator)");
      Test_Define (VM, "(accumulate 3 4)", 7);
      Test_Define (VM, "(accumulate 10 20)", 37);

      --  A multi-form body behaves the same as the equivalent lambda,
      --  which already compiles its body as a sequence.

      Evaluate (VM, "(define lambda-counter 0)");
      Evaluate (VM,
                "(define lambda-bump"
                & " (lambda ()"
                & " (set! lambda-counter (+ lambda-counter 1))"
                & " (set! lambda-counter (+ lambda-counter 10))"
                & " lambda-counter))");
      Test_Define (VM, "(lambda-bump)", 11);

      --  A single form body still works.

      Evaluate (VM, "(define (one-form x) (+ x 1))");
      Test_Define (VM, "(one-form 41)", 42);

      --  Recursion still works with a multi-form body.

      Evaluate (VM, "(define call-count 0)");
      Evaluate (VM,
                "(define (count-down n)"
                & " (set! call-count (+ call-count 1))"
                & " (if (eq? n 0) call-count (count-down (- n 1))))");
      Test_Define (VM, "(count-down 4)", 5);

      --  A name can be defined again, and the second definition wins.
      --  A definition is not a promise that the name is new.

      Evaluate (VM, "(define probe-name 1)");
      Test_Define (VM, "probe-name", 1);
      Evaluate (VM, "(define probe-name 2)");
      Test_Define (VM, "probe-name", 2);

      Evaluate (VM, "(define (probe-f) 1)");
      Test_Define (VM, "(probe-f)", 1);
      Evaluate (VM, "(define (probe-f) 2)");
      Test_Define (VM, "(probe-f)", 2);

      --  set! on a name the machine holds on the stack, rather than
      --  one a library holds.  The operand of ST is the same pair the
      --  operand of LD is, so both reach what they were given.

      Evaluate (VM, "(define (probe-set-arg x) (set! x 99) x)");
      Test_Define (VM, "(probe-set-arg 1)", 99);

      Evaluate (VM,
                "(define (probe-set-inner y)"
                & " ((lambda (z) (set! z (+ z y)) z) 10))");
      Test_Define (VM, "(probe-set-inner 5)", 15);

      --  A definition takes the name here and leaves the library it
      --  came from alone, so loading that library again does not put
      --  its own back: what the host defines, the host keeps.  Before
      --  libraries there was one name to take, and the second load was
      --  what took it back.

      Evaluate (VM, "(define (xcons xs x) 99)");
      Test_Define (VM, "(xcons '(2 3) 1)", 99);
      VM.Import_Library
        ("(scheme base)",
         Library_Path & "/scheme/base.scm");
      Test_Define (VM, "(xcons '(2 3) 1)", 99);

      --  The library itself still has its own, and loading it a second
      --  time did not fall over its own definitions.

      Test_Define (VM, "(length '(1 2 3))", 3);
   end Run_Tests;

   -----------------
   -- Test_Define --
   -----------------

   procedure Test_Define
     (VM         : Raven_VM;
      Expression : String;
      Expected   : Integer)
   is
   begin
      Evaluate (VM, Expression);
      Test ("evaluate: " & Expression,
            Integer'Image (VM.Get_Slot (1)),
            Integer'Image (Expected));
   end Test_Define;

end Raven.Tests.Define;
