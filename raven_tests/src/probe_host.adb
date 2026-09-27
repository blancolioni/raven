with Ada.Unchecked_Deallocation;

with Raven.Foreign_Values;

package body Probe_Host is

   use Raven;

   --  Two objects of the program's, held by something of the host's.
   --  The host's own type, in the host's own memory; what makes it a
   --  foreign value is the instantiation below, and nothing else.

   type Couple is
      record
         Left  : Object;
         Right : Object;
      end record;

   type Couple_Access is access Couple;

   --  The four an instantiation asks for, each of them said on purpose.

   function Equal
     (Left, Right  : Couple_Access;
      Equal_Object : not null access function (X, Y : Object) return Boolean)
      return Boolean;

   procedure Free (Item : in out Couple_Access);

   procedure Mark
     (Item    : in out Couple;
      Process : not null access procedure (Value : in out Object));

   function Show
     (Item        : Couple;
      Show_Object : not null access function (X : Object) return String)
      return String;

   package Couples is
     new Raven.Foreign_Values (Couple, Couple_Access);

   Freed : Natural := 0;

   --  Calling back into the program: a procedure and its arguments,
   --  applied from inside a foreign function, which is where a host is
   --  when a program has handed it something to call.  Try is the same
   --  with the failure caught, to say the program can go on after it.

   procedure Apply_One (VM : Raven_VM);
   procedure Apply_Two (VM : Raven_VM);
   procedure Try_Apply (VM : Raven_VM);

   procedure Is_Couple (VM : Raven_VM);
   procedure Left_Of (VM : Raven_VM);
   procedure Make (VM : Raven_VM);
   procedure Right_Of (VM : Raven_VM);

   ---------------
   -- Apply_One --
   ---------------

   procedure Apply_One (VM : Raven_VM) is
   begin
      VM.Slot_Apply (1, 1);
   end Apply_One;

   ---------------
   -- Apply_Two --
   ---------------

   procedure Apply_Two (VM : Raven_VM) is
   begin
      VM.Slot_Apply (1, 2);
   end Apply_Two;

   ----------
   -- Bind --
   ----------

   procedure Bind (VM : Raven.Raven_VM) is
   begin
      VM.Bind_Foreign_Function ("probe-couple", Make'Access, 2);
      VM.Bind_Foreign_Function ("probe-left", Left_Of'Access, 1);
      VM.Bind_Foreign_Function ("probe-right", Right_Of'Access, 1);
      VM.Bind_Foreign_Function ("probe-couple?", Is_Couple'Access, 1);
      VM.Bind_Foreign_Function ("probe-apply", Apply_One'Access, 2);
      VM.Bind_Foreign_Function ("probe-apply2", Apply_Two'Access, 3);
      VM.Bind_Foreign_Function ("probe-try", Try_Apply'Access, 2);
   end Bind;

   -------------------
   -- Couples_Freed --
   -------------------

   function Couples_Freed return Natural
   is (Freed);

   -----------
   -- Equal --
   -----------

   --  Equal when what they hold is, as equal? would say.

   function Equal
     (Left, Right  : Couple_Access;
      Equal_Object : not null access function (X, Y : Object) return Boolean)
      return Boolean
   is (Equal_Object (Left.Left, Right.Left)
       and then Equal_Object (Left.Right, Right.Right));

   ----------
   -- Free --
   ----------

   procedure Free (Item : in out Couple_Access) is
      procedure Deallocate is
        new Ada.Unchecked_Deallocation (Couple, Couple_Access);
   begin
      Freed := Freed + 1;
      Deallocate (Item);
   end Free;

   ---------------
   -- Is_Couple --
   ---------------

   procedure Is_Couple (VM : Raven_VM) is
   begin
      VM.Set_Slot (1, Couples.Is_Mine (VM, 1));
   end Is_Couple;

   -------------
   -- Left_Of --
   -------------

   procedure Left_Of (VM : Raven_VM) is
   begin
      VM.Set_Slot (1, Couples.Get_Slot (VM, 1).Left);
   end Left_Of;

   ----------
   -- Make --
   ----------

   procedure Make (VM : Raven_VM) is

      --  The couple is made in the host's memory, which does not
      --  collect, with the two objects read out of their slots as the
      --  last thing before it is handed over.  Handing it over collects
      --  only when every foreign value id is taken -- sixteen million
      --  live at once -- and then the two would be moved from under it.

      Item : constant Couple_Access :=
               new Couple'(Left => VM.Get_Slot (1), Right => VM.Get_Slot (2));
   begin
      Couples.Set_Slot (VM, 1, Item);
   end Make;

   ----------
   -- Mark --
   ----------

   procedure Mark
     (Item    : in out Couple;
      Process : not null access procedure (Value : in out Object))
   is
   begin
      Process (Item.Left);
      Process (Item.Right);
   end Mark;

   --------------
   -- Right_Of --
   --------------

   procedure Right_Of (VM : Raven_VM) is
   begin
      VM.Set_Slot (1, Couples.Get_Slot (VM, 1).Right);
   end Right_Of;

   ----------
   -- Show --
   ----------

   function Show
     (Item        : Couple;
      Show_Object : not null access function (X : Object) return String)
      return String
   is ("#<couple " & Show_Object (Item.Left)
       & " " & Show_Object (Item.Right) & ">");

   ---------------
   -- Try_Apply --
   ---------------

   procedure Try_Apply (VM : Raven_VM) is
   begin
      VM.Slot_Apply (1, 1);
   exception
      when Constraint_Error =>
         VM.Set_Slot_Symbol (1, "failed");
   end Try_Apply;

end Probe_Host;
