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
      elsif Is_Symbol (X) then
         return This.To_String (Raven.Objects.To_Symbol (X));
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

   function To_String (X : Object) return String is
      Ds      : constant String := "0123456789ABCDEF";
      Tag     : constant Object := X mod 16;
      Payload : constant Object := X / 16;
      Img     : constant String := Payload'Image;
      Prefix  : constant Character := Ds (Natural (Tag) + 1);
   begin
      return Prefix & "/" & Img (2 .. Img'Last);
   end To_String;

end Raven.Target;
