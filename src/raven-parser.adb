with Ada.Strings.Fixed;
with Ada.Unchecked_Deallocation;
with Raven.Objects;
with Raven.Parser.Tokens;             use Raven.Parser.Tokens;
with Raven.Parser.Lexical;

package body Raven.Parser is

   type Source_Record is
      record
         Lex : Raven.Parser.Lexical.Instance;
      end record;

   procedure Parse_S_Expression
     (Lex    : in out Raven.Parser.Lexical.Instance'Class;
      Target : Raven.Target.Reference);

   ------------
   -- At_End --
   ------------

   function At_End (This : Instance) return Boolean is
   begin
      return This.Data = null
        or else This.Data.Lex.Tok = Tok_End_Of_File;
   end At_End;

   -----------
   -- Close --
   -----------

   procedure Close (This : in out Instance) is
      procedure Free is
        new Ada.Unchecked_Deallocation (Source_Record, Source_Access);
   begin
      if This.Data /= null then
         This.Data.Lex.Close;
         Free (This.Data);
      end if;
   end Close;

   ----------
   -- Open --
   ----------

   procedure Open
     (This   : in out Instance;
      Name   : String;
      Source : String)
   is
   begin
      This.Data := new Source_Record;
      This.Data.Lex.Open (Name, Decode (Source));
   end Open;

   ----------------------
   -- Parse_Expression --
   ----------------------

   procedure Parse_Expression
     (Expression : String;
      Target     : Raven.Target.Reference)
   is
      Lex : Raven.Parser.Lexical.Instance;
   begin
      Lex.Open ("user input", Decode (Expression));
      Parse_S_Expression (Lex, Target);
      Lex.Close;
   end Parse_Expression;

   ----------------
   -- Parse_Next --
   ----------------

   procedure Parse_Next
     (This   : in out Instance;
      Target : Raven.Target.Reference)
   is
   begin
      Parse_S_Expression (This.Data.Lex, Target);
   end Parse_Next;

   ------------------------
   -- Parse_S_Expression --
   ------------------------

   procedure Parse_S_Expression
     (Lex    : in out Raven.Parser.Lexical.Instance'Class;
      Target : Raven.Target.Reference)
   is

      procedure Parse_Expression;

      procedure Parse_Rest_Of_List;

      procedure Skip_Datum_Comments;

      ----------------------
      -- Parse_Expression --
      ----------------------

      procedure Parse_Expression is
      begin
         Skip_Datum_Comments;

         case Lex.Tok is
            when Tok_Nil =>
               Lex.Scan;
               Target.Push (Raven.Objects.Nil);
            when Tok_Left_Paren =>
               Lex.Scan;
               Parse_Rest_Of_List;

            when Tok_Identifier =>
               declare
                  Sym : constant Wide_Wide_String := Lex.Tok_Text;
               begin
                  Lex.Scan;
                  --  R7RS gives all four spellings and only the two
                  --  short ones were matched, so #true and #false were
                  --  interned as ordinary names.

                  if Sym = "#t" or else Sym = "#true" then
                     Target.Push (Raven.Objects.To_Object (True));
                  elsif Sym = "#f" or else Sym = "#false" then
                     Target.Push (Raven.Objects.To_Object (False));
                  elsif Sym = "if" then
                     Target.Push (Raven.Objects.If_Obj);
                  elsif Sym = "lambda" then
                     Target.Push (Raven.Objects.Lambda);
                  elsif Sym = "quote" then

                     --  The translator matches a quotation by object
                     --  identity, so the written-out name has to reach
                     --  it as the same object the reader's ' produces.

                     Target.Push (Raven.Objects.Quote);
                  else
                     Target.Push
                       (Raven.Objects.To_Object
                          (Target.To_Symbol_Id (Encode (Sym))));
                  end if;
               end;
            when Tok_Bar_Identifier =>

               --  Whatever is between the bars is the name, and
               --  nothing it spells means anything else: |if| is the
               --  identifier if, and |#t| is a symbol rather than a
               --  boolean, which is why this is a token of its own.

               declare
                  Sym : constant Wide_Wide_String := Lex.Tok_Text;
               begin
                  Lex.Scan;
                  Target.Push
                    (Raven.Objects.To_Object
                       (Target.To_Symbol_Id (Encode (Sym))));
               end;

            when Tok_Start_Vector =>

               --  A vector written out is a literal, so its elements
               --  are read as data and the vector is built here.  It
               --  used to read as a call of vector, which made its
               --  elements expressions: #(1 2 3) was right because a
               --  number stands for itself, and #(a b) was undefined.

               Lex.Scan;

               --  #() has no elements, and Parse_Rest_Of_List reads
               --  one before it looks for the bracket, so the empty
               --  one is read here.  It was a bad token before, on
               --  this path and on the one this replaced.

               if Lex.Tok = Tok_Right_Paren then
                  Lex.Scan;
                  Target.Push_Nil;
               else
                  Parse_Rest_Of_List;
               end if;

               Target.List_To_Vector;

            when Tok_Start_Bytevector =>

               --  A literal, the way a vector written out is one, and
               --  for the same reason: #u8(1 2) read as a call of
               --  bytevector, so its elements were expressions.

               Lex.Scan;

               if Lex.Tok = Tok_Right_Paren then
                  Lex.Scan;
                  Target.Push_Nil;
               else
                  Parse_Rest_Of_List;
               end if;

               Target.List_To_Bytevector;

            when Tok_Character =>
               Target.Push (Raven.Objects.To_Object (Lex.Tok_Character_Value));
               Lex.Scan;

            when Tok_String =>

               --  One object, made here.  This used to read as the
               --  form that builds a string, which made another every
               --  time it was evaluated -- so a literal in a loop
               --  spent a foreign value on every turn.

               Target.Push (Target.Create_String (Lex.Tok_Text));
               Lex.Scan;

            when Tok_Quote =>
               Lex.Scan;
               Target.Push (Raven.Objects.Quote);
               Parse_Expression;
               Target.Push_Nil;
               Target.Cons;
               Target.Cons;

            when Tok_Quasiquote =>
               Lex.Scan;
               Target.Push (Target.To_Symbol ("quasiquote"));
               Parse_Expression;
               Target.Push_Nil;
               Target.Cons;
               Target.Cons;

            when Tok_Comma =>
               Lex.Scan;
               Target.Push (Target.To_Symbol ("unquote"));
               Parse_Expression;
               Target.Push_Nil;
               Target.Cons;
               Target.Cons;

            when Tok_Unquote_Splice =>
               Lex.Scan;
               Target.Push (Target.To_Symbol ("unquote-splicing"));
               Parse_Expression;
               Target.Push_Nil;
               Target.Cons;
               Target.Cons;

            when Tok_Integer =>

               --  Read wide, and a fixnum when it fits.  One that does
               --  not is a bignum, which the machine makes: it is the
               --  heap's, and the lexer has only the text.  It used to be
               --  refused (#99), and before that read into an Integer and
               --  overflowed on the way.

               declare
                  Value : constant Long_Long_Integer :=
                            Lex.Tok_Integer_Value;
               begin
                  if Value in
                    Raven.Objects.Min_Integer .. Raven.Objects.Max_Integer
                  then
                     Target.Push (Raven.Objects.To_Object (Integer (Value)));
                  else
                     Target.Push (Target.Read_Integer (Encode (Lex.Tok_Text)));
                  end if;
                  Lex.Scan;
               end;

            when Tok_Float =>

               --  Raven's float keeps every mantissa bit of a single
               --  and shortens the exponent, so what it cannot hold is
               --  a number too large or too small rather than one too
               --  precise.  Saying so here is the whole of what the
               --  encoding asks of the reader; it used to mask the
               --  bottom of the number off instead, and 0.1 read as a
               --  broken promise.

               declare
                  Value : constant Float := Lex.Tok_Float_Value;
               begin
                  if not Raven.Objects.Is_Representable (Value) then
                     Lex.Error
                       ("number out of range for a float: " & Lex.Tok_Text);
                     Lex.Scan;
                     Target.Push_Nil;
                  else
                     Target.Push (Raven.Objects.To_Object (Value));
                     Lex.Scan;
                  end if;
               end;
            when others =>
               Lex.Error ("bad token");
               Lex.Scan;
               Target.Push_Nil;
         end case;
      end Parse_Expression;

      ------------------------
      -- Parse_Rest_Of_List --
      ------------------------

      procedure Parse_Rest_Of_List is
         Start_Line : constant Natural := Lex.Current_Line;
      begin
         Parse_Expression;

         --  A datum comment after an element takes the next one out of
         --  the list, and what follows may then be the closing
         --  parenthesis -- which is why this is here and not only at
         --  the top of Parse_Expression.

         Skip_Datum_Comments;

         if Lex.Tok = Tok_Dot then
            Lex.Scan;
            Parse_Expression;
            if Lex.Tok = Tok_Right_Paren then
               Lex.Scan;
            else
               Lex.Error ("missing ')'");
            end if;
         elsif Lex.Tok = Tok_Right_Paren then
            Lex.Scan;
            Target.Push (Raven.Objects.Nil);
         elsif Lex.Tok = Tok_End_Of_File then
            Lex.Error ("Missing ')' in expression started on line"
                       & Natural'Wide_Wide_Image (Start_Line));
            Target.Push (Raven.Objects.Nil);
         else
            Parse_Rest_Of_List;
         end if;

         Target.Cons;
      end Parse_Rest_Of_List;

      --------------------------
      -- Skip_Datum_Comments --
      --------------------------

      procedure Skip_Datum_Comments is
      begin
         --  #; takes out the datum after it, whatever that datum turns
         --  out to be, so the only way to skip one is to read it and
         --  throw it away.  Several in a row take out several.

         while Lex.Tok = Tok_Datum_Comment loop
            Lex.Scan;
            Parse_Expression;
            Target.Drop;
         end loop;
      end Skip_Datum_Comments;

   begin
      --  What the lexer has to say goes where this target's host says
      --  errors go.  It had no way of reaching one and wrote to the
      --  terminal.

      Lex.Report_To (Target);

      Parse_Expression;
   end Parse_S_Expression;

   -----------
   -- Where --
   -----------

   function Where (This : Instance) return String is
      use Ada.Strings, Ada.Strings.Fixed;
   begin
      if This.Data = null then
         return "";
      end if;

      return This.Data.Lex.Current_File_Name
        & ":"
        & Trim (Natural'Image (This.Data.Lex.Current_Line), Left);
   end Where;

end Raven.Parser;
