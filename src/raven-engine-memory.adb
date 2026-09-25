with Ada.Calendar;
with Ada.Containers.Indefinite_Doubly_Linked_Lists;
with Ada.Containers.Vectors;
with Ada.Text_IO;

with Raven.Containers;
with Raven.Objects;

package body Raven.Engine.Memory is

   Stress_GC : constant Boolean := False;

   type Cell_Array is
     array (Address_Type range <>) of Raven.Memory.Cell_Type;

   type Container_Reference is access all Raven.Containers.Abstraction'Class;

   package Container_Lists is
     new Ada.Containers.Doubly_Linked_Lists (Container_Reference);

   package Foreign_Value_Lists is
     new Ada.Containers.Indefinite_Doubly_Linked_Lists
       (Foreign_Value_Instance'Class);

   package Foreign_Value_Vectors is
     new Ada.Containers.Vectors
       (Raven.Objects.Foreign_Value_Id,
        Foreign_Value_Lists.Cursor, Foreign_Value_Lists."=");

   --  The ids the collector has given back, so that finding one is
   --  taking the last rather than looking through all of them.

   package Free_Id_Vectors is
     new Ada.Containers.Vectors
       (Positive, Raven.Objects.Foreign_Value_Id, Raven.Objects."=");

   type Instance (Last : Address_Type) is new Raven.Memory.Abstraction with
      record
         Top               : Address_Type;
         Free              : Address_Type;
         From_Space        : Address_Type;
         To_Space          : Address_Type;
         Space_Size        : Address_Type;
         Scan              : Address_Type;
         Containers        : Container_Lists.List;
         Alloc_Car         : Object;
         Alloc_Cdr         : Object;
         Trace_GC          : Boolean := False;
         Alloc_Count       : Natural := 0;
         Active_Cells      : Natural := 0;
         Max_Active_Cells  : Natural := 0;
         Total_Alloc_Count : Natural := 0;
         Reclaimed         : Natural := 0;
         GC_Time           : Duration := 0.0;
         GC_Count          : Natural := 0;
         Value_List        : Foreign_Value_Lists.List;
         Value_Ids         : Foreign_Value_Vectors.Vector;
         Free_Ids          : Free_Id_Vectors.Vector;

         Core              : Cell_Array (0 .. Last);
      end record;

   overriding procedure Add_Container
     (This      : in out Instance;
      Container : not null access Raven.Containers.Abstraction'Class);

   overriding function Create_Foreign_Value
     (This  : in out Instance;
      Value : Foreign_Value_Instance'Class)
      return Object;

   overriding function To_Foreign_Value
     (This : Instance;
      Value : Object)
      return Foreign_Value_Instance'Class
   is (Foreign_Value_Lists.Element
       (This.Value_Ids (Objects.To_Foreign_Value_Id (Value))));

   overriding function Get
     (This    : Instance;
      Address : Address_Type)
      return Raven.Memory.Cell_Type
   is (This.Core (Address));

   overriding procedure Set
     (This    : in out Instance;
      Address : Address_Type;
      Cell    : Raven.Memory.Cell_Type);

   overriding function Cons
     (This : in out Instance;
      Car  : Object;
      Cdr  : Object)
      return Object;

   overriding function New_Vector
     (This   : in out Instance;
      Length : Natural)
      return Object;

   overriding function New_Bytevector
     (This   : in out Instance;
      Length : Natural)
      return Object;

   overriding function Vector_Length
     (This : Instance;
      V    : Object)
      return Natural;

   overriding function Vector_Element
     (This  : Instance;
      V     : Object;
      Index : Natural)
      return Object;

   overriding procedure Set_Vector_Element
     (This  : in out Instance;
      V     : Object;
      Index : Natural;
      Value : Object);

   overriding procedure Mark
     (This : in out Instance;
      Item : in out Object);

   overriding procedure Report (This : Instance);

   function Quick_Allocate
     (This   : in out Instance'Class;
      Car    : Object;
      Cdr    : Object)
      return Object;

   --  How many cells a vector of this many elements takes: one for
   --  the length, and then the elements two to a cell.  A vector of
   --  none is the header alone.

   function Cells_For (Length : Natural) return Address_Type
   is (Address_Type (1 + (Length + 1) / 2));

   function Allocate_Block
     (This  : in out Instance'Class;
      Count : Address_Type)
      return Address_Type;

   function Copy_Block
     (This    : in out Instance'Class;
      Address : Address_Type;
      Count   : Address_Type)
      return Address_Type;

   --  Where an element sits: the cell after the header it falls in,
   --  and which half of that cell.

   function Element_Cell
     (V     : Object;
      Index : Natural)
      return Address_Type
   is (Raven.Objects.Get_Address (V) + 1 + Address_Type (Index / 2));

   function In_From_Space
     (This   : Instance'Class;
      Item   : Object)
      return Boolean;

   function In_To_Space
     (This   : Instance'Class;
      Item   : Object)
      return Boolean;

   function Copy
     (This    : in out Instance'Class;
      Address : Address_Type)
      return Address_Type;

   function Move
     (This : in out Instance'Class;
      Item : Object)
      return Object;

   procedure Flip (This : in out Instance'Class);

   function Free_And_Allocate
     (This   : in out Instance'Class;
      Car    : Object;
      Cdr    : Object)
      return Object;

   procedure GC
     (This : in out Instance'Class);

   procedure Trace_GC
     (This    : in out Instance'Class;
      Enabled : Boolean)
     with Unreferenced;

   -------------------
   -- Add_Container --
   -------------------

   overriding procedure Add_Container
     (This      : in out Instance;
      Container : not null access Raven.Containers.Abstraction'Class)
   is
   begin
      This.Containers.Append (Container_Reference (Container));
   end Add_Container;

   ----------
   -- Cons --
   ----------

   overriding function Cons
     (This : in out Instance;
      Car  : Object;
      Cdr  : Object)
      return Object
   is (if not Stress_GC and then This.Free < This.Top
       then This.Quick_Allocate (Car, Cdr)
       else This.Free_And_Allocate (Car, Cdr));

   -----------------------
   -- Free_And_Allocate --
   -----------------------

   function Free_And_Allocate
     (This   : in out Instance'Class;
      Car    : Object;
      Cdr    : Object)
      return Object
   is
   begin
      This.Alloc_Car := Car;
      This.Alloc_Cdr := Cdr;

      GC (This);

      if This.Free = This.Top then
         raise Constraint_Error with "out of memory";
      end if;

      return Quick_Allocate (This, This.Alloc_Car, This.Alloc_Cdr);
   end Free_And_Allocate;

   --------------------
   -- Allocate_Block --
   --------------------

   function Allocate_Block
     (This  : in out Instance'Class;
      Count : Address_Type)
      return Address_Type
   is
      Base : Address_Type;
   begin
      --  Written as what is left rather than as Free + Count, because
      --  an address wraps and the sum of two of them says nothing.

      if Stress_GC or else Count > This.Top - This.Free then
         GC (This);
      end if;

      if Count > This.Top - This.Free then
         raise Constraint_Error with
           "out of memory: a vector wants" & Count'Image
           & " cells and there are"
           & Address_Type'Image (This.Top - This.Free);
      end if;

      Base := This.Free;
      This.Free := This.Free + Count;
      This.Alloc_Count := This.Alloc_Count + Natural (Count);
      This.Total_Alloc_Count := @ + Natural (Count);
      return Base;
   end Allocate_Block;

   ----------
   -- Copy --
   ----------

   function Copy
     (This    : in out Instance'Class;
      Address : Address_Type)
      return Address_Type
   is
   begin
      return Result : constant Address_Type := This.Free do
         This.Core (This.Free) := This.Core (Address);
         This.Free := This.Free + 1;
      end return;
   end Copy;

   ----------------
   -- Copy_Block --
   ----------------

   --  The same as Copy and as many cells as it is told.  It does not
   --  ask whether there is room, for the same reason Copy does not:
   --  what is being copied was live in from-space, and to-space is
   --  the same size.

   function Copy_Block
     (This    : in out Instance'Class;
      Address : Address_Type;
      Count   : Address_Type)
      return Address_Type
   is
      Base : constant Address_Type := This.Free;
   begin
      for Offset in 0 .. Count - 1 loop
         This.Core (Base + Offset) := This.Core (Address + Offset);
      end loop;

      This.Free := This.Free + Count;
      return Base;
   end Copy_Block;

   ------------
   -- Create --
   ------------

   function Create
     (Size      : Natural)
      return Raven.Memory.Reference
   is
      Top_Address : constant Address_Type := Address_Type (Size - 1);
      Space_Size  : constant Address_Type := Address_Type (Size / 2);
      To_Space    : constant Address_Type := 0;
      From_Space  : constant Address_Type := Space_Size;

      Mem : constant Raven.Memory.Reference :=
              new Instance'
                (Last              => Top_Address,
                 Core              => <>,
                 Top               => To_Space + Space_Size,
                 Free              => To_Space,
                 From_Space        => From_Space,
                 To_Space          => To_Space,
                 Space_Size        => Space_Size,
                 others            => <>);
   begin
      --  A closure names a cell with twenty four bits where a pair
      --  does it with thirty, so a heap past that could hold a
      --  procedure no procedure object could point at.  Said here
      --  rather than left to truncate a pointer quietly.

      if Size > Raven.Objects.Max_Addressable_Cells then
         raise Constraint_Error with
           "heap of" & Size'Image & " cells asked for, and"
           & Natural'Image (Raven.Objects.Max_Addressable_Cells)
           & " is the most a closure can name";
      end if;

      return Mem;
   end Create;

   --------------------------
   -- Create_Foreign_Value --
   --------------------------

   overriding function Create_Foreign_Value
     (This  : in out Instance;
      Value : Foreign_Value_Instance'Class)
      return Object
   is
      use Raven.Objects;
      use Foreign_Value_Lists;

      function Take_Id (Id : out Foreign_Value_Id) return Boolean;

      -------------
      -- Take_Id --
      -------------

      function Take_Id (Id : out Foreign_Value_Id) return Boolean is
      begin
         if not This.Free_Ids.Is_Empty then
            Id := This.Free_Ids.Last_Element;
            This.Free_Ids.Delete_Last;
            return True;
         elsif This.Value_Ids.Last_Index < Foreign_Value_Id'Last then
            This.Value_Ids.Append (No_Element);
            Id := This.Value_Ids.Last_Index;
            return True;
         else
            Id := Foreign_Value_Id'First;
            return False;
         end if;
      end Take_Id;

      Id : Foreign_Value_Id;
   begin
      --  Running out is worth a collection before it is worth an
      --  error: nothing else collects on account of foreign values,
      --  and the ids a program is finished with are given back there.

      if not Take_Id (Id) then
         GC (This);

         if not Take_Id (Id) then
            --  Short enough to survive: an exception message is cut
            --  off at two hundred characters.

            raise Constraint_Error with
              "out of foreign values: all"
              & Foreign_Value_Id'Last'Image
              & " live after a collection."
              & "  Every string is one -- a literal, or the result of"
              & " string-append, list->string or display.";
         end if;
      end if;

      This.Value_List.Append (Value);
      This.Value_Ids (Id) := This.Value_List.Last;

      return To_Object (Id);

   end Create_Foreign_Value;

   ----------
   -- Flip --
   ----------

   procedure Flip (This : in out Instance'Class) is
      Original_To_Space : constant Address_Type := This.To_Space;
   begin
      This.To_Space := This.From_Space;
      This.From_Space := Original_To_Space;
      This.Top := This.To_Space + This.Space_Size;
      This.Free := This.To_Space;
      This.Scan := This.To_Space;
   end Flip;

   --------
   -- GC --
   --------

   procedure GC
     (This : in out Instance'Class)
   is
      use Ada.Calendar;
      Start           : constant Time := Clock;
      Old_Alloc_Count : constant Natural := This.Alloc_Count;
   begin

      for Container of This.Containers loop
         Container.Before_Collection;
      end loop;

      for Value of This.Value_List loop
         Value.Marked := False;
      end loop;

      This.Flip;

      declare
         procedure Mark (Item : in out Object);

         ----------
         -- Mark --
         ----------

         procedure Mark (Item : in out Object) is
         begin
            Item := This.Move (Item);
         end Mark;
      begin
         for Container of This.Containers loop
            Container.Mark (Mark'Access);
         end loop;
      end;

      This.Alloc_Car := This.Move (This.Alloc_Car);
      This.Alloc_Cdr := This.Move (This.Alloc_Cdr);

      while This.Scan < This.Free loop
         declare
            Cell renames This.Core (This.Scan);
            New_Car : constant Object := Move (This, Cell.Car);
            New_Cdr : constant Object := Move (This, Cell.Cdr);
         begin
            Cell := (New_Car, New_Cdr);
            This.Scan := @ + 1;
         end;
      end loop;

      This.Alloc_Count := Natural (This.Scan - This.To_Space);
      This.Max_Active_Cells := Natural'Max (@, This.Alloc_Count);
      This.Active_Cells := This.Alloc_Count;
      This.Reclaimed := @ + Old_Alloc_Count - This.Alloc_Count;
      This.GC_Time := @ + Clock - Start;
      This.GC_Count := @ + 1;

      for Container of This.Containers loop
         Container.After_Collection;
      end loop;

      for Id in 1 .. This.Value_Ids.Last_Index loop
         declare
            Val : Foreign_Value_Lists.Cursor := This.Value_Ids (Id);
         begin
            if Foreign_Value_Lists.Has_Element (Val)
              and then not Foreign_Value_Lists.Element (Val).Marked
            then
               --  Free is what a foreign value holding something of
               --  the host's is told by, and it was never called: the
               --  value was deleted and whatever it stood for was
               --  left.  A string has nothing to give back and did
               --  not notice; a port has a file.

               This.Value_List (Val).Free;
               This.Value_List.Delete (Val);
               This.Value_Ids (Id) := Foreign_Value_Lists.No_Element;
               This.Free_Ids.Append (Id);
            end if;
         end;
      end loop;

      if This.Trace_GC then
         Ada.Text_IO.Put
           ("[GC"
            & Integer'Image (-This.GC_Count)
            & Integer'Image (-This.Alloc_Count)
            & "]");
      end if;
   end GC;

   -------------------
   -- In_From_Space --
   -------------------

   function In_From_Space
     (This   : Instance'Class;
      Item   : Object)
      return Boolean
   is
   begin
      return Raven.Objects.Has_Address (Item)
        and then Raven.Objects.Get_Address (Item)
      in This.From_Space .. This.From_Space + This.Space_Size - 1;
   end In_From_Space;

   -----------------
   -- In_To_Space --
   -----------------

   function In_To_Space
     (This   : Instance'Class;
      Item   : Object)
      return Boolean
   is
   begin
      return Raven.Objects.Has_Address (Item)
        and then Raven.Objects.Get_Address (Item)
      in This.To_Space .. This.To_Space + This.Space_Size - 1;
   end In_To_Space;

   ----------
   -- Mark --
   ----------

   overriding procedure Mark
     (This : in out Instance;
      Item : in out Object)
   is
   begin
      Item := This.Move (Item);
   end Mark;

   ----------
   -- Move --
   ----------

   function Move
     (This : in out Instance'Class;
      Item : Object)
      return Object
   is
   begin
      if Objects.Is_Foreign_Value (Item) then
         declare
            Id : constant Raven.Objects.Foreign_Value_Id :=
                   Objects.To_Foreign_Value_Id (Item);
            Position : constant Foreign_Value_Lists.Cursor :=
                         This.Value_Ids (Id);
            Value    : Foreign_Value_Instance'Class renames
                         This.Value_List (Position);
         begin
            Value.Marked := True;
         end;
      end if;

      if not In_From_Space (This, Item) then
         return Item;
      end if;

      declare
         Address : constant Address_Type :=
                     Raven.Objects.Get_Address (Item);
         Cell renames This.Core (Address);
      begin
         if not In_To_Space (This, Cell.Car) then

            --  A vector is one object of however many cells, so all
            --  of them go together.  How many is the length, which is
            --  in the car being replaced -- and is read before it is,
            --  because the right of an assignment is worked out
            --  first.

            if Raven.Objects.Is_Vector (Item)
              or else Raven.Objects.Is_Bytevector (Item)
            then
               Cell.Car :=
                 Raven.Objects.To_Pair
                   (Copy_Block
                      (This, Address,
                       Cells_For (Raven.Objects.To_Integer (Cell.Car))));
            else
               Cell.Car :=
                 Raven.Objects.To_Pair
                   (Copy (This, Address));
            end if;
         end if;

         --  The forwarding pointer left behind is written as a pair,
         --  which is all it needs to be for In_To_Space to know it
         --  again.  What is given back has to carry the tag it arrived
         --  with, though: a closure that has been copied is still a
         --  closure, and handing back the pair would turn every
         --  procedure that survived a collection into a list.

         if Raven.Objects.Is_Closure (Item) then
            return Raven.Objects.To_Closure
              (Raven.Objects.Get_Address (Cell.Car));
         elsif Raven.Objects.Is_Vector (Item) then
            return Raven.Objects.To_Vector
              (Raven.Objects.Get_Address (Cell.Car));
         elsif Raven.Objects.Is_Bytevector (Item) then
            return Raven.Objects.To_Bytevector
              (Raven.Objects.Get_Address (Cell.Car));
         else
            return Cell.Car;
         end if;
      end;

   end Move;

   --------------------
   -- Quick_Allocate --
   --------------------

   function Quick_Allocate
     (This   : in out Instance'Class;
      Car    : Object;
      Cdr    : Object)
      return Object
   is
      Result : constant Object :=
                 Raven.Objects.To_Pair (This.Free);
   begin
      This.Core (This.Free) := (Car, Cdr);
      This.Free := This.Free + 1;
      This.Alloc_Count := This.Alloc_Count + 1;
      This.Total_Alloc_Count := @ + 1;
      return Result;
   end Quick_Allocate;

   ----------------
   -- New_Vector --
   ----------------

   overriding function New_Vector
     (This   : in out Instance;
      Length : Natural)
      return Object
   is
      Count : constant Address_Type := Cells_For (Length);
      Base  : constant Address_Type := Allocate_Block (This, Count);
   begin
      This.Core (Base) :=
        (Raven.Objects.To_Object (Length), Raven.Objects.Nil);

      --  Every element nil, and the half cell an odd length leaves
      --  over as well -- the scan reads both halves of every cell it
      --  walks, so nothing in one may be left as it was found.

      for Offset in 1 .. Count - 1 loop
         This.Core (Base + Offset) :=
           (Raven.Objects.Nil, Raven.Objects.Nil);
      end loop;

      return Raven.Objects.To_Vector (Base);
   end New_Vector;

   --------------------
   -- New_Bytevector --
   --------------------

   overriding function New_Bytevector
     (This   : in out Instance;
      Length : Natural)
      return Object
   is
      V : constant Object := This.New_Vector (Length);
   begin
      --  The same block, said to be a bytevector.  What tells them
      --  apart is the tag and nothing else, because what a bytevector
      --  may hold is checked where it is put in rather than by the
      --  shape of the thing holding it.

      return Raven.Objects.To_Bytevector (Raven.Objects.Get_Address (V));
   end New_Bytevector;

   -------------------
   -- Vector_Length --
   -------------------

   overriding function Vector_Length
     (This : Instance;
      V    : Object)
      return Natural
   is
   begin
      return Raven.Objects.To_Integer
        (This.Core (Raven.Objects.Get_Address (V)).Car);
   end Vector_Length;

   --------------------
   -- Vector_Element --
   --------------------

   overriding function Vector_Element
     (This  : Instance;
      V     : Object;
      Index : Natural)
      return Object
   is
      Cell : constant Address_Type := Element_Cell (V, Index);
   begin
      return (if Index mod 2 = 0
              then This.Core (Cell).Car
              else This.Core (Cell).Cdr);
   end Vector_Element;

   ------------------------
   -- Set_Vector_Element --
   ------------------------

   overriding procedure Set_Vector_Element
     (This  : in out Instance;
      V     : Object;
      Index : Natural;
      Value : Object)
   is
      Cell : constant Address_Type := Element_Cell (V, Index);
   begin
      if Index mod 2 = 0 then
         This.Core (Cell).Car := Value;
      else
         This.Core (Cell).Cdr := Value;
      end if;
   end Set_Vector_Element;

   ------------
   -- Report --
   ------------

   overriding procedure Report (This : Instance) is
   begin
      Ada.Text_IO.Put_Line
        ("Total number of cells:"
         & Address_Type'Image (This.Core'Length / 2));
      Ada.Text_IO.Put_Line
        ("Allocated cell count: "
         & Address_Type'Image (This.Free - This.To_Space));
      Ada.Text_IO.Put_Line
        ("Free cell count: "
         & Address_Type'Image (This.Top - This.Free));
      Ada.Text_IO.Put_Line
        ("Active cell count:"
         & This.Active_Cells'Image
         & "; max:"
         & This.Max_Active_Cells'Image);

      Ada.Text_IO.Put_Line
        ("GC:"
         & Natural'Image (This.GC_Count)
         & " @"
         & Natural'Image (Natural (This.GC_Time * 1000.0))
         & "ms");
      Ada.Text_IO.Put_Line
        ("Allocated cells:"
         & Natural'Image (This.Total_Alloc_Count));
      Ada.Text_IO.Put_Line
        ("Reclaimed cells:"
         & Natural'Image (This.Reclaimed));
   end Report;

   ---------
   -- Set --
   ---------

   overriding procedure Set
     (This    : in out Instance;
      Address : Address_Type;
      Cell    : Raven.Memory.Cell_Type)
   is
   begin
      This.Core (Address) := Cell;
   end Set;

   --------------
   -- Trace_GC --
   --------------

   procedure Trace_GC
     (This    : in out Instance'Class;
      Enabled : Boolean)
   is
   begin
      This.Trace_GC := Enabled;
   end Trace_GC;

end Raven.Engine.Memory;
