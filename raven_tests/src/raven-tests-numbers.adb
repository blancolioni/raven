with Ada.Exceptions;
with Ada.Text_IO;

package body Raven.Tests.Numbers is

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
      Test_Number (VM, "(length '(1 2 3 4 5))", 5);
      Test_Number (VM, "(length (append '(1 2 3) '(4 5 6)))", 6);
   end Run_Tests;

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
