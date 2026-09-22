with Ada.Exceptions;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

package body Raven.Tests.Macros is

   --  A macro definition holds its body, and its body is part of the
   --  form that defined it, so a definition that is never given back
   --  pins that much of the heap for the life of the VM.  These two
   --  numbers are chosen so that leaking one definition per evaluation
   --  costs more cells than the VM has: the loop below runs out of
   --  memory if a region scoped definition outlives its region.

   Repeat_Count : constant := 300;
   Body_Length  : constant := 150;

   function Local_Macro_Form return String;

   procedure Evaluate
     (VM         : Raven_VM;
      Expression : String);

   procedure Test_Macro
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

   ----------------------
   -- Local_Macro_Form --
   ----------------------

   function Local_Macro_Form return String is
      use Ada.Strings.Unbounded;
      Result : Unbounded_String;
   begin
      Append (Result, "((lambda () (define-macro (blob) ''(");
      for I in 1 .. Body_Length loop
         Append (Result, Integer'Image (I));
      end loop;
      Append (Result, ")) (car (blob))))");
      return To_String (Result);
   end Local_Macro_Form;

   ---------------
   -- Run_Tests --
   ---------------

   procedure Run_Tests (VM : Raven_VM) is
      Form      : constant String := Local_Macro_Form;
      Exhausted : Boolean := False;
   begin
      --  A region scoped definition is given back when its region
      --  closes, so translating the same body again and again costs
      --  nothing that lasts.

      for I in 1 .. Repeat_Count loop
         begin
            VM.Evaluate (Form);
         exception
            when E : others =>
               Ada.Text_IO.Put_Line
                 (Ada.Text_IO.Standard_Error,
                  "local macro form:"
                  & I'Image & ": "
                  & Ada.Exceptions.Exception_Message (E));
               Exhausted := True;
               exit;
         end;
      end loop;

      Test ("repeated local macro definitions are reclaimed",
            not Exhausted);

      if not Exhausted then
         Test ("local macro still expands after the last one",
               Integer'Image (VM.Get_Slot (1)),
               Integer'Image (1));
      end if;

      --  A second definition of the same name in the same region wins,
      --  and the first one is gone.

      Evaluate (VM,
                "(define (twice-defined)"
                & " (define-macro (m) '1)"
                & " (define-macro (m) '2)"
                & " (m))");
      Test_Macro (VM, "(twice-defined)", 2);

      --  A definition released with its region leaves its id behind for
      --  the next one, which must not disturb what came before.

      Evaluate (VM, "(define (first-host) (define-macro (m) '1) (m))");
      Evaluate (VM, "(define (second-host) (define-macro (m) '2) (m))");
      Test_Macro (VM, "(first-host)", 1);
      Test_Macro (VM, "(second-host)", 2);
   end Run_Tests;

   ----------------
   -- Test_Macro --
   ----------------

   procedure Test_Macro
     (VM         : Raven_VM;
      Expression : String;
      Expected   : Integer)
   is
   begin
      Evaluate (VM, Expression);
      Test ("evaluate: " & Expression,
            Integer'Image (VM.Get_Slot (1)),
            Integer'Image (Expected));
   end Test_Macro;

end Raven.Tests.Macros;
