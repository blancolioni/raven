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

   type Instance (Length : Natural) is
     new Foreign_Value_Instance with
      record
         Value : Wide_Wide_String (1 .. Length);
      end record;

   overriding function Show (This : Instance) return String;
   overriding function Display (This : Instance) return String;

   overriding function Equal
     (This : Instance;
      To   : Instance)
      return Boolean
   is (This.Value = To.Value);

end Raven.Strings;
