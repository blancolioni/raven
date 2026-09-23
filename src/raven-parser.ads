with Raven.Target;

private package Raven.Parser is

   procedure Parse_Expression
     (Expression : String;
      Target     : Raven.Target.Reference);

   --  A source read one form at a time.  The loop that read a whole
   --  file used to live here, and that left nowhere for a declaration
   --  to be acted on between one form and the next: an import has to
   --  take effect before the forms that use what it brings in.

   type Instance is tagged limited private;

   procedure Open
     (This   : in out Instance;
      Name   : String;
      Source : String);

   function At_End (This : Instance) return Boolean;

   --  Reads the next form and leaves it on the target's stack.  It
   --  stays there because the caller has nowhere of its own to keep an
   --  object across an allocation, and the stack is a collection root.

   procedure Parse_Next
     (This   : in out Instance;
      Target : Raven.Target.Reference)
     with Pre => not This.At_End;

   procedure Close (This : in out Instance);

private

   --  The lexer is a child of this package, so its type cannot be
   --  named here.  What is being read lives in the body instead.

   type Source_Record;

   type Source_Access is access Source_Record;

   type Instance is tagged limited
      record
         Data : Source_Access;
      end record;

end Raven.Parser;
