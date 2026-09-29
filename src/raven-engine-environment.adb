with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Hash;
with Ada.Unchecked_Deallocation;
with Raven.Objects;

package body Raven.Engine.Environment is

   --  Names are compared as they are written, as symbols are (#160):
   --  this still folded case, so Foo and foo were one name here.

   package Object_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Object,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   type Instance is new Raven.Environment.Abstraction with
      record
         Parent : Raven.Environment.Reference;
         Map    : Object_Maps.Map;
      end record;

   type Environment_Reference is access all Instance'Class;

   overriding function Parent
     (This : Instance)
      return Raven.Environment.Reference
   is (This.Parent);

   overriding procedure Close
     (This  : not null access Instance);

   overriding procedure Mark
     (This : in out Instance;
      Process : not null access procedure (Value : in out Object));

   overriding function Lookup
     (This : Instance;
      Name : String)
      return Object;

   overriding procedure Define
     (This  : in out Instance;
      Name  : String;
      Value : Object);

   overriding procedure Insert
     (This  : in out Instance;
      Name  : String;
      Value : Object);

   overriding procedure Replace
     (This  : in out Instance;
      Name  : String;
      Value : Object);

   -----------
   -- Close --
   -----------

   overriding procedure Close
     (This  : not null access Instance)
   is
      procedure Free is
        new Ada.Unchecked_Deallocation
          (Instance'Class, Environment_Reference);
      Ref : Environment_Reference := Environment_Reference (This);
   begin
      Free (Ref);
   end Close;

   ------------
   -- Create --
   ------------

   function Create
     return Raven.Environment.Reference
   is
   begin
      return new Instance;
   end Create;

   ------------
   -- Create --
   ------------

   function Create
     (Parent : Raven.Environment.Reference)
      return Raven.Environment.Reference
   is
   begin
      return new Instance'(Parent => Parent, others => <>);
   end Create;

   ------------
   -- Define --
   ------------

   overriding procedure Define
     (This  : in out Instance;
      Name  : String;
      Value : Object)
   is
   begin
      This.Map.Include (Name, Value);
   end Define;

   ------------
   -- Insert --
   ------------

   overriding procedure Insert
     (This  : in out Instance;
      Name  : String;
      Value : Object)
   is
   begin
      This.Map.Insert (Name, Value);
   end Insert;

   ------------
   -- Lookup --
   ------------

   overriding function Lookup
     (This : Instance;
      Name : String)
      return Object
   is
      use Object_Maps;
      use type Raven.Environment.Reference;
      Position : constant Cursor := This.Map.Find (Name);
   begin
      if Has_Element (Position) then
         return Element (Position);
      elsif This.Parent /= null then
         return This.Parent.Lookup (Name);
      else
         return Raven.Objects.Undefined;
      end if;
   end Lookup;

   ----------
   -- Mark --
   ----------

   overriding procedure Mark
     (This : in out Instance;
      Process : not null access procedure (Value : in out Object))
   is
   begin
      --  What this holds, and no more.  A parent is marked by whoever
      --  holds it: every library shares one, and following it here
      --  would walk it once for each of them.

      for Item of This.Map loop
         Process (Item);
      end loop;
   end Mark;

   -------------
   -- Replace --
   -------------

   overriding procedure Replace
     (This  : in out Instance;
      Name  : String;
      Value : Object)
   is
      use Object_Maps;
      use type Raven.Environment.Reference;
      Position : constant Cursor := This.Map.Find (Name);
   begin
      if Has_Element (Position) then
         This.Map (Position) := Value;
      elsif This.Parent /= null then
         This.Parent.Replace (Name, Value);
      else
         raise Program_Error with
           "replace: undefined: " & Name;
      end if;
   end Replace;

end Raven.Engine.Environment;
