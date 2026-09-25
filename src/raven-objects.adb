with Ada.Unchecked_Conversion;

package body Raven.Objects is

   pragma Compile_Time_Error
     (Float'Size /= 32,
      "raven reads and writes a float as a 32 bit IEEE single");

   function To_Word is new Ada.Unchecked_Conversion (Float, Object);
   function To_Single is new Ada.Unchecked_Conversion (Object, Float);

   --  A single is one sign bit, eight of exponent biased by 127, and
   --  twenty three of mantissa.  Raven keeps the sign and all twenty
   --  three mantissa bits, and re-biases the exponent by 31 to fit it
   --  in six -- so the significand is a single's exactly and the range
   --  is what is given up.
   --
   --  Six bits leave 1 .. 62 for a real exponent, with 0 kept for zero
   --  and 63 for the infinities and NaNs that nothing here can write.
   --  Re-biasing is therefore subtracting the difference of the two
   --  biases, and a single's exponent fits when it lands in that span.

   Mantissa_Bits  : constant := 23;
   Exponent_Bits  : constant := 6;
   Sign_Shift     : constant := Mantissa_Bits + Exponent_Bits;

   Exponent_Shift : constant := 127 - 31;

   Least_Exponent : constant := Exponent_Shift + 1;
   Most_Exponent  : constant := Exponent_Shift + 2 ** Exponent_Bits - 2;

   function Single_Sign (W : Object) return Object
   is (W / 2 ** 31);

   function Single_Exponent (W : Object) return Object
   is ((W / 2 ** Mantissa_Bits) mod 2 ** 8);

   function Single_Mantissa (W : Object) return Object
   is (W mod 2 ** Mantissa_Bits);

   ---------------------
   -- Is_Representable --
   ---------------------

   function Is_Representable (F : Float) return Boolean is
      W : constant Object := To_Word (F);
      E : constant Object := Single_Exponent (W);
   begin
      --  An empty exponent is zero, or a subnormal -- and every
      --  subnormal single is far below the smallest exponent here can
      --  say, so zero is the whole of what it can be.

      if E = 0 then
         return Single_Mantissa (W) = 0;
      else
         return E in Least_Exponent .. Most_Exponent;
      end if;
   end Is_Representable;

   ---------------
   -- To_Object --
   ---------------

   function To_Object (F : Float) return Object is
      W : constant Object := To_Word (F);
      E : constant Object := Single_Exponent (W);
      P : constant Object :=
            Single_Sign (W) * 2 ** Sign_Shift
              + (if E = 0
                 then 0
                 else (E - Exponent_Shift) * 2 ** Mantissa_Bits
                        + Single_Mantissa (W));
   begin
      return Tag (P, Float_Tag);
   end To_Object;

   --------------
   -- To_Float --
   --------------

   function To_Float (X : Object) return Float is
      P : constant Object := Payload (X);
      S : constant Object := P / 2 ** Sign_Shift;
      E : constant Object := (P / 2 ** Mantissa_Bits) mod 2 ** Exponent_Bits;
      M : constant Object := P mod 2 ** Mantissa_Bits;
   begin
      return To_Single
        (S * 2 ** 31
         + (if E = 0
            then 0
            else (E + Exponent_Shift) * 2 ** Mantissa_Bits + M));
   end To_Float;

   function Image
     (X : Object)
      return String
   is
   begin
      if X = Nil then
         return "()";
      elsif X = To_Object (True) then
         return "#t";
      elsif X = To_Object (False) then
         return "#f";
      elsif X = Lambda then
         return "lambda";
      elsif X = Quote then
         return "quote";
      elsif X = Pending then
         return "<pending>";
      elsif X = Undefined then
         return "<undefined>";
      elsif Is_Eof (X) then
         return "#eof";
      elsif Is_Instruction (X) then
         return To_Instruction (X)'Image;
      elsif Is_Integer (X) then
         declare
            I   : constant Integer := To_Integer (X);
            Img : constant String := I'Image;
         begin
            return (if I < 0 then Img else Img (2 .. Img'Last));
         end;
      elsif Is_Character (X) then
         declare
            Ch : constant Wide_Wide_Character := To_Character (X);
         begin
            if Wide_Wide_Character'Pos (Ch) <= 255 then
               return [Character'Val (Wide_Wide_Character'Pos (Ch))];
            else
               return Natural'Image (Wide_Wide_Character'Pos (Ch));
            end if;
         end;
      elsif Is_Float (X) then
         declare
            Img : constant String := To_Float (X)'Image;
         begin
            return (if Img (Img'First) = ' '
                    then Img (Img'First + 1 .. Img'Last)
                    else Img);
         end;
      elsif Is_Symbol (X) then
         return "#sym" & Integer'Image (-Integer (Raven.Objects.To_Symbol (X)));
      elsif Is_Closure (X) then
         return "#procedure";
      elsif Is_Vector (X) then
         return "#vector";
      elsif Is_Bytevector (X) then
         return "#bytevector";
      elsif Is_Foreign_Function (X) then
         return "#fn" & Integer'Image (-Integer (To_Foreign_Function_Id (X)));
      elsif Is_Pair (X) then
         return "#pair" & Integer'Image (-Integer (Get_Address (X)));
      else
         return X'Image;
      end if;
   end Image;

end Raven.Objects;
