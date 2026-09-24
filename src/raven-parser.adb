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

      ----------------------
      -- Parse_Expression --
      ----------------------

      procedure Parse_Expression is
      begin
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
                  if Sym = "#t" then
                     Target.Push (Raven.Objects.To_Object (True));
                  elsif Sym = "#f" then
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
            when Tok_Start_Vector =>
               Lex.Scan;
               Target.Push
                 (Raven.Objects.To_Object
                    (Target.To_Symbol_Id ("vector")));
               Parse_Rest_Of_List;
               Target.Cons;

            when Tok_Start_Bytevector =>
               Lex.Scan;
               Target.Push
                 (Raven.Objects.To_Object
                    (Target.To_Symbol_Id ("bytevector")));
               Parse_Rest_Of_List;
               Target.Cons;

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
               Target.Push
                 (Raven.Objects.To_Object
                    (Lex.Tok_Integer_Value));
               Lex.Scan;

            when Tok_Float =>

               --  Raven's float keeps every mantissa bit of a single
               --  and shortens the exponent, so what it cannot hold is
               --  a number too large or too small rather than one too
               --  precise.  Saying so here is the whole of what the
               --  encoding asks of the reader; it used to mask the
               --  bottom of the number off instead, and 0.1 read as a
               --  broken promise.

               declare
                  Value : constant Float :=
                            Float'Wide_Wide_Value (Lex.Tok_Text);
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

   begin
      Parse_Expression;
   end Parse_S_Expression;

end Raven.Parser;
