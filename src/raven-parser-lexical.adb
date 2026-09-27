with Ada.Strings.Wide_Wide_Fixed;
with Ada.Strings.Wide_Wide_Unbounded;  use Ada.Strings.Wide_Wide_Unbounded;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Ada.Unchecked_Deallocation;
with Ada.Wide_Wide_Characters.Handling;

with Raven.Parser.Lexical.Characters;
with Raven.Parser.Lexical.Identifiers;

package body Raven.Parser.Lexical is

   package Chars renames Ada.Wide_Wide_Characters.Handling;

   procedure Open_Stream (This : in out Instance; Identity : String);

   procedure Next_Character (This : in out Instance'Class);
   procedure Start_Token (This : in out Instance'Class);
   procedure Stop_Token (This : in out Instance'Class);

   function Peek (This : Instance'Class) return Wide_Wide_Character;

   function Is_White_Space (This : Instance'Class) return Boolean;
   function Is_Alphanumeric (This : Instance'Class) return Boolean;
   function End_Of_Stream (This : Instance) return Boolean;
   function End_Of_Line (This : Instance) return Boolean;
   function Hex_To_Character
     (Hex : Wide_Wide_String)
      return Wide_Wide_Character;

   function Read_Character (This       : in out Instance'Class;
      Long_Names : Boolean)
                            return Wide_Wide_Character;

   -----------
   -- Close --
   -----------

   procedure Close (This : in out Instance) is
      procedure Free is
        new Ada.Unchecked_Deallocation (Source_Stream_Record, Source_Stream);
   begin
      Free (This.Current_Stream);
      This.Current_Stream_Index := @ - 1;
      if This.Current_Stream_Index > 0 then
         This.Current_Stream :=
           This.Source_Stream_Stack (This.Current_Stream_Index);
      else
         This.Current_Stream := null;
      end if;
   end Close;

   -----------------------
   -- Current_File_Name --
   -----------------------

   function Current_File_Name (This : Instance)  return String is
   begin
      return Encode (To_Wide_Wide_String (This.Current_Stream.Identity));
   end Current_File_Name;

   ------------------
   -- Current_Line --
   ------------------

   function Current_Line (This : Instance)  return Natural is
   begin
      return This.Current_Stream.Tok_Line;
   end Current_Line;

   -----------------
   -- End_Of_Line --
   -----------------

   function End_Of_Line (This : Instance) return Boolean is
   begin
      return This.Current_Stream.Column =
        This.Current_Stream.Lines.Element (This.Current_Stream.Line)'Length;
   end End_Of_Line;

   -------------------
   -- End_Of_Stream --
   -------------------

   function End_Of_Stream (This : Instance) return Boolean is
   begin
      return This.Current_Stream.EOF;
   end End_Of_Stream;

   -----------
   -- Error --
   -----------

   procedure Error
     (This    : in out Instance;
      Message : Wide_Wide_String)
   is
      use Ada.Strings, Ada.Strings.Fixed;
      use Ada.Text_IO;
      use type Raven.Target.Reference;

      Text : constant String :=
               Encode (To_Wide_Wide_String (This.Current_Stream.Identity))
               & ":"
               & Trim (Natural'Image (This.Current_Stream.Tok_Line), Left)
               & ":"
               & Trim (Natural'Image (This.Current_Stream.Tok_Column), Left)
               & ": "
               & Encode (Message);
   begin
      if This.Target = null then

         --  Nothing has said where to send it, which is a lexer being
         --  read outside a parse.  The terminal is all there is.

         Put_Line (Standard_Error, Text);
      else
         This.Target.Report_Error (Text);
      end if;
   end Error;

   ---------------
   -- Hex_Digit --
   ---------------

   function Hex_Digit (Ch : Wide_Wide_Character) return Natural is
   begin
      if Ch in '0' .. '9' then
         return Wide_Wide_Character'Pos (Ch)
           - Wide_Wide_Character'Pos ('0');
      elsif Ch in 'A' .. 'F' then
         return Wide_Wide_Character'Pos (Ch)
           - Wide_Wide_Character'Pos ('A')
           + 10;
      elsif Ch in 'a' .. 'f' then
         return Wide_Wide_Character'Pos (Ch)
           - Wide_Wide_Character'Pos ('a')
           + 10;
      else
         raise Constraint_Error with
           "expected a hex digit";
      end if;
   end Hex_Digit;

   ----------------------
   -- Hex_To_Character --
   ----------------------

   function Hex_To_Character
     (Hex : Wide_Wide_String)
      return Wide_Wide_Character
   is
      V : Natural := 0;
   begin
      for D of Hex loop
         V := V * 16 + Hex_Digit (D);
      end loop;
      return Wide_Wide_Character'Val (V);
   end Hex_To_Character;

   ---------------------
   -- Is_Alphanumeric --
   ---------------------

   function Is_Alphanumeric (This : Instance'Class) return Boolean is
   begin
      return Chars.Is_Alphanumeric (This.Current_Stream.Ch);
   end Is_Alphanumeric;

   --------------------
   -- Is_White_Space --
   --------------------

   function Is_White_Space (This : Instance'Class) return Boolean is
   begin
      return Chars.Is_Space (This.Current_Stream.Ch)
        or else Wide_Wide_Character'Pos (This.Current_Stream.Ch) < 32;
   end Is_White_Space;

   --------------------
   -- Next_Character --
   --------------------

   procedure Next_Character (This : in out Instance'Class) is
      S : constant Source_Stream := This.Current_Stream;
   begin
      S.Tok_Text :=
        S.Tok_Text & S.Ch;
      if S.Line = 0 then
         S.Line := 1;
      end if;

      if S.Line > S.Lines.Last_Index then
         S.EOF := True;
         S.Ch := ' ';
      else
         S.Column := S.Column + 1;
         if S.Column > S.Lines.Element (S.Line)'Last then
            S.Line := S.Line + 1;
            while S.Line < S.Lines.Last_Index and then
                  S.Lines.Element (S.Line)'Length = 0
            loop
               S.Line := S.Line + 1;
            end loop;
            if S.Line > S.Lines.Last_Index then
               S.EOF := True;
               S.Ch := ' ';
               return;
            end if;
            S.Column := 1;
            S.Ch := S.Lines.Element (S.Line)(S.Column);
         else
            S.Ch :=
              S.Lines.Element (S.Line)
              (S.Column);
         end if;
      end if;
   end Next_Character;

   ----------
   -- Open --
   ----------

   procedure Open
     (This   : in out Instance;
      Name   : String;
      Source : Wide_Wide_String)
   is
   begin
      This.Open_Stream (Name);
      declare
         Start : Positive := Source'First;
      begin
         for Index in Source'Range loop
            declare
               Ch renames Source (Index);
            begin
               if Wide_Wide_Character'Pos (Ch) = 10 then
                  declare
                     Line : constant Wide_Wide_String (1 .. Index - Start) :=
                       Source (Start .. Index - 1);
                  begin
                     This.Current_Stream.Lines.Append (Line);
                  end;
                  Start := Index + 1;
               end if;
            end;
         end loop;
         if Start <= Source'Last then
            This.Current_Stream.Lines.Append
              (Source (Start .. Source'Last));
         end if;
      end;
      This.Scan;
   end Open;

   -----------------
   -- Open_Stream --
   -----------------

   procedure Open_Stream (This : in out Instance; Identity : String) is
   begin
      if This.Current_Stream_Index = Max_Source_Files then
         raise Program_Error with "maximum source file nesting exceeded";
      end if;
      This.Current_Stream_Index := @ + 1;
      This.Current_Stream := new Source_Stream_Record'(Empty_Stream);
      This.Current_Stream.Identity :=
        To_Unbounded_Wide_Wide_String (Decode (Identity));
      This.Current_Stream.EOF := False;
   end Open_Stream;

   ----------
   -- Peek --
   ----------

   function Peek (This : Instance'Class) return Wide_Wide_Character is
      Current_Stream : constant Source_Stream := This.Current_Stream;
   begin
      if Current_Stream.Line > Current_Stream.Lines.Last_Index then
         return ' ';
      elsif Current_Stream.Column
        >= Current_Stream.Lines.Element (Current_Stream.Line)'Length
      then
         return ' ';
      else
         return
           Current_Stream.Lines.Element (Current_Stream.Line)
           (Current_Stream.Column + 1);
      end if;
   end Peek;

   --------------------
   -- Read_Character --
   --------------------

   function Read_Character
     (This       : in out Instance'Class;
      Long_Names : Boolean)
      return Wide_Wide_Character
   is
      Buffer : Wide_Wide_String (1 .. 20);
      Count  : Natural := 0;
      Current_Stream : constant Source_Stream := This.Current_Stream;
   begin
      if Current_Stream.Ch = 'x' then
         This.Next_Character;
         while Current_Stream.Ch in '0' .. '9'
           or else Current_Stream.Ch in 'a' .. 'z'
           or else Current_Stream.Ch in 'A' .. 'Z'
         loop
            Count := Count + 1;
            Buffer (Count) := Current_Stream.Ch;
            This.Next_Character;
         end loop;

         if Count = 0 then
            return 'x';
         end if;

         if not Long_Names then
            if Current_Stream.Ch = ';' then
               This.Next_Character;
            else
               This.Error ("missing ';'");
            end if;
         end if;

         return Hex_To_Character (Buffer (1 .. Count));

      elsif Long_Names then
         if This.Is_White_Space then
            This.Next_Character;
            return ' ';
         elsif This.Is_Alphanumeric then
            while Count + 1 in Buffer'Range
              and then This.Is_Alphanumeric
            loop
               Count := Count + 1;
               Buffer (Count) := Current_Stream.Ch;
               This.Next_Character;
            end loop;

            return Raven.Parser.Lexical.Characters.Name_To_Character
              (Buffer (1 .. Count));
         else
            declare
               Result : constant Wide_Wide_Character :=
                          Current_Stream.Ch;
            begin
               This.Next_Character;
               return Result;
            end;
         end if;
      else
         declare
            V : Integer := -1;
         begin

            case Current_Stream.Ch is
               when 'a' =>
                  V := 7;
               when 'b' =>
                  V := 8;
               when 't' =>
                  V := 9;
               when 'n' =>
                  V := 10;
               when 'r' =>
                  V := 13;
               when '"' =>
                  V := 34;
               when '\' =>
                  V := 16#5C#;
               when '|' =>
                  V := 16#7C#;
               when others =>

                  --  R7RS says a backslash before anything else is an
                  --  error.  This reported one through the reader's
                  --  own error channel and then raised as well, which
                  --  took the form and the host with it -- one thing
                  --  too many, since a bad token is reported and the
                  --  reader carries on.
                  --
                  --  So is this now, with the escaped character
                  --  standing for itself, which is the reading that
                  --  keeps a typo in a string from ending a session.

                  This.Error ("bad escape");
                  V := Wide_Wide_Character'Pos (Current_Stream.Ch);
            end case;
            This.Next_Character;
            return Wide_Wide_Character'Val (V);
         end;
      end if;
   end Read_Character;

   ----------------
   -- Report_To --
   ----------------

   procedure Report_To
     (This   : in out Instance;
      Target : Raven.Target.Reference)
   is
   begin
      This.Target := Target;
   end Report_To;

   ----------
   -- Scan --
   ----------

   procedure Scan
     (This : in out Instance)
   is
      Current_Stream : constant Source_Stream := This.Current_Stream;
      Tok : Token renames Current_Stream.Tok;
   begin
      while not This.End_Of_Stream and then This.Is_White_Space loop
         This.Next_Character;
      end loop;

      if This.End_Of_Stream then
         Tok := Tok_End_Of_File;
         return;
      end if;

      This.Start_Token;

      case Current_Stream.Ch is
         when '(' =>
            This.Next_Character;
            if Current_Stream.Ch = ')' then
               This.Next_Character;
               This.Stop_Token;
               Tok := Tok_Nil;
            else
               This.Stop_Token;
               Tok := Tok_Left_Paren;
            end if;
         when ')' =>
            This.Next_Character;
            This.Stop_Token;
            Tok := Tok_Right_Paren;
         when ''' =>
            This.Next_Character;
            This.Stop_Token;
            Tok := Tok_Quote;
         when '`' =>
            This.Next_Character;
            This.Stop_Token;
            Tok := Tok_Quasiquote;
         when ',' =>
            This.Next_Character;
            if Current_Stream.Ch = '@' then
               This.Next_Character;
               This.Stop_Token;
               Tok := Tok_Unquote_Splice;
            else
               This.Stop_Token;
               Tok := Tok_Comma;
            end if;
         when ';' =>
            This.Stop_Token;
            Current_Stream.Line := Current_Stream.Line + 1;
            Current_Stream.Column := 0;
            Current_Stream.Ch := ' ';
            This.Scan;
         when '|' =>

            --  A name between vertical bars, which may hold anything
            --  at all -- spaces and the characters that would
            --  otherwise end it included.  The bar was in no branch
            --  of this at all, so each one was a bad token and the
            --  words between them were read as separate names.
            --
            --  It matters more now than it looks, because
            --  symbol->string and string->symbol are both here: a
            --  program can make a symbol whose name has a space in
            --  it, and without this there is no way to write that
            --  symbol down and read it again.

            This.Next_Character;
            This.Start_Token;

            declare
               Result : Unbounded_Wide_Wide_String;
            begin
               while not This.End_Of_Stream
                 and then Current_Stream.Ch /= '|'
               loop
                  if Current_Stream.Ch = '\' then
                     This.Next_Character;
                     Result := Result
                       & This.Read_Character (Long_Names => False);
                  elsif This.End_Of_Line then
                     This.Error ("unterminated name");
                     exit;
                  else
                     Result := Result & Current_Stream.Ch;
                     This.Next_Character;
                  end if;
               end loop;

               This.Stop_Token;

               if This.End_Of_Stream then
                  This.Error ("unterminated name");
               else
                  This.Next_Character;
               end if;

               Current_Stream.Tok_Text := Result;
               Tok := Tok_Bar_Identifier;
            end;

         when '"' =>
            This.Next_Character;
            This.Start_Token;

            declare
               Result : Unbounded_Wide_Wide_String;
            begin
               while not This.End_Of_Stream
                 and then Current_Stream.Ch /= '"'
               loop
                  if Current_Stream.Ch = '\' then
                     This.Next_Character;
                     Result := Result
                       & This.Read_Character (Long_Names => False);
                  elsif This.End_Of_Line then
                     This.Error ("unterminated string constant");
                     exit;
                  else
                     Result := Result & Current_Stream.Ch;
                     This.Next_Character;
                  end if;
               end loop;

               This.Stop_Token;

               if This.End_Of_Stream then
                  This.Error ("unterminated string constant");
               else
                  This.Next_Character;
               end if;

               Current_Stream.Tok_Text := Result;
               Tok := Tok_String;
            end;

         when others =>
            declare
               use Ada.Strings.Wide_Wide_Fixed;
               use Chars;

               function Is_Id return Boolean
               is (not This.End_Of_Stream
                   and then (Is_Alphanumeric (Current_Stream.Ch)
                             or else Index ("!$%&*+-./:<=>?@^_~#",
                                            [Current_Stream.Ch]) > 0));
            begin
               if Current_Stream.Ch = '#'
                 and then This.Peek = '|'
               then

                  --  A block comment, which was not one: # is a
                  --  character an identifier may be made of and | is
                  --  not, so #| read as the identifier # followed by a
                  --  bad token, and every word of the comment after it
                  --  was read as code.
                  --
                  --  R7RS says the pairs nest, so this counts them
                  --  rather than looking for the first |#.

                  declare
                     Depth : Natural := 1;
                  begin
                     This.Next_Character;
                     This.Next_Character;

                     while Depth > 0 and then not This.End_Of_Stream loop
                        if Current_Stream.Ch = '|'
                          and then This.Peek = '#'
                        then
                           Depth := Depth - 1;
                           This.Next_Character;
                           This.Next_Character;
                        elsif Current_Stream.Ch = '#'
                          and then This.Peek = '|'
                        then
                           Depth := Depth + 1;
                           This.Next_Character;
                           This.Next_Character;
                        else
                           This.Next_Character;
                        end if;
                     end loop;

                     if Depth > 0 then
                        This.Error ("unterminated block comment");
                     end if;
                  end;

                  This.Stop_Token;
                  This.Scan;
                  return;
               elsif Current_Stream.Ch = '#'
                 and then This.Peek = ';'
               then

                  --  A datum comment.  # read as an identifier and
                  --  then ; commented out the rest of the line, which
                  --  took whatever was left of the form with it.

                  This.Next_Character;
                  This.Next_Character;
                  This.Stop_Token;
                  Tok := Tok_Datum_Comment;
               elsif Current_Stream.Ch = '#'
                 and then This.Peek = '\'
               then
                  This.Next_Character;
                  This.Next_Character;
                  Current_Stream.Tok_Char :=
                    This.Read_Character (Long_Names => True);
                  This.Stop_Token;
                  Tok := Tok_Character;
               elsif Current_Stream.Ch = '#'
                 and then This.Peek = '('
               then
                  This.Next_Character;
                  This.Next_Character;
                  This.Stop_Token;
                  Tok := Tok_Start_Vector;
               elsif Current_Stream.Ch = '.'
                 and then Chars.Is_Space (This.Peek)
               then
                  This.Next_Character;
                  This.Stop_Token;
                  Tok := Tok_Dot;
               elsif Is_Id then
                  while Is_Id loop
                     This.Next_Character;
                  end loop;

                  This.Stop_Token;

                  if This.Tok_Text = "#u8"
                    and then Current_Stream.Ch = '('
                  then
                     This.Next_Character;
                     Tok := Tok_Start_Bytevector;
                  else
                     Tok :=
                       Raven.Parser.Lexical.Identifiers.Classify_Identifier
                         (This.Tok_Text);
                  end if;

               else
                  This.Next_Character;
                  This.Stop_Token;
                  Tok := Tok_Bad_Character;
               end if;
            end;
      end case;
   end Scan;

   -----------------
   -- Start_Token --
   -----------------

   procedure Start_Token
     (This : in out Instance'Class)
   is
   begin
      This.Current_Stream.Tok_Line := This.Current_Stream.Line;
      This.Current_Stream.Tok_Column := This.Current_Stream.Column;
      This.Current_Stream.Tok_Text := Null_Unbounded_Wide_Wide_String;
   end Start_Token;

   ----------------
   -- Stop_Token --
   ----------------

   procedure Stop_Token
     (This : in out Instance'Class)
   is
   begin
      null;
   end Stop_Token;

   ---------
   -- Tok --
   ---------

   function Tok
     (This : Instance'Class)
      return Token
   is
   begin
      return This.Current_Stream.Tok;
   end Tok;

   -------------------------
   -- Tok_Character_Value --
   -------------------------

   function Tok_Character_Value
     (This : in out Instance'Class)
      return Wide_Wide_Character
   is
   begin
      return This.Current_Stream.Tok_Char;
   end Tok_Character_Value;

   ---------------------
   -- Tok_Float_Value --
   ---------------------

   function Tok_Float_Value
     (This : in out Instance'Class)
      return Float
   is
      Text : constant Wide_Wide_String :=
               To_Wide_Wide_String (This.Current_Stream.Tok_Text);

      --  Ada's Value wants a real literal, and a real literal always
      --  has a point with a digit on each side of it.  Scheme's
      --  numbers do not: .5, 1., and 1e20 are all numbers the scanner
      --  now takes and none of them is an Ada literal.  So the text is
      --  written out again with what Ada is missing put in.
      --
      --  Four more characters is room for every case: a zero in front
      --  of a leading point, a zero after a trailing one, and the .0
      --  an exponent with no point of its own wants.

      Norm : Wide_Wide_String (1 .. Text'Length + 4);
      Last : Natural := 0;
      Point : Boolean := False;

      procedure Put (Ch : Wide_Wide_Character);

      ---------
      -- Put --
      ---------

      procedure Put (Ch : Wide_Wide_Character) is
      begin
         Last := Last + 1;
         Norm (Last) := Ch;
      end Put;

   begin
      for I in Text'Range loop
         declare
            Ch : constant Wide_Wide_Character := Text (I);
         begin
            if Ch = '.' then
               Point := True;
               if Last = 0 or else Norm (Last) not in '0' .. '9' then
                  Put ('0');
               end if;
               Put ('.');
               if I = Text'Last or else Text (I + 1) not in '0' .. '9' then
                  Put ('0');
               end if;
            elsif not Point and then (Ch = 'e' or else Ch = 'E') then
               Put ('.');
               Put ('0');
               Put (Ch);
               Point := True;
            else
               Put (Ch);
            end if;
         end;
      end loop;

      return Float'Wide_Wide_Value (Norm (1 .. Last));
   end Tok_Float_Value;

   -----------------------
   -- Tok_Integer_Value --
   -----------------------

   function Tok_Integer_Value
     (This : in out Instance'Class)
      return Integer
   is
      Text : constant Wide_Wide_String :=
               To_Wide_Wide_String (This.Current_Stream.Tok_Text);
      Base     : Natural := 10;
      Negative : Boolean := False;
      Result   : Integer := 0;
      I        : Natural := Text'First;
   begin
      --  The token is whatever the identifier scanner classified as an
      --  integer, and both a leading sign and a radix prefix are part
      --  of that: -13, #x1F and #x-1F are each one token and not a
      --  name.
      --
      --  This used to hand the whole text to Integer'Value, which
      --  takes Ada's spelling of a based number -- 16#1F# -- and not
      --  scheme's, so every prefix the scanner had gone to the trouble
      --  of recognising and checking the digits of then failed to be
      --  read at all.  The scanner works the base out; so does this.

      if I <= Text'Last
        and then (Text (I) = '+' or else Text (I) = '-')
      then
         Negative := Text (I) = '-';
         I := I + 1;
      end if;

      if I < Text'Last and then Text (I) = '#' then
         case Text (I + 1) is
            when 'b' | 'B' => Base := 2;
            when 'o' | 'O' => Base := 8;
            when 'd' | 'D' => Base := 10;
            when 'x' | 'X' => Base := 16;
            when others => null;
         end case;
         I := I + 2;

         if I <= Text'Last
           and then (Text (I) = '+' or else Text (I) = '-')
         then
            Negative := Text (I) = '-';
            I := I + 1;
         end if;
      end if;

      while I <= Text'Last loop
         Result := Result * Base + Hex_Digit (Text (I));
         I := I + 1;
      end loop;

      return (if Negative then -Result else Result);
   end Tok_Integer_Value;

   --------------
   -- Tok_Text --
   --------------

   function Tok_Text
     (This : in out Instance'Class)
      return Wide_Wide_String
   is
   begin
      return To_Wide_Wide_String (This.Current_Stream.Tok_Text);
   end Tok_Text;

end Raven.Parser.Lexical;
