with Raven.Objects;

package body Raven.Stacks is

   ----------
   -- Drop --
   ----------

   procedure Drop
     (This : in out Abstraction'Class)
   is
      X : Object;
   begin
      This.Pop (X);
   end Drop;

   ---------
   -- Pop --
   ---------

   function Pop
     (This : in out Abstraction'Class)
      return Object
   is
      Value : Object;
   begin
      This.Pop (Value);
      return Value;
   end Pop;

   --------------
   -- Push_Nil --
   --------------

   procedure Push_Nil
     (This  : in out Abstraction'Class)
   is
   begin
      This.Push (Raven.Objects.Nil);
   end Push_Nil;

end Raven.Stacks;
