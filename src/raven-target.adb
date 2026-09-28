package body Raven.Target is

   function Character_To_Name
     (Ch : Wide_Wide_Character)
      return String;

   function To_String (X : Object) return String;

   --  A symbol's name as write writes it, or as display does.

   function Symbol_Text
     (Name     : String;
      Readable : Boolean)
      return String;

   -----------------------
   -- Character_To_Name --
   -----------------------

   --  The name a character is written under, and empty for one that
   --  has none and is written as itself.  These are the nine R7RS
   --  gives, and are Raven.Parser.Lexical.Characters' table read the
   --  other way round -- which is where a name is turned back into a
   --  character, and is a private child of the reader that this
   --  cannot reach.  The two have to agree, and what keeps them
   --  agreeing is that R7RS fixes the list.

   function Character_To_Name
     (Ch : Wide_Wide_Character)
      return String
   is
   begin
      case Wide_Wide_Character'Pos (Ch) is
         when 0      => return "null";
         when 7      => return "alarm";
         when 8      => return "backspace";
         when 9      => return "tab";
         when 10     => return "newline";
         when 13     => return "return";
         when 27     => return "escape";
         when 32     => return "space";
         when 127    => return "delete";
         when others => return "";
      end case;
   end Character_To_Name;

   ----------
   -- Show --
   ----------

   function Show (This     : Abstraction'Class;
                  X        : Object;
                  Readable : Boolean := True)
                  return String
   is
      use Raven.Objects;

      function Show_Held (Held : Object) return String;
      function Show_List (List : Object) return String;

      ---------------
      -- Show_Held --
      ---------------

      --  An object a foreign value holds, shown as this one is being:
      --  written if it is written, displayed if it is displayed.

      function Show_Held (Held : Object) return String
      is (This.Show (Held, Readable));

      ---------------
      -- Show_List --
      ---------------

      function Show_List (List : Object) return String is
      begin
         if List = Nil then
            return "";
         elsif Is_Pair (List) then
            return " " & This.Show (This.Car (List), Readable)
              & Show_List (This.Cdr (List));
         else
            return " . "
              & This.Show (List, Readable);
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
      elsif X = Call_CC then
         return "#<procedure call/cc>";
      elsif Is_Continuation (X) then
         return "#<continuation>";
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
      elsif Is_Bignum (X) or else Is_Ratnum (X)
        or else Is_Float (X) or else Is_Flonum (X)
      then
         return This.Show_Number (X);
      elsif Is_Integer (X) then
         declare
            I   : constant Integer := To_Integer (X);
            Img : constant String := I'Image;
         begin
            return (if I < 0 then Img else Img (2 .. Img'Last));
         end;
      elsif Is_Character (X) then
         declare
            Ch   : constant Wide_Wide_Character := To_Character (X);
            Name : constant String := Character_To_Name (Ch);

            --  The character on its own, which is what it is read as
            --  and what display answers with.

            function Bare return String
            is (if Wide_Wide_Character'Pos (Ch) <= 255
                then [Character'Val (Wide_Wide_Character'Pos (Ch))]
                else Encode ([Ch]));
         begin
            if not Readable then
               return Bare;
            elsif Name /= "" then
               return "#\" & Name;
            else
               return "#\" & Bare;
            end if;
         end;
      elsif Is_Symbol (X) then
         return Symbol_Text
           (This.To_String (Raven.Objects.To_Symbol (X)), Readable);
      elsif Is_Closure (X) then

         --  What a procedure shows as, rather than the whole of its
         --  code and everything it captured, which is what a pair
         --  showed as and what a closure was.

         return "#procedure";
      elsif Is_Foreign_Function (X) then
         return "#ff" & Integer'Image (-Integer (To_Foreign_Function_Id (X)));
      elsif Is_Pair (X) then
         return "(" & This.Show (This.Car (X), Readable)
           & Show_List (This.Cdr (X)) & ")";
      elsif Is_Values (X) then

         --  Several values where one was wanted, which R7RS calls an
         --  error and raven lets through: written so that it is plain
         --  what it is.

         declare
            List : constant Object := This.Car (X);
         begin
            return "#<values"
              & (if List = Nil then ""
                 else " " & This.Show (This.Car (List), Readable)
                      & Show_List (This.Cdr (List)))
              & ">";
         end;
      elsif Is_Record (X) then

         --  Which type it is, since nothing else says so: #<point> for
         --  a point, and #<record-type point> for the type itself,
         --  whose name is the first of its fields.

         declare
            Of_Type : constant Object := This.Vector_Element (X, 0);
         begin
            if Is_Record (Of_Type) then
               return "#<" & This.Show (This.Vector_Element (Of_Type, 1))
                 & ">";
            else
               return "#<record-type "
                 & This.Show (This.Vector_Element (X, 1)) & ">";
            end if;
         end;
      elsif Is_Vector (X) or else Is_Bytevector (X) then

         --  #(1 2 3) and #u8(1 2 3), which is how each is written and
         --  how the reader takes it back.

         declare
            function Elements (Index : Natural) return String
            is (if Index = This.Vector_Length (X)
                then ""
                else (if Index = 0 then "" else " ")
                  & This.Show (This.Vector_Element (X, Index), Readable)
                  & Elements (Index + 1));
         begin
            return (if Is_Bytevector (X) then "#u8(" else "#(")
              & Elements (0) & ")";
         end;
      elsif Is_Foreign_Value (X) then
         return (if Readable
                 then This.To_Foreign_Value (X).Show (Show_Held'Access)
                 else This.To_Foreign_Value (X).Display (Show_Held'Access));
      else
         return To_String (X);
      end if;
   end Show;

   -----------------
   -- Symbol_Text --
   -----------------

   function Symbol_Text
     (Name     : String;
      Readable : Boolean)
      return String
   is
      function Needs_Bars return Boolean;

      ----------------
      -- Needs_Bars --
      ----------------

      --  Whether the name would not read back as this symbol written as
      --  it is: it is empty, has in it what ends a name or starts
      --  something else, or reads as a number, a dot or a # form.

      function Needs_Bars return Boolean is
         First : Character;
      begin
         if Name'Length = 0 or else Name = "." then
            return True;
         end if;

         for Ch of Name loop
            if Character'Pos (Ch) < 33
              or else Ch in '(' | ')' | '"' | ';' | ''' | '`' | ','
                          | '|' | '[' | ']' | '{' | '}' | '\'
            then
               return True;
            end if;
         end loop;

         First := Name (Name'First);

         if First in '0' .. '9' | '#' then
            return True;
         elsif First in '+' | '-' | '.'
           and then Name'Length > 1
           and then Name (Name'First + 1) in '0' .. '9' | '.'
           and then Name /= "..."
         then
            return True;
         end if;

         return False;
      end Needs_Bars;

   begin
      --  A name that would not read back is written between bars
      --  (#159), with a bar or a backslash in it escaped and a control
      --  character written as its code.  display writes it as it is.

      if not Readable or else not Needs_Bars then
         return Name;
      end if;

      declare
         Hex    : constant String := "0123456789ABCDEF";
         Result : String (1 .. 6 * Name'Length + 2);
         Last   : Natural := 1;
      begin
         Result (1) := '|';
         for Ch of Name loop
            if Ch = '|' or else Ch = '\' then
               Result (Last + 1 .. Last + 2) := ['\', Ch];
               Last := Last + 2;
            elsif Character'Pos (Ch) < 32 then
               Result (Last + 1 .. Last + 5) :=
                 ['\', 'x', Hex (Character'Pos (Ch) / 16 + 1),
                  Hex (Character'Pos (Ch) mod 16 + 1), ';'];
               Last := Last + 5;
            else
               Last := Last + 1;
               Result (Last) := Ch;
            end if;
         end loop;
         Last := Last + 1;
         Result (Last) := '|';
         return Result (1 .. Last);
      end;
   end Symbol_Text;

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
