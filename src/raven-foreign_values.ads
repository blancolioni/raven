--  A foreign value whose content is a pointer to the host's own value.
--
--  This is the shape nearly every host wants: a concrete type holding
--  an access and nothing else, with everything interesting behind it.
--  Deriving from Foreign_Value_Instance by hand meant writing the same
--  type every time, and getting a value back meant a membership test
--  and a view conversion in every accessor -- the part a host gets
--  wrong.  An instantiation declares the type, forwards to the four
--  subprograms it is given, and does the membership test once.
--
--  All four are required, with "is <>": each is a claim a host should
--  make on purpose.  Forgetting Mark when the payload holds objects of
--  the program's corrupts the heap; forgetting Free leaks; and a Show
--  or Equal that says nothing useful is still better written down than
--  assumed.  A payload holding nothing of the program's has a Mark
--  that does nothing, and saying so is the point.
--
--  Equal is given the two accesses rather than what they point at, so
--  that identity is one of the things it can say: "is (Left = Right)".

generic
   type Payload (<>) is limited private;
   type Payload_Access is access Payload;

   --  What the payload holds that the collector must know about: each
   --  object in it, handed to Process and written back, because the
   --  collector moves what it copies.

   with procedure Mark
     (Item    : in out Payload;
      Process : not null access procedure (Value : in out Object)) is <>;

   --  Told when the collector has given the value up, or its VM has
   --  closed; the payload is the host's to give back, and Item should be
   --  left null.

   with procedure Free (Item : in out Payload_Access) is <>;

   --  Show_Object shows an object the payload holds the way the machine
   --  is showing this value; Equal_Object is equal? on two objects.

   with function Show
     (Item        : Payload;
      Show_Object : not null access function (X : Object) return String)
      return String is <>;

   with function Equal
     (Left, Right  : Payload_Access;
      Equal_Object : not null access function (X, Y : Object) return Boolean)
      return Boolean is <>;

package Raven.Foreign_Values is

   --  A new foreign value standing for Value, in this slot.  From here
   --  the value is the machine's to keep and to give up: Free is called
   --  when nothing names it any more.

   procedure Set_Slot
     (VM    : Raven_VM;
      Index : Slot_Index;
      Value : not null Payload_Access);

   --  Whether the slot holds a value of this instantiation's kind, and
   --  the payload of one that does.  Get_Slot of anything else raises,
   --  and says what the slot held instead.

   function Is_Mine
     (VM    : Raven_VM;
      Index : Slot_Index)
      return Boolean;

   function Get_Slot
     (VM    : Raven_VM;
      Index : Slot_Index)
      return not null Payload_Access;

private

   type Instance is new Foreign_Value_Instance with
      record
         Item : Payload_Access;
      end record;

   overriding procedure Mark
     (This    : in out Instance;
      Process : not null access procedure (Value : in out Object));

   overriding procedure Free (This : in out Instance);

   overriding function Show
     (This        : Instance;
      Show_Object : not null access function (X : Object) return String)
      return String;

   overriding function Equal
     (This         : Instance;
      To           : Instance;
      Equal_Object : not null access function (X, Y : Object) return Boolean)
      return Boolean;

end Raven.Foreign_Values;
