with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Text_IO;

with Raven.Numbers;
with Raven.Objects;

package body Raven.Tests.Numbers is

   procedure Test_Error
     (VM         : Raven_VM;
      Expression : String);

   procedure Test_Message
     (VM         : Raven_VM;
      Expression : String;
      Expected   : String);

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

      --  - and / want an argument, where they used to answer 0 and 1 --
      --  which are the identities of adding and multiplying and not of
      --  anything these two do.

      Test_Error (VM, "(-)");
      Test_Error (VM, "(/)");

      --  = asks about numbers.  It used to be identity, so it answered
      --  for anything at all and (= 'a 'a) was #t.

      Test_Error (VM, "(= 'a 'a)");
      Test_Error (VM, "(= 1 'a)");
      Test_Error (VM, "(= '(1) '(1))");
      Test_Error (VM, "(= ""a"" ""a"")");

      --  map and for-each want a list to walk.

      Test_Error (VM, "(map car)");
      Test_Error (VM, "(for-each car)");

      Test_Number (VM, "(length '(1 2 3 4 5))", 5);
      Test_Number (VM, "(length (append '(1 2 3) '(4 5 6)))", 6);

      --  An integer is 29 bits and a sign.  Up to the edge is fine,
      --  and past it is refused and says so, where it used to be an
      --  assertion out of the machine with contracts on and a number
      --  with its top bits lost with them off.

      Test_Number (VM, "(+ 536870910 1)", 536_870_911);
      Test_Number (VM, "(- -536870911 1)", -536_870_912);
      Test_Number (VM, "(* 23170 23170)", 536_848_900);
      Test_Number (VM, "(- 0 536870911)", -536_870_911);

      Test_Error (VM, "(+ 536870911 1)");
      Test_Error (VM, "(- -536870912 1)");
      Test_Error (VM, "(* 23171 23171)");
      Test_Error (VM, "(- -536870912)");

      --  A product too large for Ada's own Integer as well, which is
      --  the case where computing it narrow was not even a wrong
      --  answer but an overflow in the arithmetic.

      Test_Error (VM, "(* 65536 65536)");

      --  And the one division that overflows.

      Test_Error (VM, "(/ -536870912 -1)");
      Test_Number (VM, "(/ -536870912 1)", -536_870_912);

      Test_Message
        (VM, "(+ 536870911 1)",
         "integer overflow: 536870911 + 1 is past the largest integer"
         & " raven holds, 536870911");
      Test_Message
        (VM, "(* -536870912 2)",
         "integer overflow: -536870912 * 2 is past the smallest integer"
         & " raven holds, -536870912");

      --  What arithmetic is given that it cannot take is refused by the
      --  primitive that was asked, and a float is said to be a number,
      --  which it is, that there is no arithmetic on yet.  Both were a
      --  failed precondition on Get_Slot, out of the machine.

      Test_Message (VM, "(+ 1 'a)", "+: not a number: a");
      Test_Message
        (VM, "(* 1.5 2)", "*: raven has no arithmetic on floats yet: 1.5");
      Test_Message (VM, "(< 1 'a)", "comparison: not a number: a");

      --  And Raven.Numbers itself, which every primitive now goes
      --  through: what goes in comes out, at both ends, and an answer is
      --  normal -- a zero arrived at by subtraction is the fixnum zero,
      --  the same word as the zero read from the source.

      declare
         use Raven.Numbers;

         Largest  : constant Object :=
                      Raven.Objects.To_Object
                        (Integer'(Raven.Objects.Max_Integer));
         Smallest : constant Object :=
                      Raven.Objects.To_Object
                        (Integer'(Raven.Objects.Min_Integer));
      begin
         Test ("a number decoded and encoded is itself",
               Encode (Decode (Largest)) = Largest
                 and then Encode (Decode (Smallest)) = Smallest);
         Test ("an answer is normal",
               Encode (Subtract (Decode (Largest), Decode (Largest)))
                 = Raven.Objects.To_Object (Integer'(0)));
         Test ("and compares as the number it is",
               Less_Or_Equal (Decode (Smallest), Decode (Largest))
                 and then not Less_Or_Equal
                                (Decode (Largest), Decode (Smallest)));
      end;
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

   ------------------
   -- Test_Message --
   ------------------

   procedure Test_Message
     (VM         : Raven_VM;
      Expression : String;
      Expected   : String)
   is
   begin
      VM.Evaluate (Expression);
      Test ("evaluate: " & Expression & " says " & Expected, False);
   exception
      when E : Constraint_Error =>
         Test ("evaluate: " & Expression & " says so",
               Ada.Strings.Fixed.Index
                 (Ada.Exceptions.Exception_Message (E), Expected) > 0);
   end Test_Message;

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
