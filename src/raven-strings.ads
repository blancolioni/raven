with Raven.Evaluator;

private package Raven.Strings is

   type Instance (<>) is
     new Foreign_Value_Instance with private;

   procedure Load_String_Library
     (Evaluator : not null access Raven.Evaluator.Abstraction'Class);

   --  A string object holding this text.  The reader makes one when it
   --  reads a string, so that a string written in the source is an
   --  object rather than a form that builds one every time it is
   --  evaluated.

   function To_Value (Text : Wide_Wide_String) return Instance;

   --  Whether a foreign value is a string, and the characters of one
   --  without the quotation marks Show puts round them.

   function Is_String (From : Foreign_Value_Instance'Class) return Boolean;

   function Text (From : Foreign_Value_Instance'Class) return String
     with Pre => Is_String (From);

   --  Whether a string is held a byte to a character, which it is when
   --  every character in it fits in one.  It is for the tests: nothing
   --  else needs to know, because nothing else can tell.

   function Is_Narrow (From : Foreign_Value_Instance'Class) return Boolean
     with Pre => Is_String (From);

   procedure Write_String
     (VM   : Raven_VM;
      Slot : Slot_Index;
      S    : String);

   function Is_String
     (VM   : Raven_VM;
      Slot : Slot_Index)
      return Boolean;

   function Get_String
     (VM   : Raven_VM;
      Slot : Slot_Index)
      return String;

private

   --  A string is held a byte to a character when every character in
   --  it is Latin-1, which in the ordinary case is all of them, and four
   --  bytes to a character only when one is not.  Strings do not change
   --  once made, so which it is is decided once, by To_Value, and every
   --  string is made by To_Value.  That makes the choice depend only on
   --  the characters, so two strings with the same characters are held
   --  the same way and Equal can compare them as they are.
   --
   --  The line is Latin-1 rather than UTF-8 because a byte holds it
   --  exactly: a character is still found by an index, which string-ref
   --  depends on, where UTF-8 would have to walk to it.

   type Instance (Wide : Boolean; Length : Natural) is
     new Foreign_Value_Instance with
      record
         case Wide is
            when False =>
               Narrow : String (1 .. Length);
            when True =>
               Value  : Wide_Wide_String (1 .. Length);
         end case;
      end record;

   --  A string holds nothing of the machine's, so neither is asked of
   --  the callbacks the machine hands over.

   overriding function Show
     (This        : Instance;
      Show_Object : not null access function (X : Object) return String)
      return String;

   overriding function Display
     (This        : Instance;
      Show_Object : not null access function (X : Object) return String)
      return String;

   overriding function Equal
     (This         : Instance;
      To           : Instance;
      Equal_Object : not null access function (X, Y : Object) return Boolean)
      return Boolean
   is (This.Wide = To.Wide
       and then This.Length = To.Length
       and then (if This.Wide
                 then This.Value = To.Value
                 else This.Narrow = To.Narrow));

end Raven.Strings;
