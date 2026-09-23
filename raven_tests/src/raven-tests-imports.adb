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
