package body Probe_Host is

   use Raven;

   --  Two objects of the program's, held by something of the host's.

   type Couple is new Foreign_Value_Instance with
      record
         Left  : Object;
         Right : Object;
      end record;

   overriding function Show (This : Couple) return String;

   overriding function Equal
     (This : Couple;
      To   : Couple)
      return Boolean
   is (This.Left = To.Left and then This.Right = To.Right);

   overriding procedure Mark
     (This    : in out Couple;
      Process : not null access procedure (Value : in out Object));

   procedure Make (VM : Raven_VM);
   procedure Left_Of (VM : Raven_VM);
   procedure Right_Of (VM : Raven_VM);

   ----------
   -- Bind --
   ----------

   procedure Bind (VM : Raven.Raven_VM) is
   begin
      VM.Bind_Foreign_Function ("probe-couple", Make'Access, 2);
      VM.Bind_Foreign_Function ("probe-left", Left_Of'Access, 1);
      VM.Bind_Foreign_Function ("probe-right", Right_Of'Access, 1);
   end Bind;

   -------------
   -- Left_Of --
   -------------

   procedure Left_Of (VM : Raven_VM) is
      Value : constant Foreign_Value_Instance'Class :=
                VM.To_Foreign_Value (VM.Get_Slot (1));
   begin
      VM.Set_Slot (1, Couple'Class (Value).Left);
   end Left_Of;

   ----------
   -- Make --
   ----------

   procedure Make (VM : Raven_VM) is

      --  Both arguments are taken out of their slots before anything
      --  is made, because making the value allocates and an object in
      --  an Ada variable is not somewhere the collector looks.

      Left  : constant Object := VM.Get_Slot (1);
      Right : constant Object := VM.Get_Slot (2);
   begin
      VM.Set_Slot
        (1,
         VM.Create_Foreign_Value
           (Couple'(Foreign_Value_Instance with Left, Right)));
   end Make;

   ----------
   -- Mark --
   ----------

   overriding procedure Mark
     (This    : in out Couple;
      Process : not null access procedure (Value : in out Object))
   is
   begin
      Process (This.Left);
      Process (This.Right);
   end Mark;

   --------------
   -- Right_Of --
   --------------

   procedure Right_Of (VM : Raven_VM) is
      Value : constant Foreign_Value_Instance'Class :=
                VM.To_Foreign_Value (VM.Get_Slot (1));
   begin
      VM.Set_Slot (1, Couple'Class (Value).Right);
   end Right_Of;

   ----------
   -- Show --
   ----------

   overriding function Show (This : Couple) return String is
      pragma Unreferenced (This);
   begin
      --  Show is given no VM, so this cannot say what it holds.  That
      --  is the other half of the same omission and is its own issue.

      return "#couple";
   end Show;

end Probe_Host;
