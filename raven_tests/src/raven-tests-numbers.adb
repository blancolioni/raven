with Ada.Exceptions;
with Ada.Text_IO;

package body Raven.Tests.Numbers is

   procedure Test_Error
     (VM         : Raven_VM;
      Expression : String);

   procedure Test_Number
     (VM         : Raven_VM;
      Expression : String;
      Expected   : Integer);

   ---------------
   -- Run_Tests --
   ---------------

   procedure Run_Tests (VM : Raven_VM) is
   begin
      Test_Number (VM, "123", 123);
      Test_Number (VM, "(+)", 0);
      Test_Number (VM, "(+ 1)", 1);
      Test_Number (VM, "(+ 1 2)", 3);
      Test_Number (VM, "(+ 1 2 3 4)", 10);

      --  The identity of a product is 1, as the identity of a sum is
      --  0.  This folded with 0, so it answered 0 for everything.

      Test_Number (VM, "(*)", 1);
      Test_Number (VM, "(* 3)", 3);
      Test_Number (VM, "(* 2 3)", 6);
      Test_Number (VM, "(* 2 3 4)", 24);

      Test_Number (VM, "(/ 6 2)", 3);
      Test_Number (VM, "(/ 24 2 3)", 4);

      --  Every number here is an integer, so a division that does not
      --  come out exactly throws the remainder away.  R7RS asks for
      --  7/2 and there is nothing to say it with, so this is written
      --  down as what happens rather than left to be found.

      Test_Number (VM, "(/ 7 2)", 3);
      Test_Number (VM, "(/ 2)", 0);

      Test_Error (VM, "(/ 1 0)");

      Test_Number (VM, "(length '(1 2 3 4 5))", 5);
      Test_Number (VM, "(length (append '(1 2 3) '(4 5 6)))", 6);
   end Run_Tests;

   ----------------
   -- Test_Error --
   ----------------

   procedure Test_Error
     (VM         : Raven_VM;
      Expression : String)
   is
   begin
      VM.Evaluate (Expression);
      Test ("evaluate: " & Expression & " is an error", False);
   exception
      when Constraint_Error =>
         Test ("evaluate: " & Expression & " is an error", True);
   end Test_Error;

   -----------------
   -- Test_Number --
   -----------------

   procedure Test_Number
     (VM         : Raven_VM;
      Expression : String;
      Expected   : Integer)
   is
   begin
      VM.Evaluate (Expression);
      Test ("evaluate: " & Expression,
            Integer'Image (VM.Get_Slot (1)),
            Integer'Image (Expected));
   exception
      when E : others =>
         Ada.Text_IO.Put (Expression);
         Ada.Text_IO.Set_Col (74);
         Ada.Text_IO.Put (Ada.Exceptions.Exception_Message (E));
         Ada.Text_IO.New_Line;
         raise;
   end Test_Number;

end Raven.Tests.Numbers;
