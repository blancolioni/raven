package body Raven.Foreign_Values is

   --  The payload of the value in this slot, or null if the slot holds
   --  anything else.  It looks at the value where it is, through
   --  Query_Foreign_Value, rather than copying it out to ask.

   function Payload_Of
     (VM    : Raven_VM;
      Index : Slot_Index)
      return Payload_Access;

   -----------
   -- Equal --
   -----------

   overriding function Equal
     (This         : Instance;
      To           : Instance;
      Equal_Object : not null access function (X, Y : Object) return Boolean)
      return Boolean
   is (Equal (This.Item, To.Item, Equal_Object));

   ----------
   -- Free --
   ----------

   overriding procedure Free (This : in out Instance) is
   begin
      if This.Item /= null then
         Free (This.Item);
      end if;
   end Free;

   --------------
   -- Get_Slot --
   --------------

   function Get_Slot
     (VM    : Raven_VM;
      Index : Slot_Index)
      return not null Payload_Access
   is
      Item : constant Payload_Access := Payload_Of (VM, Index);
   begin
      if Item = null then
         raise Constraint_Error with
           "slot" & Index'Image & " holds " & VM.Show_Slot (Index)
           & ", which is not a value of this kind";
      end if;

      return Item;
   end Get_Slot;

   -------------
   -- Is_Mine --
   -------------

   function Is_Mine
     (VM    : Raven_VM;
      Index : Slot_Index)
      return Boolean
   is (Payload_Of (VM, Index) /= null);

   ----------
   -- Mark --
   ----------

   overriding procedure Mark
     (This    : in out Instance;
      Process : not null access procedure (Value : in out Object))
   is
   begin
      if This.Item /= null then
         Mark (This.Item.all, Process);
      end if;
   end Mark;

   ----------------
   -- Payload_Of --
   ----------------

   function Payload_Of
     (VM    : Raven_VM;
      Index : Slot_Index)
      return Payload_Access
   is
      Result : Payload_Access := null;

      procedure Look (Item : Foreign_Value_Instance'Class);

      ----------
      -- Look --
      ----------

      procedure Look (Item : Foreign_Value_Instance'Class) is
      begin
         if Item in Instance'Class then
            Result := Instance'Class (Item).Item;
         end if;
      end Look;

   begin
      if VM.Kind (Index) = Foreign_Kind then
         VM.Query_Foreign_Value (VM.Get_Slot (Index), Look'Access);
      end if;

      return Result;
   end Payload_Of;

   --------------
   -- Set_Slot --
   --------------

   procedure Set_Slot
     (VM    : Raven_VM;
      Index : Slot_Index;
      Value : not null Payload_Access)
   is
   begin
      VM.Set_Slot
        (Index,
         VM.Create_Foreign_Value
           (Instance'(Foreign_Value_Instance with Item => Value)));
   end Set_Slot;

   ----------
   -- Show --
   ----------

   overriding function Show
     (This        : Instance;
      Show_Object : not null access function (X : Object) return String)
      return String
   is (Show (This.Item.all, Show_Object));

end Raven.Foreign_Values;
