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
      Test ("max integer is preserved",
            Raven.Objects.To_Integer
              (Raven.Objects.To_Object (Integer'(134217727)))
            = 134217727);
      Test ("min integer is preserved",
            Raven.Objects.To_Integer
              (Raven.Objects.To_Object (Integer'(-134217728)))
            = -134217728);
      Test ("zero is truthy",
            Raven.Objects.Is_Truthy
              (Raven.Objects.To_Object (Integer'(0))));

   end Run_Tests;

end Raven.Tests.Objects;
