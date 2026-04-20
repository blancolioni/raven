package body Raven.Objects is

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
         return "#sym" & Integer'Image (-Integer (Raven.Objects.To_Symbol (X)));
      elsif Is_Foreign_Function (X) then
         return "#fn" & Integer'Image (-Integer (To_Foreign_Function_Id (X)));
      elsif Is_Pair (X) then
         return "#pair" & Integer'Image (-Integer (Get_Address (X)));
      else
         return X'Image;
      end if;
   end Image;

end Raven.Objects;
