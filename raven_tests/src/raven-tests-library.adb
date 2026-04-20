package body Raven.Tests.Library is

   procedure Test_Library
     (VM         : Raven_VM;
      Expression : String;
      Expected   : Boolean);

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
   end Run_Tests;

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

end Raven.Tests.Library;
