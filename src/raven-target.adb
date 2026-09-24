package body Raven.Target is

   function To_String (X : Object) return String;

   ----------
   -- Show --
   ----------

   function Show (This : Abstraction'Class;
                  X    : Object)
                  return String
   is
      use Raven.Objects;

      function Show_List (List : Object) return String;

      ---------------
      -- Show_List --
      ---------------

      function Show_List (List : Object) return String is
      begin
         if List = Nil then
            return "";
         elsif Is_Pair (List) then
            return " " & This.Show (This.Car (List))
              & Show_List (This.Cdr (List));
         else
            return " . "
              & This.Show (List);
         end if;
      end Show_List;

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
         return This.To_String (Raven.Objects.To_Symbol (X));
      elsif Is_Closure (X) then

         --  What a procedure shows as, rather than the whole of its
         --  code and everything it captured, which is what a pair
         --  showed as and what a closure was.

         return "#procedure";
      elsif Is_Foreign_Function (X) then
         return "#ff" & Integer'Image (-Integer (To_Foreign_Function_Id (X)));
      elsif Is_Pair (X) then
         return "(" & This.Show (This.Car (X))
           & Show_List (This.Cdr (X)) & ")";
      elsif Is_Foreign_Value (X) then
         return This.To_Foreign_Value (X).Show;
      else
         return To_String (X);
      end if;
   end Show;

   ---------------
   -- To_String --
   ---------------

   --  What is left when Show knows of nothing else, which is the whole
   --  word in hex.  It used to take the tag as the low nibble and show
   --  it apart from the payload; the tag is two bits or eight
   --  depending on what it is, so splitting it here would be saying
   --  something that is not so.

   function To_String (X : Object) return String is
      Ds     : constant String := "0123456789ABCDEF";
      Digits_Of : String (1 .. Object_Size / 4);
      W      : Object := X;
   begin
      for I in reverse Digits_Of'Range loop
         Digits_Of (I) := Ds (Natural (W mod 16) + 1);
         W := W / 16;
      end loop;
      return "#x" & Digits_Of;
   end To_String;

end Raven.Target;
