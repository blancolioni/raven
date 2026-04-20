with Raven.Evaluator;

private package Raven.Strings is

   type Instance (<>) is
     new Foreign_Value_Instance with private;

   procedure Load_String_Library
     (Evaluator : not null access Raven.Evaluator.Abstraction'Class);

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

   overriding function Equal
     (This : Instance;
      To   : Instance)
      return Boolean
   is (This.Value = To.Value);

end Raven.Strings;
