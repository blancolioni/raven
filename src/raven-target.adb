with Ada.Containers.Ordered_Maps;
with Ada.Containers.Ordered_Sets;
with Ada.Containers.Vectors;

package body Raven.Target is

   package Object_Sets is new Ada.Containers.Ordered_Sets (Object);

   package Object_Vectors is
     new Ada.Containers.Vectors (Positive, Object);

   package Label_Maps is
     new Ada.Containers.Ordered_Maps (Object, Natural);

   --  A label's number as it is written, with no space in front.

   function Image (N : Natural) return String;

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

   -----------
   -- Image --
   -----------

   function Image (N : Natural) return String is
      Text : constant String := N'Image;
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Image;

   ----------
   -- Show --
   ----------

   function Show (This     : Abstraction'Class;
                  X        : Object;
                  Readable : Boolean := True;
                  Shared   : Boolean := False)
                  return String
   is
      use Raven.Objects;

      --  Datum labels (#167).  A pair or vector that the object runs
      --  back into from inside itself is written #n= where it is first
      --  written and #n# wherever it comes again, so that writing a
      --  circular list comes to an end; with Shared, which is
      --  write-shared, so is every one that is reached more than once.
      --  Which need a label is found before anything is written, and
      --  each is numbered as it is first written.
      --
      --  Nothing is made while an object is shown, so nothing moves:
      --  an object is the same word from the first look to the last.

      Needs  : Object_Sets.Set;
      Labels : Label_Maps.Map;
      Next   : Natural := 0;

      procedure Find_Labels (Top : Object);

      function Render (Item : Object) return String;
      function Render_List (List : Object) return String;
      function Render_Plain (Item : Object) return String;
      function Show_Held (Held : Object) return String;

      -----------------
      -- Find_Labels --
      -----------------

      procedure Find_Labels (Top : Object) is
         On_Path : Object_Sets.Set;
         Done    : Object_Sets.Set;

         procedure Walk (Item : Object);

         ----------
         -- Walk --
         ----------

         --  Along the cdrs by looping and into the rest by asking again,
         --  so that a long list is not a deep one.

         procedure Walk (Item : Object) is
            Chain : Object_Vectors.Vector;
            It    : Object := Item;
         begin
            loop
               exit when not (Is_Pair (It) or else Is_Vector (It));

               if On_Path.Contains (It) then
                  Needs.Include (It);
                  exit;
               elsif Done.Contains (It) then
                  if Shared then
                     Needs.Include (It);
                  end if;
                  exit;
               end if;

               On_Path.Insert (It);
               Chain.Append (It);

               if Is_Vector (It) then
                  for I in 0 .. This.Vector_Length (It) - 1 loop
                     Walk (This.Vector_Element (It, I));
                  end loop;
                  exit;
               end if;

               Walk (This.Car (It));
               It := This.Cdr (It);
            end loop;

            for Passed of Chain loop
               On_Path.Delete (Passed);
               Done.Insert (Passed);
            end loop;
         end Walk;

      begin
         Walk (Top);
      end Find_Labels;

      ------------
      -- Render --
      ------------

      function Render (Item : Object) return String is
      begin
         if not Needs.Contains (Item) then
            return Render_Plain (Item);
         elsif Labels.Contains (Item) then
            return "#" & Image (Labels (Item)) & "#";
         end if;

         declare
            Label : constant Natural := Next;
         begin
            Next := Next + 1;
            Labels.Insert (Item, Label);
            return "#" & Image (Label) & "=" & Render_Plain (Item);
         end;
      end Render;

      -----------------
      -- Render_List --
      -----------------

      --  The rest of a list.  A pair in it that has a label is written
      --  after a dot, because what the label names starts there.

      function Render_List (List : Object) return String is
      begin
         if List = Nil then
            return "";
         elsif Is_Pair (List) and then not Needs.Contains (List) then
            return " " & Render (This.Car (List))
              & Render_List (This.Cdr (List));
         else
            return " . " & Render (List);
         end if;
      end Render_List;

      ------------------
      -- Render_Plain --
      ------------------

      function Render_Plain (Item : Object) return String is
      begin
         if Item = Nil then
            return "()";
         elsif Item = To_Object (True) then
            return "#t";
         elsif Item = To_Object (False) then
            return "#f";
         elsif Item = Lambda then
            return "lambda";
         elsif Item = Call_CC then
            return "#<procedure call/cc>";
         elsif Is_Continuation (Item) then
            return "#<continuation>";
         elsif Item = Quote then
            return "quote";
         elsif Item = Pending then
            return "<pending>";
         elsif Item = Undefined then
            return "<undefined>";
         elsif Is_Eof (Item) then
            return "#eof";
         elsif Is_Instruction (Item) then
            return To_Instruction (Item)'Image;
         elsif Is_Bignum (Item) or else Is_Ratnum (Item)
           or else Is_Float (Item) or else Is_Flonum (Item)
         then
            return This.Show_Number (Item);
         elsif Is_Integer (Item) then
            declare
               I   : constant Integer := To_Integer (Item);
               Img : constant String := I'Image;
            begin
               return (if I < 0 then Img else Img (2 .. Img'Last));
            end;
         elsif Is_Character (Item) then
            declare
               Ch   : constant Wide_Wide_Character := To_Character (Item);
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
         elsif Is_Symbol (Item) then
            return Symbol_Text
              (This.To_String (Raven.Objects.To_Symbol (Item)), Readable);
         elsif Is_Closure (Item) then

            --  What a procedure shows as, rather than the whole of its
            --  code and everything it captured, which is what a pair
            --  showed as and what a closure was.

            return "#procedure";
         elsif Is_Foreign_Function (Item) then
            return "#ff"
              & Integer'Image (-Integer (To_Foreign_Function_Id (Item)));
         elsif Is_Pair (Item) then
            return "(" & Render (This.Car (Item))
              & Render_List (This.Cdr (Item)) & ")";
         elsif Is_Values (Item) then

            --  Several values where one was wanted, which R7RS calls an
            --  error and raven lets through: written so that it is plain
            --  what it is.

            declare
               List : constant Object := This.Car (Item);
            begin
               return "#<values"
                 & (if List = Nil then ""
                    else " " & Render (This.Car (List))
                         & Render_List (This.Cdr (List)))
                 & ">";
            end;
         elsif Is_Record (Item) then

            --  Which type it is, since nothing else says so: #<point> for
            --  a point, and #<record-type point> for the type itself,
            --  whose name is the first of its fields.

            declare
               Of_Type : constant Object := This.Vector_Element (Item, 0);
            begin
               if Is_Record (Of_Type) then
                  return "#<"
                    & This.Show (This.Vector_Element (Of_Type, 1)) & ">";
               else
                  return "#<record-type "
                    & This.Show (This.Vector_Element (Item, 1)) & ">";
               end if;
            end;
         elsif Is_Vector (Item) or else Is_Bytevector (Item) then

            --  #(1 2 3) and #u8(1 2 3), which is how each is written and
            --  how the reader takes it back.

            declare
               function Elements (Index : Natural) return String
               is (if Index = This.Vector_Length (Item)
                   then ""
                   else (if Index = 0 then "" else " ")
                     & Render (This.Vector_Element (Item, Index))
                     & Elements (Index + 1));
            begin
               return (if Is_Bytevector (Item) then "#u8(" else "#(")
                 & Elements (0) & ")";
            end;
         elsif Is_Foreign_Value (Item) then
            return (if Readable
                    then This.To_Foreign_Value (Item).Show (Show_Held'Access)
                    else This.To_Foreign_Value (Item).Display
                           (Show_Held'Access));
         else
            return To_String (Item);
         end if;
      end Render_Plain;

      ---------------
      -- Show_Held --
      ---------------

      --  An object a foreign value holds, shown as this one is being:
      --  written if it is written, displayed if it is displayed.

      function Show_Held (Held : Object) return String
      is (This.Show (Held, Readable, Shared));

   begin
      if Is_Pair (X) or else Is_Vector (X) then
         Find_Labels (X);
      end if;

      return Render (X);
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
