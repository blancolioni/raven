with Raven.Instructions;
with Raven.Objects;

package body Raven.Tests.Objects is

   ---------------
   -- Run_Tests --
   ---------------

   procedure Run_Tests is
   begin
      Test ("nil is not truthy",
            not Raven.Objects.Is_Truthy (Raven.Objects.Nil));
      Test ("false is not truthy",
            not Raven.Objects.Is_Truthy (Raven.Objects.To_Object (False)));
      Test ("true is truthy",
            Raven.Objects.Is_Truthy (Raven.Objects.To_Object (True)));

      Test ("positive integer values are preserved",
            Raven.Objects.To_Integer
              (Raven.Objects.To_Object (Integer'(42)))
            = 42);
      Test ("floating point values are preserved",
            Raven.Objects.To_Float
              (Raven.Objects.To_Object (Float'(12.75)))
            = 12.75);
      Test ("negative integer values are preserved",
            Raven.Objects.To_Integer
              (Raven.Objects.To_Object (Integer'(-42)))
            = -42);
      Test ("integer zero is preserved",
            Raven.Objects.To_Integer
              (Raven.Objects.To_Object (Integer'(0)))
            = 0);
      --  Two bits of tag leave thirty of payload, so an exact integer
      --  is four times the range it was.  The old ceiling is kept
      --  below it as a number that used to be the end of the road.

      Test ("max integer is preserved",
            Raven.Objects.To_Integer
              (Raven.Objects.To_Object (Integer'(536870911)))
            = 536870911);
      Test ("min integer is preserved",
            Raven.Objects.To_Integer
              (Raven.Objects.To_Object (Integer'(-536870912)))
            = -536870912);
      Test ("what used to be the max integer is now ordinary",
            Raven.Objects.To_Integer
              (Raven.Objects.To_Object (Integer'(134217728)))
            = 134217728);
      Test ("and so is what used to be under the min",
            Raven.Objects.To_Integer
              (Raven.Objects.To_Object (Integer'(-134217729)))
            = -134217729);

      --  A float keeps every mantissa bit of a single now, so the
      --  round trip is exact rather than exact for the values whose
      --  last four bits happened to be zero.  0.1 is the one that
      --  could not be read at all.

      Test ("a float with bits at the bottom is preserved",
            Raven.Objects.To_Float
              (Raven.Objects.To_Object (Float'(0.1)))
            = 0.1);
      Test ("a negative float is preserved",
            Raven.Objects.To_Float
              (Raven.Objects.To_Object (Float'(-0.1)))
            = -0.1);
      Test ("one is preserved",
            Raven.Objects.To_Float
              (Raven.Objects.To_Object (Float'(1.0)))
            = 1.0);
      Test ("zero is preserved",
            Raven.Objects.To_Float
              (Raven.Objects.To_Object (Float'(0.0)))
            = 0.0);
      Test ("a float is not an integer",
            not Raven.Objects.Is_Integer
              (Raven.Objects.To_Object (Float'(0.1))));
      Test ("an integer is not a float",
            not Raven.Objects.Is_Float
              (Raven.Objects.To_Object (Integer'(1))));

      --  What it cannot hold is a number out of range rather than one
      --  too precise, and it says which before it is asked to.

      Test ("a float in range is representable",
            Raven.Objects.Is_Representable (0.1));
      Test ("zero is representable",
            Raven.Objects.Is_Representable (0.0));
      Test ("a float near the top of the range is representable",
            Raven.Objects.Is_Representable (1.0e9));
      Test ("a float near the bottom of the range is representable",
            Raven.Objects.Is_Representable (1.0e-9));
      Test ("a float too large is not representable",
            not Raven.Objects.Is_Representable (1.0e20));
      Test ("a float too small is not representable",
            not Raven.Objects.Is_Representable (1.0e-20));
      Test ("the largest single is not representable",
            not Raven.Objects.Is_Representable (Float'Last));

      --  Integer is tag 0 and float is tag 1, so one mask answers for
      --  both and nothing else answers to it.

      Test ("an integer is a number",
            Raven.Objects.Is_Number (Raven.Objects.To_Object (Integer'(1))));
      Test ("a float is a number",
            Raven.Objects.Is_Number (Raven.Objects.To_Object (Float'(0.1))));
      Test ("a negative integer is a number",
            Raven.Objects.Is_Number (Raven.Objects.To_Object (Integer'(-1))));
      Test ("nil is not a number",
            not Raven.Objects.Is_Number (Raven.Objects.Nil));
      Test ("a character is not a number",
            not Raven.Objects.Is_Number (Raven.Objects.To_Object ('a')));
      Test ("a boolean is not a number",
            not Raven.Objects.Is_Number (Raven.Objects.To_Object (True)));
      Test ("a pair is not a number",
            not Raven.Objects.Is_Number (Raven.Objects.To_Pair (1)));

      --  Every extended type shares the escape in the primary tag, so
      --  telling two of them apart takes all eight bits.  equal? is
      --  what this is for: it asks whether two things are the same
      --  kind before it asks anything else, and if a string and a
      --  character came back the same kind it would read the
      --  character as a foreign value id.

      Test ("a symbol and a character are not the same kind",
            not Raven.Objects.Tag_Equal
              (Raven.Objects.To_Object (Raven.Objects.Symbol_Id'(1)),
               Raven.Objects.To_Object ('a')));
      Test ("a character and an instruction are not the same kind",
            not Raven.Objects.Tag_Equal
              (Raven.Objects.To_Object ('a'),
               Raven.Objects.To_Object (Raven.Instructions.AP)));
      Test ("nil and a symbol are not the same kind",
            not Raven.Objects.Tag_Equal
              (Raven.Objects.Nil,
               Raven.Objects.To_Object (Raven.Objects.Symbol_Id'(1))));
      Test ("two symbols are the same kind",
            Raven.Objects.Tag_Equal
              (Raven.Objects.To_Object (Raven.Objects.Symbol_Id'(1)),
               Raven.Objects.To_Object (Raven.Objects.Symbol_Id'(2))));
      Test ("two integers are the same kind",
            Raven.Objects.Tag_Equal
              (Raven.Objects.To_Object (Integer'(1)),
               Raven.Objects.To_Object (Integer'(2))));
      Test ("an integer and a float are not the same kind",
            not Raven.Objects.Tag_Equal
              (Raven.Objects.To_Object (Integer'(1)),
               Raven.Objects.To_Object (Float'(1.0))));
      Test ("an integer and a symbol are not the same kind",
            not Raven.Objects.Tag_Equal
              (Raven.Objects.To_Object (Integer'(1)),
               Raven.Objects.To_Object (Raven.Objects.Symbol_Id'(1))));

      --  And the round trips of the types that moved behind the
      --  escape, which have twenty four bits of payload now.

      Test ("a symbol id is preserved",
            Raven.Objects."="
              (Raven.Objects.To_Symbol
                 (Raven.Objects.To_Object (Raven.Objects.Symbol_Id'(12345))),
               12345));
      Test ("the largest symbol id is preserved",
            Raven.Objects."="
              (Raven.Objects.To_Symbol
                 (Raven.Objects.To_Object (Raven.Objects.Symbol_Id'Last)),
               Raven.Objects.Symbol_Id'Last));
      Test ("a character is preserved",
            Raven.Objects.To_Character
              (Raven.Objects.To_Object ('a')) = 'a');
      Test ("the last code point is preserved",
            Raven.Objects.To_Character
              (Raven.Objects.To_Object (Raven.Objects.Character_Value'Last))
            = Raven.Objects.Character_Value'Last);
      Test ("an instruction is preserved",
            Raven.Instructions."="
              (Raven.Objects.To_Instruction
                 (Raven.Objects.To_Object (Raven.Instructions.TAP)),
               Raven.Instructions.TAP));
      Test ("an address is preserved",
            Raven.Objects.Get_Address
              (Raven.Objects.To_Pair (123456)) = 123456);
      Test ("the largest address is preserved",
            Raven.Objects.Get_Address
              (Raven.Objects.To_Pair (Address_Type'Last))
            = Address_Type'Last);
      Test ("zero is truthy",
            Raven.Objects.Is_Truthy
              (Raven.Objects.To_Object (Integer'(0))));

   end Run_Tests;

end Raven.Tests.Objects;
