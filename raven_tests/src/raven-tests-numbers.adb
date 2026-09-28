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

   --  What the answer shows as, for one that is not a fixnum.

   procedure Test_Shown
     (VM         : Raven_VM;
      Expression : String;
      Expected   : String);

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

      --  A division that does not come out exactly is the rational it
      --  comes to, where it threw the remainder away while there was
      --  nothing to say 7/2 with (#104).

      Test_Shown (VM, "(/ 7 2)", "7/2");
      Test_Shown (VM, "(/ 2)", "1/2");

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

      --  A fixnum is 29 bits and a sign.  Up to the edge it is what it
      --  was.  Past it the answer is a bignum and is exact, where it was
      --  refused (#99), and before that an assertion out of the machine
      --  with contracts on and a number with its top bits lost with them
      --  off.

      Test_Number (VM, "(+ 536870910 1)", 536_870_911);
      Test_Number (VM, "(- -536870911 1)", -536_870_912);
      Test_Number (VM, "(* 23170 23170)", 536_848_900);
      Test_Number (VM, "(- 0 536870911)", -536_870_911);

      Test_Shown (VM, "(+ 536870911 1)", "536870912");
      Test_Shown (VM, "(- -536870912 1)", "-536870913");
      Test_Shown (VM, "(* 23171 23171)", "536895241");
      Test_Shown (VM, "(- -536870912)", "536870912");

      --  A product too large for Ada's own Integer as well, and one far
      --  past anything Long_Long_Integer holds.

      Test_Shown (VM, "(* 65536 65536)", "4294967296");
      Test_Shown
        (VM, "(* 4294967296 4294967296 4294967296)",
         "79228162514264337593543950336");
      Test_Shown (VM, "(expt 2 100)", "1267650600228229401496703205376");
      Test_Shown (VM, "(- (expt 2 100))", "-1267650600228229401496703205376");

      --  The division that did not fit, and division of bignums, which
      --  truncates as a fixnum's does.

      Test_Shown (VM, "(/ -536870912 -1)", "536870912");
      Test_Number (VM, "(/ -536870912 1)", -536_870_912);
      Test_Shown
        (VM, "(/ (expt 2 100) (expt 2 98))", "4");
      Test_Shown
        (VM, "(quotient (expt 10 30) 7)", "142857142857142857142857142857");
      Test_Shown (VM, "(remainder (expt 10 30) 7)", "1");
      Test_Shown (VM, "(modulo (- (expt 10 30)) 7)", "6");

      --  And normal: an answer that fits is a fixnum again however large
      --  what it was worked out from.

      Test_Number (VM, "(- (expt 2 40) (expt 2 40))", 0);
      Test_Number (VM, "(- (+ 536870911 1) 1)", 536_870_911);
      Test_Number (VM, "(/ (expt 2 40) (expt 2 20))", 1_048_576);

      --  Literals past a fixnum read as the bignums they are, where they
      --  were refused.

      Test_Shown (VM, "536870912", "536870912");
      Test_Shown (VM, "-536870913", "-536870913");
      Test_Shown (VM, "#x20000000", "536870912");
      Test_Shown (VM, "123456789012345678901234567890",
                  "123456789012345678901234567890");
      Test_Shown (VM, "#x-ffffffffffffffffffff",
                  "-1208925819614629174706175");

      --  What arithmetic is given that it cannot take is refused by the
      --  primitive that was asked.  It was a failed precondition on
      --  Get_Slot, out of the machine.

      Test_Message (VM, "(+ 1 'a)", "+: not a number: a");
      Test_Shown (VM, "(* 1.5 2)", "3.0");

      --  Every double is an exact rational, so exact always answers:
      --  (exact 1.5) is 3/2, where it was refused while there were no
      --  exact fractions.  And a double past a double.

      Test_Shown (VM, "(exact 1.5)", "3/2");

      --  Integer division refuses what is not an integer, and every
      --  division refuses nought.

      Test_Message (VM, "(quotient 1/2 1)", "quotient: not an integer: 1/2");
      Test_Message (VM, "(/ 1/2 0)", "divide by zero");

      --  What has only a complex answer, or would be an infinity, is
      --  refused and says which.

      VM.Evaluate ("(import (scheme inexact))");
      Test_Message
        (VM, "(sqrt -4)",
         "sqrt: -4 has no real square root, and raven has no complex"
         & " numbers");
      Test_Message
        (VM, "(log 0)",
         "log: 0 has no real logarithm, and raven has no infinities");
      Test_Message
        (VM, "(log -1)",
         "log: -1 has no real logarithm, and raven has no complex numbers");
      Test_Message
        (VM, "(asin 2)",
         "asin: 2 is outside -1 .. 1, and raven has no complex numbers");
      Test_Message (VM, "(atan 0 0)", "atan: the point (0, 0) has no angle");
      Test_Message
        (VM, "(expt -8 1/3)",
         "expt: -8 to the power 1/3 is a complex number, and raven has none");
      Test_Message
        (VM, "(exp 1000)", "exp: 1000 has no answer a double holds");
      Test_Message
        (VM, "(* 1e300 1e300)",
         "inexact overflow: past what a double holds");
      Test_Message (VM, "(/ 1.5 0)", "divide by zero");
      Test_Message (VM, "(/ 1.5 0.0)", "divide by zero");
      Test_Message (VM, "(< 1 'a)", "comparison: not a number: a");
      Test_Message (VM, "(= 1 'a)", "=: not a number: a");
      Test_Message (VM, "(= 1.5 'a)", "=: not a number: a");

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
         L        : constant Number := Decode (VM, Largest);
         S        : constant Number := Decode (VM, Smallest);
         One      : constant Number :=
                      Decode (VM, Raven.Objects.To_Object (Integer'(1)));
      begin
         Test ("a number decoded and encoded is itself",
               Encode (VM, L) = Largest and then Encode (VM, S) = Smallest);
         Test ("an answer is normal",
               Encode (VM, Subtract (L, L))
                 = Raven.Objects.To_Object (Integer'(0)));
         Test ("and compares as the number it is",
               Less_Or_Equal (S, L) and then not Less_Or_Equal (L, S));
         Test ("= and eqv? are the machine's",
               Equal (L, L) and then Eqv (S, S)
                 and then not Equal (L, S) and then not Eqv (L, S));

         --  One past a fixnum is a bignum, a block in the heap, and one
         --  back from it is the fixnum it was, the same word as before:
         --  normal both ways.  And two bignums that are the same number
         --  are two objects, which is what = and eqv? were made the
         --  machine's for (#101).

         declare
            Past  : constant Number := Add (L, One);
            Big   : constant Object := Encode (VM, Past);
            Again : constant Object := Encode (VM, Past);
         begin
            Test ("one past a fixnum is a bignum",
                  Raven.Objects.Is_Bignum (Big));
            Test ("and decodes as the number it is",
                  Equal (Decode (VM, Big), Past)
                    and then Image (Decode (VM, Big)) = "536870912");
            Test ("and one back from it is the fixnum it was",
                  Encode (VM, Subtract (Decode (VM, Big), One)) = Largest);
            Test ("two equal bignums are two objects",
                  Big /= Again
                    and then Equal (Decode (VM, Big), Decode (VM, Again))
                    and then Eqv (Decode (VM, Big), Decode (VM, Again)));
         end;
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

   ----------------
   -- Test_Shown --
   ----------------

   procedure Test_Shown
     (VM         : Raven_VM;
      Expression : String;
      Expected   : String)
   is
   begin
      VM.Evaluate (Expression);
      Test ("evaluate: " & Expression, Expected, VM.Show_Slot (1));
   exception
      when E : others =>
         Ada.Text_IO.Put (Expression);
         Ada.Text_IO.Set_Col (74);
         Ada.Text_IO.Put (Ada.Exceptions.Exception_Message (E));
         Ada.Text_IO.New_Line;
         Test ("evaluate: " & Expression, False);
   end Test_Shown;

end Raven.Tests.Numbers;
