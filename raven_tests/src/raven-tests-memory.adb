with Raven.Containers;
with Raven.Engine;
with Raven.Memory;
with Raven.Objects;

package body Raven.Tests.Memory is

   type Stack_Record is
     new Raven.Containers.Abstraction with
      record
         Top : Object := Raven.Objects.Nil;
      end record;

   overriding procedure Mark
     (This : in out Stack_Record;
      Process : not null access procedure (Value : in out Object));

   type Stack_Reference is access all Stack_Record'Class;

   ----------
   -- Mark --
   ----------

   overriding procedure Mark
     (This : in out Stack_Record;
      Process : not null access procedure (Value : in out Object))
   is
   begin
      Process (This.Top);
   end Mark;

   ---------------
   -- Run_Tests --
   ---------------

   procedure Run_Tests is
      Size : constant Natural := 65536;
      Count : constant Natural := 1000;
      M     : constant Raven.Memory.Reference :=
                Raven.Engine.Create_Memory (Size);
      Stack : constant Stack_Reference := new Stack_Record;
   begin
      M.Add_Container (Stack);

      for I in 1 .. Count loop
         Stack.Top := M.Cons (Raven.Objects.To_Object (I), Stack.Top);
      end loop;

      for I in reverse 1 .. Count loop
         declare
            Cell : constant Raven.Memory.Cell_Type :=
                     M.Get (Raven.Objects.Get_Address (Stack.Top));
         begin
            pragma Assert (Cell.Car = Raven.Objects.To_Object (I),
                           "at" & I'Image & ": Expected"
                           & I'Image & " but found "
                           & Raven.Objects.Image (Cell.Car));
            Stack.Top := Cell.Cdr;
         end;
      end loop;
   end Run_Tests;

end Raven.Tests.Memory;
