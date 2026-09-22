with Ada.Exceptions;
with Ada.Text_IO;
with Raven.Objects;
with Raven.Parser.Tokens;             use Raven.Parser.Tokens;
with Raven.Parser.Lexical;            use Raven.Parser.Lexical;

package body Raven.Parser is

   procedure Parse_S_Expression
     (Lex    : in out Raven.Parser.Lexical.Instance'Class;
      Target : Raven.Target.Reference);

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

   -----------------
   -- Load_Module --
   -----------------

   procedure Load_Module
     (Name   : String;
      Source : String;
      Target : Raven.Target.Reference)
   is
      Lex : Raven.Parser.Lexical.Instance;
   begin
      Lex.Open (Name, Decode (Source));
      while Lex.Tok /= Tok_End_Of_File loop
         begin
            Parse_S_Expression (Lex, Target);
            Target.Translate;
            Target.Execute;
            Target.Drop;
         exception
            when E : Raven.Target.Undefined_Symbol =>
               Ada.Text_IO.Put_Line
                 (Ada.Text_IO.Standard_Error,
                  "undefined: " & Ada.Exceptions.Exception_Message (E));
         end;
      end loop;
      Lex.Close;
   end Load_Module;

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
               Target.Push
                 (Raven.Objects.To_Object
                    (Target.To_Symbol_Id ("list->string")));
               Target.Push (Raven.Objects.Quote);
               for Ch of Lex.Tok_Text loop
                  Target.Push (Raven.Objects.To_Object (Ch));
               end loop;
               Target.Push_Nil;
               for I in 1 .. Lex.Tok_Text'Length loop
                  Target.Cons;
               end loop;
               Target.Push_Nil;
               Target.Cons;
               Target.Cons;
               Target.Push_Nil;
               Target.Cons;
               Target.Cons;
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
               Target.Push
                 (Raven.Objects.To_Object
                    (Float'Wide_Wide_Value (Lex.Tok_Text)));
               Lex.Scan;
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
